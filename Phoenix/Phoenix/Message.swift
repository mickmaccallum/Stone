//
//  Message.swift
//  Phoenix
//
//  Created by Michael MacCallum on 5/19/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import Foundation
import Unbox

public struct Message {
	public let ref: String
	public let topic: String
	public let event: Event
	public let payload: [String: AnyObject]

	private static var reference: UInt = 0

	public init<RawType: RawRepresentable where RawType.RawValue == String>(topic: RawType, event: Event, payload: [String: AnyObject] = [:], ref: String? = nil) {
		self.init(topic: topic.rawValue, event: event, payload: payload, ref: ref)
	}

	public init(topic: String, event: Event, payload: [String: AnyObject] = [:], ref: String? = nil) {
		self.topic		= topic
		self.event		= event
		self.payload	= payload

		if let ref = ref {
			self.ref = ref
		} else {
			let currentRef = String(format: "%zd", Message.reference)
			Message.reference = Message.reference.successor()
			self.ref = currentRef
		}
	}
}

extension Message: Unboxable {
	public init(unboxer: Unboxer) {
		topic		= unboxer.unbox("topic")
		event		= unboxer.unbox("event")
		payload		= unboxer.unbox("payload")
		ref			= unboxer.unbox("ref")
	}
}
