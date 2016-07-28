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
The connection over which Channel communication can occur.
*/
public final class Socket {
	/// The underlying WebSocket used for communicating with the server.
	public private(set) var socket: WebSocket?
	/// The interval at which a heartbeat message will be broadcast to the server.
	public let heartbeatInterval: NSTimeInterval?
	/// The interval at which we should try to reconnect to the socket if the connection is lost.
	public var reconnectInterval: NSTimeInterval
	/// The URL that the web socket is connected to.
	public let url: NSURL
	/// Whether or not we should automatically attempt to reconnect to the server if an error occurs.
	public var shouldReconnectOnError = true

	public var shouldAutoJoinChannels = true

	/// Called whenever a web socket connection is established.
	public var onOpen: (() -> Void)?
	/// Called whenever the socket receives an error event.
	public var onError: ((error: NSError) -> Void)?
	/// Called whenever the web socket connection is closed.
	public var onClose: ((code: Int, reason: String, wasClean: Bool) -> Void)?
	/// Called for every message that is received over the socket (called a lot).
	public var onMessage: ((result: Stone.Result<Stone.Message>) -> Void)?

	/// The connection state of the underlying socket.
	public var socketState: SocketState {
		return socket?.readyState ?? .Closed
	}

	/// Returns true if the socket is currenly connected to the server, false otherwise.
	public var connected: Bool {
		return socket?.readyState == .Some(.Open)
	}

	private var heartBeatTimer: NSTimer?
	private var reconnectTimer: NSTimer?
	public private(set) var channels = Set<Channel>()
	private var lastParams: [NSURLQueryItem]?
	private let queue = NSOperationQueue()

