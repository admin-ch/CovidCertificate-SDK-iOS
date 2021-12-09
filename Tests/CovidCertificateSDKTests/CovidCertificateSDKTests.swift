//
@testable import CovidCertificateSDK
import JSON
import jsonlogic
import XCTest

private extension CheckMode {
    static let threeG = "THREE_G"
    static let twoG = "TWO_G"
}

private extension Array where Element == CheckMode {
    static let threeG = [CheckMode.threeG]
    static let twoG = [CheckMode.twoG]
}

final class CovidCertificateSDKTests: XCTestCase {
    var verifier: CovidCertificateImpl {
        let ver = CovidCertificateImpl(environment: SDKEnvironment.dev, apiKey: "", trustListManager: TestTrustlistManager())
        return ver
    }

    var dateFormatter: DateFormatter {
        let d = DateFormatter()
        d.dateFormat = "yyyy-MM-dd"
        return d
    }

    // MARK: - Setup

    override class func setUp() {
        CovidCertificateSDK.initialize(environment: SDKEnvironment.dev, apiKey: "")
    }

    // MARK: - Helpers

    func areSameVaccineDates(_ date1: Date, _ date2: Date) -> Bool {
        dateFormatter.string(from: date1) == dateFormatter.string(from: date2)
    }

    // MARK: - Tests

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

    // cbor has no exp and no iat and was calculated from rust
    func testCustomCBOR() {
        let hcert = "HC1:6BFMY3ZX73PO%203CCBR4OF7NI2*RLLTIKQDKYMW03%MG:GKCDKP-38E9/:N2QIL44RC5WA9+-0*Q3Q56CE0WC6W77K66U$QO37HMG.MO+FLAHV9LP9GK0JL2I989BBCL$G4.R3ITA6URNWLWMLW7H+SSOI8YF5MIP8 6VWK*96PYJ:D3:T0-Y5DLITLUM5K $25QHGJEQ85B54W7B8JCM40-D2R+8T1O2SI2DPYRJO9C5Q1693$58EFQ/%IH*O7JGS+GAV2PYFGYHXC707CGU8/4S5ART-45GHCCRI-9%MH 0BB%4U7VUONPWPBAG4-SDC6T3D 50E+CU+GCTIL64HEHAGUBJD9A3:72S471JOJQBMLPWDI910RH0IUG53SUFBK7RRJH9IC%NRC:AT15OC4%CM19DQZ33APNY9/P9DBWNCC5M6E9I6-0N6M-VR$7P+DQEXOUKMAW8I4VX19VLV6S3JZBJ7P:*I 392*TPPAQ1GGQV61Q:8R1OLE14W6PZLOQFERKJJ9NCMD55DVVF"

        let key = TrustListPublicKey(keyId: "AAABAQICAwM=", withX: "YRmTm5MEXXVb/stIK+dkoD63b5I+jgOjPrvvYHFfdHc=", andY: "xbfq2DlfMkGHxYVw7bRmteVEcNChdETQ+GyLkrBnBFM=")
        let keys: [TrustListPublicKey] = [key].compactMap { $0 }

        guard let certificateHolder = try? verifier.decode(encodedData: hcert).get() else {
            XCTAssertTrue(false)
            return
        }
        let expectations = expectation(description: "async job")

        let customVerifier = CovidCertificateImpl(environment: SDKEnvironment.dev, apiKey: "", trustListManager: TestTrustlistManager(publicKeys: keys))
        customVerifier.checkSignature(holder: certificateHolder, forceUpdate: false) { result in
            switch result {
            case let .success(r):
                XCTAssertTrue(r.isValid)
            case .failure:
                XCTFail("testCustomCBOR failed")
            }
            expectations.fulfill()
        }

        waitForExpectations(timeout: 60, handler: nil)
    }

