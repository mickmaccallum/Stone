//
//  Extensions.swift
//  Stone
//
//  Created by Michael MacCallum on 5/16/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import Foundation

extension String: QueryStringConvertible {
	/// Attempts to convert the receiver into a valid query String using the URLQueryAllowedCharacterSet NSCharacterSet.
	public var queryStringRepresentation: String? {
		return self.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
	}
}

public extension Dictionary where Key: Stone.QueryStringConvertible, Value: Stone.QueryStringConvertible {
	/**
	Converts the reciever's keys and values into and Array of NSURLQueryItems. If a key or value
	for a given item in the dictionary can't successfully be converted into a query string 
	(e.g. they contain invalid characters for a query string) the key value pair will be ommitted
	from the resulting Array.
	*/
	public func toQueryItems() -> [NSURLQueryItem] {
		return self.flatMap {
			guard let name = $0.queryStringRepresentation,
				value = $1.queryStringRepresentation else {
					return nil
			}

			return NSURLQueryItem(
				name: name,
				value: value
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