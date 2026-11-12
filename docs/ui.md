---
title: UI
sidebar_position: 9
---

# UI

The page in `web/` (React, Vite, Tailwind) owns presentation and keyboard handling. Lua owns focus, validation and routing.

## Input

- Press the open key (default `T`). Enter sends, Escape closes.
- Up and down arrows walk through your own sent history (`historyLimit`) when no suggestion list is showing.
- PageUp and PageDown scroll the history, as does the mouse wheel while the input is open.
- Typing `/` shows matching commands (`suggestionLimit`). Tab completes the highlighted entry; the arrow keys navigate.
- Ordinary messages render as text. Compatibility templates are sanitized and allow only basic formatting tags.

## Layout

The history region has a fixed height (`historyHeight`). Placement comes from `Config.chat.position` until the player moves the box in kora_hud's `/hudlayout` or `/ui`, after which the saved offset and scale apply. The `layoutOrigin` option must match kora_hud's box origin.

## Per-player settings

With kora_hud started and `playerSettings` enabled, the `/ui` editor offers: **Fade messages after** (0 to 60 seconds, 0 means never), **Background opacity** (20 to 100) and **Show new messages while chat is closed**. Defaults come from `fadeTimeout` and `backgroundOpacity`. Without kora_hud, the server config applies.

## Theme

Colours come from `kora_theme` through its client bridge.
