//
/*
 * Copyright (c) 2021 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import Foundation

protocol TrustlistManagerProtocol {
    static var jwsVerifier: JWSVerifier { get }
    var revocationListUpdater: TrustListUpdate { get }
    var trustCertificateUpdater: TrustListUpdate { get }
    var nationalRulesListUpdater: TrustListUpdate { get }

    var trustStorage: TrustStorageProtocol { get }

    func restartTrustListUpdate(completionHandler: @escaping (() -> Void), updateTimeInterval: TimeInterval)
}

class TrustlistManager: TrustlistManagerProtocol {
    // MARK: - JWS verification

    static var jwsVerifier: JWSVerifier {
        guard let data = Bundle.module.url(forResource: "swiss_governmentrootcaii", withExtension: "der") else {
            fatalError("Signing CA not in Bundle")
        }
        guard let caPem = try? Data(contentsOf: data),
              let verifier = JWSVerifier(rootCertificate: caPem, leafCertMustMatch: TrustlistManager.leafCertificateCommonName) else {
            fatalError("Cannot create certificate from data")
        }
        return verifier
    }

    private static var leafCertificateCommonName: String {
        switch CovidCertificateSDK.currentEnvironment {
        case .dev:
            return "CH01-AppContentCertificate-ref"
        case .abn:
            return "CH01-AppContentCertificate-abn"
        case .prod:
            return "CH01-AppContentCertificate"
        }
    }

    // MARK: - Components

    var trustStorage: TrustStorageProtocol
    var revocationListUpdater: TrustListUpdate
    var trustCertificateUpdater: TrustListUpdate
    var nationalRulesListUpdater: TrustListUpdate

    private let operationQueue = OperationQueue()

    private let timerQueue = DispatchQueue(label: "TrustlistManagerQueue")
    private var timer: DispatchSourceTimer?

    // MARK: - Init

    init() {
        trustStorage = TrustStorage()
        nationalRulesListUpdater = NationalRulesListUpdate(trustStorage: trustStorage)
        revocationListUpdater = RevocationListUpdate(trustStorage: trustStorage)
        trustCertificateUpdater = TrustCertificatesUpdate(trustStorage: trustStorage)
    }

    func restartTrustListUpdate(completionHandler: @escaping (() -> Void), updateTimeInterval: TimeInterval) {
        timer = DispatchSource.makeTimerSource(queue: timerQueue)

        timer?.setEventHandler(handler: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.forceUpdate(countryCode: CountryCodes.Switzerland, completionHandler: completionHandler)
        })

        timer?.schedule(deadline: .now(), repeating: updateTimeInterval)

        timer?.resume()
    }

    private func forceUpdate(countryCode: String, completionHandler: @escaping (() -> Void)) {
        let group = DispatchGroup()

        for updater in [revocationListUpdater, trustCertificateUpdater, nationalRulesListUpdater] {
            group.enter()

            updater.forceUpdate(countryCode: countryCode) {
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completionHandler()
        }
    }
}

class TrustListUpdate {
    // MARK: - Operation queue handling

    private let operationQueue = OperationQueue()
    private let forceUpdateQueue = OperationQueue()

    private let internalQueue = DispatchQueue(label: "TrustListUpdateInternalDispatchQueue")

    private var updateOperation: [String : Operation] = [:]
    private var forceUpdateOperation: [String : Operation] = [:]

    private var lastError: NetworkError?

    let trustStorage: TrustStorageProtocol

    // MARK: - Add Check Operation

    init(trustStorage: TrustStorageProtocol) {
        // ensures that the update request is done before the other tasks
        self.trustStorage = trustStorage
        operationQueue.maxConcurrentOperationCount = 1
        forceUpdateQueue.maxConcurrentOperationCount = 1
    }

    func forceUpdate(countryCode: String = CountryCodes.Switzerland, completion: @escaping (() -> Void)) {
        internalQueue.sync {
            let updateAlreadyRunnning = forceUpdateOperation[countryCode] != nil

            if !updateAlreadyRunnning {
                forceUpdateOperation[countryCode] = BlockOperation(block: { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.startForceUpdate(countryCode: countryCode)
                })

                // !: initialized just above
                forceUpdateQueue.addOperation(forceUpdateOperation[countryCode]!)
            }

            forceUpdateQueue.addOperation {
                completion()
            }
        }
    }

    func addCheckOperation(countryCode: String = CountryCodes.Switzerland, forceUpdate: Bool, checkOperation: @escaping ((NetworkError?) -> Void)) {
        internalQueue.async {
            let updateNeeded = !self.isListStillValid(countryCode: countryCode) || forceUpdate
            let updateAlreadyRunnning = self.updateOperation[countryCode] != nil

            if updateNeeded, !updateAlreadyRunnning {
                self.updateOperation[countryCode] = BlockOperation(block: { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.startUpdate(countryCode: countryCode)
                })

                // !: initialized just above
                self.operationQueue.addOperation(self.updateOperation[countryCode]!)
            }

            self.operationQueue.addOperation {
                checkOperation(self.lastError)
            }
        }
    }

    // MARK: - Update

    func synchronousUpdate(ignoreLocalCache _: Bool = false, countryCode _: String = CountryCodes.Switzerland) -> NetworkError? {
        // download data and update local storage
        nil
    }

    func isListStillValid(countryCode: String = CountryCodes.Switzerland) -> Bool {
        true
    }

    private func startUpdate(countryCode: String = CountryCodes.Switzerland) {
        internalQueue.sync {
            lastError = synchronousUpdate(ignoreLocalCache: true, countryCode: countryCode)
            updateOperation.removeValue(forKey: countryCode)
        }
    }

    private func startForceUpdate(countryCode: String = CountryCodes.Switzerland) {
        internalQueue.sync {
            let error = synchronousUpdate(ignoreLocalCache: true, countryCode: countryCode)
            operationQueue.addOperation {
                self.lastError = error
            }
            forceUpdateOperation.removeValue(forKey: countryCode)
        }
    }

    static var allowedServerTimeDiff: TimeInterval = SDKOptions.defaultAllowedServerTimeDiff
    static var timeshiftDetectionEnabled: Bool = SDKOptions.defaultTimeshiftDetectionEnabled

    func detectTimeshift(response: HTTPURLResponse) -> NetworkError? {
        guard Self.timeshiftDetectionEnabled else { return nil }
        guard let date = response.date else { return nil }

        let adjustedDate = date.addingTimeInterval(response.age)
        let timeShift = abs(Date().timeIntervalSince(adjustedDate))

        if timeShift > Self.allowedServerTimeDiff {
            return .TIME_INCONSISTENCY(timeShift: timeShift)
        }

        return nil
    }
}
