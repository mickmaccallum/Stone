//
//  PresenceChange.swift
//  Stone
//
//  Created by Michael MacCallum on 5/23/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import Foundation.NSDictionary

public struct PresenceChange: Equatable {
	public let name: String
	public let metas: [String: AnyObject]
}

public func == (lhs: Stone.PresenceChange, rhs: Stone.PresenceChange) -> Bool {
	return lhs.name == rhs.name && NSDictionary(
		dictionary: lhs.metas
	).isEqualToDictionary(rhs.metas)
}
