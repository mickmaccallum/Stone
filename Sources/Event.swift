//
//  PhoenixEvent.swift
//  Stone
//
//  Created by Michael MacCallum on 5/19/16.
//  Copyright © 2016 Tethr. All rights reserved.
//

import Unbox
import Wrap
import Foundation

public func == (lhs: Event, rhs: Event) -> Bool {
	return lhs.rawValue == rhs.rawValue
}

public func == (lhs: Event, rhs: Event.PhoenixEvent) -> Bool {
	return lhs.rawValue == rhs.rawValue
}

public func != (lhs: Event, rhs: Event.PhoenixEvent) -> Bool {
	return !(lhs == rhs)
}

/**
Used to represent any event received from a Phoenix server. Covers default events that the server may send
such as "phx_join" or "phx_reply", as well as presence related events, and the ability to specify custom events.

The full list of built in events is as follows.

- Join
- Reply
- Leave
- Close
- Error
- Heartbeat
- State
- Diff
- Default
- Presence
- Custom
*/
public enum Event: RawRepresentable, Hashable, Equatable, CustomStringConvertible {
	public enum PhoenixEvent: String {
		case join		= "phx_join"
		case reply		= "phx_reply"
		case leave		= "phx_leave"
		case close		= "phx_close"
		case error		= "phx_error"
		case heartbeat	= "heartbeat"

		public enum PresenceEvent: String {
			case state	= "presence_state"
			case diff	= "presence_diff"
		}
	}

	case phoenix(PhoenixEvent)
	case presence(PhoenixEvent.PresenceEvent)
	case custom(String)
	case none

	public var description: String {
		return rawValue
	}

	public var isDefault: Bool {
		return PhoenixEvent(rawValue: rawValue) != nil
	}

	public var rawValue: String {
		switch self {
		case .phoenix(let known):
			return known.rawValue
		case .presence(let presence):
			return presence.rawValue
		case .custom(let str):
			return str
		case .none:
			return ""
		}
	}

	public var hashValue: Int {
		return rawValue.hashValue
	}

	public init?(rawValue: String) {
		if let def = PhoenixEvent(rawValue: rawValue) {
			self = .phoenix(def)
		} else if let presence = PhoenixEvent.PresenceEvent(rawValue: rawValue) {
			self = .presence(presence)
		} else {
			self = .custom(rawValue)
		}
	}
}

extension Event: UnboxableRawType {
	public static func unboxFallbackValue() -> Event {
		return .none
	}

	public static func transform(unboxedNumber: NSNumber) -> Event? {
		return nil
	}

	public static func transform(_ unboxedInt: Int) -> Event? {
		return nil
	}

	public static func transform(unboxedString: String) -> Event? {
		return Event(rawValue: unboxedString)
	}
}

extension Event: WrappableEnum {
	public func wrap() -> AnyObject? {
		return rawValue as AnyObject?
	}
}
