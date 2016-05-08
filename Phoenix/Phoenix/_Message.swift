//
//  Message.swift
//  Phoenix
//
//  Created by Michael MacCallum on 5/8/16.
//  Copyright © 2016 Tethr. All rights reserved.
//

import Foundation

public class Message: Serializable {
	var subject: String?
	var body: AnyObject?
	public var message: AnyObject?

	public init(subject: String, body: AnyObject) {
		(self.subject, self.body) = (subject, body)
		super.init()
		create()
	}

	public init(message: AnyObject) {
		self.message = message
		super.init()
		create(false)
	}

	func create(single: Bool = true) -> [String: AnyObject] {
		if single {
			return [self.subject!: self.body!]
		} else {
			return self.message! as! [String: AnyObject]
		}
	}
}
