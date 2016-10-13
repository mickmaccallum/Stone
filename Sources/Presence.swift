//
//  Presence.swift
//  Stone
//
//  Created by Michael MacCallum on 8/13/16.
//
//

import Unbox

public struct Presence {
//	let name: String
//	let metas: [T]
	public fileprivate(set) var presences = [String: [UnboxableDictionary]]()

	public init() {
		
	}

	public func list<T: Unboxable>() throws -> [String: [T]] {
		let ret = [String: [T]](minimumCapacity: presences.count)

		

//		try presences.forEach {
//			ret.updateValue(
//				try unbox($0.1),
//				forKey: $0.0
//			)
//		}

		return ret
	}

//	public init(unboxer: Unboxer) {
//		name = unboxer.unbox("name")
//
//		metas = unboxer.unbox("payload")
//	}

//	internal init(name: String, metas: [T]) {
//		self.name = name
//		self.metas = metas
//	}
}

//public func == <T: protocol<Unboxable, Hashable>>(lhs: Stone.Presence<T>, rhs: Stone.Presence<T>) -> Bool {
//	return true
//}
