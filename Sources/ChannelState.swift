//
//  ChannelState.swift
//  Stone
//
//  Created by Michael MacCallum on 5/20/16.
//  Copyright © 2016 Tethr. All rights reserved.
//

/**
Indicates the current connection status of a Channel.

- Closed:	Indicates that the Channel is closed.
- Errored:	Indicates that the Channel is closed with an error.
- Joining:	Indicates that the Channel is currently trying to join.
- Joined:	Indicates that the Channel is joined and active.
*/
public enum ChannelState {
	case Closed, Errored, Joining, Joined
}
