Config = Config or {}

Config.chat = {
    defaultKey = 'T',
    localRange = 20.0,
    maxMessageLength = 400,
    minimumMessageInterval = 500,
    messageLimit = 200,
    historyLimit = 50,
    -- ms after which a message fades out while the input is closed. It is the
    -- default of the per-player "Fade messages after" setting in /ui (kora_hud);
    -- 0 keeps messages on screen.
    fadeTimeout = 8000,
    -- 'message': each message fades out on its own fadeTimeout after it arrived
    -- (smooth, fadeDuration ms). 'feed': the previous behaviour, the whole feed
    -- hides fadeTimeout after the last message.
    fadeMode = 'message',
    fadeDuration = 600,
    -- Default background opacity (20-100 %) of message rows and the input; each
    -- player can change it in /ui.
    backgroundOpacity = 94,
    -- Register the chat with kora_hud's /ui editor (position, size and the
    -- settings above, per player). false = only the server config applies.
    playerSettings = true,
    -- Height of the chat history region, in percent of the screen height (10-90).
    -- The region has this fixed size whether or not it holds messages, so neither it nor the
    -- input moves as messages arrive. It shrinks only if the screen has less room than this
    -- next to the input. Older messages scroll with the mouse wheel / PageUp / PageDown while
    -- the input is open. The older openHistoryHeight key is still honoured when historyHeight
    -- is unset.
    historyHeight = 32,
    -- Where the history sits relative to the input: 'above' (newest message right above the
    -- input), 'below', or 'auto' (above when there is room for historyHeight, otherwise below,
    -- e.g. when the input is placed at the top of the screen with /hudlayout).
    historyPlacement = 'auto',
    -- Default placement in pixels, used while the player has no /hudlayout chat placement (never
    -- moved, or reset). anchor = 'top' measures y from the top edge to the top of the history
    -- region (the input sits historyHeight below it); 'bottom' measures y from the bottom edge
    -- of the screen to the bottom of the input.
    position = { anchor = 'top', x = 16, y = 40 },
    -- Zero point of kora_hud's /hudlayout "Chat input" box, in pixels from the top-left of the
    -- screen at 1080p. A saved placement puts the input exactly where that box was dropped;
    -- change this only if the kora_hud proxy's default corner is changed.
    layoutOrigin = { x = 16, y = 16 },
    -- Whether /me action messages are prefixed with the author name, both in the chat UI
    -- ("* Alex Mercer waves" vs "* waves") and in the overhead world text. The name is
    -- coloured with kora_theme's primary colour when shown. Off by default.
    showActionAuthor = false,
    -- Whether /me action messages start with "* " in the chat UI and the overhead world text.
    -- Off by default ("waves"); true restores "* waves".
    showActionAsterisk = false,
    -- Notify text when a chat command such as /me or /ooc is sent without a message
    -- (%s = command name). false restores kora_lib's generic "Missing arguments for /%s".
    missingMessageText = 'Missing message for /%s',
    -- How long (ms) a /me bubble stays above the player's head (1-30000). Bubbles are only
    -- drawn for players within localRange.
    overheadDuration = 5000,
    -- Colour the /me bubble from kora_theme instead of the default white text. Off by default
    -- because it changes how the bubble looks for every player. The text colour, background and
    -- opacity options below only apply while this is true.
    overheadThemed = false,
    -- Author name colour (only drawn when showActionAuthor is on) and bubble text colour: a
    -- kora_theme colour key (primary, foreground, success, warning, danger, info, ...) or a
    -- '#RRGGBB' string. 'primary' follows the player's own /theme choice.
    overheadNameColour = 'primary',
    -- Colour the author name with overheadNameColour whenever showActionAuthor is on, even if
    -- overheadThemed is off (the rest of the bubble stays plain white text).
    overheadColourName = true,
    overheadTextColour = 'foreground',
    -- Bubble background: a kora_theme colour key or '#RRGGBB', or false for no background.
    overheadBackground = 'background',
    -- Background opacity, 0-255.
    overheadBackgroundAlpha = 170,
    overheadLimitPerPlayer = 3,
    suggestionLimit = 8,
    suggestionResultLimit = 20,
    suggestionDebounce = 125,
    suggestionRequestsPerSecond = 10,
}

-- On-screen warnings (kora_lib notify) when a message is rejected or shortened.
--   enabled           show the warnings at all.
--   overLimitAction   what to do with a message longer than Config.chat.maxMessageLength:
--                     'reject' (do not send it, tell the player) or 'truncate' (send the
--                     first maxMessageLength characters and tell the player).
--   interval          minimum ms between two warnings to the same player, so spamming does
--                     not also spam notifications.
--   title/tooLong/truncated/rateLimited   texts shown; set a text to '' to silence that case.
Config.chatWarnings = {
    enabled = true,
    overLimitAction = 'reject',
    interval = 1500,
    title = 'Chat',
    tooLong = 'Your message is too long (max %d characters) and was not sent.',
    truncated = 'Your message was longer than %d characters and was shortened.',
    rateLimited = 'You are sending messages too quickly. Slow down.',
}

-- Local /clearchat command: wipes only the player own chat feed on their client.
-- command is the name without the slash.
Config.clearChat = { enabled = true, command = 'clearchat' }

-- Additional declarative types use the same schema as the
-- registerMessageType server export. Built-ins (say, me, ooc) are registered
-- by server/main.lua so their behavior cannot drift from the documented API.
Config.messageTypes = {}

-- Registers this resource-owned configuration with kora_lib without changing its public Config table.
if Kora and Kora.config and Kora.config.adopt then
    Config.messageTypes = Kora.config.map({}, Kora.config.object({}), {
        label = 'Message types',
        description = 'Defines custom chat message types by command name. Each key becomes the command identifier and its value supplies the authored presentation data used when that message type is registered.',
    })
    Config = Kora.config.adopt(Config)
end
