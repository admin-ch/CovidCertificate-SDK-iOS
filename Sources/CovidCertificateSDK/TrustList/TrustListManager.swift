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
    private var timer: Timer?

    // MARK: - Init

    init() {
        trustStorage = TrustStorage()
        nationalRulesListUpdater = NationalRulesListUpdate(trustStorage: trustStorage)
        revocationListUpdater = RevocationListUpdate(trustStorage: trustStorage)
        trustCertificateUpdater = TrustCertificatesUpdate(trustStorage: trustStorage)
    }

    func restartTrustListUpdate(completionHandler: @escaping (() -> Void), updateTimeInterval: TimeInterval) {
        timer = Timer.scheduledTimer(withTimeInterval: updateTimeInterval, repeats: true, block: { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.forceUpdate(completionHandler: completionHandler)
        })

        timer?.fire()
    }

    private func forceUpdate(completionHandler: @escaping (() -> Void)) {
        let group = DispatchGroup()

        for updater in [revocationListUpdater, trustCertificateUpdater, nationalRulesListUpdater] {
            group.enter()

            updater.forceUpdate {
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

    private var updateOperation: Operation?
    private var forceUpdateOperation: Operation?

    private var lastError: NetworkError?

    let trustStorage: TrustStorageProtocol

    // MARK: - Add Check Operation

    init(trustStorage: TrustStorageProtocol) {
        // ensures that the update request is done before the other tasks
        self.trustStorage = trustStorage
        operationQueue.maxConcurrentOperationCount = 1
        forceUpdateQueue.maxConcurrentOperationCount = 1
    }

    func forceUpdate(completion: @escaping (() -> Void)) {
        internalQueue.sync {
            let updateAlreadyRunnning = forceUpdateOperation != nil

            if !updateAlreadyRunnning {
                forceUpdateOperation = BlockOperation(block: { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.startForceUpdate()
                })

                // !: initialized just above
                forceUpdateQueue.addOperation(forceUpdateOperation!)
            }

            forceUpdateQueue.addOperation {
                completion()
            }
        }
    }

    func addCheckOperation(forceUpdate: Bool, checkOperation: @escaping ((NetworkError?) -> Void)) {
        internalQueue.async {
            let updateNeeeded = !self.isListStillValid() || forceUpdate
            let updateAlreadyRunnning = self.updateOperation != nil

            if updateNeeeded, !updateAlreadyRunnning {
                self.updateOperation = BlockOperation(block: { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.startUpdate()
                })

                // !: initialized just above
                self.operationQueue.addOperation(self.updateOperation!)
            }

            self.operationQueue.addOperation {
                checkOperation(self.lastError)
            }
        }
    }

    // MARK: - Update

    func synchronousUpdate(ignoreLocalCache _: Bool = false) -> NetworkError? {
        // download data and update local storage
        return nil
    }

    func isListStillValid() -> Bool {
        return true
    }

    private func startUpdate() {
        internalQueue.sync {
            lastError = synchronousUpdate(ignoreLocalCache: true)
            updateOperation = nil
        }
    }

    private func startForceUpdate() {
        internalQueue.sync {
            let error = synchronousUpdate(ignoreLocalCache: true)
            // Only reset lastError if synchronousUpdate was successful
            if error == nil {
                operationQueue.addOperation {
                    self.lastError = nil
                }
            }
            forceUpdateOperation = nil
        }
    }
}
