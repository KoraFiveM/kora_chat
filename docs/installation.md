---
title: Installation
sidebar_position: 3
---

# Installation

## Dependencies

`fxmanifest.lua` declares `dependency` on `kora_theme`, `kora_lib` and `kora_core`:

- `kora_lib` - loaded via `@kora_lib/init.lua` as a shared script. Provides commands, callbacks, keybinds, notifications, timers, drawing and compatibility helpers.
- `kora_core` - the server calls `exports.kora_core:hasPermission` for message type permissions and `exports.kora_core:getPlayerData(source, { 'name' })` for character names. The client reads the `kora_core:loggedIn` state bag.
- `kora_theme` - its client bridge (`@kora_theme/client/bridge.lua`) is loaded and the `/me` bubble colours use `exports.kora_theme:getColours` and `getPlayerTheme`.
- `kora_hud` - optional and not declared. Used when started; see [UI](./ui.md).

## Steps

1. Place the resource folder as `kora_chat`. The built page in `web/build` is committed, so no build step is needed to run it.
2. Do not start the stock `chat` resource. `kora_chat` provides its identity.
3. Start it after its dependencies:

```cfg
ensure kora_lib
ensure kora_core
ensure kora_chat
```

4. Adjust [Configuration](./configuration.md) and restart `kora_chat`.

## Building the page

The source is in `web/`. From that folder run `pnpm typecheck`, `pnpm test` and `pnpm build`. `web/build` is committed and must not be edited by hand.
