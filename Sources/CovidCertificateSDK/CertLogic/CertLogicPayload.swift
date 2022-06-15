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

struct CertLogicPayload: Codable {
    let nam: Person?
    let dob: String?
    let ver: String?
    let v: [Vaccination]?
    let t: [Test]?
    let r: [PastInfection]?
    let h: CertLogicPayloadHeader?
}

struct CertLogicPayloadHeader: Codable {
    let iat: String?
    let exp: String?
    let isLight: Bool
    let mode: String?
    let iss: String?
    let kid: String?
}
