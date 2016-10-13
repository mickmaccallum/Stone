//
//  Message.swift
//  Stone
//
//  Created by Michael MacCallum on 5/19/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import Foundation
import Unbox
import Wrap
/**
Represents a message to be sent over a Channel. Includes fields for reference, topic, event, and a payload object.
*/
public struct Message {
	public let ref: String?
	public let topic: String
	public let event: Stone.Event
	public let payload: WrappedDictionary

	public init<RawType: RawRepresentable>(topic: RawType, event: Event, payload: WrappedDictionary = [:], ref: String? = UUID().uuidString) where RawType.RawValue == String {
		self.init(topic: topic.rawValue, event: event, payload: payload, ref: ref)
	}

	public init(topic: String, event: Stone.Event, payload: WrappedDictionary = [:], ref: String? = UUID().uuidString) {
		self.topic		= topic
		self.event		= event
		self.payload	= payload
		self.ref		= ref
	}
}

extension Message: Unboxable {
	public init(unboxer: Unboxer) throws {
		topic		= try unboxer.unbox(key: "topic")
		do {
			payload = try unboxer.unbox(key: "payload.response")
		} catch {
			payload = try unboxer.unbox(key: "payload")
		}

		ref			= unboxer.unbox(key: "ref")

		let eventString: String = try unboxer.unbox(key: "event")
		event = Stone.Event(rawValue: eventString) ?? Stone.Event.custom("")
	}
}
