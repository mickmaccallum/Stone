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

	private var eventBindings = [Event: ResultCallback]()
	private var internalEventBindings = [Event: ResultCallback]()
	private var callbackBindings = [Event: ResultCallback]()

	private weak var socket: Socket?

	public var hashValue: Int {
		return topic.hashValue
	}

	public convenience init<RawType: RawRepresentable where RawType.RawValue == String>(socket: Socket, topic: RawType) {
		self.init(socket: socket, topic: topic.rawValue)
	}

	public init(socket: Socket, topic: String) {
		self.topic = topic
		self.socket = socket
	}

	public func isMemberOfTopic(otherTopic: String) -> Bool {
		return topic == otherTopic
	}

	internal func triggerEvent(event: Event, ref: String? = nil, payload: [String: AnyObject] = [:]) {
		guard let callback = eventBindings[event] else {
			return
		}

		let message = Message(
			topic: topic,
			event: event,
			payload: payload,
			ref: ref
		)

		if let defaultEvent = Event.PhoenixEvent(rawValue: event.rawValue) {
			triggerInternalEvent(
				defaultEvent,
				withMessage: message
			)
		}

		callback(result: .Success(message))
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
			onJoin?(message: message)
		case .Reply:
			onReply?(message: message)
		case .Heartbeat:
			onHeartbeat?(message: message)
		case .Error:
			onError?(message: message)
		case .Leave:
			onLeave?(message: message)
		case .Close:
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

	public func join(completion: Callback) {
		let joinMessage = Message(
			topic: topic,
			event: Event.Default(.Join),
			payload: [:]
		)
		
		sendMessage(joinMessage, completion: completion)
	}

	/**
	<#Description#>
	*/
	public func leave() {
		let leaveMessage = Message(
			topic: topic,
			event: Event.Default(.Leave)
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
