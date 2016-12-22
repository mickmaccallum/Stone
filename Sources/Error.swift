//
//  StoneError.swift
//  Stone
//
//  Created by Michael MacCallum on 5/19/16.
//  Copyright © 2016 Tethr. All rights reserved.
//

/**
Represents various errors that can occur while interacting with 

- LostSocket:
- InvalidJSON:
- AlreadyJoined:
*/
public enum StoneError: Error, CustomStringConvertible {
	case lostSocket, invalidJSON, alreadyJoined

	public var description: String {
		switch self {
		case .lostSocket:
			return "The connection to the Web Socket was lost"
		case .invalidJSON:
			return "The given payload couldn't be represented as JSON."
		case .alreadyJoined:
			return "Attempted to join a channel that you had already joined."
		}
	}
}
