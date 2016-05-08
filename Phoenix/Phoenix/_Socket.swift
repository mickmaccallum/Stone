//
//  Socket.swift
//  Phoenix
//
//  Created by Michael MacCallum on 5/8/16.
//  Copyright © 2016 Tethr. All rights reserved.
//

import Foundation
import SwiftWebSocket

public class Socket: NSObject, WebSocketDelegate {
	var conn: WebSocket?
	var endPoint: String?
	var channels: [Channel] = []

	var sendBuffer: [Void] = []
	var sendBufferTimer = NSTimer()
	let flushEveryMs = 1.0

	var reconnectTimer = NSTimer()
	let reconnectAfterMs = 1.0

	var heartbeatTimer = NSTimer()
	let heartbeatDelay = 30.0

	var messageReference: UInt64 = UInt64.min // 0 (max: 18,446,744,073,709,551,615)

	public init(domainAndPort:String, path:String, transport:String, prot:String = "http") {
		self.endPoint = Path.endpointWithProtocol(prot, domainAndPort: domainAndPort, path: path, transport: transport)
		super.init()
		resetBufferTimer()
		startHeartbeatTimer()
		reconnect()
	}

	func close(callback: () -> ()) {
		if let connection = self.conn {
			connection.delegate = nil
			connection.close()
//			connection.disconnect()
		}
		callback()
	}

	func startHeartbeatTimer() {
		heartbeatTimer.invalidate()
		heartbeatTimer = NSTimer.scheduledTimerWithTimeInterval(heartbeatDelay, target: self, selector: #selector(Socket.heartbeat), userInfo: nil, repeats: true)
	}

	func heartbeat() {
		let message = Message(message: ["body": "Pong"])
		let payload = Phoenix.Payload(topic: "phoenix", event: "heartbeat", message: message)
		send(payload)
	}

	func reconnect() {
		close() {
			self.conn = WebSocket(url: NSURL(string: self.endPoint!)!)
			if let connection = self.conn {
				connection.delegate = self
//				connection.connect()
//				connection.op
			}
		}
	}

	func resetBufferTimer() {
		sendBufferTimer.invalidate()
		sendBufferTimer = NSTimer.scheduledTimerWithTimeInterval(flushEveryMs, target: self, selector: #selector(Socket.flushSendBuffer), userInfo: nil, repeats: true)
		sendBufferTimer.fire()
	}

	func onOpen() {
		reconnectTimer.invalidate()
		rejoinAll()
	}

	func onClose(event: String) {
		reconnectTimer.invalidate()
		reconnectTimer = NSTimer.scheduledTimerWithTimeInterval(reconnectAfterMs, target: self, selector: #selector(Socket.reconnect), userInfo: nil, repeats: true)
	}

	func onError(error: NSError) {
		print("Error: \(error)")
		for chan in channels {
			let msg = Message(message: ["body": error.localizedDescription])
			chan.trigger("error", msg: msg)
		}
	}

	func isConnected() -> Bool {
		if let connection = self.conn {
			return connection.isConnected
		} else {
			return false
		}

	}

	func rejoinAll() {
		for chan in channels {
			rejoin(chan as Channel)
		}
	}

	func rejoin(chan: Channel) {
		chan.reset()
		let joinMessage = Message(subject: "status", body: "joining")
		let payload = Phoenix.Payload(topic: chan.topic!, event: "phx_join", message: joinMessage)
		send(payload)
		chan.callback(chan)
	}

	public func join(topic  topic: String, message: Message, callback: (AnyObject -> Void)) {
		let chan = Channel(topic: topic, message: message, callback: callback, socket: self)
		channels.append(chan)
		if isConnected() {
			print("joining")
			rejoin(chan)
		}
	}

	func leave(topic  topic: String, message: Message) {
		let leavingMessage = Message(subject: "status", body: "leaving")
		let payload = Phoenix.Payload(topic: topic, event: "leave", message: leavingMessage)
		send(payload)
		var newChannels: [Channel] = []
		for chan in channels {
			let c = chan as Channel
			if !c.isMember(topic: topic) {
				newChannels.append(c)
			}
		}
		channels = newChannels
	}

	public func send(data: Phoenix.Payload) {
		let callback = {
			(payload: Phoenix.Payload) -> Void in
			if let connection = self.conn {
				let json = self.payloadToJson(payload)
				print("json: \(json)")
				connection.writeString(json)
			}
		}
		if isConnected() {
			callback(data)
		} else {
			sendBuffer.append(callback(data))
		}
	}

	func flushSendBuffer() {
		if isConnected() && sendBuffer.count > 0 {
			for callback in sendBuffer {
				callback
			}
			sendBuffer = []
			resetBufferTimer()
		}
	}

	func onMessage(payload: Phoenix.Payload) {
		let (topic, event, message) = (payload.topic, payload.event, payload.message)
		for chan in channels {
			if chan.isMember(topic: topic) {
				chan.trigger(event, msg: message)
			}
		}
	}

	// WebSocket Delegate Methods
	public func websocketDidReceiveMessage(socket: WebSocket, text: String) {
		print("socket message: \(text)")
		let json = JSON.parse(text as NSString as String as String)
		let (topic, event) = (
			unwrappedJsonString(json["topic"].asString),
			unwrappedJsonString(json["event"].asString)
		)
		let msg: [String: AnyObject] = json["payload"].asDictionary!

		let messagePayload = Phoenix.Payload(topic: topic, event: event, message: Message(message: msg))
		onMessage(messagePayload)
	}

	public func websocketDidReceiveData(socket: WebSocket, data: NSData) {
		print("got some data: \(data.length)")
	}

	public func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
		if let err = error { onError(err) }
		print("socket closed: \(error?.localizedDescription)")
		onClose("reason: \(error?.localizedDescription)")
	}

	public func websocketDidConnect(socket: WebSocket) {
		print("socket opened")
		onOpen()
	}

	public func websocketDidWriteError(error: NSError?) {
		onError(error!)
	}

	func unwrappedJsonString(string: String?) -> String {
		if let stringVal = string {
			return stringVal
		} else {
			return ""
		}
	}

	func makeRef() -> UInt64 {
		let newRef = messageReference + 1
		messageReference = (newRef == UINT64_MAX) ? 0 : newRef
		return newRef
	}

	func payloadToJson(payload: Phoenix.Payload) -> String {
		let ref = makeRef()
		var json = "{\"topic\": \"\(payload.topic)\", \"event\": \"\(payload.event)\", \"ref\": \"\(ref)\", "
		if NSString(string: payload.message.toJsonString()).containsString("message") {
			let msg = JSON.parse(String(payload.message.toJsonString()))["message"]
			let jsonMessage = msg.toString(true)
			json += "\"payload\": \(jsonMessage)"
		} else {
			json += "\"payload\": \(payload.message.toJsonString())"
		}
		json += "}"

		return json
	}
}