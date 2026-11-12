# kora_chat agent guide

## Architecture

kora_chat replaces the stock `chat` resource while continuing to provide its
identity, common exports, and event surface. Lua owns input focus, validation,
routing, compatibility, and `/me` world text; React owns presentation and
keyboard autocomplete.

The resource owns its own NUI frame. Use raw `SendNUIMessage`,
`RegisterNUICallback`, and `SetNuiFocus` here; `Kora.nui.*` targets kora_lib's frame.
Pure kora_lib APIs such as `Kora.keybind`, `Kora.commands`, `Kora.callback`,
`Kora.distance` and `Kora.drawing` remain appropriate. Theme transport comes from
the imported kora_theme bridge.

## Input and loops

The T binding must stay a `Kora.keybind.add` registration. Never add a permanent
control-polling thread. The only per-frame loop is activity-bound `/me` drawing
and must exit as soon as the final overhead message expires.

## Security

All player-authored messages are validated, truncated, rate-limited, named,
and routed on the server. The frontend renders ordinary messages as React text.
Compatibility templates pass through the restricted sanitizer and must never
enable scripts, remote styles, event handlers, or arbitrary inline CSS.

## Testing and build

Run `test/run.sh` for Lua smoke coverage. The frontend is built with
`pnpm typecheck`, `pnpm test`, and `pnpm build`; `web/build` is committed and
must never be edited by hand.

## Documentation

User-facing documentation lives in `docs/` (Markdown, published via the Kora Docusaurus site, kora_docs_next). Read `docs/index.md` first for an overview of features, configuration, commands, exports, events and message types.

When you add, change, or remove a feature, config option, command, export, event, item, permission, or database table/column, update the matching page in `docs/` in the same change. Keep docs accurate to the code; do not document behaviour that does not exist.

Docs rules: plain Markdown with `title`/`sidebar_position` front matter (no `id`/`slug`), relative links only between docs pages, assets inside `docs/`, fenced code blocks with a language, and no raw `<`, `>`, `{`, `}` outside code (pages are parsed as MDX). The release version comes from `fxmanifest.lua`'s `version` field.
