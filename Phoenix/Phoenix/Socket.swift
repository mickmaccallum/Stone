//
//  Socket.swift
//  Phoenix
//
//  Created by Michael MacCallum on 5/8/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import Foundation
import SwiftWebSocket

public final class Socket {
	
}

extension Socket: WebSocketDelegate {
	@objc public func webSocketOpen() {

	}

	@objc public func webSocketPong() {

	}

	@objc public func webSocketError(error: NSError) {

	}

	@objc public func webSocketMessageText(text: String) {

	}

	@objc public func webSocketMessageData(data: NSData) {

	}

	@objc public func webSocketClose(code: Int, reason: String, wasClean: Bool) {

	}

	@objc public func webSocketEnd(code: Int, reason: String, wasClean: Bool, error: NSError?) {

	}
}
