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

struct TestType: Unboxable, Hashable {
	init(unboxer: Unboxer) {

	}

	var hashValue: Int {
		return 0
	}
}

func ==(lhs: TestType, rhs: TestType) -> Bool {
	return true
}

/**
Defines a Channel for communicating with a given topic on your Phoenix server.
*/
public final class Channel: Hashable, Equatable, CustomStringConvertible {
	public let topic: String

	public typealias ResultCallback = (_ result: Stone.Result<Stone.Message>) -> Void
	public typealias EventCallback = (_ message: Stone.Message) -> Void
	/// The state of the connection to this Channel.
	public internal(set) var state: Stone.ChannelState = .closed

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

	internal func triggerEvent(_ event: Stone.Event, ref: String? = nil, payload: WrappedDictionary = [:]) {
		guard state != .closed else {
			return
		}

		let message = Stone.Message(
			topic: topic,
			event: event,
			payload: payload,
			ref: ref
		)

		if event == .Reply {
			guard let ref = ref else {
				return
			}

			if let defaultEvent = Event.PhoenixEvent(rawValue: ref) {
				handleDefaultEvent(defaultEvent, message: message)
			}

			if let replyCallback = callbackBindings.removeValue(forKey: ref) {
				replyCallback?(.success(message))
			}
		} else {
			if let eventBinding = eventBindings[event.rawValue] {
				eventBinding(.success(message))
			}

			if let presenceEvent = Stone.Event.PhoenixEvent.PresenceEvent(rawValue: event.rawValue) , shouldTrackPresence {
				handlePresenceEvent(presenceEvent, withPayload: message.payload)
			}
		}
	}

	fileprivate func handleDefaultEvent(_ event: Event.PhoenixEvent, message: Message) {
		switch event {
		case .Join:
			onJoin?(message)
		case .Reply:
			onReply?(message)
		case .Leave:
			onLeave?(message)
		case .Close:
			onClose?(message)
		case .Error:
			onError?(message)
		default:
			break
		}
	}

	fileprivate func handlePresenceEvent(_ event: Stone.Event.PhoenixEvent.PresenceEvent, withPayload payload: WrappedDictionary) {
		switch event {
		case .State:
			presenceStateCallback?(
				Stone.Result.success(
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
					.success(
						try unbox(dictionary: payload)
					)
				)
			} catch {
				presenceDiffCallback?(.failure(Stone.StoneError.invalidJSON))
			}
		}
	}

	public var onJoin: EventCallback?
	public var onReply: EventCallback?
	public var onError: EventCallback?
	public var onLeave: EventCallback?
	public var onClose: EventCallback?

	fileprivate func triggerInternalEvent(_ event: Stone.Event.PhoenixEvent, withMessage message: Stone.Message) {
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
	public func onEvent(_ event: Stone.Event, callback: @escaping ResultCallback) -> ResultCallback? {
		return eventBindings.updateValue(callback, forKey: event.rawValue)
	}

	/**
	Unregisters a callback from occurring when this Channel receives the given event.

	- returns: The function that used to be the callback for this Event if one exists, nil otherwise.
	*/
	public func offEvent(_ event: Stone.Event) -> ResultCallback? {
		return eventBindings.removeValue(forKey: event.rawValue)
	}

	fileprivate var presenceDiffCallback: ((_ result: Stone.Result<Stone.PresenceDiff>) -> Void)?

	/**
	Registers a callback to be received whenever a presence diff update occurs.
	*/
	public func onPresenceDiff(_ callback: @escaping (_ result: Stone.Result<Stone.PresenceDiff>) -> Void) {
		presenceDiffCallback = callback
	}

	fileprivate var presenceStateCallback: ((_ result: Stone.Result<Array<Stone.PresenceChange>>) -> Void)?


//	public func test<T: protocol<Unboxable, Hashable>>(closure: (result: Stone.Presence<T>) -> Void) {
////		testState = closure
//		let p = Presence<T>(name: "", metas: [])
//		closure(result: p)
//	}

	var presence: Stone.Presence?

	public func presences<T: Unboxable & Hashable>(_ closure: (_ presences: [String: Set<T>]) -> Void) {
		closure([:])

	}

	/**
	Registers a callback to be received whenever a presence state update occurs.
	*/
	public func onPresenceState(_ callback: @escaping (_ result: Stone.Result<Array<Stone.PresenceChange>>) -> Void) {
		presenceStateCallback = callback
	}

	/**
	Sends the given Message over the receiving Channel. When the server replies, the contents of the reply will be
	given in the completion handler.
	*/
	public func sendMessage(_ message: Stone.Message, completion: ResultCallback? = nil) {
		guard let socket = socket else {
			completion?(.failure(Stone.StoneError.lostSocket))
			return
		}

		do {
			try socket.push(message)

			callbackBindings.updateValue(
				completion,
				forKey: message.ref!
			)
		} catch {
			completion?(.failure(Stone.StoneError.invalidJSON))
		}
	}

	/**
	Sends a join message to the Channel's topic.
	*/
	public func join(_ completion: ResultCallback? = nil) {
		guard state == .closed || state == Stone.ChannelState.errored else {
			return
		}
		
		state = .joining
		let joinMessage = Stone.Message(
			topic: topic,
			event: Stone.Event.phoenix(.Join),
			payload: [:],
			ref: Stone.Event.phoenix(.Join).description
		)

		callbackBindings[joinMessage.ref!] = completion
		sendMessage(joinMessage, completion: nil)
	}

	/**
	Leaves the receiving Channel. If you leave a Channel, you won't continue to get callbacks for the messages that
	it receives, even if the Channel object happens to still be alive.
	*/
	public func leave(_ completion: ((_ success: Bool) -> Void)? = nil) {
		let leaveMessage = Stone.Message(
			topic: topic,
			event: Stone.Event.phoenix(.Leave)
		)

		sendMessage(leaveMessage) { [weak self] result in
			self?.state = .closed
			
			do {
				let message = try result.value()

				self?.triggerEvent(
					leaveMessage.event,
					ref: message.ref,
					payload: message.payload
				)

				completion?(true)
			} catch {
				completion?(false)
			}
		}
	}
}

public func == (lhs: Stone.Channel, rhs: Stone.Channel) -> Bool {
	return lhs.hashValue == rhs.hashValue
}
