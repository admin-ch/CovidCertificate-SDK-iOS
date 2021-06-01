//
@testable import CovidCertificateSDK
/*
 * Copyright (c) 2021 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */
import XCTest

final class CovidCertificateSDKTests: XCTestCase {
    var verifier: ChCovidCert {
        let ver = ChCovidCert(environment: SDKEnvironment.dev)
        return ver
    }

    override class func setUp() {
        CovidCertificateSDK.initialize(environment: SDKEnvironment.dev)
    }

    func testDevSignature() {
        let data = Data(base64Encoded: "hGpTaWduYXR1cmUxTqIBOCQESJpq386TFOsXQFkBCaQBZkNIIEJBRwQaYn+8rQYaYJ6JLTkBA6EBpGF2gapiY2l4HjAxOkNIOjgxQzlBMjVEQ0U4MkExNUQ1QzZDREVDRmJjb2JDSGJkbgFiZHRqMjAyMS0wNC0zMGJpc3gfQnVuZGVzYW10IGbDvHIgR2VzdW5kaGVpdCAoQkFHKWJtYW1PUkctMTAwMDMwMjE1Ym1wbEVVLzEvMjAvMTUwN2JzZAJidGdpODQwNTM5MDA2YnZwajExMTkzNDkwMDdjZG9iajE5NDMtMDItMDFjbmFtpGJmbmdNw7xsbGVyYmduZ0PDqWxpbmVjZm50Z01VRUxMRVJjZ250ZkNFTElORWN2ZXJlMS4wLjA=")!

        let signature = Data(base64Encoded: "K9bHTIul7baBNMX3wpGVIGheA9MfsuM3DEwifN2FwbtzxVBxfBnAh6Gdov91zMT4H+1SZwL8k3ikEGOPwhyJla9uIUlXiR0Dt4GYwpazKXY490FsdOligjx7x7eLVYDdfTCG8tLlcEJ/qtcey8B4UnQoBKcZ7KTVfZ8tJwfg3YJKBzL0xtthP2PbSNrkZBopqpds1AasmSTJ9NP2/XDs0nvEm2Qwc39rQpWrwyeEtbxXCI6zx9hIotQ/t1ePoP0yqJYAKVv7zQREkeqYKLieUEplA7FBlAl9F+KEPfssxrbxi21KSkEcWXKO1kkDfQaqjlMF/nQuZYmcdtcwe/ohBg==")!

        let keydata = Data(base64Encoded: "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4uZO4/7tneZ3XD5OAiTyoANOohQZC+DzZ4YC0AoLnEO+Z3PcTialCuRKS1zHfujNPI0GGG09DRVVXdv+tcKNXFDt/nRU1zlWDGFf4/63l5RIjkWFD3JFKqR8IlcJjrYYxstuZs3May3SGQJ+kZaeH5GFZMRvE0waHqMxbfwakvjf8qyBXCrZ1WsK+XJf7iYbJS2dO1a5HnegxPuRA7Zz8ikO7QRzmSongqOlkejEaIkFjx7gLGTUsOrBPYa5sdZqinDwmnjtKi52HLWarMXs+t1MN4etIp7GE7/zarjBNxk1Efiiwl+RdcwJ2uVwfrgzxfv3/TekZF8IUykV2Geu3QIDAQAB")!

        let attributes: [CFString: Any] = [kSecAttrKeyClass: kSecAttrKeyClassPublic,
                                           kSecAttrKeyType: kSecAttrKeyTypeRSA]
        let key = SecKeyCreateWithData(keydata as CFData, attributes as CFDictionary, nil)!

        let algorithm: SecKeyAlgorithm = .rsaSignatureMessagePSSSHA256

        var error: Unmanaged<CFError>?
        let result = SecKeyVerifySignature(key, algorithm, data as CFData, signature as CFData, &error)
        if let err = error?.takeUnretainedValue().localizedDescription {
            print(err)
        }
        error?.release()
        XCTAssertTrue(result)
    }

