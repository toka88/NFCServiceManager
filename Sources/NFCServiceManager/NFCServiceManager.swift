//
//  NFCService.swift
//  NFC Test
//
//  Created by Goran Tokovic on 11/22/19.
//  Copyright © 2019 Goran Tokovic. All rights reserved.
//

import CoreNFC

public enum NFCServiceError: Error, LocalizedError {
    case readSessionAlreadyStarted
    case writeSessionAlreadyStarted
    case dataCannotBeWritten
    case sessionStopped
    case unableToConnectToTag
    case unableToQueryTheNDEFStatusOfTag
    case tagIsNotNDEFCompilant
    case readOnlyTag
    case unknownNDEFTagStatus

    var localizedDescription: String {
        switch self {
        case .readSessionAlreadyStarted:
            return NSLocalizedString("NFC reader is already started.", comment: "")
        case .writeSessionAlreadyStarted:
            return NSLocalizedString("NFC writed is already started.", comment: "")
        case .sessionStopped:
            return NSLocalizedString("NFC reader stopped.", comment: "")
        case .dataCannotBeWritten:
            return NSLocalizedString("Passed data cannot be written to NFC tag.", comment: "")
        case .unableToConnectToTag:
            return NSLocalizedString("Unable to connect to tag.", comment: "")
        case .unableToQueryTheNDEFStatusOfTag:
            return NSLocalizedString("Unable to query the NDEF status of tag.", comment: "")
        case .tagIsNotNDEFCompilant:
            return NSLocalizedString("Tag is not NDEF compliant.", comment: "")
        case .readOnlyTag:
            return NSLocalizedString("Tag is read only.", comment: "")
        case .unknownNDEFTagStatus:
            return NSLocalizedString("Unknown NDEF tag status.", comment: "")
        }
    }

    public var errorDescription: String? {
        return localizedDescription
    }
}

public final class NFCServiceManager: NSObject {
    private var readerSession: NFCNDEFReaderSession?
    private var completionBlock: ((Result<String, Error>) -> Void)?
    private var writingCompletionBlock: ((Result<Bool, Error>) -> Void)?
    private var messageToWrite: NFCNDEFMessage?

    /// Singleton instance
    public static let shared: NFCServiceManager = NFCServiceManager()

    /// Check does this device support NFC service
    public var isNFCSupported: Bool {
        let answer = NFCNDEFReaderSession.readingAvailable
        return answer
    }

    /// Is NFC readed started
    public var isScanning: Bool {
        return completionBlock != nil
    }

    /// Is NFC writing started
    public var isWriting: Bool {
        return writingCompletionBlock != nil
    }


    /// Stop scanning for NFC tags.
    public func stopScanning() {
        readerSession?.invalidate()
        readerSession = nil
        completionBlock?(.failure(NFCServiceError.sessionStopped))
        completionBlock = nil
        writingCompletionBlock?(.failure(NFCServiceError.sessionStopped))
        writingCompletionBlock = nil
    }


    /// Scan for NFC tags
    /// - Parameter completion: completion block
    public func scanTag(completion:@escaping ((Result<String, Error>) -> Void)) {
        guard !isScanning else {
            completion(.failure(NFCServiceError.readSessionAlreadyStarted))
            return
        }

        guard !isWriting else {
            completion(.failure(NFCServiceError.writeSessionAlreadyStarted))
            return
        }

        readerSession?.invalidate()
        completionBlock = completion
        readerSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        readerSession?.alertMessage = "Hold your iPhone near tag."
        readerSession?.begin()
    }

    @available(iOS 13.0, *)
    public func writeToTag(text: String, completion: @escaping ((Result<Bool, Error>) -> Void)) {
        guard !isScanning else {
            completion(.failure(NFCServiceError.readSessionAlreadyStarted))
            return
        }

        guard !isWriting else {
            completion(.failure(NFCServiceError.writeSessionAlreadyStarted))
            return
        }

        guard let textPayload = NFCNDEFPayload.wellKnownTypeTextPayload(string: text, locale: Locale(identifier: "En")) else {
            completion(.failure(NFCServiceError.dataCannotBeWritten))
            return
        }

        messageToWrite = NFCNDEFMessage(records: [textPayload])
        readerSession?.invalidate()
        writingCompletionBlock = completion
        readerSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        readerSession?.alertMessage = "Hold your iPhone near an NDEF tag to write the message."
        readerSession?.begin()

    }
}

