//
//  Socket.swift
//  Stone
//
//  Created by Michael MacCallum on 5/8/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import Foundation
import SwiftWebSocket
import Wrap
import Unbox

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

	/// <#Description#>
	public var onOpen: (() -> Void)?
	/// <#Description#>
	public var onError: ((error: NSError) -> Void)?
	/// <#Description#>
	public var onClose: ((code: Int, reason: String, wasClean: Bool) -> Void)?
	/// <#Description#>
	public var onMessage: ((result: Result<Message>) -> Void)?

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
	Instantiates a new Stone Socket with the given url and optional heartbeat and reconnect intervals.


	- parameter url:				The URL at which the socket should try to connect to.
	- parameter heartbeatInterval:	Once connected, this is the interval at which we will tell the server that we're still listening. Default value is nil. If nil or <= 0.0, a heartbeat won't be used, and the socket will organically disconnect.
	- parameter reconnectInterval:	The interval after which we should try to reconnect after a socket disconnects.
	*/
	public init?(url: NSURL, heartbeatInterval: NSTimeInterval? = nil, reconnectInterval: NSTimeInterval = 5.0) {
		self.heartbeatInterval = heartbeatInterval
		self.reconnectInterval = reconnectInterval

		queue.suspended = true

		let components = NSURLComponents(
			URL: url.URLByAppendingPathComponent("websocket"),
			resolvingAgainstBaseURL: true
		)

		if url.scheme == "http" {
			components?.scheme = "ws"
		} else if url.scheme == "https" {
			components?.scheme = "wss"
		} else {
			assert(
				url.scheme == "ws" || url.scheme == "wss",
				"Invalid URL scheme provided. Must be either HTTP, HTTPS, WS, or WSS."
			)
		}

		guard let url = components?.URL else {
			return nil
		}

		self.url = url
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
		if !channels.contains(channel) {
			channels.insert(channel)
		}
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
		try! push(
			Message(
				topic: "phoenix",
				event: Event.Default(.Heartbeat)
			)
		)
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

	/**
	<#Description#>

	- parameter message:	<#message description#>

	- throws: If message couldn't successfully be converted to JSON.
	*/
	public func push(message: Message) throws {
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

		onOpen?()
	}

	private func webSocketDidReceiveMessage(messageStr: String) {
		guard let messageData = messageStr.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false) else {
			return
		}

		do {
			let message: Message = try Unbox(messageData)

			for channel in channels where channel.isMemberOfTopic(message.topic) {

				channel.triggerEvent(
					message.event,
					payload: message.payload
				)
			}

			onMessage?(result: .Success(message))
		} catch let error as NSError {
			webSocketDidError(error)
			onMessage?(result: .Failure(error))
		}
	}
	
	private func webSocketDidClose(code code: Int, reason: String, wasClean: Bool) {
		queue.suspended = true
		// trigger channel event here

		if reconnectOnError {

		}

		onClose?(code: code, reason: reason, wasClean: wasClean)
	}

	private func webSocketDidError(error: NSError) {
		queue.suspended = true
		discardHeartBeatTimer()

		onError?(error: error)

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
