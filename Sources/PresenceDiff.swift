//
//  PresenceDiff.swift
//  Stone
//
//  Created by Michael MacCallum on 5/21/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import Foundation
import Unbox

public struct PresenceDiff: Unboxable {
	public let joins:  [Stone.PresenceChange]
	public let leaves: [Stone.PresenceChange]

	public init(unboxer: Unboxer) {
		let tmpJoins: [String: AnyObject] = unboxer.unbox("joins")

		joins = tmpJoins.map {
			Stone.PresenceChange(
				name: $0.0,
				metas: ($0.1 as? [String: AnyObject]) ?? [String: AnyObject]()
			)
		}

		let tmpLeaves: [String: AnyObject] = unboxer.unbox("leaves")

		leaves = tmpLeaves.map {
			Stone.PresenceChange(
				name: $0.0,
				metas: ($0.1 as? [String: AnyObject]) ?? [String: AnyObject]()
			)
		}
	}
}


