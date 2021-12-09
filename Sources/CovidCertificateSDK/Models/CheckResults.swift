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

public struct CheckResults {
    public let signature: Result<ValidationResult, ValidationError>
    public let revocationStatus: Result<ValidationResult, ValidationError>?
    public let nationalRules: Result<VerificationResult, NationalRulesError>
    public let modeResults: Result<ModeResults, NationalRulesError>
}

public struct ModeResults: Equatable {
    public let results: [CheckMode: ModeCheckResult]

    public func getResult(for mode: CheckMode) -> ModeCheckResult? {
        results.keys.contains(mode) ? results[mode] : nil
    }
}