    func testCompleteToolchain() {
        let hcert = "HC1:NCFJ60EG0/3WUWGSLKH47GO0KNJ9DSWQIIWT9CK+500XKY-CE59-G80:84F3ZKG%QU2F30GK JEY50.FK6ZK7:EDOLOPCF8F746KG7+59.Q6+A80:6JM8SX8RM8.A8TL6IA7-Q6.Q6JM8WJCT3EYM8XJC +DXJCCWENF6OF63W5$Q69L6%JC+QE$.32%E6VCHQEU$DE44NXOBJE719$QE0/D+8D-ED.24-G8$:8.JCBECB1A-:8$96646AL60A60S6Q$D.UDRYA 96NF6L/5QW6307KQEPD09WEQDD+Q6TW6FA7C466KCN9E%961A6DL6FA7D46JPCT3E5JDJA76L68463W5/A6..DX%DZJC3/DH$9- NTVDWKEI3DK2D4XOXVD1/DLPCG/DU2D4ZA2T9GY8MPCG/DY-CAY81C9XY8O/EZKEZ96446256V50G7AZQ4CUBCD9-FV-.6+OJROVHIBEI3KMU/TLRYPM0FA9DCTID.GQ$NYE3NPBP90/9IQH24YL7WMO0CNV1 SDB1AHX7:O26872.NV/LC+VJ75L%NGF7PT134ERGJ.I0 /49BB6JA7WKY:AL19PB120CUQ37XL1P9505-YEFJHVETB3CB-KE8EN9BPQIMPRTEW*DU+X2STCJ6O6S4XXVJ$UQNJW6IIO0X20D4S3AWSTHTA5FF7I/J9:8ALF/VP 4K1+8QGI:N0H 91QBHPJLSMNSJC BFZC5YSD.9-9E5R8-.IXUB-OG1RRQR7JEH/5T852EA3T7P6 VPFADBFUN0ZD93MQY07/4OH1FKHL9P95LIG841 BM7EXDR/PLCUUE88+-IX:Q"
//            let hcert = "HC1:NCFOXNYTSFDHJI8-.O0:A%1W RI%.BI06-JV1WG21QKP85NPV*JVH5MVI$068WA.VU1/M:ZH6I1$4JN:IN1MPK9V L9L6O MH8VWJE+9663FHFE$96L07Z*65LEK.EUW61R6A46EN9U3Q+QUSH9UKPSH9WC5PF6846A$Q 76SW6%V98T5%BIMI5DN9XW5O PICA$O7T6LEJOA+MY55EII-EBBAK%ZM2L6:/6N9R%EPXCROGO3HO-HQKOOEC5L64HX6IAS3DS2980IQRDOUHLO$GAHLW 70SO:GOLIROGO3T59YLLYP-HQLTQ9R0+L69/9E2A1PB2AD$ZJ*DJWP42W5JY4I47-V5KV3Q0531TAYKD%0QCNH9LZ33/HLIJL8JF8JF0IIVP1TX2SK6L8K6G1%5ECJVL3FI:1L$8:SN55K*0GQ2VJ*035C26VQONPOUZ9NVUT0KVPNB8XB8-RD/VR7GSEFRCSSUVRXNIVDCFLCP6UV6GXO7RT* CU.7D DLTL.GHME2MMNPH5 ET3PFF1EY+D6 I5FUSNS7J8+Z2Q:6R6RXAO59WJNP*WML/T93N*9U%Z953T1K9$%GIOOTW4 X06$C-WHIRC1+IWEBJCBTICQPFY63G8L 5HHOT:ED399X VL2NF1QUKB2XDT4W.3U38K%RH$WVG*R1FVNJK 27X7I$LH6:SLLI.$VE:KRP15C2SZE$GD$MAU93+ 9EWU1H7/%R/6RMSJGOPPJB-/L$PLHYF%2AKY46NG*9TYRA-PBQ8LFD7GX5FOVODAANJKLGRFW-TEC6BF7R"

        let dgcHolder = try? verifier.decode(encodedData: hcert).get()
        XCTAssertNotNil(dgcHolder)

        verifier.checkSignature(cose: dgcHolder!) { result in
            let res: ValidationResult? = try? result.get()
            XCTAssertNotNil(res)
            XCTAssertTrue(res!.isValid)
        }
        verifier.checkRevocationStatus(dgc: dgcHolder!.healthCert) { result in
            let res: ValidationResult? = try? result.get()
            XCTAssertNotNil(res)
            XCTAssertTrue(res!.isValid)
        }
//            verifier.checkNationalRules(dgc: dgcHolder!.healthCert) {result in
//                let res : VerificationResult? = try? result.get()
//                XCTAssertNotNil(res)
//                XCTAssertTrue(res!.isValid)
//            }
    }

