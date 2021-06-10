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

public protocol TrustlistManagerProtocol {
    var revocationListUpdater: TrustListUpdate { get }
    var trustCertificateUpdater: TrustListUpdate { get }
    var nationalRulesListUpdater: TrustListUpdate { get }

    var trustStorage : TrustStorageProtocol { get }

    func restartTrustListUpdate(completionHandler: @escaping (() -> ()), updateTimeInterval: TimeInterval)
}

class TrustlistManager : TrustlistManagerProtocol {
    // MARK: - Components

    var trustStorage : TrustStorageProtocol
    var revocationListUpdater : TrustListUpdate
    var trustCertificateUpdater : TrustListUpdate
    var nationalRulesListUpdater : TrustListUpdate

    private let operationQueue = OperationQueue()
    private var timer : Timer? = nil

    // MARK: - Init
    
    init() {
        self.trustStorage = TrustStorage()
        self.nationalRulesListUpdater = NationalRulesListUpdate(trustStorage: self.trustStorage)
        self.revocationListUpdater = RevocationListUpdate(trustStorage: self.trustStorage)
        self.trustCertificateUpdater = TrustCertificatesUpdate(trustStorage: self.trustStorage)
    }

    func restartTrustListUpdate(completionHandler: @escaping (() -> ()), updateTimeInterval: TimeInterval) {
        self.timer = Timer.scheduledTimer(withTimeInterval: updateTimeInterval, repeats: true, block: { [weak self] timer in
            guard let strongSelf = self else { return }
            strongSelf.forceUpdate(completionHandler: completionHandler)
        })

        self.timer?.fire()
    }

    private func forceUpdate(completionHandler: @escaping (() -> ())) {
        let group = DispatchGroup()

        for updater in [self.nationalRulesListUpdater, self.revocationListUpdater, self.trustCertificateUpdater] {
            group.enter()

            updater.addCheckOperation(checkOperation: { _ in
                group.leave()
            }, forceUpdate: true)
        }

        group.notify(queue: .main) {
            completionHandler()
        }
    }
}

public class TrustListUpdate {
    // MARK: - Operation queue handling

    private let operationQueue = OperationQueue()

    private var updateOperation : Operation? = nil

    internal var lastUpdate: Date?
    private var lastError : NetworkError? = nil

    internal let trustStorage : TrustStorageProtocol

    // MARK: - Add Check Operation

    init(trustStorage: TrustStorageProtocol) {
        // ensures that the update request is done before the other tasks
        self.trustStorage = trustStorage
        self.operationQueue.maxConcurrentOperationCount = 1
    }

    public func addCheckOperation(checkOperation: @escaping ((NetworkError?) -> ()), forceUpdate: Bool = false) {
        let updateNeeeded = !self.isListStillValid() || forceUpdate
        let updateAlreadyRunnning = self.updateOperation != nil

        if updateNeeeded && !updateAlreadyRunnning {
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

    // MARK: - Update

    internal func synchronousUpdate() -> NetworkError? {
        // download data and update local storage
        return nil
    }

    internal func isListStillValid() -> Bool {
        return true
    }

    private func startUpdate() {
        self.lastError = self.synchronousUpdate()

        if self.lastError == nil {
            self.lastUpdate = Date()
        }

        self.updateOperation = nil
    }

    private func forceUpdate() {
        
    }
}
