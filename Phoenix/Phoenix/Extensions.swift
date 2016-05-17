//
//  Extensions.swift
//  Phoenix
//
//  Created by Michael MacCallum on 5/16/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import Foundation

extension String: QueryStringConvertible {
	public var queryStringRepresentation: String {
		return self.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!
	}
}

public extension Dictionary where Key: QueryStringConvertible, Value: QueryStringConvertible {
	public func toQueryItems() -> [NSURLQueryItem] {
		return self.map {
			NSURLQueryItem(
				name: $0.queryStringRepresentation,
				value: $1.queryStringRepresentation
			)
		}
	}
}

extension NSURL {
	/**
	Creates a new NSURL by appending queryItems to the receiver.
	*/
	func urlByAppendingQueryItems(queryItems: [NSURLQueryItem]?) -> NSURL? {
		let components = NSURLComponents(URL: self, resolvingAgainstBaseURL: true)

		if var currentItems = components?.queryItems where !currentItems.isEmpty {
			currentItems.appendContentsOf(queryItems ?? [])
			components?.queryItems = currentItems
		} else {
			components?.queryItems = queryItems
		}

		return components?.URL
	}
}