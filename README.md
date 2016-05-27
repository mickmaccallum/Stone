# Stone

A Swift library for communicating with a Phoenix server via Web Sockets. You know, two birds, one Stone?...

This will be built within the next couple weeks. Check back soon!

#### Working With Sockets

```{swift}
guard let url = NSURL(string: "ws://localhost:4000/socket"),
  socket = Socket(url: url, heartbeatInterval: 15.0) else {
    return
}

socket.onOpen = {
  print("socket open")
}

socket.onMessage = { result in
  // Will print every single event that comes over the socket.
  // print("received message: \(result)")
}

socket.onError = { error in
  print("error received: \(error)")
}

socket.onClose = { code, reason, clean in
  print("socket closed - code: \(code), reason: \(reason), clean: \(clean)")
}

let params = [NSURLQueryItem(name: "user_id", value: "iPhone")]
socket.connect(params)
```

#### Working With Channels

```{swift}
let channel = Channel(topic: MyTopics.Lobby)

channel.shouldTrackPresence = true

channel.onEvent(Event.Custom("new:msg")) { [unowned self] result in
  do {
    self.messages.append(try result.value())
    self.tableView.reloadData()
    let indexPath = NSIndexPath(forRow: self.messages.count.predecessor(), inSection: 0)
    self.tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition: .Bottom, animated: true)
  } catch {
    print(error)
  }
}

channel.onPresenceDiff { [unowned self] result in
  do {
    let diff = try result.value()

    self.connections = self.connections.filter {
      !diff.leaves.contains($0)
    }

    self.connections.appendContentsOf(diff.joins)
  } catch {
    print(error)
  }
}

channel.onPresenceState { [unowned self] result in
  do {
    self.connections = try result.value()
  } catch {
    print(error)
  }
}

socket.addChannel(channel)
```
