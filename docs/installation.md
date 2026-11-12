---
title: "Installation"
sidebar_position: 2
---


# Installation

Kora Chat is an event-driven, React-NUI chat replacement built on Kora Lib: proximity in-character chat, `/me` with an overhead bubble, a global `/ooc`, command argument autocomplete, and the stock `chat` event/export surface. It provides the `chat` resource identity, so the stock `chat` resource must not also run.

## Install Kora Chat

1. **Add the folder** — Place `kora_chat` in your resources directory (on the Kora dev server: `resources/[standalone]/kora_chat`). Keep the folder name unchanged.

2. **Start it after its dependencies** — Kora Chat declares `dependency 'kora_theme'`, `dependency 'kora_lib'` and `dependency 'kora_core'`, so FXServer starts those first. Do not also `ensure` the stock `chat` resource: Kora Chat already `provide`s that identity.

   ```bash title="server.cfg"
   ensure kora_theme
   ensure kora_lib
   ensure kora_core
   ensure kora_chat
   ```

3. **What the manifest sets up** — The highlighted lines load the kora_theme NUI bridge on the client and ship the built React frontend (`web/build`) as the `ui_page`. Nothing else needs to be added for a resource to just use the chat.

   ```lua title="fxmanifest.lua" {16,21}
   fx_version 'cerulean'
   game 'gta5'
   lua54 'yes'

   name 'kora_chat'
   provide 'chat'

   dependency 'kora_theme'
   dependency 'kora_lib'
   dependency 'kora_core'

   shared_script '@kora_lib/init.lua'
   shared_script 'config.lua'

   client_scripts {
       '@kora_theme/client/bridge.lua',
       'client/main.lua',
   }
   server_script 'server/main.lua'

   ui_page 'web/build/index.html'

   files {
       'web/build/index.html',
       'web/build/assets/**/*'
   }
   ```

## Dependencies in detail

`fxmanifest.lua` declares `dependency` on `kora_theme`, `kora_lib` and `kora_core`:

- `kora_lib` - loaded via `@kora_lib/init.lua` as a shared script. Provides commands, callbacks, keybinds, notifications, timers, drawing and compatibility helpers.
- `kora_core` - the server calls `exports.kora_core:hasPermission` for message type permissions and `exports.kora_core:getPlayerData(source, { 'name' })` for character names. The client reads the `kora_core:loggedIn` state bag.
- `kora_theme` - its client bridge (`@kora_theme/client/bridge.lua`) is loaded and the `/me` bubble colours use `exports.kora_theme:getColours` and `getPlayerTheme`.
- `kora_hud` - optional and not declared. Used when started; see [UI](./ui.md).

The manifest excerpt above is abbreviated: the real `fxmanifest.lua` also sets `author`, `version` and `description` and a `qa_feature` test entry. The release version is the `version` field of `fxmanifest.lua`.

## Next steps

Adjust [Configuration](./api/configuration.md) and restart `kora_chat`.

## Building the page

The built page in `web/build` is committed, so no build step is needed to run the resource. The source is in `web/`. From that folder run `pnpm typecheck`, `pnpm test` and `pnpm build`. `web/build` is committed and must not be edited by hand.
