//
//  HomeViewModel.swift
//  Mercury
//
//  Created by Nico Ameghino on 14/6/18.
//  Copyright © 2018 Nico Ameghino. All rights reserved.
//

import Foundation

class HomeViewModel: HomeViewModelProtocol {
    private let handler: SessionHandlerProtocol
    private var multipeerManager: MultipeerManager<MercuryMessage> = MultipeerManager<MercuryMessage>(serviceType: "boarding")

    private var scanMultipeerManager = MultipeerManager<Scan>(serviceType: "boarding-scan")

    init(with handler: SessionHandlerProtocol) {
        self.handler = handler

        // Ugly hack, too late to do it right, maybe tomorrow
        multipeerManager.messageReceived = { from, message in
            handler.received(message: message, from: from)
        }

        multipeerManager.peerStateChanged = { peer, isConnected in
            handler.peer(peer, stateChangedTo: isConnected)
        }
    }

    func host() {
        multipeerManager.role = .advertiser
        multipeerManager.start()
    }

    func join() {
        multipeerManager.role = .joiner
        multipeerManager.start()
    }

    func sendPing() {
        let message = MercuryMessage(type: .buzz)
        multipeerManager.broadcast(message: message)
    }

    func send(message: String) {
        let message = MercuryMessage(type: .message, payload: ["text": message])
        handler.received(message: message, from: "Me")
        multipeerManager.broadcast(message: message)
    }

    struct Scan: MultipeerMessage, Codable {
        let sid: String
        let date: Date
    }

    func play() {
        let s = Scan(sid: "o587933", date: Date())
        scanMultipeerManager.broadcast(message: s)
    }
}
