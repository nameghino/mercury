//
//  MultipeerSyncEngine.swift
//  Mercury
//
//  Created by Nico Ameghino on 14/6/18.
//  Copyright © 2018 Nico Ameghino. All rights reserved.
//

import Foundation
import MultipeerConnectivity

class MultipeerSyncEngine<Message: MultipeerMessage & Codable> {
    class SyncEngineMessage<M: MultipeerMessage & Codable>: MultipeerMessage, Codable {
        let key: String
        let value: M
        let date: Date

        init(value: M, key: String? = nil) {
            self.key = key ?? UUID().uuidString
            self.value = value
            self.date = Date()
        }
    }

    private var manager: MultipeerManager<SyncEngineMessage> {
        didSet {
            manager.messageReceived = self.onSyncMessageReceived
        }
    }

    private var cache: [String : Message] = [:]

    init(serviceType: String, discoveryInfo: [String : String]? = nil) {
        self.manager = MultipeerManager<SyncEngineMessage>(serviceType: serviceType, discoveryInfo: discoveryInfo)
    }

    func insert(_ o: Message) {
        let syncMessage = SyncEngineMessage(value: o)
        cache[syncMessage.key] = o
        manager.broadcast(message: syncMessage)
    }

    func onSyncMessageReceived(from peer: String, message: SyncEngineMessage) {

    }




}
