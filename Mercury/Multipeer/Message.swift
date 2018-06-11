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
}

typealias Message = (type: MessageType, payload: [String : Any])

func encodeMessage(_ message: Message) throws -> Data {
    var contents: [String : Any] = [:]
    contents["messageType"] = message.type.rawValue
    contents["payload"] = message.payload
    return try JSONSerialization.data(withJSONObject: contents, options: [.sortedKeys])
}

enum MessageDecodingError: Error {
    case illegalPayload
}

func decodeMessage(_ data: Data) throws -> Message {
    guard
        let object = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any],
        let typeString = object["messageType"] as? String,
        let type = MessageType(rawValue: typeString),
        let payload = object["payload"] as? [String : Any]
    else {
        throw MessageDecodingError.illegalPayload
    }

    return (type, payload)
}
