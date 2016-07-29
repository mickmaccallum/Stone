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

/**
Defines a Channel for communicating with a given topic on your Phoenix server.
*/
public final class Channel: Hashable, Equatable {
	public let topic: String

	public typealias ResultCallback = (result: Stone.Result<Stone.Message>) -> Void
	public typealias EventCallback = (message: Stone.Message) -> Void
	/// The state of the connection to this Channel.
	public internal(set) var state: Stone.ChannelState = .Closed

	public var shouldTrackPresence = false

	private var eventBindings = [String: ResultCallback]()
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

	public func isMemberOfTopic<RawType: RawRepresentable where RawType.RawValue == String>(otherTopic: RawType) -> Bool {
		return isMemberOfTopic(otherTopic.rawValue)
	}

	internal func triggerEvent(event: Stone.Event, ref: String? = nil, payload: [String: AnyObject] = [:]) {
		guard state != .Closed else {
			return
		}

		let message = Stone.Message(
			topic: topic,
			event: event,
			payload: payload,
			ref: ref
		)

		if event == .Reply {
			if let ref = ref {
				if let defaultEvent = Event.PhoenixEvent(rawValue: ref) {
					handleDefaultEvent(defaultEvent, message: message)
				}

				if let replyCallback = callbackBindings.removeValueForKey(ref) {
					replyCallback?(result: .Success(message))
				}
			}
		} else {
			
			if let eventBinding = eventBindings[event.rawValue] {
				eventBinding(result: .Success(message))
			}

			if let presenceEvent = Stone.Event.PhoenixEvent.PresenceEvent(rawValue: event.rawValue) where shouldTrackPresence {
				handlePresenceEvent(presenceEvent, withPayload: message.payload)
			}
		}
	}

	private func handleDefaultEvent(event: Event.PhoenixEvent, message: Message) {
		switch event {
		case .Join:
			onJoin?(message: message)
		case .Reply:
			onReply?(message: message)
		case .Leave:
			onLeave?(message: message)
		case .Close:
			onClose?(message: message)
		case .Error:
			onError?(message: message)
		default:
			break
		}
	}

	private func handlePresenceEvent(event: Stone.Event.PhoenixEvent.PresenceEvent, withPayload payload: [String: AnyObject]) {
		switch event {
		case .State:
			presenceStateCallback?(
				result: Stone.Result.Success(
					payload.map {
						Stone.PresenceChange(
							name: $0.0,
							metas: ($0.1 as? [String: AnyObject]) ?? [String: AnyObject]()
						)
					}
				)
			)
		case .Diff:
			do {
				presenceDiffCallback?(
					result: .Success(
						try Unbox(payload)
					)
				)
			} catch {
				presenceDiffCallback?(result: .Failure(Stone.Error.InvalidJSON))
			}
		}
	}

	public var onJoin: EventCallback?
	public var onReply: EventCallback?
	public var onError: EventCallback?
	public var onLeave: EventCallback?
	public var onClose: EventCallback?

	private func triggerInternalEvent(event: Stone.Event.PhoenixEvent, withMessage message: Stone.Message) {
		switch message.topic {
		case topic:
			state = .Joined
			onJoin?(message: message)
		default:
			onReply?(message: message)
		}
	}

	/**
	Registers a callback to occur when this Channel receives the given event.

	- returns: The last function given as a callback for this Event on this Channel if one exists, nil otherwise.
	*/
	public func onEvent(event: Stone.Event, callback: ResultCallback) -> ResultCallback? {
		return eventBindings.updateValue(callback, forKey: event.rawValue)
	}

	/**
	Unregisters a callback from occurring when this Channel receives the given event.

	- returns: The function that used to be the callback for this Event if one exists, nil otherwise.
	*/
	public func offEvent(event: Stone.Event) -> ResultCallback? {
		return eventBindings.removeValueForKey(event.rawValue)
	}

	private var presenceDiffCallback: ((result: Stone.Result<Stone.PresenceDiff>) -> Void)?

	/**
	Registers a callback to be received whenever a presence diff update occurs.
	*/
	public func onPresenceDiff(callback: (result: Stone.Result<Stone.PresenceDiff>) -> Void) {
		presenceDiffCallback = callback
	}

	private var presenceStateCallback: ((result: Stone.Result<Array<Stone.PresenceChange>>) -> Void)?

	/**
	Registers a callback to be received whenever a presence state update occurs.
	*/
	public func onPresenceState(callback: (result: Stone.Result<Array<Stone.PresenceChange>>) -> Void) {
		presenceStateCallback = callback
	}

	/**
	Sends the given Message over the receiving Channel. When the server replies, the contents of the reply will be
	given in the completion handler.
	*/
	public func sendMessage(message: Stone.Message, completion: ResultCallback? = nil) {
		guard let socket = socket else {
			completion?(result: .Failure(Stone.Error.LostSocket))
			return
		}

		do {
			try socket.push(message)

			callbackBindings.updateValue(
				completion,
				forKey: message.ref!
			)
		} catch {
			completion?(result: .Failure(Stone.Error.InvalidJSON))
		}
	}

	/**
	Sends a join message to the Channel's topic.
	*/
	public func join(completion: ResultCallback? = nil) {
		guard state == .Closed || state == Stone.ChannelState.Errored else {
			return
		}
		
		state = .Joining
		let joinMessage = Stone.Message(
			topic: topic,
			event: Stone.Event.Phoenix(.Join),
			ref: Stone.Event.Phoenix(.Join).description,
			payload: [:]
		)

		callbackBindings[joinMessage.ref!] = completion
		sendMessage(joinMessage, completion: nil)
	}

	/**
	Leaves the receiving Channel. If you leave a Channel, you won't continue to get callbacks for the messages that
	it receives, even if the Channel object happens to still be alive.
	*/
	public func leave(completion: ((success: Bool) -> Void)? = nil) {
		let leaveMessage = Stone.Message(
			topic: topic,
			event: Stone.Event.Phoenix(.Leave)
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

				completion?(success: true)
			} catch {
				completion?(success: false)
			}
		}
	}
}

public func == (lhs: Stone.Channel, rhs: Stone.Channel) -> Bool {
	return lhs.hashValue == rhs.hashValue
}
