//
//  File.swift
//  
//
//  Created by Goran Tokovic on 30/12/2019.
//

import XCTest
import CoreNFC
@testable import NFCServiceManager

@available(iOS 13.0, *)
final class NFCNDEFMessageTests: XCTestCase {
    func testText_recordsIsEmpty_ShouldReturnNil() {
        let message = NFCNDEFMessage(records: [])
        XCTAssertNil(message.text)
    }

    func testText_FirstRecordTypeNameIsEmpty_ShouldReturnNil() {
        let payload = NFCNDEFPayload(format: .empty, type: Data(), identifier: Data(), payload: Data())
        let message = NFCNDEFMessage(records: [payload])
        XCTAssertNil(message.text)
    }

    func testText_PayloadTypeNameFormatIsMedia_ShouldReturnNil() {
        let payload = NFCNDEFPayload(format: .media, type: Data(), identifier: Data(), payload: Data())
        let message = NFCNDEFMessage(records: [payload])
        XCTAssertNil(message.text)
    }

    func testText_PayloadTypeNameFormatIsAbsoluteURL_ShouldReturnNil() {
        let payload = NFCNDEFPayload(format: .absoluteURI, type: Data(), identifier: Data(), payload: Data())
        let message = NFCNDEFMessage(records: [payload])
        XCTAssertNil(message.text)
    }

    func testText_PayloadTypeNameFormatIsUnkown_ShouldReturnNil() {
        let payload = NFCNDEFPayload(format: .unknown, type: Data(), identifier: Data(), payload: Data())
        let message = NFCNDEFMessage(records: [payload])
        XCTAssertNil(message.text)
    }

    func testText_PayloadTypeNameFormatIsUnchanged_ShouldReturnNil() {
        let payload = NFCNDEFPayload(format: .unchanged, type: Data(), identifier: Data(), payload: Data())
        let message = NFCNDEFMessage(records: [payload])
        XCTAssertNil(message.text)
    }
}
