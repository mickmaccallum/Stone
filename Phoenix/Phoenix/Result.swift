//
//  Result.swift
//  Phoenix
//
//  Created by Michael MacCallum on 5/17/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import Foundation

public enum Result<T> {
	case Success(T), Failure(ErrorType)

	public func value() throws -> T {
		switch self {
		case .Success(let value): return value
		case .Failure(let error): throw error
		}
	}

	public init(@noescape f: () throws -> T) {
		do {
			self = .Success(try f())
		} catch {
			self = .Failure(error)
		}
	}
}
