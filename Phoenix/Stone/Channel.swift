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

	public typealias Callback = Result<Void> -> Void
	public private(set) var state: ChannelState = .Closed
	private var bindings = [String: Callback]()

	public var hashValue: Int {
		return topic.hashValue
	}

	public convenience init<RawType: RawRepresentable where RawType.RawValue == String>(socket: Socket, topic: RawType) {
		self.init(socket: socket, topic: topic.rawValue)
	}

	public init(socket: Socket, topic: String) {
		self.topic = topic
	}

	public func isMemberOfTopic(otherTopic: String) -> Bool {
		return topic == otherTopic
	}

	internal func sendMessage(message: Message) {
		
	}

	internal func triggerEvent(event: Event, ref: String, payload: [String: AnyObject]? = nil) {

	}

	public func onEvent<RawType: RawRepresentable where RawType.RawValue == String>(event: RawType, callback: Callback) {
		onEvent(event.rawValue, callback: callback)
	}

	public func onEvent(event: String, callback: Callback) {
		
	}
}

public func == (lhs: Channel, rhs: Channel) -> Bool {
	return true
}