	/**
	Instantiates a new Stone Socket with the given url and optional heartbeat and reconnect intervals.


	- parameter url:				The URL at which the socket should try to connect to.
	- parameter heartbeatInterval:	Once connected, this is the interval at which we will tell the server that we're still listening. Default value is nil. If nil or <= 0.0, a heartbeat won't be used, and the socket will organically disconnect.
	- parameter reconnectInterval:	The interval after which we should try to reconnect after a socket disconnects.
	
	This initializer is failable because it guards against invalid URLs be passed in. You can freely use ws, wss, http or https
	as a scheme and this will be handled correctly. If you're passing a hard coded URL, this failing should be consier
	*/
	public init?(url: NSURL, heartbeatInterval: NSTimeInterval? = nil, reconnectInterval: NSTimeInterval = 5.0) {
		self.heartbeatInterval = heartbeatInterval
		self.reconnectInterval = reconnectInterval

		queue.suspended = true

		let webSocketPathComponent: String
		if let lastPathComponent = url.lastPathComponent where lastPathComponent == "websocket" {
			webSocketPathComponent = ""
		} else {
			webSocketPathComponent = "websocket"
		}

		let components = NSURLComponents(
			URL: url.URLByAppendingPathComponent(webSocketPathComponent),
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

	/**
	Attemps to reconnect to the socket using the parameters supplied the last time connect() was called. If you want to
	supply new parameters, call disconnect and then connect.
	
	If the socket is currently connected, the connection will disconnect before reconnecting.
	*/
	@objc public func reconnect() {
		disconnectSocket()
		connect(lastParams)
	}

	/**
	Disconnects the socket connection after sending a leave message over all currently connected Channels.
	*/
	public func disconnect(completion: ((clean: Bool) -> Void)? = nil) {
		discardHeartBeatTimer()
		discardReconnectTimer()

		leaveAllChannels { _ in
			self.disconnectSocket()
		}
	}

	private func disconnectSocket() {
		guard let socket = socket else {
			return
		}

		socket.delegate = nil
		socket.close()
		self.socket = nil
	}

	/**
	Sends a leave message for every currently connected Channel.

	- parameter completion:	Called after every Channel has been left. Clean parameter will be true if 
							every Channel was left without incident, false otherwise.
	*/
	func leaveAllChannels(completion: ((clean: Bool) -> Void)? = nil) {
		var disconnected = [Int: Bool]()
		let group = dispatch_group_create()

		for channel in channels where [.Joining, .Joined].contains(channel.state) {
			dispatch_group_enter(group)
			channel.leave { success in
				disconnected[channel.hashValue] = success
				dispatch_group_leave(group)
			}
		}

		dispatch_group_notify(group, dispatch_get_main_queue()) {
			completion?(
				clean: !disconnected.values.contains(false)
			)
		}
	}

	/**
	Adds the supplied Channel to the socket, and connects to it if the socket is open and shouldAutoJoinChannels is enabled.
	Since Channel uniqueness is determined by its topic, adding a new Channel that has the same topic as any other Channel
	on this topic will cause the old one to be removed.
	
	A single instance of Channel shouldn't be used on multiple Sockets at the same time. The Channel will only be connected
	to the most recent Socket which it was added to.
	*/
	public func addChannel(channel: Stone.Channel) {
		if !channels.contains(channel) {
			channel.socket = self
			channels.insert(channel)

			if shouldAutoJoinChannels && socketState == .Open {
				channel.join()
			}
		}
	}

	/**
	Removes the supplied Channel from the receiver, and returns it if it was being tracked. Otherwise, this returns nil.
	*/
	public func removeChannel(channel: Stone.Channel, completion: ((clean: Bool?, channel: Stone.Channel?) -> Void)?) {
		guard channels.contains(channel) else {
			completion?(clean: nil, channel: nil)
			return
		}

		channel.leave { [weak channel, weak self] success in
			if let channel = channel {
				self?.channels.remove(channel)
			}

			channel?.socket = nil
			completion?(clean: success, channel: channel)
		}
	}

	public func channelForTopic<RawType: RawRepresentable where RawType.RawValue == String>(topic: RawType) -> Stone.Channel? {
		return channelForTopic(topic.rawValue)
	}

	public func channelForTopic(topic: String) -> Stone.Channel? {
		return channels.filter {
			$0.isMemberOfTopic(topic)
		}.first
	}

	private func startHeatBeatTimer(timeInterval timeInterval: NSTimeInterval) {
		discardHeartBeatTimer()

		heartBeatTimer = NSTimer.scheduledTimerWithTimeInterval(
			timeInterval,
			target: self,
			selector: #selector(Stone.Socket.sendHeartBeat),
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
				event: Event.Phoenix(.Heartbeat)
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
	Pushes the given Message over the Socket. This has been exposed publicly in case you need it, but it only facilitates
	channel communication, so you should probably use Channels and let this be handled for you.
	*/
	public func push(message: Stone.Message) throws {
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

		if shouldAutoJoinChannels {
			for channel in channels {
				channel.join()
			}
		}

		onOpen?()
	}

	private func webSocketDidReceiveMessage(messageStr: String) {
		guard let messageData = messageStr.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false) else {
			return
		}

		do {
			let message: Stone.Message = try Unbox(messageData)
			relayMessage(message)
			onMessage?(result: .Success(message))
		} catch let error as NSError {
			webSocketDidError(error)
			onMessage?(result: .Failure(error))
		}
	}

	private func relayMessage(message: Stone.Message) {
		triggerEvent(
			message.event,
			withRef: message.ref,
			andPayload: message.payload,
			inChannels: channels.filter { $0.isMemberOfTopic(message.topic) }
		)
	}

	private func triggerEvent<T: SequenceType where T.Generator.Element == Stone.Channel>(event: Stone.Event, withRef ref: String? = nil, andPayload payload: [String: AnyObject] = [:], inChannels channels: T) {
		for channel in channels {
			channel.triggerEvent(event, ref: ref, payload: payload)
		}
	}

	private func webSocketDidClose(code code: Int, reason: String, wasClean: Bool) {
		queue.suspended = true
		
		triggerEvent(Event.Phoenix(.Close), inChannels: channels)

		discardHeartBeatTimer()
		if shouldReconnectOnError {
			startReconnectTimer()
		}

		onClose?(code: code, reason: reason, wasClean: wasClean)
	}

	private func webSocketDidError(error: NSError) {
		onError?(error: error)

		triggerEvent(Event.Phoenix(.Error), inChannels: channels)

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
}
