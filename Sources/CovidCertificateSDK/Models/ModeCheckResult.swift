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

public enum ModeCheckValidationCode : String {
    case success = "SUCCESS"
    case success2g = "SUCCESS_2G"
    case success2gPlus = "SUCCESS_2G_PLUS"
    case isLight = "IS_LIGHT"
    case unknownMode = "UNKNOWN_MODE"
    case unknown = "UNKNOWN"

    public var isValid : Bool {
        return self == .success || self == .success2g || self == .success2gPlus
    }

    public var is2GSuccess : Bool {
        return self == .success2g || self == .success2gPlus
    }

    public var is2GTestSuccess : Bool {
        return self == .success2gPlus
    }
}

public struct ModeCheckResult: Equatable {
    public let code: ModeCheckValidationCode

    // MARK: - Init

    init(validationCode: String) {
        code = ModeCheckValidationCode(rawValue: validationCode) ?? .unknown
    }

    // MARK: - API

    public var isValid: Bool {
        return code.isValid
    }

    public func isModeUnknown() -> Bool {
        return code == .unknownMode
    }

    public func isLightUnsupported() -> Bool {
        return code == .isLight
    }

    public func isUnknown() -> Bool {
        return code == .unknown
    }
}
