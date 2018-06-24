//
//  EncryptionManager.swift
//  Mercury
//
//  Created by Nico Ameghino on 24/6/18.
//  Copyright © 2018 Nico Ameghino. All rights reserved.
//

import Foundation

class EncryptionKey {
    enum Error: Swift.Error {
        case noPrivateKeyAvailable
    }

    enum Size: Int {
        case size1024 = 1024
        case size2048 = 2048
        case size4096 = 4096
    }

    private let privateKey: SecKey?
    let publicKey: SecKey

    init(applicationTag: String, keySize: EncryptionKey.Size) {
        // create keys
        let pk = EncryptionKey.createPrivateKey(applicationTag: applicationTag, keySize: keySize)
        self.privateKey = pk
        self.publicKey = EncryptionKey.createPublicKey(from: pk)
    }

    init(privateKey: SecKey) {
        // create private key
        self.privateKey = privateKey
        self.publicKey = EncryptionKey.createPublicKey(from: privateKey)
    }

    init(privateKey: SecKey? = nil, publicKey: SecKey) {
        self.privateKey = privateKey
        self.publicKey = publicKey
    }

    init(base64String string: String, keySize: EncryptionKey.Size) {
        self.privateKey = nil
        self.publicKey = EncryptionKey.createPublicKey(fromBase64: string, keySize: keySize)
    }

    init(base64String data: Data, keySize: EncryptionKey.Size) {
        self.privateKey = nil
        self.publicKey = EncryptionKey.createPublicKey(fromBase64: data, keySize: keySize)
    }

    func encrypt(data: Data) throws -> Data {
        guard let pk = self.privateKey else {
            throw EncryptionKey.Error.noPrivateKeyAvailable
        }

        return EncryptionKey.encrypt(data: data, with: pk)
    }

    func decrypt(data: Data) throws -> Data {
        return EncryptionKey.decrypt(data: data, with: self.publicKey)
    }

    static func createPrivateKey(applicationTag: String, keySize: EncryptionKey.Size) -> SecKey {
        // Create attributes dictionaries.
        var hostPrivateAttributes = [String: Any]()
        hostPrivateAttributes[kSecAttrIsPermanent as String] = false
        hostPrivateAttributes[kSecAttrApplicationTag as String] = applicationTag

        var hostAttributes = [String: Any]()
        hostAttributes[kSecAttrKeyType as String] = kSecAttrKeyTypeRSA
        hostAttributes[kSecAttrKeySizeInBits as String] = keySize.rawValue
        hostAttributes[kSecPrivateKeyAttrs as String] = hostPrivateAttributes

        // Generate the private key.
        var hostError: Unmanaged<CFError>?
        guard let hostPrivateKey = SecKeyCreateRandomKey(hostAttributes as CFDictionary, &hostError) else {
            fatalError("😡 Could not generate the private key.")
        }

        return hostPrivateKey
    }

    static func createPublicKey(from privateKey: SecKey) -> SecKey {
        guard let hostPublicKey = SecKeyCopyPublicKey(privateKey) else {
            fatalError("😡 Could not generate the public key.")
        }

        return hostPublicKey
    }

    static func createPublicKey(fromBase64 string: String, keySize: EncryptionKey.Size) -> SecKey {
        guard let clientPublicKeyData = Data(base64Encoded: string) else {
            fatalError("😡 Could not untangle the Base 64 encoding of the public key.")
        }
        return createPublicKey(fromBase64: clientPublicKeyData, keySize: keySize)
    }

    static func createPublicKey(fromBase64 data: Data, keySize: EncryptionKey.Size) -> SecKey {
        var clientAttributes = [String: Any]()
        clientAttributes[kSecAttrKeyType as String] = kSecAttrKeyTypeRSA
        clientAttributes[kSecAttrKeyClass as String] = kSecAttrKeyClassPublic
        clientAttributes[kSecAttrKeySizeInBits as String] = keySize.rawValue
        clientAttributes[kSecReturnPersistentRef as String] = false as NSObject

        var error: Unmanaged<CFError>?
        guard let clientPublicKey = SecKeyCreateWithData(data as CFData,
                                                         clientAttributes as CFDictionary,
                                                         &error)
            else {
                fatalError("😡 Client could not recreate the public key.")
        }

        return clientPublicKey
    }

    static func encrypt(data: Data, with key: SecKey) -> Data {
        var clientError: Unmanaged<CFError>?
        let clientTemp = SecKeyCreateEncryptedData(key,
                                                   SecKeyAlgorithm.rsaEncryptionPKCS1,
                                                   data as CFData,
                                                   &clientError)

        guard let clientEncryptedData = clientTemp else {
            fatalError("😡 Encryption failed.")
        }

        return clientEncryptedData as Data
    }

    static func decrypt(data: Data, with key: SecKey) -> Data {
        var error: Unmanaged<CFError>?
        let clientTemp = SecKeyCreateDecryptedData(key,
                                                   SecKeyAlgorithm.rsaEncryptionPKCS1,
                                                   data as CFData,
                                                   &error)

        guard let clientEncryptedData = clientTemp else {
            fatalError("😡 Encryption failed.")
        }

        return clientEncryptedData as Data
    }

}
