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

public struct CheckMode: Equatable, Hashable {
    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    public let id: String
    public let displayName: String
}
