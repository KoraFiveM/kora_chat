> [!WARNING]
> **Kora Framework is in alpha and actively being developed.**
>
> This resource is a work in progress. Features may be incomplete or unstable,
> and APIs, configuration, and behavior may change. It is not ready for production use.
>
> **Help shape Kora:** try it out, share feedback, report bugs through this
> repository’s Issues, and contribute improvements through pull requests.

# kora_chat

An event-driven FiveM chat replacement built on kora_lib. It provides proximity
IC chat, `/me`, global `/ooc`, kora_lib command metadata and dynamic argument
completion, owner-tracked custom message types, and the common stock `chat`
events/exports.

The chat opens on `T` by default and is rebindable in FiveM settings. While the input is open the recent history is shown and can be scrolled with the mouse wheel or PageUp/PageDown. The history is a fixed-size region (`Config.chat.historyHeight`, percent of screen height, default 32; the older `openHistoryHeight` key is still honoured when `historyHeight` is unset), so neither it nor the input moves however many messages arrive. The `/hudlayout` "Chat input" box (kora_hud) is where the input goes: after Confirm, and on every reconnect, the input lands exactly on that box at any resolution and scale, and the history sits directly above it, or below it when there is no room above (`Config.chat.historyPlacement = 'auto'|'above'|'below'`, default `auto`). `Config.chat.layoutOrigin = { x = 16, y = 16 }` is that box's zero point and must match kora_hud. Until a player moves the box (or after a reset) `Config.chat.position = { anchor = 'top'|'bottom', x, y }` in pixels applies (default top, x 16, y 40; with `top`, y is the top of the history region and the input sits `historyHeight` below it, with `bottom`, y is the gap between the input and the bottom of the screen). `/clearchat` clears your own chat feed locally (`Config.clearChat = { enabled = true, command = 'clearchat' }`). No thread
polls for keyboard input.

With kora_hud's `/ui` editor each player can also move and resize the chat and choose how long messages stay before fading (0 = never), the background opacity, and whether messages show while chat is closed (`Config.chat.playerSettings = true`; defaults come from `fadeTimeout` and `backgroundOpacity`). Messages fade one by one (`Config.chat.fadeMode = 'message'`, `fadeDuration` ms); `'feed'` restores the old whole-feed fade.

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

### `/me` overhead bubble options

All in `Config.chat` (`config.lua`); restart `kora_chat` after editing.

- `showActionAuthor` (default `false`): show the character name in the bubble (and chat line).
- `overheadColourName` (default `true`): colour that name with `overheadNameColour` from
  `kora_theme`, even when `overheadThemed` is off.
- `overheadNameColour`, `overheadTextColour`: a `kora_theme` colour key (`primary`,
  `foreground`, `success`, ...) or `'#RRGGBB'`. `primary` follows the player's `/theme`.
- `overheadThemed` (default `false`): apply the text colour, background and opacity.
- `overheadBackground` / `overheadBackgroundAlpha`: bubble background colour (or `false`) and 0-255 opacity.
- `overheadDuration` (default `5000`): ms the bubble stays up.
- `localRange`: only players within this range see the bubble.

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
- `identity = 'character' | 'account'` and a kora_lib/kora_core `permission`
- `icon = 'message' | 'action' | 'globe' | 'radio' | 'shield' | 'info'`
- optional `color = '#RRGGBB'`, `overhead`, and `overheadDuration`

`sendMessage(target, typeName, message, opts?)` accepts one player id, an array
of player ids, or `-1`. Server callers may set trusted `author` and `source`
overrides in `opts`.

## Command argument suggestions

kora_lib commands can attach static or synchronous server-side completions:

```lua
Kora.commands.add('vehicle', 'Spawn a vehicle', {
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

Full documentation: see [docs/](docs/index.md).