    func testNationalRulesVerifier() {
        _ = NationalRulesVerifier()
    }

    func testCWTIsNotExpired() {}

    func testCWTIsNotIssuedInTheFuture() {}

    /// VACCINE TESTS

    func testVaccineDiseaseTargetedHasToBeSarsCoV2() {
        let hcert_targets_covid = "HC1:NCFTW2SX7YUO/232Y9F*A3.2%K74MH8 RCOI3%4DHQ/-BN0R:XKJFR%PEFD3M%T7EDYO35ZI7OHIYVOA2:$5JDNJMOTE9./3GIAO7E:N00F89WVVY7FDRLFJLFWTQ87HOD1P4MVRYQ32BQTV/9WI+V%DKBW5A6G23FFV83GHCXT1OA0M59*E7PAU IUSQJG4112JBE.G49VA1%DTDI160VCOC1SFKRUY13K31G0Y1JD90CCBQFS5V6WYA.J5Q35Z2TR01+13TNK4J9NG9LL0GT7ETB5HI%NVHJC:888O12W5KSSDO0T8BP54MW2B$A3GHY.APKJ3JI%RMP6BLD5X.7JOJ612C:J*70 E3%M9Z+L5ZB*UIG7TIMIQ%KOAI5-H-OR3ZIDV23ZK53LTE3ZKQI/N $RW6EWLBKQ6*:P%6U6Q55XI93KU%OOL1RG9 VP$T63PHJ23JP1WIQUW4-K4JT2HBO2JRU41I7QY:H217NBSZ.0T4AYVRI$JE F+PPX8CSTE72L5WU+VV%J789OTUJ5ZRO%BS8LYLOK29SEWWRR1061VV*CQF RZ7PFQVNPG"

        let dgcHolder = try? verifier.decode(encodedData: hcert_targets_covid).get()
        XCTAssertNotNil(dgcHolder)

        verifier.checkNationalRules(dgc: dgcHolder!.healthCert) { result in
            switch result {
            case .failure(.WRONG_DISEASE_TARGET):
                XCTAssertTrue(false)
            default:
                XCTAssertTrue(true)
            }
        }

        let hcert_does_not_target_covid = "HC1:NCFOXN%TS3DH3ZSUZK+.V0ETD%65NL-AH%TAIOOP-IPOIZLH4G5EDBUV2ZMIN9HNO4*J8OX4W$C2VL*LA 43/IE%TE6UG+ZEAT1HQ13W1:O1YUI%F1PN1/T1J$HTR9/O14SI.J9DYHZROVZ05QNZ 20OP748$NI4L6-O16VH6ZL4XP:N6ON1 *L:O8PN1QP5O PLU9A/RUX96 B0V1ZZB.T12.H.ZJ$%HN 9GTBIQ1EK0ZIEQKERQ8IY1I$HH%U8 9PS5OH6*ZUFXFE.R:YN/P3JRH8LHGL2-LH/CJTK96L6SR9MU9RP5 R1:PI/E2$4J6AL.+I9UV6$0+BNPHNBC7CTR3$VDY0DUFRLN/Y0Y/K9/IIF0%:K6*K$X4FUTD14//E3:FL.B$JDBLEH-BL1H6TK-CI:ULOPD6LF20HFJC3DAYJDPKDUDBQEAJJKHHGEC8ZI9$JAQJKZ%K+EPM+8172WLC0NQ-/RRCTCIMCJENCB%BK8YN2MI8DL8HN96URFW3:F3.BXDU$ZRMEO7DSPCEK45PJ3+UND5K/831-7KH12$DUBFUA60JFADAA%8G*QLEG"
        let invalidDgcHolder = try? verifier.decode(encodedData: hcert_does_not_target_covid).get()
        XCTAssertNotNil(invalidDgcHolder)

        verifier.checkNationalRules(dgc: invalidDgcHolder!.healthCert) { result in
            switch result {
            case .failure(.WRONG_DISEASE_TARGET):
                XCTAssertTrue(true)
            default:
                XCTAssertTrue(false)
            }
        }
    }

