//
//  Message.swift
//  Stone
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

	/**
	<#Description#>

	- parameter topic:		<#topic description#>
	- parameter event:		<#event description#>
	- parameter payload:	<#payload description#>
	- parameter ref:			<#ref description#>

	- returns: <#return value description#>
	*/
	public init<RawType: RawRepresentable where RawType.RawValue == String>(topic: RawType, event: Event, payload: [String: AnyObject] = [:], ref: String? = Message.reference.description) {
		self.init(topic: topic.rawValue, event: event, payload: payload, ref: ref)
	}

	/**
	<#Description#>

	- parameter topic:		<#topic description#>
	- parameter event:		<#event description#>
	- parameter payload:	<#payload description#>
	- parameter ref:			<#ref description#>

	- returns: <#return value description#>
	*/
	public init(topic: String, event: Event, payload: [String: AnyObject] = [:], ref: String? = Message.reference.description) {
		self.topic		= topic
		self.event		= event
		self.payload	= payload
		self.ref		= ref ?? String(format: "%lu", Message.reference)
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
