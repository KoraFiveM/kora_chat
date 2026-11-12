---
title: Commands
sidebar_position: 5
---

# Commands

| Command | Where | Description |
| --- | --- | --- |
| `/me <text>` | Server (kora_lib command) | Local action message with an overhead bubble. Registered for the `me` message type. |
| `/ooc <text>` | Server (kora_lib command) | Global out-of-character message, labelled with the account name. |
| `/say <text>` | Server (`RegisterCommand`) | In game it sends local chat. From the server console it sends a global `ooc` message authored `console`. Empty text is ignored. |
| `/clearchat` | Client | Clears only your own chat feed. Name and availability come from `Config.clearChat`. |
| `/<custom>` | Server | One command per registered message type that has a `command`. Names are lower-cased. |

An empty `/me` or `/ooc` shows `Config.chat.missingMessageText`. Message commands honour the type's `permission`.

## Key binding

`kora_chat_open` (description "Open chat") is registered with `Kora.keybind.add` and defaults to `Config.chat.defaultKey` (`T`). It can be rebound in FiveM key bindings. It does nothing while the player is not logged in, while the `/ui` editor is open, or while another NUI has focus.

## Slash input

Text starting with `/` is run through `ExecuteCommand`, so any registered command works from the chat input. Plain text is sent as local chat.
