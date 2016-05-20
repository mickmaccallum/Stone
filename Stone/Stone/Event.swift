//
//  PhoenixEvent.swift
//  Stone
//
//  Created by Michael MacCallum on 5/19/16.
//  Copyright © 2016 Tethr. All rights reserved.
//

import Foundation
import Unbox
import Wrap

public func == (lhs: Event, rhs: Event) -> Bool {
	return lhs.rawValue == rhs.rawValue
}

public func == (lhs: Event, rhs: Event.PhoenixEvent) -> Bool {
	return lhs.rawValue == rhs.rawValue
}

public func != (lhs: Event, rhs: Event.PhoenixEvent) -> Bool {
	return !(lhs == rhs)
}

public enum Event: RawRepresentable, Hashable, Equatable {
	public enum PhoenixEvent: String {
		case Join		= "phx_join"
		case Reply		= "phx_reply"
		case Leave		= "phx_leave"
		case Close		= "phx_close"
		case Error		= "phx_error"
		case Heartbeat	= "heartbeat"
	}

	case Default(PhoenixEvent)
	case Custom(String)

	public var rawValue: String {
		switch self {
		case .Default(let known):
			return known.rawValue
		case .Custom(let str):
			return str
		}
	}

	public var hashValue: Int {
		return rawValue.hashValue
	}

	public init?(rawValue: String) {
		if let def = PhoenixEvent(rawValue: rawValue) {
			self = .Default(def)
		} else {
			self = .Custom(rawValue)
		}
	}
}

extension Event: UnboxableRawType {
	public static func unboxFallbackValue() -> Event {
		return .Custom("")
	}

	public static func transformUnboxedString(unboxedString: String) -> Event? {
		return Event(rawValue: unboxedString)
	}
}

extension Event: WrappableEnum {
	public func wrap() -> AnyObject? {
		return rawValue
	}
}
