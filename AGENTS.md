# qbchat agent guide

## Architecture

qbchat replaces the stock `chat` resource while continuing to provide its
identity, common exports, and event surface. Lua owns input focus, validation,
routing, compatibility, and `/me` world text; React owns presentation and
keyboard autocomplete.

The resource owns its own NUI frame. Use raw `SendNUIMessage`,
`RegisterNUICallback`, and `SetNuiFocus` here; `QB.nui.*` targets qblib's frame.
Pure qblib APIs such as `QB.keybind`, `QB.commands`, `QB.callback`,
`QB.distance` and `QB.drawing` remain appropriate. Theme transport comes from
the imported qbtheme bridge.

## Input and loops

The T binding must stay a `QB.keybind.add` registration. Never add a permanent
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
