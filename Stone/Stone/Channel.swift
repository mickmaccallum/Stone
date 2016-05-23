//
//  Channel.swift
//  Stone
//
//  Created by Michael MacCallum on 5/16/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import Foundation
import SwiftWebSocket
import Unbox
public final class Channel: Hashable, Equatable {
	public let topic: String

	public typealias Callback = (result: Result<Message>) -> Void
	public private(set) var state: ChannelState = .Closed

	public var shouldTrackPresence = false

	private var eventBindings = [Event: ResultCallback]()
	private var callbackBindings = [String: ResultCallback?]()

	internal weak var socket: Socket?

	/// Channels are unique by their topics.
	public var hashValue: Int {
		return topic.hashValue
	}

	/**
	Creates a new channel for the given topic. Topic can either be a String, or any enum you've defined whose
	RawValue == String for convenience.
	*/
	public convenience init<RawType: RawRepresentable where RawType.RawValue == String>(topic: RawType) {
		self.init(topic: topic.rawValue)
	}

	/**
	Creates a new channel for the given topic. Topic can either be a String, or any enum you've defined whose
	RawValue == String for convenience.
	*/
	public init(topic: String) {
		self.topic = topic
	}

	/**
	Returns true iff the receiver is a member of the given topic, false otherwise. This method does not take connection
	status into account.
	*/
	public func isMemberOfTopic(otherTopic: String) -> Bool {
		return topic == otherTopic
	}

	internal func triggerEvent(event: Event, ref: String? = nil, payload: [String: AnyObject] = [:]) {
		guard state != .Closed else {
			return
		}

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
			handlePresenceEvent(presenceEvent, withPayload: message.payload)
		}
	}

	private func handlePresenceEvent(event: Event.PhoenixEvent.PresenceEvent, withPayload payload: [String: AnyObject]) {
		switch event {
		case .State:
			presenceStateCallback?(
				result: Result.Success(
					payload.map {
						PresenceChange(
							name: $0.0,
							metas: ($0.1 as? [String: AnyObject]) ?? [String: AnyObject]()
						)
					)
				} catch {
					presenceDiffCallback?(result: .Failure(Error.InvalidJSON))
				}
			}
		}
	}

	public var onJoin: EventCallback?
	public var onReply: EventCallback?
	public var onHeartbeat: EventCallback?
	public var onError: EventCallback?
	public var onLeave: EventCallback?
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
	Registers a callback to occur when this Channel receives the given event.

	- returns: The last function given as a callback for this Event on this Channel if one exists, nil otherwise.
	*/
	public func onEvent(event: Event, callback: ResultCallback) -> ResultCallback? {
		return eventBindings.updateValue(callback, forKey: event)
	}

	/**
	Unregisters a callback from occurring when this Channel receives the given event.

	- returns: The function that used to be the callback for this Event if one exists, nil otherwise.
	*/
	public func offEvent(event: Event) -> ResultCallback? {
		return eventBindings.removeValueForKey(event)
	}

	private var presenceDiffCallback: ((result: Result<PresenceDiff>) -> Void)?

	public func onPresenceDiff(callback: (result: Result<PresenceDiff>) -> Void) {
		presenceDiffCallback = callback
	}

	private var presenceStateCallback: ((result: Result<Array<PresenceChange>>) -> Void)?

	public func onPresenceState(callback: (result: Result<Array<PresenceChange>>) -> Void) {
		presenceStateCallback = callback
	}

	/**
	Sends the given Message over the receiving Channel. When the server replies, the contents of the reply will be
	given in the completion handler.
	*/
	public func sendMessage(message: Message, completion: ResultCallback? = nil) {
		guard let socket = socket else {
			completion?(result: .Failure(Error.LostSocket))
			return
		}

		do {
			try socket.push(message)

			callbackBindings.updateValue(
				completion,
				forKey: message.ref!
			)
		} catch {
			completion?(result: .Failure(Error.InvalidJSON))
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
	Leaves the receiving Channel. If you leave a Channel, you won't continue to get callbacks for the messages that
	it receives, even if the Channel object happens to still be alive.
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
