//
//  EventRef.swift
//  Stone
//
//  Created by Michael MacCallum on 5/22/16.
//  Copyright © 2016 Tethr. All rights reserved.
//

import Foundation

internal struct EventRef: Hashable {
	internal let event: Event
	internal let ref: String?

	internal var hashValue: Int {
		if let ref = ref {
			return "\(event.hashValue)\(ref.hashValue)".hashValue
		}

		return event.hashValue
	}
}

internal func == (lhs: Stone.EventRef, rhs: Stone.EventRef) -> Bool {
	return lhs.event == rhs.event && lhs.ref == rhs.ref
}
