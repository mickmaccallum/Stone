//
//  ViewController.swift
//  Stone Demo iOS
//
//  Created by Michael MacCallum on 7/27/16.
//
//

import UIKit
import Stone

struct Message {
	let sender: String
	let body: String
}

class ViewController: UIViewController {
	private var messages = [Message]()
	@IBOutlet private weak var tableView: UITableView!

	static let userId = Int(arc4random_uniform(25) + 1)

	let socket = Socket(
		url: NSURL(string: "http://localhost:4000/socket/websocket?user_id=\(ViewController.userId)")!,
		heartbeatInterval: 15.0,
		reconnectInterval: 15.0
	)!

	override func viewDidLoad() {
		super.viewDidLoad()

		let channel = Channel(topic: "chat:lobby")
		channel.shouldTrackPresence = true

//		channel.onJoin = { [unowned channel] result in
//			print("joined")
//
//			let catchUpMessage = Stone.Message(
//				topic: channel.topic,
//				event: Event.Custom("chat:catchup"),
//				payload: [
//					"last_update_date": "yesterday"
//				]
//			)
//
//			channel.sendMessage(catchUpMessage) { result in
//				do {
////					print(try result.value())
//				} catch {
//					print(error)
//				}
//			}
//		}

		channel.onEvent(Event.Custom("chat:new:message")) { result in
			do {
				print(try result.value())
			} catch {
				print(error)
			}
		}

		channel.onPresenceState { (result) in
			do {
				_ = try result.value()
				print("presense changed")
			} catch {
				print("presence state failed")
			}
			print("presence updated state")
		}

		channel.onPresenceDiff { (result) in
			do {
				let diff = try result.value()
				print("users joined: \(diff.joins)")
				print("users left: \(diff.leaves)")
			} catch {
				print("presence diff failed")
			}
		}

		socket.addChannel(channel)

		socket.shouldReconnectOnError = true
		socket.shouldAutoJoinChannels = true

		socket.onOpen = {
			print("socket open")
		}

		socket.onMessage = { message in
//			print("Socket message: \(message)")
		}

		socket.onHeartbeat = { result in
			print("Heartbeat")
		}

		socket.onError = { (error: NSError) in
			print("socket received error: \(error)")
		}

		socket.onClose = { (code: Int, reason: String, clean: Bool) in
			print("socket closed - code: \(code), reason: \(reason), clean: \(clean)")
		}

		socket.connect()
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	@IBAction private func sendMessage(barButton: UIBarButtonItem) {
		let channel = socket.channels.filter {
			$0.isMemberOfTopic("chat:lobby")
		}.first!

		let message = Stone.Message(
			topic: channel.topic,
			event: Event.Custom("new:msg"),
			payload: [
				"hello": "phoenix"
			]
		)
		print("Sending message")
		channel.sendMessage(message) { (result) in
			print("message completion")

			do {
				print("success")
				let message = try result.value()
				print(message)
			} catch {
				print(error)
			}
		}
	}
}

extension ViewController: UITableViewDataSource {
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return messages.count
	}

	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("cell_id", forIndexPath: indexPath)

		let message = messages[indexPath.row]

		cell.textLabel?.text = message.body
		cell.detailTextLabel?.text = message.sender

		return cell
	}
}

extension ViewController: UITableViewDelegate {
	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {

	}
}

