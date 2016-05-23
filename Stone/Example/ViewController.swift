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
	@IBOutlet private weak var textField: UITextField!

	private var messages = [Message]()

	let channel = Channel(topic: MyTopics.Lobby)
	
	override func viewDidLoad() {
		super.viewDidLoad()

		let socket = Socket(
			url: NSURL(string: "ws://localhost:4000/socket")!,
			heartbeatInterval: 15.0
		)!

		socket.onOpen = {
			print("socket open")
		}

		socket.onMessage = { result in
//			print("received message: \(result)")
		}

		socket.onError = { error in
			print("error received: \(error)")
		}

		socket.onClose = { code, reason, clean in
			print("socket closed - code: \(code), reason: \(reason), clean: \(clean)")
		}

		socket.addChannel(channel)

		let params = [NSURLQueryItem(name: "user_id", value: "iPhone")]
		socket.connect(params)
	}

	private var connections = [PresenceChange]() {
		didSet {
			title = "\(connections.count) user(s) connected"
		}
	}

	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)

		channel.shouldTrackPresence = true

		channel.onEvent(Event.Custom("new:msg")) { [unowned self] result in
			do {
				self.messages.append(try result.value())
				self.tableView.reloadData()
			} catch {
				print(error)
			}
		}

		channel.onPresenceDiff { [unowned self] result in
			print(result)
			do {
				let diff = try result.value()

				self.connections = self.connections.filter {
					!diff.leaves.contains($0)
				}

				self.connections.appendContentsOf(diff.joins)
			} catch {
				print(error)
			}
		}

		channel.onPresenceState { [unowned self] result in
			do {
				self.connections = try result.value()
			} catch {
				print(error)
			}
		}
	}


	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	@IBAction private func sendButtonTapped(button: UIButton) {
		let payload = [
			"body": textField.text ?? "",
			"user": UIDevice.currentDevice().name
		]

		let message = Message(
			topic: MyTopics.Lobby,
			event: Event.Custom("new:msg"),
			payload: payload
		)

		button.enabled = false
		channel.sendMessage(message) { [weak self] (result) in
			dispatch_async(dispatch_get_main_queue()) {
				button.enabled = true
				self?.textField.text = ""
			}
		}
	}
}

extension ViewController: UITableViewDataSource {
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return messages.count
	}

	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath)

		let message = messages[indexPath.row]

		cell.textLabel?.text = message.payload["body"] as? String
		cell.detailTextLabel?.text = message.payload["user"] as? String

		return cell
	}
}
