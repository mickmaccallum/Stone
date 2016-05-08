//
//  Payload.swift
//  Phoenix
//
//  Created by Michael MacCallum on 5/8/16.
//  Copyright © 2016 Tethr. All rights reserved.
//

import Foundation

public class Payload {
	var topic: String
	var event: String
	var message: Message

	public init(topic: String, event: String, message: Message) {
		(self.topic, self.event, self.message) = (topic, event, message)
	}

}
