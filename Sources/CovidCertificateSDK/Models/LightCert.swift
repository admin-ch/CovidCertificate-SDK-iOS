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

public struct LightCert: CovidCertificate, Codable {
    public let person: Person
    public let dateOfBirth: String
    public let version: String

    public var type: CertificateType { .lightCert }

    public var immunisationType: ImmunisationType? { nil }

    private enum CodingKeys: String, CodingKey {
        case person = "nam"
        case dateOfBirth = "dob"
        case version = "ver"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        person = try container.decode(Person.self, forKey: .person)
        version = try container.decode(String.self, forKey: .version)
        dateOfBirth = try container.decode(String.self, forKey: .dateOfBirth)
    }
}
