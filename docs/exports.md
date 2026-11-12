---
title: Exports
sidebar_position: 6
---

# Exports

## Server

### `registerMessageType(name, definition)`

Registers a message type and, unless `command = false`, a slash command. Returns `true`. Throws an assertion error when the definition is invalid, when the name is owned by another resource, or when the command is used by another type. The caller is recorded as the owner and the type is removed automatically when that resource stops. See [Message types](./message-types.md).

```lua
exports.kora_chat:registerMessageType('radio', {
    label = 'Radio',
    help = 'Send a radio message',
    command = 'radio',
    scope = 'global',
    identity = 'character',
    permission = 'user',
    icon = 'radio',
})
```

### `unregisterMessageType(name)`

Removes a type and its command. Returns `false` when the type does not exist or is owned by a different resource.

### `sendMessage(target, typeName, message, opts?)`

Sends a trusted message. `target` is a player id, an array of player ids, or `-1` for everyone. `opts.author` and `opts.source` override the author and source. The permission and rate limit checks are skipped for this export, but the message is still cleaned and truncated to `maxMessageLength`. Returns `true`, or `false` plus a reason (`invalid message` or `cancelled`).

```lua
exports.kora_chat:sendMessage(-1, 'radio', 'Units respond.', { author = 'Dispatch' })
```

### Stock `chat` exports

`addMessage(target, message)` (or `addMessage(message)` for everyone), `registerMessageHook(hook)` and `registerMode(modeData)`. Available on both `kora_chat` and the provided `chat` identity.

- `registerMessageHook(hook)` returns a hook id. The hook receives `source`, the message payload and a reference with `updateMessage`, `cancel`, `setSeObject` and `setRouting`. Hooks are removed when their resource stops.
- `registerMode(modeData)` needs `name`, `displayName` and `cb`. It creates a message type and a command with the mode's name and notifies clients with `chat:addMode`. `seObject` restricts it to players with that ACE object. `isGlobal` selects global or local scope.

## Client

`addMessage(message)` and `addSuggestion(name, help, params)`, on both `kora_chat` and `chat`. A string message is shown as plain text.

```lua
exports.kora_chat:addMessage({ args = { 'System', 'Hello' } })
```

## Command suggestions

Providers are declared through kora_lib commands, not through this resource. Each argument can carry `values` or a `provider(source, context)` function. The context contains `command`, `argumentIndex`, `query` and `args`. Providers run after the command's permission check and results are capped by `suggestionResultLimit`.

```lua
Kora.commands.add('vehicle', 'Spawn a vehicle', {
    { name = 'model', help = 'Vehicle model', values = { 'adder', 'sultan' } },
}, true, function(source, args) end)
```
