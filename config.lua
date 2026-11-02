Config = Config or {}

Config.chat = {
    defaultKey = 'T',
    localRange = 20.0,
    maxMessageLength = 400,
    minimumMessageInterval = 500,
    messageLimit = 200,
    historyLimit = 50,
    fadeTimeout = 8000,
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
    overheadDuration = 5000,
    overheadLimitPerPlayer = 3,
    suggestionLimit = 8,
    suggestionResultLimit = 20,
    suggestionDebounce = 125,
    suggestionRequestsPerSecond = 10,
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
