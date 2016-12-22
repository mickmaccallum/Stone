//
//  Presence.swift
//  Stone
//
//  Created by Michael MacCallum on 8/13/16.
//
//

import Foundation
import Unbox

public typealias PresenceTrackingType = Unboxable & Hashable

public struct PresenceDiffWrapper {
	public let data: Data?

	public func unbox<T: PresenceTrackingType, U: Sequence>() throws -> PresenceDiff<T, U>? where U.Iterator.Element: Unboxable {
		guard let data = data else {
			return nil
		}

		// couldn't quite figure out how to make this happen with Unbox.
		guard let rawPresences = try JSONSerialization.jsonObject(with: data, options: []) as? [String: [T: [String: U]]] else {
			throw Unbox.UnboxError.customUnboxingFailed
		}

		guard let leaves = rawPresences["leaves"], let joins = rawPresences["joins"] else {
			throw Unbox.UnboxError.invalidData
		}

		return PresenceDiff(
			joins: try PresenceWrapper.parse(rawPresences: joins),
			leaves: try PresenceWrapper.parse(rawPresences: leaves)
		)
	}
}

public struct PresenceDiff<T: PresenceTrackingType, U: Sequence> where U.Iterator.Element: Unboxable {
	public let joins: Set<Presence<T, U>>
	public let leaves: Set<Presence<T, U>>
}

public struct PresenceWrapper {
	public let data: Data?

	public func unbox<T: PresenceTrackingType, U: Sequence>() throws
		-> Set<Presence<T, U>>? where U.Iterator.Element: Unboxable {

			guard let data = data else {
				return nil
			}

			// couldn't quite figure out how to make this happen with Unbox.
			guard let rawPresences = try JSONSerialization.jsonObject(with: data, options: []) as? [T: [String: U]] else {
				throw Unbox.UnboxError.customUnboxingFailed
			}

			return try PresenceWrapper.parse(rawPresences: rawPresences)
	}

	static func parse<T: PresenceTrackingType, U: Sequence>(rawPresences: [T: [String: U]]) throws
		-> Set<Presence<T, U>> where U.Iterator.Element: Unboxable {

			return rawPresences.flatMap {
				guard let metas = $0.value["metas"] else {
					return nil
				}

				return Presence(tracking: $0.key, metas: metas)
			}.reduce(Set<Presence<T, U>>(minimumCapacity: rawPresences.count)) {
				$0.0.union([$0.1])
			}
	}
}

public struct Presence<T: PresenceTrackingType, U: Sequence>: Hashable where U.Iterator.Element: Unboxable {
	public let tracking: T
	public let metas: U

	public var hashValue: Int {
		return tracking.hashValue
	}
}

public func == <T: PresenceTrackingType, U: Sequence>(lhs: Presence<T, U>, rhs: Presence<T, U>) -> Bool where U.Iterator.Element: Unboxable {
	return lhs.tracking == rhs.tracking
}