    func testCWTExpiredWithInvalidSignature() {
        let hcert = "HC1:6BF3TDJ%B6FL:TSOGOAHPH*OW*PQDI7YO-96W*OHAS0C6LDAI81POIF:0S1E2-I534LRHRXQQHIZC4.OI1RM8ZA*LP$V25$0$/AQ$3H-8R6TU:C//CW$5 -D1$4C5PE/H:Y0D$0M+8H:H00M-$4U/HYE9/MVKQC*LA 436IAXPMHQ1*P1TU12XE %POH6JK5 *JAYUQJATK25M9:OQPAU:IAJ0AGY0OWCR/C+T44%4GIP77TLXKQ/S1E5E6J90J7*KP/S57TT65:9TNIF 35:U47AL+T4 %23NJ.43CGJ8X2+36D-I/2DBAJDAJCNB-43 X4VV2 73-E3GG3V20-7TZD5CC9T0HQ+4CNNG.85$07LPMIH-O92UQKRQT02.MPDB9SH9C9QG3FSZN0/4P/5CA7G6ME1SDQ6CS4:ZJ83B-6THC1G%5TW5A 6YO67N659EWEWJ2T7+VCK19ASG+7G7WH0JSZARUA82WIAQ/+IY%NT2G5+GG 95MD5FN:3VJXRUN3U.LF:HKVTFZIP.4X7GHBBJ17IN6$MQV7SH.5941GPG"

        let expectations = expectation(description: "async job")

        guard let certificateHolder = try? verifier.decode(encodedData: hcert).get() else {
            XCTFail("testVariousFloatAndSignedIntCBORDates failed")
            return
        }
        verifier.checkSignature(holder: certificateHolder, forceUpdate: false) { result in
            switch result {
            case let .success(res):
                XCTAssert(!res.isValid)
            case .failure:
                XCTFail("testVariousFloatAndSignedIntCBORDates failed")
            }
            expectations.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }

    func testCWTExpired() {
        let hcert = "HC1:6BF3TDJ%B6FL:TSOGOAHPH*OW*PQDI7YO-96W*OHAS0C6LDAI81POI-.08WAJVIT:RVGAS7IMYLSA3/-2E%5VR5VVBJZI+EBI.CXBDX*TT*C.BD-8DUVDAVT USVJCYMCNST/DCMMC*8DY5TJ*S7BCH*S*NI WJUQ6395R4I-B5ET42HPPEPHCRSV85EPAC5ADNJSQ*Q6NY4U47Q7N0D4%IUOD4*EV3LCT58DKD5C9/.D +GC4EFI9+CA3NK%9E+-C-ZAOCARJC/MH8RFQNIW0IGOA9FEP+9A.DNPL%*G4IJ0JAXD15IAXMFU*GSHGRKMXGG6DBYCB-1JMJKR.KI91L4DWZJ$7K+ CNED*ZLZ9C%PD8DJI7JSTNB95D26MFVE2K8$JBPKC.U2ZEDUOFPEAYU/UIGSUKRQNN94E8TNP8EF-GDPIL/NST*QGTA4W7.Y7N31D$5B:UPZUUUH-F9216AGWU5ES4ASO96584HMXLQZAMK%AQOR5CBT:72+R+.NE3MQ8B4*LG+D.PKZQFH6THHV5-B4/N-B9 36YJD1W7ENVW$F"

        let expectations = expectation(description: "async job")

        guard let certificateHolder = try? verifier.decode(encodedData: hcert).get() else {
            XCTFail("Could not decode")
            return
        }
        let key = TrustListPublicKey(keyId: "AAABAQICAwM=", withX: "S/yUgaRwgbGh73OGTAaidN+WSf16Tak3oYi4KwjeA4g=", andY: "4nWXiEKZkApaDwzXrUcA1zphiCSry8Xd4zqNL5XVREw=")
        let keys: [TrustListPublicKey] = [key].compactMap { $0 }
        let customVerifier = CovidCertificateImpl(environment: SDKEnvironment.dev, apiKey: "", trustListManager: TestTrustlistManager(publicKeys: keys))
        customVerifier.checkSignature(holder: certificateHolder, forceUpdate: false) { result in
            switch result {
            case .success:
                XCTFail("Should fail")
            case let .failure(error):
                // we should fail with CWT expired
                XCTAssertTrue(error.errorCode == ValidationError.CWT_EXPIRED.errorCode)
            }
            expectations.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }

    func testVariousFloatAndSignedIntCBORDates() {
        let hcert = "HC1:6BF3TDJ%B6FL:TSOGOAHPH*OW*PQDI7YO-96W*OHAS0C6RLQI81POIF:0:3BAG1PZIQ+Q%SQXZI3VUD%N/+P.SS  QS+G3WOHVU978MRLQ+Q.OIVTQA+QWQ23E2F/8X*G3M9JUPY0BZW4:.AY73CIBVQFM83IMJTLJ8UJARN*FN4DJV53/G7-43Z23EG3%971IN/AJVC7SP499TVW5KK9+OC+G9QJPNF67J6QW67KQ9G66PP33M/TEJG3LKBXBJFF02JNEJOA+MY55V90*F7$17IK8D:6NY4R35OBA4DN/VM/H5J35 96$ 8BX7/JP9398C5Y47Z.4Z6NC1R4SO* PUHLO$GAHLW 70SO:GOLIROGO3T59YLLYP-HQLTQ9R0+L69/9-3AKI6-Q6R3RX76QW6.V99Q9E$BDZIE9JIRF71A4-9SCA6LFOSNENSUC75HF KP8EFXOTJ.K274M.SY$N/U6ZVA69E$JDVPLW1KD0K%XG$GNHYGB5TA2PR-9+RD NFXHPW6TSLBD:FX7QV:GYF8+2LH EC.U:05 WT*+M3CWH/UXKJ8RFI1J71QYDF0N1YPR%8M$EWVSN%GP69TL5UCOI"

        let expectations = expectation(description: "async job")

        guard let certificateHolder = try? verifier.decode(encodedData: hcert).get() else {
            XCTFail("Could not decode")
            return
        }
        let key = TrustListPublicKey(keyId: "AAABAQICAwM=", withX: "8OvCEph8PWTFDrLaObg5c6gK9HI0tfJUMmma/WfvlVE=", andY: "uJ2i55ZbAVpMhklwqZfVKhLXeO0Yrz69qKoh2Y86FR8=")
        let keys: [TrustListPublicKey] = [key].compactMap { $0 }
        let customVerifier = CovidCertificateImpl(environment: SDKEnvironment.dev, apiKey: "", trustListManager: TestTrustlistManager(publicKeys: keys))
        customVerifier.checkSignature(holder: certificateHolder, forceUpdate: false) { result in
            switch result {
            case .success:
                XCTFail("Should fail")
            case let .failure(error):
                // we should fail with CWT expired
                XCTAssertTrue(error.errorCode == ValidationError.SIGNATURE_TYPE_INVALID(.CWT_HEADER_PARSE_ERROR).errorCode)
            }
            expectations.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }

//    func testEC() {
    ////        kid: 2Rk3X8HntrI=
//        let key = TrustListPublicKey(keyId: "2Rk3X8HntrI=", withX: "rdVc9a0bltR6jm1BPTA3u0cyJNYKuF1uRk8h7h04+XA=", andY: "USfZGB7fv6Eg18JllyjOnBAp3Jqmis9Q/VMTtRaXQXc=")
//        let keys : [TrustListPublicKey] = [key].compactMap { $0 }
//        let testTrustList =  TestTrustList(publicKeys: keys)
//
//        let hcert = "HC1:NCFOXN%TS3DH3ZSUZK+.V0ETD%65NL-AH-R6IOOP-IZXPQFG4G54$VO%0AT4V22F/8X*G3M9JUPY0BX/KR96R/S09T./0LWTKD33236J3TA3M*4VV2 73-E3GG396B-43O058YIB73A*G3W19UEBY5:PI0EGSP4*2DN43U*0CEBQ/GXQFY73CIBC:G 7376BXBJBAJ UNFMJCRN0H3PQN*E33H3OA70M3FMJIJN523.K5QZ4A+2XEN QT QTHC31M3+E32R44$28A9H0D3ZCL4JMYAZ+S-A5$XKX6T2YC 35H/ITX8GL2-LH/CJTK96L6SR9MU9RFGJA6Q3QR$P2OIC0JVLA8J3ET3:H3A+2+33U SAAUOT3TPTO4UBZIC0JKQTL*QDKBO.AI9BVYTOCFOPS4IJCOT0$89NT2V457U8+9W2KQ-7LF9-DF07U$B97JJ1D7WKP/HLIJLRKF1MFHJP7NVDEBU1J*Z222E.GJ:575JH2E90$6.Q9MEI**SQVFGHPMVLSRB5-FQC3$SDTTHWLUP/JI5N%7UT*T88VNVACATXYPO-Q1L1MWN95TV0R 3T.Y1YNPS/8SNV-10HF2D3"
//
//        guard let dgcHolder = try? verifier.decode(encodedData: hcert).get() else {
//            XCTAssertTrue(false)
//            return
//        }
//
//        let customVerifier = ChCovidCert(environment: SDKEnvironment.dev, trustListManager: TestTrustlistManager(publicKeys: keys))
//        customVerifier.checkSignature(holder: dgcHolder) { result in
//            if case let .success(r) = result {
//                XCTAssertTrue(r.isValid)
//            } else {
//                XCTAssertFalse(true)
//            }
//        }
//    }

    func testCompleteToolchain() {
        let hcert = "HC1:NCFJ60EG0/3WUWGSLKH47GO0KNJ9DSWQIIWT9CK+500XKY-CE59-G80:84F3ZKG%QU2F30GK JEY50.FK6ZK7:EDOLOPCF8F746KG7+59.Q6+A80:6JM8SX8RM8.A8TL6IA7-Q6.Q6JM8WJCT3EYM8XJC +DXJCCWENF6OF63W5$Q69L6%JC+QE$.32%E6VCHQEU$DE44NXOBJE719$QE0/D+8D-ED.24-G8$:8.JCBECB1A-:8$96646AL60A60S6Q$D.UDRYA 96NF6L/5QW6307KQEPD09WEQDD+Q6TW6FA7C466KCN9E%961A6DL6FA7D46JPCT3E5JDJA76L68463W5/A6..DX%DZJC3/DH$9- NTVDWKEI3DK2D4XOXVD1/DLPCG/DU2D4ZA2T9GY8MPCG/DY-CAY81C9XY8O/EZKEZ96446256V50G7AZQ4CUBCD9-FV-.6+OJROVHIBEI3KMU/TLRYPM0FA9DCTID.GQ$NYE3NPBP90/9IQH24YL7WMO0CNV1 SDB1AHX7:O26872.NV/LC+VJ75L%NGF7PT134ERGJ.I0 /49BB6JA7WKY:AL19PB120CUQ37XL1P9505-YEFJHVETB3CB-KE8EN9BPQIMPRTEW*DU+X2STCJ6O6S4XXVJ$UQNJW6IIO0X20D4S3AWSTHTA5FF7I/J9:8ALF/VP 4K1+8QGI:N0H 91QBHPJLSMNSJC BFZC5YSD.9-9E5R8-.IXUB-OG1RRQR7JEH/5T852EA3T7P6 VPFADBFUN0ZD93MQY07/4OH1FKHL9P95LIG841 BM7EXDR/PLCUUE88+-IX:Q"
//            let hcert = "HC1:NCFOXNYTSFDHJI8-.O0:A%1W RI%.BI06-JV1WG21QKP85NPV*JVH5MVI$068WA.VU1/M:ZH6I1$4JN:IN1MPK9V L9L6O MH8VWJE+9663FHFE$96L07Z*65LEK.EUW61R6A46EN9U3Q+QUSH9UKPSH9WC5PF6846A$Q 76SW6%V98T5%BIMI5DN9XW5O PICA$O7T6LEJOA+MY55EII-EBBAK%ZM2L6:/6N9R%EPXCROGO3HO-HQKOOEC5L64HX6IAS3DS2980IQRDOUHLO$GAHLW 70SO:GOLIROGO3T59YLLYP-HQLTQ9R0+L69/9E2A1PB2AD$ZJ*DJWP42W5JY4I47-V5KV3Q0531TAYKD%0QCNH9LZ33/HLIJL8JF8JF0IIVP1TX2SK6L8K6G1%5ECJVL3FI:1L$8:SN55K*0GQ2VJ*035C26VQONPOUZ9NVUT0KVPNB8XB8-RD/VR7GSEFRCSSUVRXNIVDCFLCP6UV6GXO7RT* CU.7D DLTL.GHME2MMNPH5 ET3PFF1EY+D6 I5FUSNS7J8+Z2Q:6R6RXAO59WJNP*WML/T93N*9U%Z953T1K9$%GIOOTW4 X06$C-WHIRC1+IWEBJCBTICQPFY63G8L 5HHOT:ED399X VL2NF1QUKB2XDT4W.3U38K%RH$WVG*R1FVNJK 27X7I$LH6:SLLI.$VE:KRP15C2SZE$GD$MAU93+ 9EWU1H7/%R/6RMSJGOPPJB-/L$PLHYF%2AKY46NG*9TYRA-PBQ8LFD7GX5FOVODAANJKLGRFW-TEC6BF7R"

        let signatureExpectation = expectation(description: "signature check")
        let revocationStatus = expectation(description: "revocation status")

        let certificateHolder = try? verifier.decode(encodedData: hcert).get()
        XCTAssertNotNil(certificateHolder)

        verifier.checkSignature(holder: certificateHolder!, forceUpdate: false) { result in
            let res: ValidationResult? = try? result.get()
            XCTAssertNotNil(res)
            XCTAssertTrue(res!.isValid)
            signatureExpectation.fulfill()
        }
        switch certificateHolder!.certificate {
        case let certificate as DCCCert:
            verifier.checkRevocationStatus(certificate: certificate, forceUpdate: false) { result in
                let res: ValidationResult? = try? result.get()
                XCTAssertNotNil(res)
                XCTAssertTrue(res!.isValid)
                revocationStatus.fulfill()
            }
        default:
            fatalError("Unsupported Certificate type")
        }

        waitForExpectations(timeout: 60, handler: nil)
//            verifier.checkNationalRules(dgc: dgcHolder!.healthCer, modes: .threeGt) {result in
//                let res : VerificationResult? = try? result.get()
//                XCTAssertNotNil(res)
//                XCTAssertTrue(res!.isValid)
//            }
    }

    func testCWTIsNotExpired() {}

    func testCWTIsNotIssuedInTheFuture() {}

    /// VACCINE TESTS

    func testVaccineDiseaseTargetedHasToBeSarsCoV2() {
        let hcert_targets_covid = "HC1:NCFTW2SX7YUO/232Y9F*A3.2%K74MH8 RCOI3%4DHQ/-BN0R:XKJFR%PEFD3M%T7EDYO35ZI7OHIYVOA2:$5JDNJMOTE9./3GIAO7E:N00F89WVVY7FDRLFJLFWTQ87HOD1P4MVRYQ32BQTV/9WI+V%DKBW5A6G23FFV83GHCXT1OA0M59*E7PAU IUSQJG4112JBE.G49VA1%DTDI160VCOC1SFKRUY13K31G0Y1JD90CCBQFS5V6WYA.J5Q35Z2TR01+13TNK4J9NG9LL0GT7ETB5HI%NVHJC:888O12W5KSSDO0T8BP54MW2B$A3GHY.APKJ3JI%RMP6BLD5X.7JOJ612C:J*70 E3%M9Z+L5ZB*UIG7TIMIQ%KOAI5-H-OR3ZIDV23ZK53LTE3ZKQI/N $RW6EWLBKQ6*:P%6U6Q55XI93KU%OOL1RG9 VP$T63PHJ23JP1WIQUW4-K4JT2HBO2JRU41I7QY:H217NBSZ.0T4AYVRI$JE F+PPX8CSTE72L5WU+VV%J789OTUJ5ZRO%BS8LYLOK29SEWWRR1061VV*CQF RZ7PFQVNPG"

        let certificateHolder = try? verifier.decode(encodedData: hcert_targets_covid).get()
        XCTAssertNotNil(certificateHolder)

        let successExpectation = expectation(description: "succes")
        let failExpectation = expectation(description: "fail")

        verifier.checkNationalRules(holder: certificateHolder!, forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case .failure(.WRONG_DISEASE_TARGET):
                XCTFail("Disease target sarscov should pass")
            default:
                XCTAssertTrue(true)
            }
            successExpectation.fulfill()
        }

        let hcert_does_not_target_covid = "HC1:NCFOXN%TS3DH3ZSUZK+.V0ETD%65NL-AH%TAIOOP-IPOIZLH4G5EDBUV2ZMIN9HNO4*J8OX4W$C2VL*LA 43/IE%TE6UG+ZEAT1HQ13W1:O1YUI%F1PN1/T1J$HTR9/O14SI.J9DYHZROVZ05QNZ 20OP748$NI4L6-O16VH6ZL4XP:N6ON1 *L:O8PN1QP5O PLU9A/RUX96 B0V1ZZB.T12.H.ZJ$%HN 9GTBIQ1EK0ZIEQKERQ8IY1I$HH%U8 9PS5OH6*ZUFXFE.R:YN/P3JRH8LHGL2-LH/CJTK96L6SR9MU9RP5 R1:PI/E2$4J6AL.+I9UV6$0+BNPHNBC7CTR3$VDY0DUFRLN/Y0Y/K9/IIF0%:K6*K$X4FUTD14//E3:FL.B$JDBLEH-BL1H6TK-CI:ULOPD6LF20HFJC3DAYJDPKDUDBQEAJJKHHGEC8ZI9$JAQJKZ%K+EPM+8172WLC0NQ-/RRCTCIMCJENCB%BK8YN2MI8DL8HN96URFW3:F3.BXDU$ZRMEO7DSPCEK45PJ3+UND5K/831-7KH12$DUBFUA60JFADAA%8G*QLEG"
        let invalidCertificateHolder = try? verifier.decode(encodedData: hcert_does_not_target_covid).get()
        XCTAssertNotNil(invalidCertificateHolder)

        verifier.checkNationalRules(holder: invalidCertificateHolder!, forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case .failure(.WRONG_DISEASE_TARGET):
                XCTAssertTrue(true)
            default:
                XCTFail("Wrong disease target should fail")
            }
            failExpectation.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }

    private func generateVacineCert(dn: UInt64, sd: UInt64, ma: String, mp: String, tg: String, vp: String, todayIsDateComponentsAfterVaccination: DateComponents) -> DCCCert {
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
        return try! JSONDecoder().decode(DCCCert.self, from: test.data(using: .utf8)!)
    }

    func testVaccineMustBeInWhitelist() {
        let hcert = generateVacineCert(dn: 2, sd: 2, ma: "ORG-100001699", mp: "EU/1/21/1529", tg: Disease.SarsCov2.rawValue, vp: "J07BX03", todayIsDateComponentsAfterVaccination: DateComponents(day: -15))
        let successExpectation = expectation(description: "success")
        let failExpectation = expectation(description: "fail")

        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case let .success(r):
                XCTAssertTrue(r.isValid)
            default:
                XCTFail("Vaccine should be allowed")
            }
            successExpectation.fulfill()
        }

        let invalid_hcert = generateVacineCert(dn: 2, sd: 2, ma: "ORG-100001600", mp: "Sputnik-VII", tg: Disease.SarsCov2.rawValue, vp: "J07BX03", todayIsDateComponentsAfterVaccination: DateComponents(day: -15))
        verifier.checkNationalRules(holder: TestCertificateHolder(cert: invalid_hcert), forceUpdate: false, modes: .twoG) { result in
            switch result.nationalRules {
            case .failure(.NO_VALID_PRODUCT):
                XCTAssertTrue(true)
            default:
                XCTFail("Vaccine not in whitelist should fail")
            }
            failExpectation.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }

    /// A vaccine which needs two shots
    func test2of2VaccineIsValidToday() {
        let hcert = generateVacineCert(dn: 2, sd: 2, ma: "ORG-100001699", mp: "EU/1/21/1529", tg: Disease.SarsCov2.rawValue, vp: "J07BX03", todayIsDateComponentsAfterVaccination: DateComponents(day: 0))
        let successExpectation = expectation(description: "success")
        let today = Calendar.current.startOfDay(for: Date())

        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert), forceUpdate: false, modes: .twoG) { result in
            switch result.nationalRules {
            case let .success(r):
                XCTAssertTrue(r.isValid)
                XCTAssertTrue(self.areSameVaccineDates(r.validFrom!, today))
                XCTAssertTrue(self.areSameVaccineDates(r.validUntil!, Calendar.current.date(byAdding: DateComponents(day: 364), to: today)!))
            default:
                XCTFail("Should be valid today")
            }
            successExpectation.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }

