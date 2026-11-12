---
title: kora_chat
sidebar_position: 1
---

# kora_chat

`kora_chat` is an event-driven chat replacement for Kora servers. It declares `provide 'chat'`, so it stands in for the stock `chat` resource, keeps the common stock events and exports, and adds proximity roleplay chat (`/me`, local say), global `/ooc`, owner-tracked custom message types and kora_lib command argument completion. The UI is a React NUI page styled by `kora_theme`.

Current version: see `version` in `fxmanifest.lua`.

## Pages

- [Features](./features.md) - what the chat does and how messages are routed.
- [Installation](./installation.md) - dependencies and start order.
- [Configuration](./configuration.md) - every `Config.chat`, `Config.chatWarnings`, `Config.clearChat` and `Config.messageTypes` option.
- [Commands](./commands.md) - `/me`, `/ooc`, `/say`, `/clearchat` and the open-chat key.
- [Exports](./exports.md) - server and client exports, including stock `chat` compatibility.
- [Events](./events.md) - net and local events, callbacks and the kora_hud integration events.
- [Message types](./message-types.md) - built-in types and the type definition schema.
- [UI](./ui.md) - the NUI page, keyboard handling, layout and per-player settings.
- [Troubleshooting](./troubleshooting.md) - common problems.
