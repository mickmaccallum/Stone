//
//  Channel.swift
//  Stone
//
//  Created by Michael MacCallum on 5/16/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import Foundation
import SwiftWebSocket

public final class Channel: Hashable, Equatable {
	public let topic: String

	public typealias Callback = (result: Result<Message>) -> Void
	public private(set) var state: ChannelState = .Closed

	public var shouldTrackPresence = false

	private var eventBindings = [Event: ResultCallback]()
	private var callbackBindings = [String: ResultCallback?]()

	internal weak var socket: Socket?

	public var hashValue: Int {
		return topic.hashValue
	}

	/**
	<#Description#>

	- parameter topic:	<#topic description#>

	- returns: <#return value description#>
	*/
	public convenience init<RawType: RawRepresentable where RawType.RawValue == String>(topic: RawType) {
		self.init(topic: topic.rawValue)
	}

	/**
	<#Description#>

	- parameter topic:	<#topic description#>

	- returns: <#return value description#>
	*/
	public init(topic: String) {
		self.topic = topic
	}

	public func isMemberOfTopic(otherTopic: String) -> Bool {
		return topic == otherTopic
	}

	internal func triggerEvent(event: Event, ref: String? = nil, payload: [String: AnyObject] = [:]) {
		let message = Message(
			topic: topic,
			event: event,
			payload: payload,
			ref: ref
		)

		if let ref = ref, replyCallback = callbackBindings[ref] {
			replyCallback?(result: .Success(message))
			callbackBindings.removeValueForKey(ref)
		}

		if let callback = eventBindings[event] {
			callback(result: .Success(message))
		}

		if let defaultEvent = Event.PhoenixEvent(rawValue: event.rawValue) {
			triggerInternalEvent(
				defaultEvent,
				withMessage: message
			)
		}

		if let presenceEvent = Event.PhoenixEvent.PresenceEvent(rawValue: event.rawValue) where shouldTrackPresence {
			print(presenceEvent)
			print(ref)
			print(payload)
		}
	}

	/// <#Description#>
	public var onJoin: EventCallback?
	/// <#Description#>
	public var onReply: EventCallback?
	/// <#Description#>
	public var onHeartbeat: EventCallback?
	/// <#Description#>
	public var onError: EventCallback?
	/// <#Description#>
	public var onLeave: EventCallback?
	/// <#Description#>
	public var onClose: EventCallback?

	private func triggerInternalEvent(event: Event.PhoenixEvent, withMessage message: Message) {
		switch event {
		case .Join:
			state = .Joined
			onJoin?(message: message)
		case .Reply:
			onReply?(message: message)
		case .Heartbeat:
			onHeartbeat?(message: message)
		case .Error:
			state = .Errored
			onError?(message: message)
		case .Leave:
			onLeave?(message: message)
		case .Close:
			state = .Closed
			onClose?(message: message)
		}
	}

	/**
	<#Description#>

	- parameter event:		<#event description#>
	- parameter callback:	<#callback description#>

	- returns: <#return value description#>
	*/
	public func onEvent(event: Event, callback: ResultCallback) -> ResultCallback? {
		return eventBindings.updateValue(callback, forKey: event)
	}

	public func offEvent(event: Event) -> Callback? {
		return eventBindings.removeValueForKey(event)
	}

	public func sendMessage(message: Message, completion: Callback) {
		guard let socket = socket else {
			completion(result: .Failure(Error.LostSocket))
			return
		}

		callbackBindings.updateValue(completion, forKey: message.event)

		do {
			try socket.push(message)
		} catch {
			completion(result: .Failure(Error.InvalidJSON))
		}
	}

	/**
	<#Description#>

	- parameter completion:	<#completion description#>
	*/
	public func join() {
		guard state == .Closed || state == ChannelState.Errored else {
			return
		}
		
		state = .Joining
		let joinMessage = Message(
			topic: topic,
			event: Event.Phoenix(.Join),
			payload: [:]
		)
		
		sendMessage(joinMessage, completion: nil)
	}

	/**
	<#Description#>
	*/
	public func leave() {
		let leaveMessage = Message(
			topic: topic,
			event: Event.Phoenix(.Leave)
		)

		sendMessage(leaveMessage) { [weak self] result in
			self?.state = .Closed
			
			do {
				let message = try result.value()

				self?.triggerEvent(
					leaveMessage.event,
					ref: message.ref,
					payload: message.payload
				)
			} catch {

			}
		}
	}
}

public func == (lhs: Channel, rhs: Channel) -> Bool {
	return lhs.hashValue == rhs.hashValue
}
