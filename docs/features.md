---
title: Features
sidebar_position: 2
---

# Features

- **Stock chat replacement** - `provide 'chat'` satisfies resources that depend on `chat`. The stock chat events and the common exports are implemented. See [Exports](./exports.md) and [Events](./events.md).
- **Local chat** - text typed without a leading slash is sent to the server and routed as the `say` message type to players within `Config.chat.localRange` (default 20 metres) who are in the same routing bucket. The author is the character name from `kora_core`.
- **`/me` actions** - the `me` type is local and also draws text above the sender's head for `Config.chat.overheadDuration` ms. Up to `Config.chat.overheadLimitPerPlayer` bubbles per player are stacked. Bubbles are only drawn for players within `localRange`.
- **`/ooc`** - global, labelled with the account name (`GetPlayerName`) rather than the character name.
- **Custom message types** - other resources register types at runtime, or servers declare them in `Config.messageTypes`. See [Message types](./message-types.md).
- **Server-side safety** - every player message is stripped of control characters, trimmed, length-limited, permission-checked and rate-limited on the server. Over-length messages are rejected or truncated depending on `Config.chatWarnings.overLimitAction`.
- **Command completion** - typing `/` shows matching commands the player is allowed to run. Arguments declared through `Kora.commands` can offer static values or server-side provider results. See [UI](./ui.md).
- **Login gating** - chat only opens while the player state bag `kora_core:loggedIn` is `true`. Logging out closes the input and releases NUI focus.
- **Stock compatibility** - templates, modes, suggestions and message hooks are supported. Compatibility templates pass through a restricted sanitizer; external chat theme scripts and styles are not supported.
- **Optional kora_hud integration** - when `kora_hud` is started and `Config.chat.playerSettings` is not `false`, the chat registers with the `/ui` editor so each player can move and scale it and change fade and opacity. See [UI](./ui.md).
