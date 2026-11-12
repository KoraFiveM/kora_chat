---
title: Events
sidebar_position: 7
---

# Events

## Server net events

| Event | Description |
| --- | --- |
| `kora_chat:send` | From the client with message text. Dispatched as `say` through validation, permission and rate limit. |
| `_chat:messageEntered` | Stock-compatible. Arguments are ignored except message and mode. An unknown mode falls back to `say`. |
| `chat:init` | Sent by the page when ready. The server refreshes the player's commands and replies with `kora_chat:types`. |
| `chat:addTemplate`, `chat:addMessage`, `chat:addSuggestion`, `chat:addSuggestions`, `chat:addMode`, `chat:removeMode`, `chat:removeSuggestion`, `chat:clear` | Registered server-side with no handler, so legacy resources can rely on the names existing. |

## Server local events

`chatMessage(source, author, message)` is triggered for every dispatched message. Cancelling it stops delivery.

## Client events (server to client)

| Event | Description |
| --- | --- |
| `kora_chat:message` | Delivers a message payload. Starts an overhead bubble when `overhead` is set. |
| `kora_chat:types` | Full list of public message types on init. |
| `kora_chat:typeAdded`, `kora_chat:typeRemoved` | A type was registered or removed. |
| `chatMessage`, `chat:addMessage`, `chat:addSuggestion`, `chat:addSuggestions`, `chat:removeSuggestion`, `chat:clear`, `chat:addTemplate`, `chat:addMode`, `chat:removeMode` | Stock-compatible handlers. |

## Client local events

| Event | Description |
| --- | --- |
| `kora_chat:setInputLayout` | Argument is `{ x, y, scale }`. Offsets are clamped to -0.95..0.95 and scale to 0.75..1.5. |
| `kora_hud:ui:apply` | From kora_hud with owner, id and layout. Applied only for owner `kora_chat` and id `chatInput`. |
| `kora_hud:ui:ready` | kora_hud is ready; the chat registers with the editor. |
| `kora_hud:ui:editing` | The `/ui` editor opened or closed. While editing, the input is closed and a preview is shown. |

## Callbacks

`kora_chat:commandSuggestions(command, argumentIndex, query, args)` is a `Kora.callback` used for argument completion. Invalid input returns an empty list. At most `suggestionRequestsPerSecond` requests per second per player are answered. Results are capped by `suggestionResultLimit`.

## NUI callbacks

`kora_chat:ready`, `kora_chat:submit`, `kora_chat:suggest` and `kora_chat:geometry` connect the page to the client script. They are internal.
