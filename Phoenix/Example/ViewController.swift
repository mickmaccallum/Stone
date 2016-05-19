//
//  ViewController.swift
//  Example
//
//  Created by Michael MacCallum on 5/8/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import UIKit
import Stone


class ViewController: UIViewController {

	override func viewDidLoad() {
		super.viewDidLoad()

		let params = [NSURLQueryItem(name: "user_id", value: "mick")]

		let url = NSURL(string: "ws://localhost:4000/socket")!

		let socket = Socket(
			url: url,
			heartbeatInterval: 15.0
		)!

		socket.onSocketOpen = {
			print("socket open")
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

		let channel = Channel(socket: socket, topic: "rooms:lobby")

		channel.onEvent(Event.Default(.Join)) { (result) in
			print("on channel join: \(result)")
		}

//		channel.onEvent(<#T##event: RawType##RawType#>, callback: <#T##Callback##Callback##Result<Void> -> Void#>)


		// Do any additional setup after loading the view, typically from a nib.
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}


}

