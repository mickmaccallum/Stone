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
	@IBOutlet private weak var bottomPin: NSLayoutConstraint!

	private var messages = [Message]()

	let channel = Channel(topic: MyTopics.Lobby)
	
	override func viewDidLoad() {
		super.viewDidLoad()

		guard let url = NSURL(string: "ws://localhost:4000/socket"),
			socket = Socket(url: url, heartbeatInterval: 15.0) else {
				return
		}

		socket.onOpen = {
			print("socket open")
		}

		socket.onMessage = { result in
			// Will print every single event that comes over the socket.
			// print("received message: \(result)")
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
				let indexPath = NSIndexPath(forRow: self.messages.count.predecessor(), inSection: 0)
				self.tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition: .Bottom, animated: true)
			} catch {
				print(error)
			}
		}

		channel.onPresenceDiff { [unowned self] result in
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

	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)

		NSNotificationCenter.defaultCenter().addObserverForName(
			UIKeyboardWillChangeFrameNotification,
			object: nil,
			queue: NSOperationQueue.mainQueue(),
			usingBlock: keyboardFrameWillChange
		)
	}

	override func viewDidDisappear(animated: Bool) {
		super.viewDidDisappear(animated)

		NSNotificationCenter.defaultCenter().removeObserver(self)
	}

	private func keyboardFrameWillChange(notification: NSNotification) {
		guard let userInfo = notification.userInfo,
			animationCurve = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? UInt,
			animationDuration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSTimeInterval,
			keyboardFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.CGRectValue() else {
				return
		}

		bottomPin.constant = keyboardFrame.origin.y == view.bounds.height ? 0.0 : keyboardFrame.height

		UIView.animateWithDuration(
			animationDuration,
			delay: 0.0,
			options: UIViewAnimationOptions.BeginFromCurrentState.union(UIViewAnimationOptions(rawValue: animationCurve)),
			animations: {
				self.view.layoutIfNeeded()
			},
			completion: nil
		)
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
