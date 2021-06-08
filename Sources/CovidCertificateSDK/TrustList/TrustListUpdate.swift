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

class TrustlistManager {
    // MARK: - Shared

    public static let shared = TrustlistManager()

    // MARK: - Components

    public let revocationListUpdater = RevocationListUpdate()
    public let trustCertificateUpdater = TrustCertificatesUpdate()
}


class TrustListUpdate {
    // MARK: - Operation queue handling

    private let operationQueue = OperationQueue()

    private var updateOperation : Operation? = nil

    internal var lastUpdate: Date?
    private var lastError : ValidationError? = nil

    // MARK: - Add Check Operation

    init() {
        // ensures that the update request is done before the other tasks
        self.operationQueue.maxConcurrentOperationCount = 1
    }

    public func addCheckOperation(checkOperation: @escaping ((ValidationError?) -> ())) {
        let date = lastUpdate ?? Date(timeIntervalSince1970: 0)

        let updateNeeeded = date < Date().addingTimeInterval(86400)
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

    internal func synchronousUpdate() -> ValidationError? {
        // download data and update local storage
        return nil
    }

    private func startUpdate() {
        self.lastError = self.synchronousUpdate()

        if self.lastError == nil {
            self.lastUpdate = Date()
        }

        self.updateOperation = nil
    }
}
