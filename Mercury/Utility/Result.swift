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
