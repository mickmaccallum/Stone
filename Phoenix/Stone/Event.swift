//
//  StoneEvent.swift
//  Stone
//
//  Created by Michael MacCallum on 5/19/16.
//  Copyright © 2016 Tethr. All rights reserved.
//

import Foundation
import Unbox
import Wrap

public enum Event: RawRepresentable {
	public enum StoneEvent: String {
		case Join		= "phx_join"
		case Reply		= "phx_reply"
		case Leave		= "phx_leave"
		case Close		= "phx_close"
		case Error		= "phx_error"
		case Heartbeat	= "heartbeat"
	}

	case Default(StoneEvent)
	case Custom(String)

	public var rawValue: String {
		switch self {
		case .Default(let known):
			return known.rawValue
		case .Custom(let str):
			return str
		}
	}

	public init?(rawValue: String) {
		if let def = StoneEvent(rawValue: rawValue) {
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
