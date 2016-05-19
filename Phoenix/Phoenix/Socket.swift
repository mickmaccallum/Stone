//
//  Socket.swift
//  Phoenix
//
//  Created by Michael MacCallum on 5/8/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import Foundation
import SwiftWebSocket
import Wrap

public typealias SocketState = SwiftWebSocket.WebSocketReadyState

/**
*  @author Michael MacCallum, 16-05-16
*
*  <#Description#>
*
*  @since <#1.0#>
*/
public final class Socket {
	public private(set) var socket: WebSocket?
	public let heartbeatInterval: NSTimeInterval
	public var reconnectInterval: NSTimeInterval
	public let url: NSURL
	public var reconnectOnError = true

	public var onSocketOpen: (() -> Void)?
	public var onSocketError: ((code: Int, reason: String, wasClean: Bool, error: NSError?) -> Void)?
	public var onSocketClose: ((code: Int, reason: String, wasClean: Bool) -> Void)?

	public var socketState: SocketState {
		return socket?.readyState ?? .Closed
	}

	public var connected: Bool {
		return socket?.readyState == .Some(.Open)
	}

	private var heartBeatTimer: NSTimer?
	private var reconnectTimer: NSTimer?
	private var channels = Set<Channel>()
	private var lastParams: [NSURLQueryItem]?
	private let queue = NSOperationQueue()

	public init(url: NSURL, heartbeatInterval: NSTimeInterval = 0.0, reconnectInterval: NSTimeInterval = 5.0) {
		self.url = url
		self.heartbeatInterval = heartbeatInterval
		self.reconnectInterval = reconnectInterval

		queue.suspended = true
	}

	public func connect<T: QueryStringConvertible>(params: [T: T]) {
		connect(params.toQueryItems())
	}

	public func connect(params: [NSURLQueryItem]? = nil) {
		lastParams = params
		socket = WebSocket(url: url.urlByAppendingQueryItems(params) ?? url)
		socket?.delegate = self
		socket?.open()
	}

	public func reconnect() {
		disconnectSocket()
		connect(lastParams)
	}

	public func disconnect() {
		discardHeartBeatTimer()
		discardReconnectTimer()
		disconnectSocket()
	}

	private func disconnectSocket() {
		guard let socket = socket else {
			return
		}

		socket.delegate = nil
		socket.close()
		self.socket = nil
	}

	public func addChannel(channel: Channel) {
		channels.insert(channel)
	}

	public func removeChannel(channel: Channel) -> Channel? {
		return channels.remove(channel)
	}

	private func startHeatBeatTimer() {
		discardHeartBeatTimer()

		heartBeatTimer = NSTimer.scheduledTimerWithTimeInterval(
			heartbeatInterval,
			target: self,
			selector: #selector(Socket.sendHeartBeat),
			userInfo: nil,
			repeats: true
		)
	}

	@objc private func sendHeartBeat() {
		let message = Message(
			topic: "phoenix",
			event: "heartbeat"
		)

		try! push(message)
	}

	private func discardHeartBeatTimer() {
		if let timer = heartBeatTimer where timer.valid {
			timer.invalidate()
		}

		heartBeatTimer = nil
	}

	private func discardReconnectTimer() {
		if let timer = reconnectTimer where timer.valid {
			timer.invalidate()
		}

		reconnectTimer = nil
	}

	func push(message: Message) throws {
		let dict: [String: AnyObject] = try Wrap(message)
		let jsonData = try NSJSONSerialization.dataWithJSONObject(dict, options: [])

		queue.addOperationWithBlock { [weak self] in
			self?.socket?.send(jsonData)
		}
	}
}

extension Socket: WebSocketDelegate {
	@objc public func webSocketOpen() {
		queue.suspended = false

		if heartbeatInterval > 0 {
			startHeatBeatTimer()
		}

		onSocketOpen?()
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
		onSocketClose?(code: code, reason: reason, wasClean: wasClean)
	}

	@objc public func webSocketEnd(code: Int, reason: String, wasClean: Bool, error: NSError?) {
		// close and error handled here.
		//		onSocketError?(code: code, reason: reason, wasClean: wasClean, error: error)
	}
}
