//
//  QueryStringConvertible.swift
//  Phoenix
//
//  Created by Michael MacCallum on 5/16/16.
//  Copyright © 2016 Tethr Technologies Inc. All rights reserved.
//

import Foundation

public protocol QueryStringConvertible: Hashable {
	var queryStringRepresentation: String? { get }
}

