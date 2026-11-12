---
title: "Configuration"
sidebar_position: 3
---


# Configuration

One flat `Config.chat` table plus `Config.chatWarnings`, `Config.clearChat` and `Config.messageTypes`, read by both client and server.

Namespace: `Config` · Source: `config.lua`

## How it works

Edit and restart `kora_chat` to apply. If kora_lib's config-adoption API (`Kora.config.adopt`) is present, `Config.messageTypes` is also registered with it so custom types can be edited through kora_lib's config UI without changing this file.

## Config.chat (selected keys)

Every field is optional in `config.lua`; the full defaults are listed under [Full option reference](#full-option-reference).

| Option | Type | Description |
| --- | --- | --- |
| `defaultKey` | string | Default keybind to open the chat input (default 'T'), rebindable per player in FiveM settings. |
| `localRange` | number | Range in world units for local/proximity message types (default 20.0). |
| `maxMessageLength` | integer | Maximum message length in characters (default 400); the input allows one extra character on the client so an over-limit message still reaches the server to be rejected/warned rather than silently cut. |
| `minimumMessageInterval` | integer | Per-player cooldown between messages, in ms (default 500). |
| `messageLimit` | integer | Maximum messages kept in the NUI feed (default 200). |
| `historyLimit` | integer | Maximum scrollback history kept while the input is open (default 50). |
| `fadeTimeout / fadeMode / fadeDuration` | integer / string / integer | Default fade behavior: 'message' fades each message on its own after fadeTimeout ms (fadeDuration ms transition); 'feed' fades the whole feed fadeTimeout ms after the last message. Per-player overridable through kora_hud's /ui editor when playerSettings is true. |
| `backgroundOpacity` | integer | Default background opacity 20–100% for message rows and the input (default 94). |
| `playerSettings` | boolean | Register with kora_hud's /ui editor so each player can move/resize chat and change fade/opacity (default true). |
| `historyHeight / historyPlacement` | integer / string | History region height as % of screen height (default 32) and its placement relative to the input: 'above' \| 'below' \| 'auto' (default). |
| `position / layoutOrigin` | table | Default pixel placement before a player ever moves the chat, and the zero point used by the kora_hud /hudlayout editor box. Change layoutOrigin only to match a changed kora_hud default. |
| `showActionAuthor / showActionAsterisk` | boolean | Whether /me lines and the overhead bubble show the author's name, and whether they are prefixed with '* ' (both default false). |
| `missingMessageText` | string | Notify text ('%s' = command name) shown when a message-type command is sent with no text; defaults to kora_lib's generic text when empty. |
| `overheadDuration / overheadThemed / overheadNameColour / overheadColourName / overheadTextColour / overheadBackground / overheadBackgroundAlpha / overheadLimitPerPlayer` | various | Appearance and lifetime of the /me overhead bubble — see How to use → /me overhead bubble appearance. |
| `suggestionLimit / suggestionResultLimit / suggestionDebounce / suggestionRequestsPerSecond` | integer | Client-side suggestion list size/debounce, and the server-side rate limit (per-player requests/second) applied to the `kora_chat:commandSuggestions` callback. |

## Config.chatWarnings

On-screen notify warnings (via `Kora.notify.send`) when a message is rejected or shortened. `enabled` (default true), `overLimitAction` (`'reject'` or `'truncate'`, default `'reject'`), `interval` (ms minimum between two warnings to the same player, default 1500), and the `title`/`tooLong`/`truncated`/`rateLimited` texts (set a text to `''` to silence that one).

## Config.clearChat

`{ enabled = true, command = 'clearchat' }`. The command name is used without its slash and is only ever a client-side, player-local command — nothing reaches the server.

## Config.messageTypes

Empty by default. Additional declarative message types, keyed by name, using the exact same schema as `registerMessageType`'s `definition` argument. Registered automatically by `server/main.lua` at boot alongside the built-in `say`/`me`/`ooc` types.

## Limits and related APIs

Shared — read by both realms, but only the server enforces the limits (length, rate, permission) that these values describe; the client-side copies only affect what the UI shows/allows before sending.

## Full option reference

The client sends a copy of `Config.chat` to the page (with `maxMessageLength` increased by 1 so over-limit text reaches the server check instead of being silently cut).

### `Config.chat` defaults

| Option | Default | Description |
| --- | --- | --- |
| `defaultKey` | `'T'` | Default key of the `kora_chat_open` keybind. Players can rebind it in FiveM settings. |
| `localRange` | `20.0` | Metres for local messages and `/me` bubbles. |
| `maxMessageLength` | `400` | Maximum characters of a message. |
| `minimumMessageInterval` | `500` | Minimum ms between two messages from one player. |
| `messageLimit` | `200` | Messages kept in the page. |
| `historyLimit` | `50` | Sent-message history for the up and down arrow keys. |
| `fadeTimeout` | `8000` | Default ms before a message fades while the input is closed. `0` keeps messages on screen. Default of the per-player setting. |
| `fadeMode` | `'message'` | `'message'` fades each message on its own; `'feed'` hides the whole feed after the last message. |
| `fadeDuration` | `600` | Length of one fade in ms (0 to 5000). |
| `backgroundOpacity` | `94` | Default opacity, 20 to 100, of rows and input. |
| `playerSettings` | `true` | Register with kora_hud's `/ui` editor. `false` means only the server config applies. |
| `historyHeight` | `32` | Height of the history region, percent of screen height (10 to 90). The older `openHistoryHeight` key is used when `historyHeight` is unset. |
| `historyPlacement` | `'auto'` | `'above'`, `'below'` or `'auto'` (above when there is room). |
| `position` | `{ anchor = 'top', x = 16, y = 40 }` | Pixel placement used until the player has a saved layout. With `top`, `y` is the top of the history; with `bottom`, `y` is the gap under the input. |
| `layoutOrigin` | `{ x = 16, y = 16 }` | Zero point of kora_hud's chat layout box. Must match kora_hud. |
| `showActionAuthor` | `false` | Prefix `/me` text with the character name, in chat and overhead. |
| `showActionAsterisk` | `false` | Start `/me` text with `* `. |
| `missingMessageText` | `'Missing message for /%s'` | Notification when a message command has no text. `%s` is the command. A non-string or empty value falls back to `Missing arguments for /%s`. |
| `overheadDuration` | `5000` | Ms a `/me` bubble stays (1 to 30000). |
| `overheadThemed` | `false` | Apply theme text colour, background and opacity to the bubble. |
| `overheadNameColour` | `'primary'` | kora_theme colour key or `'#RRGGBB'` for the author name. |
| `overheadColourName` | `true` | Colour the name even when `overheadThemed` is off (only if `showActionAuthor` is on). |
| `overheadTextColour` | `'foreground'` | Bubble text colour when themed. |
| `overheadBackground` | `'background'` | Bubble background colour, or `false` for none. Used when themed. |
| `overheadBackgroundAlpha` | `170` | Background opacity, 0 to 255. |
| `overheadLimitPerPlayer` | `3` | Bubbles stacked per player. |
| `suggestionLimit` | `8` | Command suggestions shown. |
| `suggestionResultLimit` | `20` | Argument suggestions kept (client and server). |
| `suggestionDebounce` | `125` | Ms before the page asks the server for argument suggestions. |
| `suggestionRequestsPerSecond` | `10` | Server cap per player per second for suggestion requests; extra requests get an empty list. |


### `Config.chatWarnings`

Notifications through kora_lib when a message is rejected or shortened.

| Option | Default | Description |
| --- | --- | --- |
| `enabled` | `true` | Show warnings at all. |
| `overLimitAction` | `'reject'` | `'reject'` drops a message longer than `maxMessageLength`; any other value truncates it and sends it. |
| `interval` | `1500` | Minimum ms between warnings to one player. |
| `title` | `'Chat'` | Notification title. |
| `tooLong` | see `config.lua` | Text for rejected messages. `%d` is the length limit. |
| `truncated` | see `config.lua` | Text for shortened messages. |
| `rateLimited` | see `config.lua` | Text when sending too fast. |

An empty string silences that case.

### `Config.clearChat`

`{ enabled = true, command = 'clearchat' }`. The command name is given without the slash; invalid names fall back to `clearchat`. See [Commands](../commands.md).

### `Config.messageTypes`

A map of type name to definition, registered at start with the same schema as the `registerMessageType` export. See [Message types](../message-types.md). It is empty by default.

```lua
Config.messageTypes = {
    staff = {
        label = 'Staff',
        command = 'staff',
        scope = 'global',
        permission = 'group.admin',
        icon = 'shield',
        color = '#FF5555',
    },
}
```

The permission string is passed to `kora_core:hasPermission`; use a value your `kora_core` accepts.
