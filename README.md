# Stone

A Swift framework for connecting to [Phoenix](https://www.phoenixframework.org) Channels in your iOS/OS X app.

#### Why Build This?

There are already a few options available for working with Phoenix Channels, such as [ObjCPhoenixClient](https://github.com/livehelpnow/ObjCPhoenixClient) and [SwiftPhoenixClient](https://github.com/davidstump/SwiftPhoenixClient). Both of these are great, and in fact, Stone took a lot of inspiration from the design of [ObjCPhoenixClient](https://github.com/livehelpnow/ObjCPhoenixClient). But I felt both of these could be made to take advantage of the additional type safety that Swift provides. Because of this, Stone attempts to provide overloads for using custom enums in place of Strings for things like Channel topics and event handlers. It also makes use of `Result<T>` enums for things like callbacks for events.

#### Why Call it Stone?

Well, as we all know, [Swift](https://swift.org) and [Phoenix](https://www.phoenixframework.org) are both named after birds. You know, two birds, one Stone?...

#### Working With Sockets

To create a Socket, simply initialize an instance of the provided Socket class.

```{swift}
guard let url = NSURL(string: "ws://localhost:4000/socket"),
  socket = Socket(url: url, heartbeatInterval: 15.0) else {
    return
}
```

Sockets were build to require minimal customization, but you can change the following settings if desired.

```{swift}
socket.shouldReconnectOnError = false // Default is true
socket.shouldAutoJoinChannels = false // Default is true
socket.reconnectInterval = 10.0 // Default is 5.0 (units are seconds)
```

To receive callbacks for any Socket level events, you can utilize the following hooks.

```{swift}
socket.onOpen = {
  print("socket open")
}

socket.onMessage = { (result: Result<Message>) in
  // Will print every single message event that comes over the socket.
  // print("received message: \(result)")
}

socket.onError = { (error: NSError) in
  print("error received: \(error)")
}

socket.onClose = { (code: Int, reason: String, clean: Bool) in
  print("socket closed - code: \(code), reason: \(reason), clean: \(clean)")
}
```

After your Socket is set up, you can optionally provide its connect method with parameters to be included in the URL's query when a connection is made. The below example uses `Array<NSURLQueryItem>`, but there is another overload available that takes `Dictionary<QueryStringConvertible, QueryStringConvertible>` to force all parameters to provide an implementation of [QueryStringConvertible](https://github.com/Tethr-Technologies-Inc/Stone/blob/master/Stone/Stone/QueryStringConvertible.swift) to escape themselves for a query string.

Since stone provides a default implementation of this protocol for `String`, you can make use of the [toQueryItems()](https://github.com/Tethr-Technologies-Inc/Stone/blob/master/Stone/Stone/Extensions.swift#L25) instance method attached to all `Dictionary<String, String>`s to convert them into `Array<NSURLQueryItem>`.

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

#### Contributing

As I stated earlier, I made this framework to support my own use, but would love for it to support yours as well. In the spirit of this, if I borked something, or you can think of a cool feature that Stone is missing, please raise an issue and I'll try to incorporate it. If you'd like to help out, pull requests are more than welcome. All I ask is that you try to keep your code style the same as is used in the rest of Stone.
