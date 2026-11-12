---
title: "How to use"
sidebar_position: 3
---


# How to use

Kora Chat owns input focus, validation, routing, compatibility and `/me` world text in Lua; the React NUI only renders and handles keyboard autocomplete. Every player-authored message is validated, truncated, rate-limited, named and routed on the server before any other player sees it.

## Built-in message types

Three message types are registered by `server/main.lua` itself at boot (`Config.messageTypes` adds more declaratively — see Configuration), so their behavior cannot drift from the documented API:

- `say` (no slash command, bound to the chat input directly): local, character-named, range `Config.chat.localRange` (default 20.0 units), permission `user`.
- `me` (`/me`): local, character-named, same range, permission `user`, draws an overhead bubble for `Config.chat.overheadDuration` ms (default 5000).
- `ooc` (`/ooc`): global, account-named (the FiveM player name, not the character name), permission `user`.

## Adding your own message type

Other resources register additional types at runtime through the `registerMessageType` export, then send through them with `sendMessage`. A type is owned by the resource that registered it and is removed automatically when that resource stops.

```lua title="my_resource/server.lua"
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

- `label`, `help`, and an optional `command` (a command name, or `false` to disable the slash command and keep the type programmatic-only).
- `scope = 'local' | 'global'` (default `global`) and an optional `range` (default `Config.chat.localRange`, must be between 0 and 1000).
- `identity = 'character' | 'account'` (default `character`) picks whose name is attached as `author`.
- `permission` (default `'user'`) is passed to `checkPermission` — by default `exports.kora_core:hasPermission(source, permission)`, skipped entirely when the permission is `'user'`.
- `icon` must be one of `message`, `action`, `globe`, `radio`, `shield`, `info`. `color` is an optional `#RRGGBB` string.
- `overhead = true` also draws a bubble above the sender for `overheadDuration` ms (default `Config.chat.overheadDuration`, capped 1–30000).
- A registration that reuses a name already owned by a different resource, or a `command` already used by another type, raises a Lua error (`assert`) rather than silently overwriting it.

## Command argument suggestions

Kora Lib commands (`Kora.commands.add`) can attach a `provider` function to an argument; it is offered in the chat suggestion panel as the player types.

```lua title="my_resource/server.lua"
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

- Providers receive `{ command, argumentIndex, query, args }` and run only after the command's own permission check has already passed.
- The client asks for suggestions through the callback `kora_chat:commandSuggestions`, which is rate-limited per player to `Config.chat.suggestionRequestsPerSecond` (default 10) requests/second and caps results to `Config.chat.suggestionResultLimit` (default 20). Malformed input (wrong types, an argument over 128 characters, more than 16 parsed args, a command name over 64 characters) is rejected with an empty result instead of being processed.

## Stock chat compatibility

Kora Chat implements the common `chatMessage`, `chat:addMessage`, suggestion, template, mode, clear and `chat:init` event surface, and exposes the stock client `addMessage`/`addSuggestion` and server `addMessage`, `registerMessageHook`, `registerMode` exports through both the `kora_chat` and the provided `chat` identity (`Kora.compat.provideExport`). Compatibility templates are passed through a restricted sanitizer: external chat themes' scripts, remote styles, event handlers and arbitrary inline CSS are intentionally unsupported.

## /me overhead bubble appearance

All in `Config.chat` (`config.lua`); restart `kora_chat` after editing.

- `showActionAuthor` (default `false`): show the character name in the bubble and chat line (`* Alex Mercer waves` vs `* waves`).
- `showActionAsterisk` (default `false`): prefix the chat line with `* `.
- `overheadColourName` (default `true`): colour that name with `overheadNameColour`, even when `overheadThemed` is off.
- `overheadNameColour`, `overheadTextColour`: a kora_theme colour key (`primary`, `foreground`, `success`, `warning`, `danger`, `info`, …) or `'#RRGGBB'`. `primary` follows the player's own `/theme` choice.
- `overheadThemed` (default `false`): also apply the text colour, background and opacity below.
- `overheadBackground` / `overheadBackgroundAlpha`: bubble background colour (or `false` for none) and 0–255 opacity.
- `overheadLimitPerPlayer` (default 3): maximum simultaneous bubbles drawn per nearby player.
