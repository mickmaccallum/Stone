# Stone

A Swift framework for using Phoenix server channels via Web Sockets.

You know, two birds, one Stone?...

This will be built within the next couple weeks. Check back soon!

#### Why Build This?




#### Working With Sockets

To create a Socket, simply initialize an instance of the provided Socket class.

```{swift}
guard let url = NSURL(string: "ws://localhost:4000/socket"),
  socket = Socket(url: url, heartbeatInterval: 15.0) else {
    return
}
```

To receive callbacks for any Socket level events, you can utilize the following hooks.

```{swift}
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
```

After your Socket is set up, you can optionally provide its connect method with parameters to be included in the URL's query when a connection is made.

```{swift}
let params = [NSURLQueryItem(name: "user_id", value: "iPhone")]
socket.connect(params)
```

When you're done with a socket, you can call `socket.disconnect()`, to disconnect from the server.

If you want to reconnect, using the parameters supplied during the first connection, simply call `socket.reconnect()`.

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
