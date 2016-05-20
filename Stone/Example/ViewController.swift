//
//  ViewController.swift
//  Example
//
//  Created by Michael MacCallum on 5/8/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import UIKit
import Stone


enum MyTopics: String {
	case Lobby = "rooms:lobby"
}

class ViewController: UIViewController {
	@IBOutlet private weak var tableView: UITableView!
	private var messages = [Message]()

	override func viewDidLoad() {
		super.viewDidLoad()

		let params = [NSURLQueryItem(name: "user_id", value: "mick")]

		let url = NSURL(string: "ws://localhost:4000/socket")!

		let socket = Socket(
			url: url,
			heartbeatInterval: 15.0
		)!

		socket.onSocketOpen = {
			let channel = Channel(socket: socket, topic: MyTopics.Lobby)

			channel.join { result in
				print("Result of joining lobby: \(result)")
			}

			channel.onEvent(Event.Custom("new:msg")) { result in
				print(result)
			}

			socket.addChannel(channel)
		}

		socket.onSocketMessage = { result in
			print("received message: \(result)")
		}

		socket.onSocketError = { error in
			print("error received: \(error)")
		}

		socket.onSocketClose = { code, reason, clean in
			print("socket closed - code: \(code), reason: \(reason), clean: \(clean)")
		}

		socket.connect(params)
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	@IBAction private func sendButtonTapped() {

	}
}

