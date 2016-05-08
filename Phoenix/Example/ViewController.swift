//
//  ViewController.swift
//  Example
//
//  Created by Michael MacCallum on 5/8/16.
//  Copyright © 2016 Tethr. All rights reserved.
//

import UIKit
import Phoenix
import SwiftWebSocket

struct Message {
	let topic: String
	let event: String
	let ref: String
	let subject: String
	let body: String

	func toJsonString() -> String {
		return "{" +
		"\"topic\":\"\(topic)\"" +
		"\"event\":\"\(event)\"" +
		"\"ref\":\"\(ref)\"" +
		"\"subject\":\"\(subject)\"" +
		"\"body\":\"\(body)\"" +
		"}"
	}
}

class ViewController: UIViewController {
	var socket: WebSocket!

	override func viewDidLoad() {
		super.viewDidLoad()

		let url = NSURL(string: "ws://localhost:4000/socket/websocket?user_id=mick")!

		let request = NSMutableURLRequest(
			URL: url,
			cachePolicy: .ReloadIgnoringLocalAndRemoteCacheData,
			timeoutInterval: 15.0
		)

		request.HTTPBody = "{\"dummy\":\"data\"".dataUsingEncoding(NSUTF8StringEncoding)

		let ws = WebSocket(request: request)

		let send : ()->() = {
			let msg = "{\"topic\": \"rooms:lobby\", \"event\": \"phx_join\", \"ref\": \"1\", \"payload\": {\"subject\":\"status\",\"body\":\"joining\"}}"
			print("send:\(msg)")
			ws.send(msg)
		}
		ws.event.open = {
			print("opened")
			send()
		}
		ws.event.close = { code, reason, clean in
			print("closed for reason: \(reason) ---- clean: \(clean)")
		}
		ws.event.error = { error in
			print("error \(error)")
		}
		ws.event.message = { message in
			if let text = message as? String {
				print("recv: \(text)")
//				if messageNum == 10 {
//					ws.close()
//				} else {
////					send()
//				}
			}
		}



		// Do any additional setup after loading the view, typically from a nib.
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}


}

extension ViewController: WebSocketDelegate {
	func webSocketOpen() {
		print("open")
	}

	func webSocketPong() {
		print("pong")
	}

	func webSocketError(error: NSError) {
		print(error)
	}

	func webSocketMessageText(text: String) {
		print("got text: \(text)")
	}

	func webSocketMessageData(data: NSData) {
		print("got data: \(data)")
	}

	func webSocketClose(code: Int, reason: String, wasClean: Bool) {
		print("closed: \(reason)")
	}

	func webSocketEnd(code: Int, reason: String, wasClean: Bool, error: NSError?) {
		print("ended: \(reason)")
	}
}