    var dateFormatter: DateFormatter {
        let d = DateFormatter()
        d.dateFormat = "yyyy-MM-dd"
        return d
    }

    private func generateVacineCert(dn: UInt64, sd: UInt64, ma: String, mp: String, tg: String, vp: String, todayIsDateComponentsAfterVaccination: DateComponents) -> EuHealthCert {
        let today = Calendar.current.startOfDay(for: Date())
        let time = Calendar.current.date(byAdding: todayIsDateComponentsAfterVaccination, to: today)!
        let vaccineDate = dateFormatter.string(from: time)
        let test = """
           {
             "v": [
               {
                 "ci": "01:CH:9C595501BBC294450BD0F6E2",
                 "co": "BE",
                 "dn": \(dn),
                 "dt": "\(vaccineDate)",
                 "is": "Bundesamt für Gesundheit (BAG)",
                 "ma": "\(ma)",
                 "mp": "\(mp)",
                 "sd": \(sd),
                 "tg": "\(tg)",
                 "vp": "\(vp)"
               }
             ],
             "dob": "1990-12-12",
             "nam": {
               "fn": "asdf",
               "gn": "asdf",
               "fnt": "ASDF",
               "gnt": "ASDF"
             },
             "ver": "1.0.0"
           }
        """
        return try! JSONDecoder().decode(EuHealthCert.self, from: test.data(using: .utf8)!)
    }

    func testVaccineMustBeInWhitelist() {
        let hcert = generateVacineCert(dn: 2, sd: 2, ma: "ORG-100001699", mp: "EU/1/21/1529", tg: Disease.SarsCov2.rawValue, vp: "J07BX03", todayIsDateComponentsAfterVaccination: DateComponents(day: -15))

        verifier.checkNationalRules(dgc: hcert) { result in
            switch result {
            case let .success(r):
                XCTAssertTrue(r.isValid)
            default:
                XCTAssertTrue(false)
            }
        }

        let invalid_hcert = generateVacineCert(dn: 2, sd: 2, ma: "ORG-100001600", mp: "Sputnik-VII", tg: Disease.SarsCov2.rawValue, vp: "J07BX03", todayIsDateComponentsAfterVaccination: DateComponents(day: -15))
        verifier.checkNationalRules(dgc: invalid_hcert) { result in
            switch result {
            case .failure(.NO_VALID_PRODUCT):
                XCTAssertTrue(true)
            default:
                XCTAssertTrue(false)
            }
        }
    }

    /// A vaccine which needs two shots
    func test2of2VaccineIsValidToday() {
        let hcert = generateVacineCert(dn: 2, sd: 2, ma: "ORG-100001699", mp: "EU/1/21/1529", tg: Disease.SarsCov2.rawValue, vp: "J07BX03", todayIsDateComponentsAfterVaccination: DateComponents(day: 0))

        verifier.checkNationalRules(dgc: hcert) { result in
            switch result {
            case let .success(r):
                XCTAssertTrue(r.isValid)
                XCTAssertEqual(r.validFrom, Calendar.current.startOfDay(for: Date()))
            default:
                XCTAssertTrue(false)
            }
        }
    }

    /// A vaccine which indicates 1/1 but is actually N/N means we had previous infections, and is valid from the day of vaccination
    func testVaccine1of1WithPreviousInfectionsIsValidToday() {
        let hcert = generateVacineCert(dn: 1, sd: 1, ma: "ORG-100001699", mp: "EU/1/21/1529", tg: Disease.SarsCov2.rawValue, vp: "J07BX03", todayIsDateComponentsAfterVaccination: DateComponents(day: 0))

        verifier.checkNationalRules(dgc: hcert) { result in
            switch result {
            case let .success(r):
                XCTAssertTrue(r.isValid)
                XCTAssertEqual(r.validFrom, Calendar.current.startOfDay(for: Date()))
            default:
                XCTAssertTrue(false)
            }
        }
    }

