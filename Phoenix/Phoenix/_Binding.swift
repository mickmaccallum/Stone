//
//  Binding.swift
//  Phoenix
//
//  Created by Michael MacCallum on 5/8/16.
//  Copyright © 2016 Tethr. All rights reserved.
//

import Foundation

class Binding {
	var event: String
	var callback: AnyObject -> Void?

	init(event: String, callback: AnyObject -> Void?) {
		(self.event, self.callback) = (event, callback)
		create()
	}

	func create() -> (String, AnyObject -> Void?) {
		return (event, callback)
	}
}
