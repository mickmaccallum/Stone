//
//  Channel.swift
//  Stone
//
//  Created by Michael MacCallum on 5/16/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import Foundation
import SwiftWebSocket

public enum ChannelState {
	case Closed, Errored, Joining, Joined
}

public final class Channel: Hashable, Equatable {
	public let topic: String

	public typealias Callback = (result: Result<Message>) -> Void
	public private(set) var state: ChannelState = .Closed

	private var eventBindings = [Event: Callback]()
	private var callbackBindings = [Event: Callback]()

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

		if event == Event.PhoenixEvent.Reply {
			receivedReply(message)
		} else {
			callback(result: .Success(message))
		}
	}

	private func receivedReply(message: Message) {
		print("Received reply in channel for message: \(message)")

		guard let callback = callbackBindings[message.event] else {
			return
		}

		callback(result: .Success(message))
	}

	public func onEvent(event: Event, callback: Callback) -> Callback? {
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
}

public func == (lhs: Channel, rhs: Channel) -> Bool {
	return lhs.hashValue == rhs.hashValue
}
