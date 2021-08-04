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

private class BundleFinder {}

extension Foundation.Bundle {
    /// Returns the resource bundle associated with the current Swift module.
    static var module: Bundle = {
        let myBundle = Bundle(for: BundleFinder.self)

        guard let resourceBundleURL = myBundle.url(
            forResource: "CovidCertificateSDK", withExtension: "bundle")
        else { fatalError("CovidCertificateSDK.bundle not found!") }

        guard let resourceBundle = Bundle(url: resourceBundleURL)
        else { fatalError("Cannot access CovidCertificateSDK.bundle!") }

        return resourceBundle
    }()
}
