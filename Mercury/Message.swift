//
//  Message.swift
//  Mercury
//
//  Created by Nico Ameghino on 11/6/18.
//  Copyright © 2018 Nico Ameghino. All rights reserved.
//

import Foundation

enum MessageType: String {
    case ping
    case pong
    case scan
    case update
    case message
    case buzz
}

struct MercuryMessage: MultipeerMessage {
    let type: MessageType
    let payload: [String : Any]

    init(type: MessageType, payload: [String : Any]? = nil) {
        self.type = type
        self.payload = payload ?? [:]
    }

    func encode() throws -> Data {
        var contents: [String : Any] = [:]
        contents["messageType"] = type.rawValue
        contents["payload"] = payload
        return try JSONSerialization.data(withJSONObject: contents, options: [.sortedKeys])
    }

    var isSystemMessage: Bool { return false }

    static func decode(from data: Data) throws -> MercuryMessage {
        guard
            let object = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any],
            let typeString = object["messageType"] as? String,
            let type = MessageType(rawValue: typeString),
            let payload = object["payload"] as? [String : Any]
            else {
                throw MessageDecodingError.illegalPayload
        }
        return MercuryMessage(type: type, payload: payload)
    }
}
