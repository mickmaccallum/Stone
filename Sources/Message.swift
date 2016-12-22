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

public protocol MessageType {
	var topic: String { get }
	var event: Event { get }
}

public struct IncomingMessage: MessageType {
	public internal(set) var ref: String?
	public internal(set) var topic: String
	public internal(set) var event: Event
	public var payload: Data?

	public init<RawType: RawRepresentable>(topic: RawType, event: Event, payload: Data? = nil, ref: String? = UUID().uuidString) where RawType.RawValue == String {
		self.init(topic: topic.rawValue, event: event, payload: payload, ref: ref)
	}

	public init(topic: String, event: Event, payload: Data? = nil, ref: String? = UUID().uuidString) {
		self.topic	 = topic
		self.event	 = event
		self.payload = payload
		self.ref     = ref
	}

	public func unboxPayload<T: Unboxable>() throws -> T? {
		guard let payload = payload else {
			return nil
		}

		let data: T = try unbox(data: payload)
		return data
	}
}

extension IncomingMessage: Unboxable {
	public init(unboxer: Unboxer) throws {
		topic	= try unboxer.unbox(key: "topic")
		if let payloadString: String = unboxer.unbox(key: "payload.response") ?? unboxer.unbox(key: "payload") {
			payload = payloadString.data(using: .utf8, allowLossyConversion: false)
		}

		ref		= unboxer.unbox(key: "ref")

		let eventString: String = try unboxer.unbox(key: "event")
		event = Event(rawValue: eventString) ?? Event.none
	}
}

public struct OutboundMessage: MessageType {
	public internal(set) var ref: String
	public internal(set) var topic: String
	public internal(set) var event: Event
	public var payload: String

	public init<RawType: RawRepresentable>(topic: RawType, event: Event, payload: String, ref: String = UUID().uuidString) where RawType.RawValue == String {
		self.init(topic: topic.rawValue, event: event, payload: payload, ref: ref)
	}

	public init(topic: String, event: Event, payload: String, ref: String = UUID().uuidString) {
		self.topic		= topic
		self.event		= event
		self.payload    = payload
		self.ref		= ref
	}
}

///**
//Represents a message to be sent over a Channel. Includes fields for reference, topic, event, and a payload object.
//*/
//public struct Message<T: Unboxable> {
//	public typealias PayloadType = T
//
//	public let ref: String?
//	public let topic: String
//	public let event: Event
//	public let payload: PayloadType?
//
//	public init<RawType: RawRepresentable>(topic: RawType, event: Event, payload: PayloadType? = nil, ref: String? = UUID().uuidString) where RawType.RawValue == String {
//		self.init(topic: topic.rawValue, event: event, payload: payload, ref: ref)
//	}
//
//	public init(topic: String, event: Event, payload: PayloadType? = nil, ref: String? = UUID().uuidString) {
//		self.topic		= topic
//		self.event		= event
//		self.payload	= payload
//		self.ref		= ref
//	}
//}
