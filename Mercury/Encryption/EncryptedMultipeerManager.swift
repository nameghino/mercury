//
//  EncryptedMultipeerManager.swift
//  Mercury
//
//  Created by Nico Ameghino on 24/6/18.
//  Copyright © 2018 Nico Ameghino. All rights reserved.
//

import Foundation
import MultipeerConnectivity

class EncryptedMultipeerManager<Message: MultipeerMessage>: MultipeerManager<Message> {
    private let ownKey: EncryptionKey
    private var peerKeys: [MCPeerID : EncryptionKey] = [:]

    private let keySize: EncryptionKey.Size

    init(serviceType: String, discoveryInfo: [String : String]? = nil, keySize: EncryptionKey.Size = .default) {
        self.keySize = keySize
        ownKey = EncryptionKey(applicationTag: serviceType, keySize: keySize)
        super.init(serviceType: serviceType, discoveryInfo: discoveryInfo)
    }

    override func send(message: Message, to peers: [MCPeerID]) {
        do {
            let data = try message.encode()
            let encryptedData = try ownKey.encrypt(data: data)
            try session.send(encryptedData, toPeers: peers, with: .reliable)
        } catch {
            fatalError()
        }
    }

    override func broadcast(message: Message) {
        do {
            let data = try message.encode()
            let encryptedData = try ownKey.encrypt(data: data)
            try session.broadcast(data: encryptedData, with: .reliable)
        } catch {
            fatalError()
        }
    }

    override func didReceive(data: Data, from peer: MCPeerID, from session: MCSession) {
        do {
            // try decoding a key exchange message
            if
                let anyPayload = try? JSONSerialization.jsonObject(with: data, options: []),
                let payload = anyPayload as? [String : String],
                let type = payload["type"],
                let base64Key = payload["peerPublicKey"],
                type == "system.key-exchange" {
                peerKeys[peer] = EncryptionKey(base64String: base64Key, keySize: self.keySize)
                return
            }

            guard let peerKey = peerKeys[peer] else {
                fatalError("could not find peer key")
            }

            let decryptedData = try peerKey.decrypt(data: data)
            let message = try Message.decode(from: decryptedData)
            self.messageReceived?(peer.displayName, message)
        } catch {
            fatalError()
        }
    }

    override func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("\(#function)")
        do {
            let context = ["peerPublicKey" : ownKey.base64PublicKey]
            let data = try JSONSerialization.data(withJSONObject: context, options: [])
            browser.invitePeer(peerID, to: self.session, withContext: data, timeout: 10)
        } catch {
            fatalError()
        }
    }

    /*
     override func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
     do {
     let dictionary = try JSONSerialization.jsonObject(with: context!, options: []) as! [String : String]
     let base64key = dictionary["peerPublicKey"]!
     let key = EncryptionKey(base64String: base64key, keySize: .default)
     peerKeys[peerID] = key
     invitationHandler(true, self.session)
     } catch {
     fatalError()
     }
     }
     */

    override func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("\(#function) - \(peerID.displayName) - \(state)")
        if state == .connected {
            // exchange keys again, just in case
            do {
                let payload = try createKeyExchangePayload()
                try session.send(payload, toPeers: [peerID], with: .reliable)
            } catch {
                fatalError()
            }
        }
        super.session(session, peer: peerID, didChange: state)
    }

    private func createKeyExchangePayload() throws -> Data {
        let payload: [String : String] = [
            "type": "system.key-exchange",
            "peerPublicKey" : ownKey.base64PublicKey
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }
}