    /// A vaccine which indicates 1/1 but is actually N/N means we had previous infections, and is valid from the day of vaccination
    func testVaccine1of1WithPreviousInfectionsIsValidToday() {
        let hcert = generateVacineCert(dn: 1, sd: 1, ma: "ORG-100001699", mp: "EU/1/21/1529", tg: Disease.SarsCov2.rawValue, vp: "J07BX03", todayIsDateComponentsAfterVaccination: DateComponents(day: 0))
        let successExpectation = expectation(description: "success")
        let today = Calendar.current.startOfDay(for: Date())

        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert), forceUpdate: false, modes: .twoG) { result in
            switch result.nationalRules {
            case let .success(r):
                XCTAssertTrue(r.isValid)
                XCTAssertTrue(self.areSameVaccineDates(r.validFrom!, today))
                XCTAssertTrue(self.areSameVaccineDates(r.validUntil!, Calendar.current.date(byAdding: DateComponents(day: 364), to: today)!))

            default:
                XCTFail("Should be valid today")
            }
            successExpectation.fulfill()
        }

        waitForExpectations(timeout: 60, handler: nil)
    }

    /// A vaccine which only needs one shot is only valid after 21 days
    func testVaccine1of1IsValidAfter21Days() {
        let hcert = generateVacineCert(dn: 1, sd: 1, ma: "ORG-100001417", mp: "EU/1/20/1525", tg: Disease.SarsCov2.rawValue, vp: "J07BX03", todayIsDateComponentsAfterVaccination: DateComponents(day: -21))

        let successExpectation = expectation(description: "success")
        let failExpectation = expectation(description: "fail")

        let today = Calendar.current.startOfDay(for: Date())
        let time = Calendar.current.date(byAdding: DateComponents(day: -21), to: today)!

        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert), forceUpdate: false, modes: .twoG) { result in
            switch result.nationalRules {
            case let .success(r):
                XCTAssertTrue(r.isValid)
                XCTAssertTrue(self.areSameVaccineDates(r.validFrom!, today))
                XCTAssertTrue(self.areSameVaccineDates(r.validUntil!, Calendar.current.date(byAdding: DateComponents(day: 364 + 22), to: time)!))
            default:
                XCTFail("Should be valid")
            }
            successExpectation.fulfill()
        }

        let invalid_cert = generateVacineCert(dn: 1, sd: 1, ma: "ORG-100001417", mp: "EU/1/20/1525", tg: Disease.SarsCov2.rawValue, vp: "J07BX03", todayIsDateComponentsAfterVaccination: DateComponents(day: -20))

        verifier.checkNationalRules(holder: TestCertificateHolder(cert: invalid_cert), forceUpdate: false, modes: .twoG) { result in
            switch result.nationalRules {
            case let .success(r):
                XCTAssertFalse(r.isValid)

                let date = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: DateComponents(day: 1), to: Date())!)
                XCTAssertTrue(self.areSameVaccineDates(r.validFrom!, date))
            default:
                XCTFail()
            }
            failExpectation.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }

    /// A valid vaccine which needs 2 shots is only valid if the certificate states that this is shot N/N
    func testWeNeedAllShots() {
        let hcert = generateVacineCert(dn: 2, sd: 2, ma: "ORG-100001699", mp: "EU/1/21/1529", tg: Disease.SarsCov2.rawValue, vp: "J07BX03", todayIsDateComponentsAfterVaccination: DateComponents(day: -15))

        let successExpcetation = expectation(description: "success")
        let failExpectation = expectation(description: "fail")

        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert), forceUpdate: false, modes: .twoG) { result in
            switch result.nationalRules {
            case let .success(r):
                XCTAssertTrue(r.isValid)
            default:
                XCTFail("N/N should be fine")
            }
            successExpcetation.fulfill()
        }

        let invalid_hcert = generateVacineCert(dn: 1, sd: 2, ma: "ORG-100001699", mp: "EU/1/21/1529", tg: Disease.SarsCov2.rawValue, vp: "J07BX03", todayIsDateComponentsAfterVaccination: DateComponents(day: -15))

        verifier.checkNationalRules(holder: TestCertificateHolder(cert: invalid_hcert), forceUpdate: false, modes: .twoG) { result in
            switch result.nationalRules {
            case .failure(.NOT_FULLY_PROTECTED):
                XCTAssertTrue(true)
            default:
                XCTFail("1/2 should fail")
            }
            failExpectation.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }

    /// Test tourist certificate that is valid for 30 days after being issued
    func testTouristCertificateIsValidFor30Days() {
        let touristCertIdentifiers = ["BBIBP-CorV_T", "CoronaVac_T", "Covaxin_T"]

        for id in touristCertIdentifiers {
            let validCert = generateVacineCert(dn: 2, sd: 2, ma: "", mp: id, tg: Disease.SarsCov2.rawValue, vp: "J07BX03", todayIsDateComponentsAfterVaccination: DateComponents(day: -250))

            let today = Calendar.current.startOfDay(for: Date())
            let issued = Calendar.current.date(byAdding: DateComponents(day: -29), to: today)!
            let expires = Calendar.current.date(byAdding: DateComponents(day: 30), to: issued)!

            let successExpcetation = expectation(description: "success")

            verifier.checkNationalRules(holder: TestCertificateHolder(cert: validCert, issuedAt: issued, expiresAt: expires), forceUpdate: false, modes: .twoG) { result in
                switch result.nationalRules {
                case let .success(r):
                    XCTAssertTrue(r.isValid)
                    XCTAssertTrue(self.areSameVaccineDates(r.validFrom!, issued))
                    XCTAssertTrue(self.areSameVaccineDates(r.validUntil!, expires))
                default:
                    XCTFail("Should be fine")
                }
                successExpcetation.fulfill()
            }

            waitForExpectations(timeout: 60, handler: nil)
        }
    }

    /// Test tourist certificate that is valid for less than 30 days after being issued, due to an early vaccination date
    func testTouristCertificateIsOnlyValidUntilVaccinationExpiration() {
        let touristCertIdentifiers = ["BBIBP-CorV_T", "CoronaVac_T", "Covaxin_T"]

        for id in touristCertIdentifiers {
            let validCert = generateVacineCert(dn: 2, sd: 2, ma: "", mp: id, tg: Disease.SarsCov2.rawValue, vp: "J07BX03", todayIsDateComponentsAfterVaccination: DateComponents(day: -355))

            let today = Calendar.current.startOfDay(for: Date())
            let issued = Calendar.current.date(byAdding: DateComponents(day: -1), to: today)!
            let expires = Calendar.current.date(byAdding: DateComponents(day: 30), to: issued)!

            let successExpcetation = expectation(description: "success")

            verifier.checkNationalRules(holder: TestCertificateHolder(cert: validCert, issuedAt: issued, expiresAt: expires), forceUpdate: false, modes: .threeG) { result in
                switch result.nationalRules {
                case let .success(r):
                    XCTAssertTrue(r.isValid)
                    XCTAssertTrue(self.areSameVaccineDates(r.validFrom!, issued))
                    XCTAssertTrue(self.areSameVaccineDates(r.validUntil!, Calendar.current.date(byAdding: DateComponents(day: 10), to: issued)!))
                default:
                    XCTFail("Should be fine")
                }
                successExpcetation.fulfill()
            }

            waitForExpectations(timeout: 60, handler: nil)
        }
    }

    /// Test tourist certificate that has no issued at and expiry set (old clients)
    func testTouristCertificateOnOlderClients() {
        let touristCertIdentifiers = ["BBIBP-CorV_T", "CoronaVac_T", "Covaxin_T"]

        for id in touristCertIdentifiers {
            let validCert = generateVacineCert(dn: 2, sd: 2, ma: "", mp: id, tg: Disease.SarsCov2.rawValue, vp: "J07BX03", todayIsDateComponentsAfterVaccination: DateComponents(day: -250))

            let today = Calendar.current.startOfDay(for: Date())

            let successExpcetation = expectation(description: "success")

            verifier.checkNationalRules(holder: TestCertificateHolder(cert: validCert, issuedAt: nil, expiresAt: nil), forceUpdate: false, modes: .threeG) { result in
                switch result.nationalRules {
                case let .success(r):
                    XCTAssertTrue(r.isValid)
                    XCTAssertTrue(self.areSameVaccineDates(r.validFrom!, today))
                    XCTAssertTrue(self.areSameVaccineDates(r.validUntil!, Calendar.current.date(byAdding: DateComponents(day: 1), to: today)!))
                default:
                    XCTFail("Should be fine")
                }
                successExpcetation.fulfill()
            }

            waitForExpectations(timeout: 60, handler: nil)
        }
    }

    /// TEST TESTS
    let isoDateFormatter = ISO8601DateFormatter()
    private func generateTestCert(testType: String, testResultType: TestResult, name: String, disease: String, sampleCollectionWasAgo: DateComponents) -> DCCCert {
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
        return try! JSONDecoder().decode(DCCCert.self, from: test.data(using: .utf8)!)
    }

    func testTestDiseaseTargetedHasToBeSarsCoV2() {
        let hcert = generateTestCert(testType: TestType.Pcr.rawValue, testResultType: TestResult.Negative, name: "Nucleic acid amplification with probe detection", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -10))

        let successExpecation = expectation(description: "success")
        let failExpectation = expectation(description: "fail")

        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case let .success(r):
                XCTAssertTrue(r.isValid)
            default:
                XCTFail("Correct disease should be valid")
            }
            successExpecation.fulfill()
        }

        let invalid_hcert = generateTestCert(testType: TestType.Pcr.rawValue, testResultType: TestResult.Negative, name: "Nucleic acid amplification with probe detection", disease: "12345", sampleCollectionWasAgo: DateComponents(hour: -10))

        verifier.checkNationalRules(holder: TestCertificateHolder(cert: invalid_hcert), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case .failure(.WRONG_DISEASE_TARGET):
                XCTAssertTrue(true)
            default:
                XCTFail("Wrong disease should fail")
            }
            failExpectation.fulfill()
        }

        waitForExpectations(timeout: 60, handler: nil)
    }

    func testTypeHasToBePcrOrRatOrSerological() {
        let hcert_rat = generateTestCert(testType: TestType.Rat.rawValue, testResultType: TestResult.Negative, name: "1232", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -10))

        let successExpectation1 = expectation(description: "success")
        let successExpectation2 = expectation(description: "success")
        let successExpectation3 = expectation(description: "success")
        let failExpectation = expectation(description: "fail")

        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert_rat), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case let .success(r):
                XCTAssertTrue(r.isValid)
            default:
                XCTFail("Correct test should be OK")
            }
            successExpectation1.fulfill()
        }

        let hcert_pcr = generateTestCert(testType: TestType.Pcr.rawValue, testResultType: TestResult.Negative, name: "Nucleic acid amplification with probe detection", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -10))

        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert_pcr), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case let .success(r):
                XCTAssertTrue(r.isValid)
            default:
                XCTFail("Correct test should be ok")
            }
            successExpectation2.fulfill()
        }

        let hcert_sero = generateTestCert(testType: TestType.Serological.rawValue, testResultType: TestResult.Positive, name: "Serological", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -10))

        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert_sero), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case let .success(r):
                XCTAssertTrue(r.isValid)
            default:
                XCTFail("Correct test should be ok")
            }
            successExpectation3.fulfill()
        }

        let invalid_cert = generateTestCert(testType: "asdbas", testResultType: TestResult.Negative, name: "Nucleic acid amplification with probe detection", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -10))

        verifier.checkNationalRules(holder: TestCertificateHolder(cert: invalid_cert), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case .failure(.WRONG_TEST_TYPE):
                XCTAssertTrue(true)
            default:
                XCTFail("Wrong test type should fail")
            }
            failExpectation.fulfill()
        }

        waitForExpectations(timeout: 60, handler: nil)
    }

    func testPcrTestsAreAlwaysAccepted() {
        // pcr tests are always accepted
        let invalid_cert_pcr = generateTestCert(testType: TestType.Pcr.rawValue, testResultType: TestResult.Negative, name: "abcdef", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -10))
        let expectation = self.expectation(description: "async task")

        verifier.checkNationalRules(holder: TestCertificateHolder(cert: invalid_cert_pcr), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case let .success(r):
                XCTAssertTrue(r.isValid)
            default:
                XCTFail("PCR should be accepted regardless of name")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }

    func testPcrIsValidFor72h() {
        let hcert = generateTestCert(testType: TestType.Pcr.rawValue, testResultType: TestResult.Negative, name: "Nucleic acid amplification with probe detection", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -71))

        let successExpectation = expectation(description: "success")
        let failExpectation = expectation(description: "fail")

        let now = Date()
        let time = Calendar.current.date(byAdding: DateComponents(hour: -71), to: now)!

        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case let .success(r):
                /// TEST MUST BE VALID
                XCTAssertTrue(r.isValid)
                XCTAssertTrue(r.validFrom!.isSimilar(to: time))
                XCTAssertTrue(r.validUntil!.isSimilar(to: Calendar.current.date(byAdding: DateComponents(hour: 1), to: now)!))
            default:
                XCTFail("Test should still be valid")
            }
            successExpectation.fulfill()
        }

        let invalid_hcert = generateTestCert(testType: TestType.Pcr.rawValue, testResultType: TestResult.Negative, name: "Nucleic acid amplification with probe detection", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -72))
        verifier.checkNationalRules(holder: TestCertificateHolder(cert: invalid_hcert), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case let .success(r):
                /// TEST MUST BE INVALID
                XCTAssertFalse(r.isValid)
            default:
                XCTFail("Test should not be invalid")
            }
            failExpectation.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }

    func testRatIsValidFor24h() {
        let hcert = generateTestCert(testType: TestType.Rat.rawValue, testResultType: TestResult.Negative, name: "1232", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -23))

        let now = Date()
        let time = Calendar.current.date(byAdding: DateComponents(hour: -23), to: now)!

        let correctExpectation = expectation(description: "correct")
        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case let .success(r):
                /// TEST MUST BE VALID
                XCTAssertTrue(r.isValid)
                XCTAssertTrue(abs(r.validFrom!.timeIntervalSince1970 - time.timeIntervalSince1970) < 10)
                XCTAssertTrue(abs(r.validUntil!.timeIntervalSince1970 - Calendar.current.date(byAdding: DateComponents(hour: 1), to: now)!.timeIntervalSince1970) < 10)
            default:
                XCTFail("Something happened")
            }
            correctExpectation.fulfill()
        }

        let invalid_hcert = generateTestCert(testType: TestType.Rat.rawValue, testResultType: TestResult.Negative, name: "1232", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -24))
        let wrongExpectation = expectation(description: "wrong")
        verifier.checkNationalRules(holder: TestCertificateHolder(cert: invalid_hcert), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case let .success(r):
                /// TEST MUST BE INVALID
                DispatchQueue.main.async {
                    XCTAssertFalse(r.isValid)
                }
            default:
                XCTFail("Something happened")
            }
            wrongExpectation.fulfill()
        }

        waitForExpectations(timeout: 60, handler: nil)
    }

    func testTestResultHasToBeNegative() {
        let hcert_rat = generateTestCert(testType: TestType.Rat.rawValue, testResultType: TestResult.Positive, name: "1232", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -23))
        let successExpectation = expectation(description: "success")
        let failExpectation = expectation(description: "fail")

        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert_rat), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case .failure(.POSITIVE_RESULT):
                XCTAssertTrue(true)
            default:
                XCTFail("Negative Result should be ok")
            }
            successExpectation.fulfill()
        }

        let hcert_pcr = generateTestCert(testType: TestType.Pcr.rawValue, testResultType: TestResult.Positive, name: "Nucleic acid amplification with probe detection", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -71))
        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert_pcr), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case .failure(.POSITIVE_RESULT):
                XCTAssertTrue(true)
            default:
                XCTFail("Positive result should fail")
            }
            failExpectation.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }

    func testSeroResultHasToBePositive() {
        let hcert_sero = generateTestCert(testType: TestType.Serological.rawValue, testResultType: TestResult.Negative, name: "1232", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -23))
        let failExpectation = expectation(description: "fail")
        let successExpectation = expectation(description: "success")

        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert_sero), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case .failure(.NEGATIVE_RESULT):
                XCTAssertTrue(true)
            default:
                XCTFail("Negative Result should fail")
            }
            failExpectation.fulfill()
        }

        let hcert_sero2 = generateTestCert(testType: TestType.Serological.rawValue, testResultType: TestResult.Positive, name: "1232", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(hour: -23))
        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert_sero2), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case let .success(r):
                XCTAssertTrue(r.isValid)
            default:
                XCTFail("Positive Result should be ok")
            }
            successExpectation.fulfill()
        }

        waitForExpectations(timeout: 60, handler: nil)
    }

    func testSeroTestIsValidFor90Days() {
        let hcert = generateTestCert(testType: TestType.Serological.rawValue, testResultType: TestResult.Positive, name: "1232", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(day: -89))

        let correctExpectation = expectation(description: "correct")
        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case let .success(r):
                /// TEST MUST BE VALID
                XCTAssertTrue(r.isValid)
            default:
                XCTFail("Something happened")
            }
            correctExpectation.fulfill()
        }

        let invalid_hcert = generateTestCert(testType: TestType.Serological.rawValue, testResultType: TestResult.Positive, name: "1232", disease: Disease.SarsCov2.rawValue, sampleCollectionWasAgo: DateComponents(day: -90))

        let wrongExpectation = expectation(description: "wrong")
        verifier.checkNationalRules(holder: TestCertificateHolder(cert: invalid_hcert), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case let .success(r):
                /// TEST MUST BE INVALID
                DispatchQueue.main.async {
                    XCTAssertFalse(r.isValid)
                }
            default:
                XCTFail("Something happened")
            }
            wrongExpectation.fulfill()
        }

        waitForExpectations(timeout: 60, handler: nil)
    }

    /// RECOVERY TESTS
    private func getCalendar() -> Calendar {
        let utc = TimeZone(identifier: "UTC")!
        var tmpCalendar = Calendar(identifier: .gregorian)
        tmpCalendar.timeZone = utc
        return tmpCalendar
    }

    private func generateRecoveryCert(validSinceNow: DateComponents, validFromNow: DateComponents, firstResultWasAgo: DateComponents, tg: String) -> DCCCert {
        let calendar = getCalendar()
        let now = calendar.startOfDay(for: Date())
        let validFrom = calendar.date(byAdding: validSinceNow, to: now)!
        let validUntil = calendar.date(byAdding: validFromNow, to: now)!
        let firstPositiveTest = calendar.date(byAdding: firstResultWasAgo, to: now)!
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
        return try! JSONDecoder().decode(DCCCert.self, from: test.data(using: .utf8)!)
    }

    func testRecoveryDiseaseTargetedHasToBeSarsCoV2() {
        let hcert = generateRecoveryCert(validSinceNow: DateComponents(day: -10), validFromNow: DateComponents(month: 6), firstResultWasAgo: DateComponents(day: -20), tg: Disease.SarsCov2.rawValue)

        let successExpectation = expectation(description: "success")
        let failExpectation = expectation(description: "fail")

        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case let .success(r):
                XCTAssertTrue(r.isValid)
            default:
                XCTFail("Correct disease target should be ok")
            }
            successExpectation.fulfill()
        }

        let invalid = generateRecoveryCert(validSinceNow: DateComponents(day: -10), validFromNow: DateComponents(month: 6), firstResultWasAgo: DateComponents(day: -20), tg: "abcdef")
        verifier.checkNationalRules(holder: TestCertificateHolder(cert: invalid), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case .failure(.WRONG_DISEASE_TARGET):
                XCTAssertTrue(true)
            default:
                XCTFail("Wrong target should fail")
            }
            failExpectation.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }

    func testSanityCheckForDateCalculations() {
        var dateFormatter: DateFormatter {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = DATE_FORMAT
            return dateFormatter
        }

        let validTestResult = dateFormatter.date(from: "2021-05-08")!
        let calculatedValidUntil = Calendar.current.date(byAdding: DateComponents(day: 179), to: validTestResult)!

        let calculatedValidFrom = Calendar.current.date(byAdding: DateComponents(day: INFECTION_VALIDITY_OFFSET_IN_DAYS), to: validTestResult)!

        let trueValidFrom = dateFormatter.date(from: "2021-05-18")!
        let dayBeforeValidFrom = Calendar.current.date(byAdding: DateComponents(day: -1), to: trueValidFrom)!
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

        // the certificate is not valid one day after trueValidUntil
        // certificate has entry calculatedValidUntil
        // today is dayAfterTrueValidUntil
        XCTAssertTrue(calculatedValidUntil.isBefore(dayAfterTrueValidUntil))
    }

    func testCertificateIsValidFor365DaysAfterTestResult() {
        // The certificate was issued 364 days ago, which means it is still valid today (the 365th day)
        let hcert = generateRecoveryCert(validSinceNow: DateComponents(day: -10), validFromNow: DateComponents(month: 0), firstResultWasAgo: DateComponents(day: -364), tg: Disease.SarsCov2.rawValue)

        let successExpectation = expectation(description: "success")
        let failExpectation = expectation(description: "fail")

        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case let .success(r):
                // SHOULD BE VALID
                XCTAssertTrue(r.isValid)
            default:
                XCTFail("Should valid")
            }
            successExpectation.fulfill()
        }
        // the certificate should not be valid anymore, since it was issued yesterday 364 days ago (hence yesterday was the 365th day)
        let hcert_invalid = generateRecoveryCert(validSinceNow: DateComponents(day: -10), validFromNow: DateComponents(month: 0), firstResultWasAgo: DateComponents(day: -365), tg: Disease.SarsCov2.rawValue)
        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert_invalid), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case let .success(r):
                // SHOULD BE INVALID
                XCTAssertFalse(r.isValid)
            default:
                XCTFail("Should not be valid anymore")
            }
            failExpectation.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }

    func testTestIsOnlyValid10DaysAfterTestResult() {
        let hcert = generateRecoveryCert(validSinceNow: DateComponents(day: -10), validFromNow: DateComponents(month: 0), firstResultWasAgo: DateComponents(day: -10), tg: Disease.SarsCov2.rawValue)

        let successExpectation = expectation(description: "success")
        let failExpectation = expectation(description: "fail")

        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case let .success(r):
                // SHOULD BE VALID
                XCTAssertTrue(r.isValid)
            default:
                XCTFail("10 days after should be fine")
            }
            successExpectation.fulfill()
        }
        let hcert_invalid = generateRecoveryCert(validSinceNow: DateComponents(day: -10), validFromNow: DateComponents(month: 0), firstResultWasAgo: DateComponents(day: -9), tg: Disease.SarsCov2.rawValue)
        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert_invalid), forceUpdate: false, modes: .threeG) { result in
            switch result.nationalRules {
            case let .success(r):
                // SHOULD BE INVALID
                XCTAssertFalse(r.isValid)
            default:
                XCTFail("Should only be valid after 10 days")
            }
            failExpectation.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }

    func testRatTestInvalidInTwoGMode() {
        let hcert = generateTestCert(testType: TestType.Rat.rawValue,
                                     testResultType: TestResult.Negative,
                                     name: "1232",
                                     disease: Disease.SarsCov2.rawValue,
                                     sampleCollectionWasAgo: DateComponents(hour: -5))

        let expectation = expectation(description: "fail")
        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert), forceUpdate: false, modes: .twoG) { result in
            switch result.modeResults {
            case let .success(r):
                /// TEST IS NOT VALID IN 2G MODE
                XCTAssertFalse(r.getResult(for: .twoG)!.isValid)
            default:
                XCTFail("Something happened")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }

    func testRatTestValidInThreeGMode() {
        let hcert = generateTestCert(testType: TestType.Rat.rawValue,
                                     testResultType: TestResult.Negative,
                                     name: "1232",
                                     disease: Disease.SarsCov2.rawValue,
                                     sampleCollectionWasAgo: DateComponents(hour: -5))

        let expectation = expectation(description: "fail")
        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert), forceUpdate: false, modes: .threeG) { result in
            switch result.modeResults {
            case let .success(r):
                /// TEST IS VALID IN 2G MODE
                XCTAssertTrue(r.getResult(for: .threeG)!.isValid)
            default:
                XCTFail("Something happened")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }

    func testVaccinationValidInTwoAndThreeGMode() {
        let hcert = generateVacineCert(dn: 2, sd: 2, ma: "ORG-100001699", mp: "EU/1/21/1529", tg: Disease.SarsCov2.rawValue, vp: "J07BX03", todayIsDateComponentsAfterVaccination: DateComponents(day: -15))

        let twoGExpecation = expectation(description: "success")
        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert), forceUpdate: false, modes: .twoG) { result in
            switch result.modeResults {
            case let .success(r):
                XCTAssertTrue(r.getResult(for: .twoG)!.isValid)
            default:
                XCTFail("Something happened")
            }
            twoGExpecation.fulfill()
        }

        let threeGExpecation = expectation(description: "success")
        verifier.checkNationalRules(holder: TestCertificateHolder(cert: hcert), forceUpdate: false, modes: .threeG) { result in
            switch result.modeResults {
            case let .success(r):
                XCTAssertTrue(r.getResult(for: .threeG)!.isValid)
            default:
                XCTFail("Something happened")
            }
            threeGExpecation.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }
}
