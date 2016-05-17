//
//  Socket.swift
//  Phoenix
//
//  Created by Michael MacCallum on 5/8/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import Foundation
import SwiftWebSocket


public typealias SocketState = WebSocketReadyState

public final class Socket {
	private var socket: WebSocket?
	public let heartbeatInterval: NSTimeInterval
	public let url: NSURL
	private var channels = Set<Channel>()
	private let queue = NSOperationQueue()

	public init(url: NSURL, heartbeatInterval: NSTimeInterval = 0.0) {
		self.url = url
		self.heartbeatInterval = heartbeatInterval

		queue.suspended = true
	}

	public func connect<T: QueryStringConvertible>(params: [T: T]) {
		connect(params.toQueryItems())
	}

	public func connect(params: [NSURLQueryItem]? = nil) {
		socket = WebSocket(url: url.urlByAppendingQueryItems(params) ?? url)
		socket?.delegate = self
		socket?.open()
		socket?.readyState
	}

	public func addChannel(channel: Channel) {
		channels.insert(channel)
	}

	public func removeChannel(channel: Channel) -> Channel? {
		return channels.remove(channel)
	}
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
