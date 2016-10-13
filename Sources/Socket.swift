//
//  Socket.swift
//  Stone
//
//  Created by Michael MacCallum on 5/8/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import SwiftWebSocket
import Wrap
import Unbox

public typealias SocketState = SwiftWebSocket.WebSocketReadyState

/**
The connection over which Channel communication can occur.
*/
public final class Socket {
	/// The underlying WebSocket used for communicating with the server.
	public fileprivate(set) var socket: WebSocket?
	/// The interval at which a heartbeat message will be broadcast to the server.
	public let heartbeatInterval: TimeInterval?
	/// The interval at which we should try to reconnect to the socket if the connection is lost.
	public var reconnectInterval: TimeInterval
	/// The URL that the web socket is connected to.
	public let url: URL
	/// Whether or not we should automatically attempt to reconnect to the server if an error occurs.
	public var shouldReconnectOnError = true

	public var shouldAutoJoinChannels = true

	/// Called whenever a web socket connection is established.
	public var onOpen: (() -> Void)?
	/// Called whenever the socket receives an error event.
	public var onError: ((_ error: NSError) -> Void)?
	/// Called whenever the web socket connection is closed.
	public var onClose: ((_ code: Int, _ reason: String, _ wasClean: Bool) -> Void)?
	/// Called for every message that is received over the socket (called a lot).
	public var onMessage: ((_ result: Stone.Result<Stone.Message>) -> Void)?
	/// Called every time a heartbeat message is received
	public var onHeartbeat: ((_ result: Stone.Result<Stone.Message>) -> Void)?

	/// The connection state of the underlying socket.
	public var socketState: SocketState {
		return socket?.readyState ?? .closed
	}

	/// Returns true if the socket is currenly connected to the server, false otherwise.
	public var connected: Bool {
		return socket?.readyState == .some(.open)
	}

	fileprivate var heartBeatTimer: Timer?
	fileprivate var reconnectTimer: Timer?
	public fileprivate(set) var channels = Set<Channel>()
	fileprivate var lastParams: [URLQueryItem]?
	fileprivate let queue = OperationQueue()

