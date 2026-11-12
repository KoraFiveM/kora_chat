---
title: Configuration
sidebar_position: 4
---

# Configuration

Everything is in `config.lua`, loaded as a shared script. Restart `kora_chat` after editing. The client sends a copy of `Config.chat` to the page (with `maxMessageLength` increased by 1 so over-limit text reaches the server check instead of being silently cut).

## `Config.chat`

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

## `Config.chatWarnings`

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

## `Config.clearChat`

`{ enabled = true, command = 'clearchat' }`. The command name is given without the slash; invalid names fall back to `clearchat`. See [Commands](./commands.md).

## `Config.messageTypes`

A map of type name to definition, registered at start with the same schema as the `registerMessageType` export. See [Message types](./message-types.md). It is empty by default.

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
