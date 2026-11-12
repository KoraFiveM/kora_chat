---
title: Troubleshooting
sidebar_position: 10
---

# Troubleshooting

- **Chat does not open** - the player must be logged in (`kora_core:loggedIn` state bag). It also does not open while the `/ui` editor is active or another NUI holds focus.
- **Two chats or missing events** - make sure the stock `chat` resource is not started.
- **Commands missing from suggestions** - suggestions only list commands the player is allowed to run (ACE `command.<name>` for native commands, kora_lib permission for Kora commands). Restarting resources refreshes the list after a short delay.
- **Message rejected as too long** - set `Config.chatWarnings.overLimitAction = 'truncate'` to shorten instead.
- **Messages dropped quietly** - the rate limit is `minimumMessageInterval` ms per player; its warning text is `Config.chatWarnings.rateLimited`.
- **Nobody sees a `/me`** - local messages reach players within `localRange` in the same routing bucket.
- **Custom type not registered** - check the server console for assertion errors (invalid name, icon, colour, command already in use, or name owned by another resource).
- **Placement wrong at a new resolution** - verify `layoutOrigin` matches kora_hud and try resetting the chat in `/ui`.
