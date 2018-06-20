//
//  Result.swift
//  Mercury
//
//  Created by Nico Ameghino on 19/6/18.
//  Copyright © 2018 Nico Ameghino. All rights reserved.
//

import Foundation

enum Either<L, R> {
    case left(L)
    case right(R)
}

extension Either: MultipeerMessage where L: MultipeerMessage, R: MultipeerMessage {

    static func decode(from data: Data) throws -> Either<L, R> {
        let lefty = try? L.decode(from: data)
        let righty = try? R.decode(from: data)

        if let v = lefty {
            return .left(v)
        }

        if let v = righty {
            return .right(v)
        }

        fatalError("could not build \(L.self) nor \(R.self) from data")
    }

    func encode() throws -> Data {
        switch self {
        case .left(let m):
            return try m.encode()
        case .right(let m):
            return try m.encode()
        }
    }

    var isSystemMessage: Bool {
        switch self {
        case .left(let m):
            return m.isSystemMessage
        case .right(let m):
            return m.isSystemMessage
        }
    }

}

enum GenericError: Error {
    case message(String)
    case wrapper(Error)
}

enum Result<T, E: Error> {
    case success(T)
    case failure(E)

    var value: T {
        switch self {
        case .failure(let error):
            fatalError("You should have checked. This result holds an error: \(error)")
        case .success(let value):
            return value
        }
    }

    var error: E {
        switch self {
        case .failure(let error):
            return error
        case .success(let value):
            fatalError("You should have checked. This result holds a value: \(value)")
        }
    }

    var isError: Bool {
        switch self {
        case .success(_): return false
        case .failure(_): return true
        }
    }
}