    /// A vaccine which only needs one shot is only valid after 15 days
    func testVaccine1of1IsValidAfter15Days() {
        let hcert = generateVacineCert(dn: 1, sd: 1, ma: "ORG-100001417", mp: "EU/1/20/1525", tg: Disease.SarsCov2.rawValue, vp: "J07BX03", todayIsDateComponentsAfterVaccination: DateComponents(day: -15))

        verifier.checkNationalRules(dgc: hcert) { result in
            switch result {
            case let .success(r):
                XCTAssertTrue(r.isValid)
            default:
                XCTAssertTrue(false)
            }
        }

        let invalid_cert = generateVacineCert(dn: 1, sd: 1, ma: "ORG-100001417", mp: "EU/1/20/1525", tg: Disease.SarsCov2.rawValue, vp: "J07BX03", todayIsDateComponentsAfterVaccination: DateComponents(day: -14))

        verifier.checkNationalRules(dgc: invalid_cert) { result in
            switch result {
            case let .success(r):
                XCTAssertFalse(r.isValid)
                XCTAssertEqual(r.validFrom, Calendar.current.startOfDay(for: Calendar.current.date(byAdding: DateComponents(day: 1), to: Date())!))
            default:
                XCTAssertTrue(false)
            }
        }
    }

    /// A valid vaccine which needs 2 shots is only valid if the certificate states that this is shot N/N
    func testWeNeedAllShots() {
        let hcert = generateVacineCert(dn: 2, sd: 2, ma: "ORG-100001699", mp: "EU/1/21/1529", tg: Disease.SarsCov2.rawValue, vp: "J07BX03", todayIsDateComponentsAfterVaccination: DateComponents(day: -15))

        verifier.checkNationalRules(dgc: hcert) { result in
            switch result {
            case let .success(r):
                XCTAssertTrue(r.isValid)
            default:
                XCTAssertTrue(false)
            }
        }

        let invalid_hcert = generateVacineCert(dn: 1, sd: 2, ma: "ORG-100001699", mp: "EU/1/21/1529", tg: Disease.SarsCov2.rawValue, vp: "J07BX03", todayIsDateComponentsAfterVaccination: DateComponents(day: -15))

        verifier.checkNationalRules(dgc: invalid_hcert) { result in
            switch result {
            case .failure(.NOT_FULLY_PROTECTED):
                XCTAssertTrue(true)
            default:
                XCTAssertTrue(false)
            }
        }
    }

    /// TEST TESTS
    let isoDateFormatter = ISO8601DateFormatter()
    private func generateTestCert(testType: String, testResultType: TestResult, name: String, disease: String, sampleCollectionWasAgo: DateComponents) -> EuHealthCert {
        let now = Date()
        let sampleCollection = Calendar.current.date(byAdding: sampleCollectionWasAgo, to: now)!
        let testResult = Calendar.current.date(byAdding: DateComponents(hour: 10), to: sampleCollection)!
        let sampleCollectionTime = isoDateFormatter.string(from: sampleCollection)
        let testResultTime = isoDateFormatter.string(from: testResult)
        let test = """
           {
             "t": [
               {
                 "ci": "urn:uvci:01:AT:71EE2559DE38C6BF7304FB65A1A451ECE",
                 "co": "AT",
                 "dr": "\(testResultTime)",
                 "is": "BMSGPK Austria",
                 "ma": "\(name)",
                 "nm": "\(name)",
                 "sc": "\(sampleCollectionTime)",
                 "tc": "Testing center Vienna 1",
                 "tg": "\(disease)",
                 "tr": "\(testResultType.rawValue)",
                 "tt": "\(testType)"
               }
             ],
             "dob": "1998-02-26",
             "nam": {
               "fn": "Musterfrau-Gößinger",
               "gn": "Gabriele",
               "fnt": "MUSTERFRAU<GOESSINGER",
               "gnt": "GABRIELE"
             },
             "ver": "1.0.0"
           }
        """
        return try! JSONDecoder().decode(EuHealthCert.self, from: test.data(using: .utf8)!)
    }

