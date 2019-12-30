//
//  NFCNDEFMessage.swift
//  NFC Test
//
//  Created by Goran Tokovic on 28/11/2019.
//  Copyright © 2019 Goran Tokovic. All rights reserved.
//

import CoreNFC

extension NFCNDEFMessage {

    /// Get text stored in NFCNDEFMessage object. Supported typeNameFormats: nfcWellKnown and nfcExternal. For other returns nil
    @available(iOS 13.0, *)
    public var text: String? {

        guard !records.isEmpty, records[0].typeNameFormat != .empty else {
                return nil
        }

        var result: String = ""
        for payload in self.records {
            debugPrint("[NFCNDEFMessage text] typeNameFormat: \(payload.typeNameFormat.rawValue)")
            switch payload.typeNameFormat {
            case .nfcWellKnown:
                if let text = payload.wellKnownTypeTextPayload().0 {
                    result += text
                } else if let url = payload.wellKnownTypeURIPayload() {
                    result += url.absoluteString
                }
            case .nfcExternal:
                if let text = String(data: payload.payload.advanced(by: 0), encoding: .utf8) {
                    result += text
                }
            default:
                return nil
            }
        }
        return result
    }
}
