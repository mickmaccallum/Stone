//
//  Push.swift
//  Phoenix
//
//  Created by Michael MacCallum on 5/16/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import Foundation
import Wrap

/// <#Description#>
public final class Push {
	private weak var channel: Channel!
	private let event: String
	private let payload: [String: AnyObject]

	private var timeoutTimer: NSTimer?

	/**
	<#Description#>

	- parameter channel: <#channel description#>
	- parameter event:   <#event description#>
	- parameter payload: <#payload description#>

	- throws: <#throws value description#>

	- returns: <#return value description#>
	*/
	public convenience init<RawType: RawRepresentable where RawType.RawValue == String>(channel: Channel, event: RawType, payload: AnyObject) throws {
		try self.init(
			channel: channel,
			event: event.rawValue,
			payload: payload
		)
	}

	/**
	<#Description#>

	- parameter channel: <#channel description#>
	- parameter event:   <#event description#>
	- parameter payload: <#payload description#>

	- returns: <#return value description#>
	*/
	public convenience init<RawType: RawRepresentable where RawType.RawValue == String>(channel: Channel, event: RawType, payload: [String: AnyObject]) throws {
		try self.init(
			channel: channel,
			event: event.rawValue,
			payload: payload
		)
	}

	/**
	<#Description#>

	- parameter channel: <#channel description#>
	- parameter event:   <#event description#>
	- parameter payload: <#payload description#>

	- throws: <#throws value description#>

	- returns: <#return value description#>
	*/
	public convenience init(channel: Channel, event: String, payload: AnyObject) throws {
		try self.init(channel: channel, event: event, payload: try Wrap(payload))
	}

	/**
	<#Description#>

	- parameter channel: <#channel description#>
	- parameter event:   <#event description#>
	- parameter payload: <#payload description#>

	- returns: <#return value description#>
	*/
	public convenience init(channel: Channel, event: String, payload: [String: AnyObject]) throws {
		let jsonData = try NSJSONSerialization.dataWithJSONObject(payload, options: [])
		let jsonString = String(data: jsonData, encoding: NSUTF8StringEncoding)!

		self.init(channel: channel, event: event, payload: jsonString)
	}

	/**
	<#Description#>

	- parameter channel: <#channel description#>
	- parameter event:   <#event description#>
	- parameter payload: <#payload description#>

	- returns: <#return value description#>
	*/
	public init(channel: Channel, event: String, payload: String) {
		self.channel = channel
		self.event = event
		self.payload = [:]
	}

	public func send() {

	}
}