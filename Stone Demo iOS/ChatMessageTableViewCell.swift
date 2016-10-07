//
//  ChatTableViewCell.swift
//  Stone
//
//  Created by Michael MacCallum on 8/12/16.
//
//

import UIKit

class ChatMessageTableViewCell: UITableViewCell {
	var chatMessage: ChatMessage! {
		didSet {
			senderLabel.text = chatMessage.sender
			bodyLabel.text = chatMessage.body
		}
	}


	@IBOutlet fileprivate weak var senderLabel: UILabel!
	@IBOutlet fileprivate weak var bodyLabel: UILabel!
}
