//
//  Message.swift
//  Phoenix
//
//  Created by Michael MacCallum on 5/19/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import Foundation

public struct Message {
	private static var reference: UInt = 0
	internal var ref: String {
		let currentRef = String(format: "%zd", Message.reference)
		Message.reference = Message.reference.successor()
		return currentRef
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
