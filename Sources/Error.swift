//
//  Error.swift
//  Stone
//
//  Created by Michael MacCallum on 5/19/16.
//  Copyright © 2016 Tethr. All rights reserved.
//

import Foundation

/**
Represents various errors that can occur while interacting with Stone.

- LostSocket:
- InvalidJSON:
- AlreadyJoined:
*/
public enum Error: ErrorType, CustomStringConvertible {
	case LostSocket, InvalidJSON, AlreadyJoined

	public var description: String {
		switch self {
		case .LostSocket:
			return "The connection to the Web Socket was lost"
		case .InvalidJSON:
			return "The given payload couldn't be represented as JSON."
		case .AlreadyJoined:
			return "Attempted to join a channel that you had already joined."
		}
	}
}