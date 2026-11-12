---
title: "Commands"
sidebar_position: 4
---


# Commands

Kora Chat registers one FiveM `RegisterCommand` directly (`say`) and one conditional local-only command (`/clearchat`); `/me` and `/ooc` are registered as slash commands through `registerMessageType`'s own `Kora.commands.add` call, so they go through Kora Lib's command/permission pipeline like any other Kora Lib command.

## Built-in commands

### `/me <message>`

Local, character-named action message. Draws an overhead bubble above the sender for `Config.chat.overheadDuration` ms.

| Field | Details |
| --- | --- |
| Context | In-game · chat command |
| Arguments | message — required; a reply with no message text shows `Config.chat.missingMessageText` instead of sending anything. |
| Access | Permission `user` (open to everyone) unless overridden by editing the built-in registration in `server/main.lua`. |

**Example**

```text
/me waves at the bartender
```

**Result**

Players within `Config.chat.localRange` (default 20.0) see the action line and the overhead bubble.

### `/ooc <message>`

Global, account-named (FiveM player name, not character name) out-of-character message.

| Field | Details |
| --- | --- |
| Context | In-game · chat command |
| Arguments | message — required. |
| Access | Permission `user`. |

**Example**

```text
/ooc anyone want to trade?
```

**Result**

Every connected player sees the message.

### `/clearchat`

Clears only the running player's own chat feed, client-side. Registered only when `Config.clearChat.enabled` is `true` (default) and only ever affects the caller.

| Field | Details |
| --- | --- |
| Context | In-game · client command |
| Arguments | No arguments. |
| Access | Open to everyone; nothing is sent to the server. |

**Example**

```text
/clearchat
```

**Result**

The local chat history is wiped on screen.

### `say <message>`

Lets the server console post as `console` into the global `/ooc` type. From an in-game source `/say <message>` sends the text as local `say` chat (`RegisterCommand('say')` in `server/main.lua`).

| Field | Details |
| --- | --- |
| Context | Server console · server command (in game it sends local chat) |
| Arguments | message — required. |
| Access | Server console (source 0) posts globally. A non-console caller is routed to the local `say` message type instead, through the same permission checks as ordinary chat. |

**Example**

```text
say Server restarting in 5 minutes
```

**Result**

Broadcast globally as an `ooc` message authored `console`.

## Message-type commands are Kora Lib commands

Because `/me`, `/ooc` and any custom type's slash command are registered with `Kora.commands.add`, they appear in kora_lib's own command list/autocomplete and honor its `permission` and `resource` metadata like any other Kora Lib command — see Kora Lib's Commands module for the shared mechanics.

## Command summary

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
