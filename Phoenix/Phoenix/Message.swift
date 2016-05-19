//
//  Message.swift
//  Phoenix
//
//  Created by Michael MacCallum on 5/19/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import Foundation
import Unbox

public struct Message {
	private static var reference: UInt = 0
	private var _ref: String?

	internal var ref: String {
		get {
			if let _ref = _ref {
				return _ref
			}

			let currentRef = String(format: "%zd", Message.reference)
			Message.reference = Message.reference.successor()
			return currentRef
		}

		set {
			_ref = newValue
		}
	}

	public let topic: String
	public let event: String
	public let payload: [String: AnyObject]?

	public init(topic: String, event: String, payload: [String: AnyObject]? = nil) {
		self.topic		= topic
		self.event		= event
		self.payload	= payload
	}
}

extension Message: Unboxable {
	public init(unboxer: Unboxer) {
		topic = unboxer.unbox("topic")
		event = unboxer.unbox("event")
		payload = unboxer.unbox("payload")
		ref = unboxer.unbox("ref")
	}
}
