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
		return self.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
	}
}

public extension Dictionary where Key: Stone.QueryStringConvertible, Value: Stone.QueryStringConvertible {
	/**
	Converts the reciever's keys and values into and Array of NSURLQueryItems. If a key or value
	for a given item in the dictionary can't successfully be converted into a query string 
	(e.g. they contain invalid characters for a query string) the key value pair will be ommitted
	from the resulting Array.
	*/
	public func toQueryItems() -> [URLQueryItem] {
		return self.flatMap {
			guard let name = $0.queryStringRepresentation,
				let value = $1.queryStringRepresentation else {
					return nil
			}

			return URLQueryItem(
				name: name,
				value: value
			)
		}
	}
}

extension URL {
	/**
	Creates a new NSURL by appending queryItems to the receiver.
	*/
	func urlByAppendingQueryItems(_ queryItems: [URLQueryItem]?) -> URL? {
		var components = URLComponents(url: self, resolvingAgainstBaseURL: true)

		if var currentItems = components?.queryItems , !currentItems.isEmpty {
			currentItems.append(contentsOf: queryItems ?? [])
			components?.queryItems = currentItems
		} else {
			components?.queryItems = queryItems
		}

		return components?.url
	}
}
