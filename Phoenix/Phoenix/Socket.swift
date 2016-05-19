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
	public let heartbeatInterval: NSTimeInterval?
	public var reconnectInterval: NSTimeInterval
	public let url: NSURL
	public var reconnectOnError = true

	public var onSocketOpen: (() -> Void)?
	public var onSocketError: ((error: NSError) -> Void)?
	public var onSocketClose: ((code: Int, reason: String, wasClean: Bool) -> Void)?
	public var onSocketMessage: ((result: Result<Message>) -> Void)?

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

	/**
	Instantiates a new Phoenix Socket with the given url and optional heartbeat and reconnect intervals.


	- parameter url:				The URL at which the socket should try to connect to.
	- parameter heartbeatInterval:	Once connected, this is the interval at which we will tell the server that we're still listening. Default value is nil. If nil or <= 0.0, a heartbeat won't be used, and the socket will organically disconnect.
	- parameter reconnectInterval:	The interval after which we should try to reconnect after a socket disconnects.
	*/
	public init(url: NSURL, heartbeatInterval: NSTimeInterval? = nil, reconnectInterval: NSTimeInterval = 5.0) {
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

	@objc public func reconnect() {
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

	private func startHeatBeatTimer(timeInterval timeInterval: NSTimeInterval) {
		discardHeartBeatTimer()

		heartBeatTimer = NSTimer.scheduledTimerWithTimeInterval(
			timeInterval,
			target: self,
			selector: #selector(Socket.sendHeartBeat),
			userInfo: nil,
			repeats: true
		)
	}

	private func startReconnectTimer() {
		discardReconnectTimer()

		reconnectTimer = NSTimer.scheduledTimerWithTimeInterval(
			reconnectInterval,
			target: self,
			selector: #selector(Socket.reconnect),
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

	private func webSocketDidOpen() {
		queue.suspended = false
		discardReconnectTimer()

		if let timeInterval = heartbeatInterval where timeInterval > 0.0 {
			startHeatBeatTimer(timeInterval: timeInterval)
		}

		onSocketOpen?()
	}

	private func webSocketDidReceiveMessage(message: String?) {

	}
	
	private func webSocketDidReceiveMessage(messageData: NSData) {
		webSocketDidReceiveMessage(String(data: messageData, encoding: NSUTF8StringEncoding))
	}
	
	private func webSocketDidClose(code code: Int, reason: String, wasClean: Bool) {
		queue.suspended = true
		// trigger channel event here

		if reconnectOnError {

		}

		onSocketClose?(code: code, reason: reason, wasClean: wasClean)
	}

	private func webSocketDidError(error: NSError) {
		queue.suspended = true
		discardHeartBeatTimer()

		onSocketError?(error: error)

		webSocketDidClose(
			code: error.code,
			reason: error.localizedDescription,
			wasClean: true
		)
	}
}

extension Socket: WebSocketDelegate {
	@objc public func webSocketOpen() {
		webSocketDidOpen()
	}

	@objc public func webSocketError(error: NSError) {
		webSocketDidError(error)
	}

	@objc public func webSocketMessageText(text: String) {
		webSocketDidReceiveMessage(text)
	}

	@objc public func webSocketMessageData(data: NSData) {
		webSocketDidReceiveMessage(data)
	}

	@objc public func webSocketClose(code: Int, reason: String, wasClean: Bool) {
		webSocketDidClose(code: code, reason: reason, wasClean: wasClean)
	}

	@objc public func webSocketEnd(code: Int, reason: String, wasClean: Bool, error: NSError?) {
		if let error = error {
			webSocketDidError(error)
		} else {
			webSocketDidClose(code: code, reason: reason, wasClean: wasClean)
		}
	}
}
