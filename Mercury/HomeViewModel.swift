//
//  HomeViewModel.swift
//  Mercury
//
//  Created by Nico Ameghino on 14/6/18.
//  Copyright © 2018 Nico Ameghino. All rights reserved.
//

import Foundation
import UIKit

typealias PinCode = String

protocol HomeViewModelProtocol {
    func host() -> PinCode
    func join(with pin: String)
    func sendPing()
    func send(message: String)

    var isHosting: Bool { get }
    var pin: String? { get }
    var joinQRCodeImage: UIImage? { get }
}

class HomeViewModel: HomeViewModelProtocol {
    private let handler: SessionHandlerProtocol

    lazy private var multipeerManager: MultipeerManager<MercuryMessage> = {
        guard let pin = self.pin else {
            fatalError("pin code was not set")
        }
        let serviceName = "boarding-\(pin)"
        return MultipeerManager<MercuryMessage>(serviceType: serviceName)
    }()

    private(set) var pin: String?
    private(set) var joinQRCodeImage: UIImage?
    private(set) var isHosting: Bool

    private func setupHandlers() {
        // Ugly hack, too late to do it right, maybe tomorrow
        multipeerManager.messageReceived = { from, message in
            self.handler.received(message: message, from: from)
        }

        multipeerManager.peerStateChanged = { peer, isConnected in
            self.handler.peer(peer, stateChangedTo: isConnected)
        }
    }

    init(with handler: SessionHandlerProtocol) {
        self.handler = handler
        self.isHosting = false
    }

    func host() -> PinCode {
        if let pin = self.pin {
            print("hosting with pin \(pin)")
        } else {
            isHosting = true
            pin = HomeViewModel.generatePin()
            joinQRCodeImage = generate(from: "mercury://join?room=\(pin!)")
            setupHandlers()
            multipeerManager.role = .advertiser
            multipeerManager.start()
        }

        let message = MercuryMessage(type: .message, payload: ["text": "Hosting with pin \(pin!)"])
        handler.received(message: message, from: "System")

        return pin!
    }

    func join(with pin: String) {
        self.pin = pin
        multipeerManager = MultipeerManager<MercuryMessage>.init(serviceType: "boarding-\(pin)")
        setupHandlers()
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

    private static func generatePin() -> String {
        let pin = arc4random() % UInt32(10000)
        return "\(pin)"
    }
}