	/**
	Instantiates a new Stone Socket with the given url and optional heartbeat and reconnect intervals.


	- parameter url:				The URL at which the socket should try to connect to.
	- parameter heartbeatInterval:	Once connected, this is the interval at which we will tell the server that we're still listening. Default value is nil. If nil or <= 0.0, a heartbeat won't be used, and the socket will organically disconnect.
	- parameter reconnectInterval:	The interval after which we should try to reconnect after a socket disconnects.
	
	This initializer is failable because it guards against invalid URLs be passed in. You can freely use ws, wss, http or https
	as a scheme and this will be handled correctly. If you're passing a hard coded URL, this failing should be consier
	*/
	public init?(url: URL, heartbeatInterval: TimeInterval? = nil, reconnectInterval: TimeInterval = 5.0) {
		self.heartbeatInterval = heartbeatInterval
		self.reconnectInterval = reconnectInterval

		queue.isSuspended = true

		let webSocketPathComponent: String
		if url.lastPathComponent == "websocket" {
			webSocketPathComponent = ""
		} else {
			webSocketPathComponent = "websocket"
		}

		var components = URLComponents(
			url: url.appendingPathComponent(webSocketPathComponent),
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

		guard let url = components?.url else {
			return nil
		}

		self.url = url
	}

	public func connect<T: QueryStringConvertible>(_ params: [T: T]) {
		connect(params.toQueryItems())
	}

	public func connect(_ params: [URLQueryItem]? = nil) {
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
	public func disconnect(_ completion: ((_ clean: Bool) -> Void)? = nil) {
		discardHeartBeatTimer()
		discardReconnectTimer()

		leaveAllChannels { _ in
			self.disconnectSocket()
		}
	}

	fileprivate func disconnectSocket() {
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
	func leaveAllChannels(_ completion: ((_ clean: Bool) -> Void)? = nil) {
		var disconnected = [Int: Bool]()
		let group = DispatchGroup()

		for channel in channels where [.joining, .joined].contains(channel.state) {
			group.enter()
			channel.leave { success in
				disconnected[channel.hashValue] = success
				group.leave()
			}
		}

		group.notify(queue: DispatchQueue.main) {
			completion?(
				!disconnected.values.contains(false)
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
	public func addChannel(_ channel: Stone.Channel) {
		guard !channels.contains(channel) else {
			return
		}

		channel.socket = self
		channels.insert(channel)

		if shouldAutoJoinChannels && socketState == .open {
			channel.join()
		}
	}

	/**
	Removes the supplied Channel from the receiver, and returns it if it was being tracked. Otherwise, this returns nil.
	*/
	public func removeChannel(_ channel: Stone.Channel, completion: ((_ clean: Bool?, _ channel: Stone.Channel?) -> Void)?) {
		guard channels.contains(channel) else {
			completion?(nil, nil)
			return
		}

		channel.leave { [weak channel, weak self] success in
			if let channel = channel {
				_ = self?.channels.remove(channel)
			}

			channel?.socket = nil
			completion?(success, channel)
		}
	}

	public func channelForTopic<RawType: RawRepresentable>(_ topic: RawType) -> Stone.Channel? where RawType.RawValue == String {
		return channelForTopic(topic.rawValue)
	}

	public func channelForTopic(_ topic: String) -> Stone.Channel? {
		return channels.filter {
			$0.isMemberOfTopic(topic)
		}.first
	}

	fileprivate func startHeatBeatTimer(_ timeInterval: TimeInterval) {
		discardHeartBeatTimer()

		heartBeatTimer = Timer.scheduledTimer(
			timeInterval: timeInterval,
			target: self,
			selector: #selector(Stone.Socket.sendHeartBeat),
			userInfo: nil,
			repeats: true
		)
	}

	fileprivate func startReconnectTimer() {
		discardReconnectTimer()

		reconnectTimer = Timer.scheduledTimer(
			timeInterval: reconnectInterval,
			target: self,
			selector: #selector(Socket.reconnect),
			userInfo: nil,
			repeats: true
		)
	}

	@objc fileprivate func sendHeartBeat() {
		try! push(
			Message(
				topic: "phoenix",
				event: Event.phoenix(.Heartbeat),
				ref: "heartbeat"
			)
		)
	}

	fileprivate func discardHeartBeatTimer() {
		if let timer = heartBeatTimer , timer.isValid {
			timer.invalidate()
		}

		heartBeatTimer = nil
	}

	fileprivate func discardReconnectTimer() {
		if let timer = reconnectTimer , timer.isValid {
			timer.invalidate()
		}

		reconnectTimer = nil
	}

	/**
	Pushes the given Message over the Socket. This has been exposed publicly in case you need it, but it only facilitates
	channel communication, so you should probably use Channels and let this be handled for you.
	*/
	public func push(_ message: Stone.Message) throws {
		let jsonData: Data = try wrap(message)

		queue.addOperation { [weak self] in
			self?.socket?.send(jsonData)
		}
	}

	fileprivate func webSocketDidOpen() {
		queue.isSuspended = false
		discardReconnectTimer()

		if let timeInterval = heartbeatInterval , timeInterval > 0.0 {
			startHeatBeatTimer(timeInterval)
		}

		if shouldAutoJoinChannels {
			for channel in channels {
				channel.join()
			}
		}

		onOpen?()
	}

	fileprivate func webSocketDidReceiveMessage(_ messageStr: String) {
		guard let messageData = messageStr.data(using: String.Encoding.utf8, allowLossyConversion: false) else {
			return
		}

		do {
			let message: Stone.Message = try unbox(data: messageData)

			if let ref = message.ref , ref == Event.PhoenixEvent.Heartbeat.rawValue {
				onHeartbeat?(Result.success(message))
			} else {
				onMessage?(.success(message))
				relayMessage(message)
			}
		} catch let error as NSError {
			webSocketDidError(error)
			onMessage?(.failure(error))
		}
	}

	fileprivate func relayMessage(_ message: Stone.Message) {
		guard let channel = channelForTopic(message.topic) else {
			return
		}

		triggerEvent(
			message.event,
			withRef: message.ref,
			andPayload: message.payload,
			inChannel: channel
		)
	}

	fileprivate func triggerEvent(_ event: Stone.Event, withRef ref: String? = nil, andPayload payload: WrappedDictionary = [:], inChannel channel: Stone.Channel) {
		channel.triggerEvent(event, ref: ref, payload: payload)
	}

	fileprivate func triggerEvent<T: Sequence>(_ event: Stone.Event, withRef ref: String? = nil, andPayload payload: WrappedDictionary = [:], inChannels channels: T) where T.Iterator.Element == Stone.Channel {
		for channel in channels {
			triggerEvent(event, withRef: ref, andPayload: payload, inChannel: channel)
		}
	}

	fileprivate func webSocketDidClose(_ code: Int, reason: String, wasClean: Bool) {
		queue.isSuspended = true
		
		triggerEvent(Event.phoenix(.Close), inChannels: channels)

		discardHeartBeatTimer()
		if shouldReconnectOnError {
			startReconnectTimer()
		}

		for channel in channels {
			channel.state = .closed
		}

		onClose?(code, reason, wasClean)
	}

	fileprivate func webSocketDidError(_ error: NSError) {
		onError?(error)

		triggerEvent(Event.phoenix(.Error), inChannels: channels)
	}
}

extension Socket: WebSocketDelegate {
	@objc public func webSocketOpen() {
		webSocketDidOpen()
	}

	@objc public func webSocketError(_ error: NSError) {
		webSocketDidError(error)
	}

	@objc public func webSocketMessageText(_ text: String) {
		webSocketDidReceiveMessage(text)
	}

	@objc public func webSocketClose(_ code: Int, reason: String, wasClean: Bool) {
		webSocketDidClose(code, reason: reason, wasClean: wasClean)
	}
}
