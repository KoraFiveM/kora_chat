---
title: Message types
sidebar_position: 8
---

# Message types

## Built-in types

| Name | Command | Scope | Identity | Notes |
| --- | --- | --- | --- | --- |
| `say` | none | local | character | Plain chat input. |
| `me` | `/me` | local | character | Has an overhead bubble. |
| `ooc` | `/ooc` | global | account | |

## Definition fields

| Field | Default | Description |
| --- | --- | --- |
| `label` | the name | Display name. Non-empty string. |
| `help` | generated | Command help text. |
| `command` | the name | Slash command (letters, digits, underscore, hyphen). `false` disables it. |
| `scope` | `'global'` | `'local'` or `'global'`. |
| `range` | `Config.chat.localRange` | Metres for local scope, above 0 and up to 1000. |
| `identity` | `'character'` | `'character'` uses the kora_core name, `'account'` uses the FiveM player name. |
| `permission` | `'user'` | Checked with `kora_core:hasPermission`. `'user'` always passes. |
| `icon` | `'message'` | One of `message`, `action`, `globe`, `radio`, `shield`, `info`. |
| `color` | none | `#RRGGBB`. |
| `overhead` | `false` | Draw an overhead bubble. |
| `overheadDuration` | `Config.chat.overheadDuration` | 1 to 30000 ms. |
| `checkPermission` | built-in | Optional function replacing the permission check. |
| `modeCallback` | none | Optional function called like a message hook. |

Names are lower-cased and must match letters, digits, underscore or hyphen. A type is owned by the registering resource; only that resource can replace or remove it, and it is removed when the resource stops.

## Message flow

1. Text is cleaned and length-checked.
2. For player messages: permission check, over-length handling, rate limit.
3. Targets are resolved: local scope uses players within range in the same routing bucket, otherwise everyone.
4. Message hooks and the type's mode callback run, and may change, re-route or cancel the message.
5. The server `chatMessage` event fires, then the payload is sent as `kora_chat:message`.
