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
    case advertiser, joiner, relay(from: MCPeerID)
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

enum MultipeerManagerInfrastructureMessageType: String {
    case upgradeToRelay
    case downgradeToPeer
}

struct MultipeerManagerInfrastructureMessage: MultipeerMessage, Codable {
    let type: String
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
        case .relay(let advertiser):
            startRelay(with: advertiser)
        }
    }

    func stop() {
        switch role {
        case .advertiser:
            advertiser.stopAdvertisingPeer()
        case .joiner:
            browser.stopBrowsingForPeers()
        case .relay(let advertiser):
            stopRelay(with: advertiser)
        }
    }

    private func startRelay(with advertiser: MCPeerID) {
    }

    private func stopRelay(with advertiser: MCPeerID) {

    }

    private func send(infrastructureMessage: MultipeerManagerInfrastructureMessage, toPeer peer: MCPeerID) {
        do {
            let data = try infrastructureMessage.encode()
            try session.send(data, toPeers: [peer], with: .reliable)
        } catch {
            print("could not send")
        }
    }

    func send(message: Message, toPeer peer: MCPeerID) {
        send(message: message, toPeers: [peer])
    }

    func send(message: Message, toPeers peers: [MCPeerID]) {
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

    private func handle(message: MultipeerManagerInfrastructureMessage) {
        guard let type = MultipeerManagerInfrastructureMessageType(rawValue: message.type) else { return }
        switch type {
        case .upgradeToRelay:
            break
        case .downgradeToPeer:
            break
        }
    }

    // MARK: - Advertiser delegate
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        guard session.connectedPeers.count <= 8 else {
            // pick peer to upgrade to relay
            // for now, just take the first one
            guard let newRelay = session.connectedPeers.first else {
                invitationHandler(false, self.session)
                return
            }

            // send message to become relay
            let message = MultipeerManagerInfrastructureMessage(type: MultipeerManagerInfrastructureMessageType.upgradeToRelay.rawValue)
            send(infrastructureMessage: message, toPeer: newRelay)

            // deny connection
            invitationHandler(false, self.session)
            return
        }
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
        do {
            let message = try Message.decode(from: data)

            // Do not forward infrastructure messages
            if let infrastructureMessage = message as? MultipeerManagerInfrastructureMessage {
                self.handle(message: infrastructureMessage)
                return
            }
            self.messageReceived?(peerID.displayName, message)
        } catch {
            print("could not decode received message")
        }
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
