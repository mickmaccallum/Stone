//
//  Result.swift
//  Stone
//
//  Created by Michael MacCallum on 5/17/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

public enum Result<T> {
	case success(T)
	case failure(Error)

	public func value() throws -> T {
		switch self {
		case .success(let value):
			return value
		case .failure(let error):
			throw error
		}
	}

	public init(function: () throws -> T) {
		do {
			self = .success(try function())
		} catch {
			self = .failure(error )
		}
	}
}