    func testTestDiseaseTargetedHasToBeSarsCoV2() {
        let hcert = generateTestCert(testType: TestType.Pcr.rawValue, testResultType: TestResult.Negative, name: "Nucleic acid amplification with probe detection", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -10))

        verifier.checkNationalRules(dgc: hcert) { result in
            switch result {
            case let .success(r):
                XCTAssertTrue(r.isValid)
            default:
                XCTAssertTrue(false)
            }
        }

        let invalid_hcert = generateTestCert(testType: TestType.Pcr.rawValue, testResultType: TestResult.Negative, name: "Nucleic acid amplification with probe detection", disease: "12345", sampleCollectionWasAgo: DateComponents(hour: -10))

        verifier.checkNationalRules(dgc: invalid_hcert) { result in
            switch result {
            case .failure(.WRONG_DISEASE_TARGET):
                XCTAssertTrue(true)
            default:
                XCTAssertTrue(false)
            }
        }
    }

    func testTypeHasToBePcrOrRat() {
        let hcert_rat = generateTestCert(testType: TestType.Rat.rawValue, testResultType: TestResult.Negative, name: "1232", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -10))

        verifier.checkNationalRules(dgc: hcert_rat) { result in
            switch result {
            case let .success(r):
                XCTAssertTrue(r.isValid)
            default:
                XCTAssertTrue(false)
            }
        }
        let hcert_pcr = generateTestCert(testType: TestType.Pcr.rawValue, testResultType: TestResult.Negative, name: "Nucleic acid amplification with probe detection", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -10))

        verifier.checkNationalRules(dgc: hcert_pcr) { result in
            switch result {
            case let .success(r):
                XCTAssertTrue(r.isValid)
            default:
                XCTAssertTrue(false)
            }
        }

        let invalid_cert = generateTestCert(testType: "asdbas", testResultType: TestResult.Negative, name: "Nucleic acid amplification with probe detection", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -10))

        verifier.checkNationalRules(dgc: invalid_cert) { result in
            switch result {
            case .failure(.WRONG_TEST_TYPE):
                XCTAssertTrue(true)
            default:
                XCTAssertTrue(false)
            }
        }
    }

    func testTestHasToBeInWhitelist() {
        let invalid_cert_rat = generateTestCert(testType: TestType.Rat.rawValue, testResultType: TestResult.Negative, name: "abcdef", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -10))

        verifier.checkNationalRules(dgc: invalid_cert_rat) { result in
            switch result {
            case .failure(.NO_VALID_PRODUCT):
                XCTAssertTrue(true)
            default:
                XCTAssertTrue(false)
            }
        }
    }

    func testPcrTestsAreAlwaysAccepted() {
        // pcr tests are always accepte
        let invalid_cert_pcr = generateTestCert(testType: TestType.Pcr.rawValue, testResultType: TestResult.Negative, name: "abcdef", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -10))

        verifier.checkNationalRules(dgc: invalid_cert_pcr) { result in
            switch result {
            case let .success(r):
                XCTAssertTrue(r.isValid)
            default:
                XCTAssertTrue(false)
            }
        }
    }

    func testPcrIsValidFor72h() {
        let hcert = generateTestCert(testType: TestType.Pcr.rawValue, testResultType: TestResult.Negative, name: "Nucleic acid amplification with probe detection", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -71))
        verifier.checkNationalRules(dgc: hcert) { result in
            switch result {
            case let .success(r):
                /// TEST MUST BE VALID
                XCTAssertTrue(r.isValid)
            default:
                XCTAssertTrue(false)
            }
        }

        let invalid_hcert = generateTestCert(testType: TestType.Pcr.rawValue, testResultType: TestResult.Negative, name: "Nucleic acid amplification with probe detection", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -72))
        verifier.checkNationalRules(dgc: invalid_hcert) { result in
            switch result {
            case let .success(r):
                /// TEST MUST BE INVALID
                XCTAssertFalse(r.isValid)
            default:
                XCTAssertTrue(false)
            }
        }
    }

    func testRatIsValidFor24h() {
        let hcert = generateTestCert(testType: TestType.Rat.rawValue, testResultType: TestResult.Negative, name: "1232", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -23))
        verifier.checkNationalRules(dgc: hcert) { result in
            switch result {
            case let .success(r):
                /// TEST MUST BE VALID
                XCTAssertTrue(r.isValid)
            default:
                XCTAssertTrue(false)
            }
        }

        let invalid_hcert = generateTestCert(testType: TestType.Rat.rawValue, testResultType: TestResult.Negative, name: "1232", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -24))
        verifier.checkNationalRules(dgc: invalid_hcert) { result in
            switch result {
            case let .success(r):
                /// TEST MUST BE INVALID
                XCTAssertFalse(r.isValid)
            default:
                XCTAssertTrue(false)
            }
        }
    }

    func testTestResultHasToBeNegative() {
        let hcert_rat = generateTestCert(testType: TestType.Rat.rawValue, testResultType: TestResult.Positive, name: "1232", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -23))
        verifier.checkNationalRules(dgc: hcert_rat) { result in
            switch result {
            case .failure(.POSITIVE_RESULT):
                XCTAssertTrue(true)
            default:
                XCTAssertTrue(false)
            }
        }

        let hcert_pcr = generateTestCert(testType: TestType.Pcr.rawValue, testResultType: TestResult.Positive, name: "Nucleic acid amplification with probe detection", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -71))
        verifier.checkNationalRules(dgc: hcert_pcr) { result in
            switch result {
            case .failure(.POSITIVE_RESULT):
                XCTAssertTrue(true)
            default:
                XCTAssertTrue(false)
            }
        }
    }

    /// RECOVERY TESTS

    private func generateRecoveryCert(validSinceNow: DateComponents, validFromNow: DateComponents, firstResultWasAgo: DateComponents, tg: String) -> EuHealthCert {
        let now = Calendar.current.startOfDay(for: Date())
        let validFrom = Calendar.current.date(byAdding: validSinceNow, to: now)!
        let validUntil = Calendar.current.date(byAdding: validFromNow, to: now)!
        let firstPositiveTest = Calendar.current.date(byAdding: firstResultWasAgo, to: now)!
        let test = """
           {
             "r": [
               {
                 "ci": "urn:uvci:01:AT:858CC18CFCF5965EF82F60E493349AA5Y",
                 "co": "AT",
                 "df": "\(dateFormatter.string(from: validFrom))",
                 "du": "\(dateFormatter.string(from: validUntil))",
                 "fr": "\(dateFormatter.string(from: firstPositiveTest))",
                 "is": "BMSGPK Austria",
                 "tg": "\(tg)"
               }
             ],
             "dob": "1998-02-26",
             "nam": {
               "fn": "Musterfrau-Gößinger",
               "gn": "Gabriele",
               "fnt": "MUSTERFRAU<GOESSINGER",
               "gnt": "GABRIELE"
             },
             "ver": "1.0.0"
           }
        """
        return try! JSONDecoder().decode(EuHealthCert.self, from: test.data(using: .utf8)!)
    }

    func testRecoveryDiseaseTargetedHasToBeSarsCoV2() {
        let hcert = generateRecoveryCert(validSinceNow: DateComponents(day: -10), validFromNow: DateComponents(month: 6), firstResultWasAgo: DateComponents(day: -20), tg: Disease.SarsCov2.rawValue)
        verifier.checkNationalRules(dgc: hcert) { result in
            switch result {
            case let .success(r):
                XCTAssertTrue(r.isValid)
            default:
                XCTAssertTrue(false)
            }
        }

        let invalid = generateRecoveryCert(validSinceNow: DateComponents(day: -10), validFromNow: DateComponents(month: 6), firstResultWasAgo: DateComponents(day: -20), tg: "abcdef")
        verifier.checkNationalRules(dgc: invalid) { result in
            switch result {
            case .failure(.WRONG_DISEASE_TARGET):
                XCTAssertTrue(true)
            default:
                XCTAssertTrue(false)
            }
        }
    }
    
    func testSanityCheckForDateCalculations() {
        var dateFormatter: DateFormatter {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = DATE_FORMAT
            return dateFormatter
        }
      
        let validTestResult = dateFormatter.date(from: "2021-05-08")!
        let calculatedValidUntil = Calendar.current.date(byAdding: DateComponents(day: 179), to: validTestResult)!
        
        let calculatedValidFrom = Calendar.current.date(byAdding: DateComponents(day: 10), to: validTestResult)!
        
    
        let trueValidFrom = dateFormatter.date(from: "2021-05-18")!
        let dayBeforeValidFrom = Calendar.current.date(byAdding: DateComponents(day:-1), to: trueValidFrom)!
        let trueValidUntil = dateFormatter.date(from: "2021-11-03")!
        let dayAfterTrueValidUntil = dateFormatter.date(from: "2021-12-03")!
        
        // before validFrom it fails
        // certificate has entry trueValidFrom
        // today is dayBeforeValidFrom
        XCTAssertTrue(trueValidFrom.isAfter(dayBeforeValidFrom))
        
        // at trueValidFrom it succeeds
        // certificate has entry calculatedValidFrom
        // today is trueValidFrom
        XCTAssertFalse(calculatedValidFrom.isAfter(trueValidFrom))
        
        // at trueValidUntil it succeeds
        // certificate has entry calculatedValidUntil
        // today is trueValidUntil
        XCTAssertFalse(calculatedValidUntil.isBefore(trueValidUntil))
        
        
        // calculated valid from should match
        XCTAssertTrue(calculatedValidFrom == trueValidFrom)
        // calculated valid until should match
        XCTAssertTrue(calculatedValidUntil == trueValidUntil)
        
        //the certificate is not valid one day after trueValidUntil
        // certificate has entry calculatedValidUntil
        // today is dayAfterTrueValidUntil
        XCTAssertTrue(calculatedValidUntil.isBefore(dayAfterTrueValidUntil))
       
    }

    func testCertificateIsValidFor180DaysAfterTestResult() {
        // The certificate was issued 179 days ago, which means it is still valid today (the 180th day)
        let hcert = generateRecoveryCert(validSinceNow: DateComponents(day: -10), validFromNow: DateComponents(month: 0), firstResultWasAgo: DateComponents(day: -179), tg: Disease.SarsCov2.rawValue)
        verifier.checkNationalRules(dgc: hcert) { result in
            switch result {
            case let .success(r):
                // SHOULD BE VALID
                XCTAssertTrue(r.isValid)
            default:
                XCTAssertTrue(false)
            }
        }
        // the certificate should not be valid anymore, since it was issued yesterday 179 days ago (hence yesterday was the 180th day)
        let hcert_invalid = generateRecoveryCert(validSinceNow: DateComponents(day: -10), validFromNow: DateComponents(month: 0), firstResultWasAgo: DateComponents(day: -180), tg: Disease.SarsCov2.rawValue)
        verifier.checkNationalRules(dgc: hcert_invalid) { result in
            switch result {
            case let .success(r):
                // SHOULD BE INVALID
                XCTAssertFalse(r.isValid)
            default:
                XCTAssertTrue(false)
            }
        }
    }

    func testTestIsOnlyValid10DaysAfterTestResult() {
        let hcert = generateRecoveryCert(validSinceNow: DateComponents(day: -10), validFromNow: DateComponents(month: 0), firstResultWasAgo: DateComponents(day: -10), tg: Disease.SarsCov2.rawValue)
        verifier.checkNationalRules(dgc: hcert) { result in
            switch result {
            case let .success(r):
                // SHOULD BE VALID
                XCTAssertTrue(r.isValid)
            default:
                XCTAssertTrue(false)
            }
        }
        let hcert_invalid = generateRecoveryCert(validSinceNow: DateComponents(day: -10), validFromNow: DateComponents(month: 0), firstResultWasAgo: DateComponents(day: -9), tg: Disease.SarsCov2.rawValue)
        verifier.checkNationalRules(dgc: hcert_invalid) { result in
            switch result {
            case let .success(r):
                // SHOULD BE INVALID
                XCTAssertFalse(r.isValid)
            default:
                XCTAssertTrue(false)
            }
        }
    }
}
