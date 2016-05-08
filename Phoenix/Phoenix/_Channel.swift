//
//  Channel.swift
//  Phoenix
//
//  Created by Michael MacCallum on 5/8/16.
//  Copyright © 2016 Tethr. All rights reserved.
//

import Foundation

public class Channel {
	var bindings: [Binding] = []
	var topic: String?
	var message: Message?
	var callback: (AnyObject -> Void?)
	var socket: Socket?

	init(topic: String, message: Message, callback: (AnyObject -> Void), socket: Socket) {
		(self.topic, self.message, self.callback, self.socket) = (topic, message, { callback($0) }, socket)
		reset()
	}

	func reset() {
		bindings = []
	}

	public func on(event: String, callback: (AnyObject -> Void)) {
		bindings.append(Binding(event: event, callback: { callback($0) }))
	}

	func isMember(topic  topic: String) -> Bool {
		return self.topic == topic
	}

	func off(event: String) {
		var newBindings: [Binding] = []
		for binding in bindings {
			if binding.event != event {
				newBindings.append(Binding(event: binding.event, callback: binding.callback))
			}
		}
		bindings = newBindings
	}

	func trigger(triggerEvent: String, msg: Message) {
		for binding in bindings {
			if binding.event == triggerEvent {
				binding.callback(msg)
			}
		}
	}

	func send(event: String, message: Message) {
		print("conn sending")
		let payload = Phoenix.Payload(topic: topic!, event: event, message: message)
		socket?.send(payload)
	}

	func leave(message: Message) {
		if let sock = socket {
			sock.leave(topic: topic!, message: message)
		}
		reset()
	}
}
