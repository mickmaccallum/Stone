//
//  Channel.swift
//  Phoenix
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
	public typealias Callback = Result<Void> -> Void
	public private(set) var state: ChannelState = .Closed
	private var bindings = [String: Callback]()

	public init(socket: Socket) {

	}

	public var hashValue: Int {
		return 0
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
