/*
 * Copyright (c) 2021 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

@testable import CovidCertificateSDK
import XCTest

final class TrustListUpdateTest: XCTestCase {
    func testConcurrentChecks() {
        let update = TestTrustListUpdate(trustStorage: TestTrustStorage(publicKeys: []))
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = .max

        for _ in 0...10000 {
            operationQueue.addOperation {
                update.addCheckOperation(forceUpdate: true, checkOperation: { _ in })
                Thread.sleep(forTimeInterval: 0.1)
                update.addCheckOperation(forceUpdate: false, checkOperation: { _ in })
            }
        }
    }
}
