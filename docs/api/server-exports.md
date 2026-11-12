---
title: "Server exports"
sidebar_position: 2
---


# Server exports

The public API other resources use to add message types, send trusted messages, and hook into the stock `chat` compatibility surface. Every export except `sendMessage` and the compat ones is also what `registerMessageType`/`unregisterMessageType`/`sendMessage` call internally.

Namespace: `exports.kora_chat` · Source: `server/main.lua`

## How it works

All exports run on the server only; there is no client export surface besides the stock-compat `addMessage`/`addSuggestion` described in How to use.

## Functions

Six server exports.

### `exports.kora_chat:registerMessageType(name, definition)`

Registers a new message type, owned by the calling resource. Automatically removed when that resource stops.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `name` | string | Letters, numbers, underscore or hyphen only; used lower-cased. |
| `definition` | table | See the fields listed in How to use → Adding your own message type. |

**Returns**

- **ok** — `true` on success.
- **Raises a Lua error (via `assert`) for an invalid definition, a name already owned by another resource, or a command already used by another type.**

**Example**

```lua
exports.kora_chat:registerMessageType('radio', { label = 'Radio', command = 'radio', scope = 'global', identity = 'character', permission = 'user', icon = 'radio' })
```

### `exports.kora_chat:unregisterMessageType(name)`

Removes a runtime type, but only when the calling resource is the one that registered it.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `name` | string | The type name. |

**Returns**

- **ok** — `true` when removed, `false` when the type does not exist or is owned by a different resource.

**Example**

```lua
exports.kora_chat:unregisterMessageType('radio')
```

### `exports.kora_chat:sendMessage(target, typeName, message, opts?)`

Trusted server-side send: skips the permission/length-reject/rate checks that an in-game sender goes through (the message is still cleaned and length-truncated).

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `target` | integer \| integer[] \| -1 | A player id, an array of player ids, or `-1` for everyone. |
| `typeName` | string | A registered message type. |
| `message` | string | The text to send. |
| `opts?` | table | May set `author` (display name override) and `source` (attributed sender id, defaults to `0`). |

**Returns**

- **handled** — same as `dispatchMessage`'s first return.
- **reason** — same as `dispatchMessage`'s second return.

**Example**

```lua
exports.kora_chat:sendMessage(-1, 'radio', 'Units respond.', { author = 'Dispatch' })
```

**Representative console output**

```text
Throws (via `assert`) for a malformed `target`, non-string `typeName`, or non-table `opts`.
```

### `exports.kora_chat:addMessage(target?, message)`

Stock-`chat` compatible: pushes a raw client message payload to one player or everyone, bypassing message-type routing entirely. Also reachable through the `chat` export identity.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `target?` | integer | Player id; omitted or `nil` broadcasts to everyone (`-1`). |
| `message` | table \| string | A raw client message object/args, passed straight to the NUI. |

**Returns**

- **ok** — `true`, or `false` when both arguments were nil.

**Example**

```lua
exports.kora_chat:addMessage(source, { color = {255,0,0}, args = {'System', 'Maintenance in 5 minutes'} })
```

### `exports.kora_chat:registerMessageHook(hook)`

Stock-`chat` compatible: registers a callback that can inspect, modify or cancel every dispatched message before it is sent. Hooks from a stopped resource are removed automatically.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `hook` | function | Called as `hook(source, payload, hookRef)`. `hookRef` exposes `updateMessage(update)`, `cancel()`, `setSeObject(object)` and `setRouting(targets)`. |

**Returns**

- **hookId** — integer id. No export removes a hook by id; hooks are removed when the registering resource stops.

**Example**

```lua
exports.kora_chat:registerMessageHook(function(source, payload, hookRef)
    if payload.message:find('badword') then hookRef.cancel() end
end)
```

**Representative console output**

```text
A hook that errors is caught (`pcall`) and logged; it does not stop the message or other hooks from running.
```

### `exports.kora_chat:registerMode(modeData)`

Stock-`chat` compatible: registers a chat "mode" (channel) as a message type under the hood, optionally gated by an ACE object instead of a kora_core permission.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `modeData` | table | `{ name, displayName, cb, isGlobal?, isChannel?, color?, seObject? }`. `seObject`, when set, restricts both sending and the client-side mode list to players passing `IsPlayerAceAllowed(source, seObject)`. |

**Returns**

- **ok** — `true`, or `false` for a malformed `modeData` (missing `name`/`displayName`/callable `cb`).

**Example**

```lua
exports.kora_chat:registerMode({ name = 'admin', displayName = 'Admin', isGlobal = true, seObject = 'command.admin', cb = function(source, payload) end })
```

## Limits and related APIs

Server only.

## Client exports

`addMessage(message)` and `addSuggestion(name, help, params)`, on both `kora_chat` and `chat`. A string message is shown as plain text.

```lua
exports.kora_chat:addMessage({ args = { 'System', 'Hello' } })
```

## Stock `chat` compatibility details

`addMessage`, `registerMessageHook` and `registerMode` are available on both `kora_chat` and the provided `chat` identity.

- `registerMessageHook(hook)` returns a hook id. The hook receives `source`, the message payload and a reference with `updateMessage`, `cancel`, `setSeObject` and `setRouting`. Hooks are removed when their resource stops.
- `registerMode(modeData)` needs `name`, `displayName` and `cb`. It creates a message type and a command with the mode's name and notifies clients with `chat:addMode`. `seObject` restricts it to players with that ACE object. `isGlobal` selects global or local scope.
- `sendMessage` returns `true`, or `false` plus a reason (`invalid message` or `cancelled`).

See [Events](../events.md) for the matching net and local events.

## Command suggestions

Providers are declared through kora_lib commands, not through this resource. Each argument can carry `values` or a `provider(source, context)` function. The context contains `command`, `argumentIndex`, `query` and `args`. Providers run after the command's permission check and results are capped by `suggestionResultLimit`. See [How to use](../how-to-use.md).

```lua
Kora.commands.add('vehicle', 'Spawn a vehicle', {
    { name = 'model', help = 'Vehicle model', values = { 'adder', 'sultan' } },
}, true, function(source, args) end)
```
