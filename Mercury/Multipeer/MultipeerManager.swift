//
//  MultipeerManager.swift
//  Mercury
//
//  Created by Nico Ameghino on 10/6/18.
//  Copyright © 2018 Nico Ameghino. All rights reserved.
//

import Foundation
import MultipeerConnectivity
import os

enum SessionRole {
    case advertiser, joiner
}

extension MCSession {
    func broadcast(data: Data, with mode: MCSessionSendDataMode) throws {
        try send(data, toPeers: connectedPeers, with: mode)
    }
}

enum MessageDecodingError: Error {
    case illegalPayload
}

protocol MultipeerMessage {
    static func decode(from data: Data) throws -> Self
    func encode() throws -> Data
    var isSystemMessage: Bool { get }
}

extension MultipeerMessage where Self: NSCoding {
    static func decode(from data: Data) throws -> Self {
        guard let m = NSKeyedUnarchiver.unarchiveObject(with: data) as? Self else {
            fatalError()
        }
        return m
    }

    func encode() throws -> Data {
        return NSKeyedArchiver.archivedData(withRootObject: self)
    }
}

extension MultipeerMessage where Self: Codable {
    static func decode(from data: Data) throws -> Self {
        let decoder = JSONDecoder()
        return try decoder.decode(Self.self, from: data)
    }

    func encode() throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(self)
    }
}

class MultipeerManager<Message: MultipeerMessage>: NSObject,
    MCSessionDelegate,
    MCNearbyServiceBrowserDelegate,
MCNearbyServiceAdvertiserDelegate {

    var serviceType = "FILL-WITH-PROPER-INFO"

    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser
    private var peers: [String : MCPeerID] = [:]

    var role: SessionRole = .advertiser
    var peerStateChanged: ((String, Bool) -> Void)?
    var messageReceived: ((String, Message) -> Void)?

    lazy var session: MCSession = {
        let s = MCSession(peer: self.peerID, securityIdentity: nil, encryptionPreference: .required)
        s.delegate = self
        return s
    }()

    init(serviceType: String, discoveryInfo: [String : String]? = nil) {
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: discoveryInfo, serviceType: serviceType)
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        super.init()
        advertiser.delegate = self
        browser.delegate = self
    }

    func start() {
        switch role {
        case .advertiser:
            advertiser.startAdvertisingPeer()
        case .joiner:
            browser.startBrowsingForPeers()
        }
    }

    func stop() {
        switch role {
        case .advertiser:
            advertiser.stopAdvertisingPeer()
        case .joiner:
            browser.stopBrowsingForPeers()
        }
    }

    func send(message: Message, to peer: MCPeerID) {
        send(message: message, to: [peer])
    }

    func send(message: Message, to peers: [MCPeerID]) {
        do {
            let data = try message.encode()
            try session.send(data, toPeers: peers, with: .reliable)
        } catch {
            print("could not send")
        }
    }

    func broadcast(message: Message) {
        do {
            let data = try message.encode()
            try session.broadcast(data: data, with: .reliable)
        } catch {
            print("could not broadcast")
        }
    }

    func didReceive(data: Data, from peer: MCPeerID, from session: MCSession) {
        do {
            let message = try Message.decode(from: data)
            self.messageReceived?(peerID.displayName, message)
        } catch {
            print("could not decode received message")
        }
    }

    // MARK: - Advertiser delegate
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, self.session)
    }

    // MARK: - Browser delegate
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("\(#function)")
        browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("\(#function)")
    }

    // MARK: - Session delegate
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("\(#function) - \(peerID.displayName) - \(state)")
        var connected = false
        switch state {
        case .connected:
            peers[peerID.displayName] = peerID
            connected = true
        case .notConnected:
            peers[peerID.displayName] = nil
        default:
            break
        }
        self.peerStateChanged?(peerID.displayName, connected)
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        print("\(#function) - \(peerID.displayName) - \(data)")
        didReceive(data: data, from: peerID, from: session)
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        fatalError("\(#function) unimplemented")
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        fatalError("\(#function) unimplemented")
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        fatalError("\(#function) unimplemented")
    }
}

class EncryptedMultipeerManager<Message: MultipeerMessage>: MultipeerManager<Message> {
    private let ownKey: EncryptionKey
    private var peerKeys: [MCPeerID : EncryptionKey] = [:]

    init(serviceType: String, discoveryInfo: [String : String]? = nil, keySize: EncryptionKey.Size = .default) {
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
                peerKeys[peer] = EncryptionKey(base64String: base64Key, keySize: .default)
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
