//
//  Message.swift
//  Stone
//
//  Created by Michael MacCallum on 5/19/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import Foundation
import Unbox

/**
Represents a message to be sent over a Channel. Includes fields for reference, topic, event, and a payload object.
*/
public struct Message {
	public let ref: String?
	public let topic: String
	public let event: Stone.Event
	public let payload: [String: AnyObject]

	private static var _reference = UInt.max
	private static var reference: UInt {
		get {
			let (new, overflowed) = UInt.addWithOverflow(Message._reference, 1)

			if overflowed {
				_reference = 0
			} else {
				_reference = new
			}

			return _reference
		}
	}

	public init<RawType: RawRepresentable where RawType.RawValue == String>(topic: RawType, event: Event, payload: [String: AnyObject] = [:], ref: String? = Stone.Message.reference.description) {
		self.init(topic: topic.rawValue, event: event, payload: payload, ref: ref)
	}

	public init(topic: String, event: Stone.Event, payload: [String: AnyObject] = [:], ref: String? = Stone.Message.reference.description) {
		self.topic		= topic
		self.event		= event
		self.payload	= payload
		self.ref		= ref ?? String(format: "%lu", Stone.Message.reference)
	}
}

extension Message: Unboxable {
	public init(unboxer: Unboxer) {
		topic		= unboxer.unbox("topic")
		payload		= unboxer.unbox("payload.response")
		ref			= unboxer.unbox("ref")

		let eventString: String = unboxer.unbox("event")
		event = Stone.Event(rawValue: eventString) ?? Stone.Event.Custom("")
	}
}
