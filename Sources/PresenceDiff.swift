//
//  PresenceDiff.swift
//  Stone
//
//  Created by Michael MacCallum on 5/21/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import Unbox

public struct PresenceDiff: Unboxable {
	public let joins:  [Stone.PresenceChange]
	public let leaves: [Stone.PresenceChange]

	public init(unboxer: Unboxer) throws {
		let tmpJoins: [String: AnyObject] = try unboxer.unbox(key: "joins")
		joins = tmpJoins.map {
			Stone.PresenceChange(
				name: $0.0,
				metas: ($0.1 as? [String: AnyObject]) ?? [String: AnyObject]()
			)
		}

		let tmpLeaves: [String: AnyObject] = try unboxer.unbox(key: "leaves")

		leaves = tmpLeaves.map {
			Stone.PresenceChange(
				name: $0.0,
				metas: ($0.1 as? [String: AnyObject]) ?? [String: AnyObject]()
			)
		}
	}
}


