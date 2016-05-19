//
//  PhoenixEvent.swift
//  Phoenix
//
//  Created by Michael MacCallum on 5/19/16.
//  Copyright © 2016 Tethr. All rights reserved.
//

import Foundation

public enum Event: String {
	case Join = "phx_join"
	case Reply = "phx_reply"
	case Leave = "phx_leave"
	case Close = "phx_close"
	case Error = "phx_error"
}