extension NFCServiceManager: NFCNDEFReaderSessionDelegate {
    public func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        print("[\(String(describing: type(of: self)))] readerSession - didInvalidateWithError")
        session.invalidate()
        DispatchQueue.main.async { [weak self] in
            self?.readerSession = nil
            self?.completionBlock?(.failure(error))
            self?.completionBlock = nil
            self?.writingCompletionBlock?(.failure(error))
            self?.writingCompletionBlock = nil
            self?.messageToWrite = nil
        }
    }

    public func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        print("[\(String(describing: type(of: self)))] readerSession - didDetectNDEFs")
        // Scanning NFC tags
        var result = ""
        for payload in messages[0].records {
            if let text = String(data: payload.payload.advanced(by: 0), encoding: .utf8) {
                result += text
            }
        }

        returnReadingSuccess(result)
    }

    @available(iOS 13.0, *)
    public func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        print("[\(String(describing: type(of: self)))] session - didDetect")
        if isScanning {
            if tags.count > 1 {
                // Restart polling in 500 milliseconds.
                let message = NSLocalizedString("More than 1 tag is detected. Please remove all tags and try again.", comment: "")
                restartPolling(session: session, alertMessage: message)
                return
            }

            guard let tag = tags.first else {
                restartPolling(session: session, alertMessage: NFCServiceError.unknownNDEFTagStatus.localizedDescription)
                return
            }

            readDataFromTag(tag, session: session)

        } else {
            guard let messageToWrite = messageToWrite else {
                session.invalidate(errorMessage: NFCServiceError.dataCannotBeWritten.localizedDescription)
                returnWritingError(NFCServiceError.dataCannotBeWritten)
                print("Error 1")
                return
            }

            if tags.count > 1 {
                let message = NSLocalizedString("More than 1 tag is detected. Please remove all tags and try again.", comment: "")
                restartPolling(session: session, alertMessage: message)
                return
            }

            guard let tag = tags.first else {
                restartPolling(session: session, alertMessage: NFCServiceError.dataCannotBeWritten.localizedDescription)
                return
            }

            writeMessageToTag(messageToWrite, tag: tag, session: session)
        }
    }

    public func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        print("[\(String(describing: type(of: self)))] readerSessionDidBecomeActive")
    }

    @available(iOS 13.0, *)
    private func readDataFromTag(_ tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        session.connect(to: tag) { [weak self] error in
            if let error = error {
                self?.restartPolling(session: session, alertMessage: error.localizedDescription)
                return
            }

            tag.queryNDEFStatus { [weak self] status, _, error in
                if let error = error {
                    self?.restartPolling(session: session, alertMessage: error.localizedDescription)
                    return
                }

                switch status {
                case .notSupported:
                    self?.restartPolling(session: session, alertMessage: NFCServiceError.tagIsNotNDEFCompilant.localizedDescription)
                case .readOnly, .readWrite:
                    tag.readNDEF { message, error in
                        if let message = message, let text = message.text {
                            session.alertMessage = NSLocalizedString("Tag scanned", comment: "")
                            self?.returnReadingSuccess(text)
                            return
                        } else if let error = error {
                            self?.restartPolling(session: session, alertMessage: error.localizedDescription)
                            return
                        }

                        self?.restartPolling(session: session, alertMessage: NFCServiceError.unableToConnectToTag.localizedDescription)
                        return
                    }
                @unknown default:
                    self?.restartPolling(session: session, alertMessage: NFCServiceError.unableToConnectToTag.localizedDescription)
                }
            }
        }
    }

    @available(iOS 13.0, *)
    private func writeMessageToTag(_ message: NFCNDEFMessage, tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        session.connect(to: tag, completionHandler: { [weak self] error in
            if let error = error {
                session.invalidate(errorMessage: error.localizedDescription)
                self?.returnWritingError(error)
                return
            }

            tag.queryNDEFStatus(completionHandler: { [weak self] ndefStatus, _, error in
                if let error = error {
                    session.invalidate(errorMessage: NFCServiceError.unableToQueryTheNDEFStatusOfTag.localizedDescription)
                    self?.returnWritingError(error)
                    print("Error 3")
                    return
                }

                switch ndefStatus {
                case .notSupported:
                    session.invalidate(errorMessage: NFCServiceError.tagIsNotNDEFCompilant.localizedDescription)
                    self?.returnWritingError(NFCServiceError.tagIsNotNDEFCompilant)
                    print("Error 4")
                case .readOnly:
                    session.invalidate(errorMessage: NFCServiceError.readOnlyTag.localizedDescription)
                    self?.returnWritingError(NFCServiceError.readOnlyTag)
                    print("Error 5")
                case .readWrite:
                    tag.writeNDEF(message, completionHandler: { [weak self] error in
                        if let error = error {
                            print("[\(String(describing: type(of: self)))] Write NDEF message fail: \(error)")
                            session.invalidate(errorMessage: "Write NDEF message fail: \(error.localizedDescription)")
                            self?.returnWritingError(error)

                            print("Error 6")
                        } else {
                            print("[\(String(describing: type(of: self)))] Write NDEF message successful.")
                            session.alertMessage = "Write NDEF message successful."
                            self?.returnWritingSuccess()
                        }
                    })
                @unknown default:
                    session.invalidate(errorMessage: NFCServiceError.unknownNDEFTagStatus.localizedDescription)
                    self?.returnWritingError(NFCServiceError.unknownNDEFTagStatus)
                    print("Error 7")
                }
            })
        })
    }

    private func returnWritingError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.readerSession?.invalidate()
            self?.readerSession = nil
            self?.writingCompletionBlock?(.failure(error))
            self?.writingCompletionBlock = nil
            self?.messageToWrite = nil
        }
    }

    private func returnWritingSuccess() {
        DispatchQueue.main.async { [weak self] in
            self?.readerSession?.invalidate()
            self?.readerSession = nil
            self?.writingCompletionBlock?(.success(true))
            self?.writingCompletionBlock = nil
            self?.messageToWrite = nil
        }
    }

    private func returnReadingError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.readerSession?.invalidate()
            self?.readerSession = nil
            self?.completionBlock?(.failure(error))
            self?.completionBlock = nil
        }
    }

    private func returnReadingSuccess(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.readerSession?.invalidate()
            self?.readerSession = nil
            self?.completionBlock?(.success(text))
            self?.completionBlock = nil
        }
    }

    @available(iOS 13.0, *)
    private func restartPolling(session: NFCNDEFReaderSession, alertMessage: String?) {
        print("\(String(describing: type(of: self))) restartPolling")
        if let message = alertMessage {
            session.alertMessage = message
        }
        // Restart polling in 500 milliseconds.
        let retryInterval = DispatchTimeInterval.milliseconds(500)
        DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
            session.restartPolling()
        })
    }
}
