# kora_chat

An event-driven FiveM chat replacement built on kora_lib. It provides proximity
IC chat, `/me`, global `/ooc`, kora_lib command metadata and dynamic argument
completion, owner-tracked custom message types, and the common stock `chat`
events/exports.

The chat opens on `T` by default and is rebindable in FiveM settings. No thread
polls for keyboard input.

Start it after kora_lib and kora_core. `provide 'chat'` satisfies resources that
depend on the stock identity, so do not also start the stock `chat` resource.

```cfg
ensure kora_lib
ensure kora_core
ensure kora_chat
```

Ordinary chat and `/me` are character-named and routed within 20 metres.
`/ooc` is account-named and global. `/me` also draws above the sender for five
seconds. Slash-prefixed input is passed to FiveM's command system.

## Server exports

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

exports.kora_chat:sendMessage(-1, 'radio', 'Units respond.', {
    author = 'Dispatch',
})
```

`unregisterMessageType(name)` removes a runtime type. Registrations are owned
by the invoking resource and are automatically removed when it stops.

Message type definitions support:

- `label`, `help`, and optional `command` (`false` disables the slash command)
- `scope = 'local' | 'global'` and an optional local `range`
- `identity = 'character' | 'account'` and a kora_lib/qbcore `permission`
- `icon = 'message' | 'action' | 'globe' | 'radio' | 'shield' | 'info'`
- optional `color = '#RRGGBB'`, `overhead`, and `overheadDuration`

`sendMessage(target, typeName, message, opts?)` accepts one player id, an array
of player ids, or `-1`. Server callers may set trusted `author` and `source`
overrides in `opts`.

## Command argument suggestions

kora_lib commands can attach static or synchronous server-side completions:

```lua
QB.commands.add('vehicle', 'Spawn a vehicle', {
    {
        name = 'model',
        help = 'Vehicle model',
        values = { 'adder', 'sultan' },
        provider = function(source, context)
            return {
                { value = 'police', label = 'Police Cruiser', help = 'Emergency vehicle' },
            }
        end,
    },
}, true, function(source, args)
    -- command body
end)
```

Providers receive `{ command, argumentIndex, query, args }`. They run only
after the command permission check; results are filtered and capped before
being returned to the chat suggestion panel.

## Stock compatibility

kora_chat implements the common `chatMessage`, `chat:addMessage`, suggestion,
template, mode, clear, and `chat:init` event surface. It also exposes the stock
client `addMessage`/`addSuggestion` and server `addMessage`,
`registerMessageHook`, and `registerMode` exports through both `kora_chat` and the
provided `chat` identity. Compatibility templates are sanitized and external
chat theme scripts/styles are intentionally unsupported.
