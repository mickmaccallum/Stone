//
//  Channel.swift
//  Stone
//
//  Created by Michael MacCallum on 5/16/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import SwiftWebSocket
import Unbox
import Wrap

/**
Defines a Channel for communicating with a given topic on your Phoenix server.
*/
public final class Channel: Hashable, Equatable, CustomStringConvertible {
	public let topic: String

	public typealias ResultCallback = (_ result: Result<IncomingMessage>) -> Void
	public typealias EventCallback = (_ message: IncomingMessage) -> Void
	/// The state of the connection to this Channel.
	public internal(set) var state: ChannelState = .closed

	public var shouldTrackPresence = false

	fileprivate var eventBindings = [String: ResultCallback]()
	fileprivate var callbackBindings = [String: ResultCallback?]()

	internal weak var socket: Socket?

	/// Channels are unique by their topics.
	public var hashValue: Int {
		return topic.hashValue
	}

	public var description: String {
		return "Channel(topic: \(topic), tracks presence: \(shouldTrackPresence), state: \(state))"
	}

	/**
	Creates a new channel for the given topic. Topic can either be a String, or any enum you've defined whose
	RawValue == String for convenience.
	*/
	public convenience init<RawType: RawRepresentable>(topic: RawType) where RawType.RawValue == String {
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
	public func isMemberOfTopic(_ otherTopic: String) -> Bool {
		return topic == otherTopic
	}

	public func isMemberOfTopic<RawType: RawRepresentable>(_ otherTopic: RawType) -> Bool where RawType.RawValue == String {
		return isMemberOfTopic(otherTopic.rawValue)
	}

	internal func receiveMessage(message: IncomingMessage) {
		if state == .closed {
			return
		}

		if message.event == .reply {
			handleReply(message: message)
		} else {
			if let eventBinding = eventBindings[message.event.rawValue] {
				eventBinding(.success(message))
			}

			guard let presenceEvent = Event.PhoenixEvent.PresenceEvent(rawValue: message.event.rawValue), shouldTrackPresence else {
				return
			}

			handlePresenceEvent(presenceEvent, withPayload: message.payload)
		}
	}

	internal func triggerEvent(_ event: Event.PhoenixEvent) {
		let message = IncomingMessage(topic: topic, event: Event.phoenix(event))
		handlePhoenixEvent(event, message: message)
	}

	fileprivate func handleReply(message: IncomingMessage) {
		guard let ref = message.ref else {
			return
		}

		if let phoenixEvent = Event.PhoenixEvent(rawValue: ref) {
			handlePhoenixEvent(phoenixEvent, message: message)
		}

		if let replyCallback = callbackBindings.removeValue(forKey: ref) {
			replyCallback?(.success(message))
		}
	}

	fileprivate func handlePhoenixEvent(_ event: Event.PhoenixEvent, message: IncomingMessage) {
		switch event {
		case .join:
			onJoin?(message)
		case .reply:
			onReply?(message)
		case .leave:
			onLeave?(message)
		case .close:
			onClose?(message)
		case .error:
			onError?(message)
		default:
			break
		}
	}

	fileprivate func handlePresenceEvent(_ event: Event.PhoenixEvent.PresenceEvent, withPayload payload: Data?) {
		switch event {
		case .state:
			presenceStateCallback?(
				Result.success(
					PresenceWrapper(data: payload)
				)
			)
		case .diff:
			presenceDiffCallback?(
				Result.success(
					PresenceDiffWrapper(data: payload)
				)
			)
		}
	}

	public var onJoin: EventCallback?
	public var onReply: EventCallback?
	public var onError: EventCallback?
	public var onLeave: EventCallback?
	public var onClose: EventCallback?

	fileprivate func triggerInternalEvent(_ event: Event.PhoenixEvent, withMessage message: IncomingMessage) {
		switch message.topic {
		case topic:
			state = .joined
			onJoin?(message)
		default:
			onReply?(message)
		}
	}

	/**
	Registers a callback to occur when this Channel receives the given event.

	- returns: The last function given as a callback for this Event on this Channel if one exists, nil otherwise.
	*/
	@discardableResult
	public func onEvent(_ event: Event, callback: @escaping ResultCallback) -> ResultCallback? {
		return eventBindings.updateValue(callback, forKey: event.rawValue)
	}

	/**
	Unregisters a callback from occurring when this Channel receives the given event.

	- returns: The function that used to be the callback for this Event if one exists, nil otherwise.
	*/
	public func offEvent(_ event: Event) -> ResultCallback? {
		return eventBindings.removeValue(forKey: event.rawValue)
	}

	fileprivate var presenceDiffCallback: ((_ result: Result<PresenceDiffWrapper>) -> Void)?

	/**
	Registers a callback to be received whenever a presence diff update occurs.
	*/
	public func onPresenceDiff(_ callback: @escaping (_ result: Result<PresenceDiffWrapper>) -> Void) {
		presenceDiffCallback = callback
	}

	fileprivate var presenceStateCallback: ((_ result: Result<PresenceWrapper>) -> Void)?

	/**
	Registers a callback to be received whenever a presence state update occurs.
	*/
	public func onPresenceState(_ callback: @escaping (_ result: Result<PresenceWrapper>) -> Void) {
		presenceStateCallback = callback
	}

	/**
	Sends the given Message over the receiving Channel. When the server replies, the contents of the reply will be
	given in the completion handler.
	*/
	// 	public typealias ResultCallback = (_ result: Result<Message>) -> Void

	public func sendMessage(_ message: OutboundMessage, completion: ResultCallback? = nil) {
		guard let socket = socket else {
			completion?(.failure(StoneError.lostSocket))
			return
		}

		do {
			try socket.push(message)

			callbackBindings.updateValue(
				completion,
				forKey: message.ref
			)
		} catch {
			completion?(.failure(StoneError.invalidJSON))
		}
	}

	/**
	Sends a join message to the Channel's topic.
	*/
	public func join(_ completion: ResultCallback? = nil) {
		guard state == .closed || state == ChannelState.errored else {
			return
		}
		
		state = .joining
		let joinMessage = OutboundMessage(
			topic: topic,
			event: .phoenix(.join),
			payload: "{}",
			ref: Event.phoenix(.join).description
		)

		callbackBindings[joinMessage.ref] = completion
		sendMessage(joinMessage, completion: nil)
	}

	/**
	Leaves the receiving Channel. If you leave a Channel, you won't continue to get callbacks for the messages that
	it receives, even if the Channel object happens to still be alive.
	*/
	public func leave(_ completion: ((_ success: Bool) -> Void)? = nil) {
		let leaveMessage = OutboundMessage(
			topic: topic,
			event: .phoenix(.leave),
			payload: "{}"
		)

		sendMessage(leaveMessage) { [weak self] result in
			self?.state = .closed
			
			do {
				self?.handleReply(message: try result.value())

				completion?(true)
			} catch {
				completion?(false)
			}
		}
	}
}

public func == (lhs: Channel, rhs: Channel) -> Bool {
	return lhs.hashValue == rhs.hashValue
}
