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

Channels are defined on a Socket by Socket basis, and are considered to be unique by their topic. To create a Channel, all you have to do is initialize one, passing the topic as input. This topic can either be a String, or an Enum whose RawType is String.

```{swift}
let channel = Channel(topic: MyTopics.Lobby)
```

```{swift}
channel.onEvent(Event.Custom("new:msg")) { (result: Result<Message>) in
  do {
    let message: Message = try result.value()
  } catch {
    print(error)
  }
}
```

If desired, Stone is capable of tracking Presence information in Channels. By default, this is disabled, but can be enabled as easily as setting the `shouldTrackPresence` instance variable.

```{swift}
channel.shouldTrackPresence = true
```

Tracking Presence changes can be done by setting the Presence related callbacks on your Channel.

```{swift}
channel.onPresenceDiff { (result: Result<PresenceDiff> in
  do {
    let diff: PresenceDiff = try result.value()
    let leaves: [PresenceChange] = diff.leaves
    let joins: [PresenceChange] = diff.joins
  } catch {
    print(error)
  }
}

channel.onPresenceState { (result: Result<Array<PresenceChange>>) in
  do {
    let connections: [PresenceChange] = try result.value()
  } catch {
    print(error)
  }
}
```

When you're done configuring your Channel, just add it to your Socket. If you've left `socket.shouldAutoJoinChannels` enabled, then you've done. If you've disabled it, you'll need to explicitly call `channel.join()` when you've ready to join the Channel's topic.

```{swift}
socket.addChannel(channel)
```

#### Working With Events

In an attempt to keep all event handling as type safe as possible, Stone provides an [Event](https://github.com/Tethr-Technologies-Inc/Stone/blob/master/Stone/Stone/Event.swift#L43) enum to try to wrap both default and custom events. Some examples of the difference Event types that can be created are as follows.

```{swift}
let phoenixEvent = Event.Phoenix(.Join)
let customEvent = Event.Custom("new:msg")
let presenceEvent = Event.Presence(.Diff)
```

#### Contributing

As I stated earlier, I made this framework to support my own use, but would love for it to support yours as well. In the spirit of this, if I borked something, or you can think of a cool feature that Stone is missing, please raise an issue and I'll try to incorporate it. If you'd like to help out, pull requests are more than welcome. All I ask is that you try to keep your code style the same as is used in the rest of Stone.
