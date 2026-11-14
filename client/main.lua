local inputOpen = false
local nuiReady = false
local pendingOpen = false
local overhead = {}
local overheadThreadRunning = false
local removedSuggestions = {}
local inputLayout = { x = 0, y = 0, scale = 1 }
local LOGIN_STATE = 'kora_core:loggedIn'
-- This is replicated by kora_core and survives a kora_chat restart, unlike the
-- legacy load/unload events.  A missing state means character select/loading,
-- where chat must remain unavailable.
local chatEnabled = LocalPlayer and LocalPlayer.state[LOGIN_STATE] == true or false

if SetTextChatEnabled then SetTextChatEnabled(false) end

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

-- The HUD owns the persisted layout because /hudlayout is its editor, while
-- this resource owns the composer that consumes this layout. Clamp again
-- at this boundary: local events are an integration surface, not trusted UI
-- input, and invalid CSS values must never reach the browser.
local function setInputLayout(layout)
    if type(layout) ~= 'table' then
        inputLayout = { x = 0, y = 0, scale = 1 }
    else
        local x, y, scale = tonumber(layout.x), tonumber(layout.y), tonumber(layout.scale)
        if not x or x ~= x or not y or y ~= y then
            inputLayout = { x = 0, y = 0, scale = 1 }
        else
            inputLayout = {
                x = math.max(-0.95, math.min(0.95, x)),
                y = math.max(-0.95, math.min(0.95, y)),
                -- Layouts saved before chat scaling had no scale key. Keep
                -- those players at the shipped size rather than treating
                -- their otherwise-valid layout as malformed.
                scale = scale and scale == scale and math.max(0.75, math.min(1.50, scale)) or 1,
            }
        end
    end

    if nuiReady then send('kora_chat:inputOffset', inputLayout) end
end

AddEventHandler('kora_chat:setInputLayout', setInputLayout)

local editing = false

local function loadHudInputLayout()
    if type(GetResourceState) ~= 'function' or GetResourceState('kora_hud') ~= 'started' then return end
    local ok, layout = pcall(function() return exports['kora_hud']:getLayout() end)
    if ok and type(layout) == 'table' then
        local offset = layout.offsets and layout.offsets.chatInput or {}
        setInputLayout({ x = offset.x or 0, y = offset.y or 0, scale = layout.scales and layout.scales.chatInput })
    end
end

-- Per-player chat preferences from kora_hud's /ui editor. The defaults are the
-- server config, so a player who never opens /ui (or a server without
-- kora_hud) sees exactly Config.chat. Re-clamped at this boundary like the
-- layout above.
local function defaultFadeSeconds()
    local ms = tonumber(Config.chat.fadeTimeout) or 8000
    return math.max(0, math.min(60, math.floor(ms / 1000 + 0.5)))
end

local function defaultOpacity()
    local value = tonumber(Config.chat.backgroundOpacity) or 94
    return math.max(20, math.min(100, math.floor(value + 0.5)))
end

local prefs = { fadeSeconds = defaultFadeSeconds(), opacity = defaultOpacity(), feedWhenClosed = true }

local function setPrefs(settings)
    settings = type(settings) == 'table' and settings or {}
    local fade = tonumber(settings.fadeSeconds)
    local opacity = tonumber(settings.opacity)
    prefs = {
        fadeSeconds = fade and fade == fade and math.max(0, math.min(60, math.floor(fade + 0.5))) or defaultFadeSeconds(),
        opacity = opacity and opacity == opacity and math.max(20, math.min(100, math.floor(opacity + 0.5))) or defaultOpacity(),
        feedWhenClosed = settings.feedWhenClosed ~= false,
    }
    if nuiReady then send('kora_chat:prefs', prefs) end
end

-- Registration with the /ui editor (kora_hud). Optional: without kora_hud, or
-- with Config.chat.playerSettings = false, the chat behaves as configured and
-- the legacy getLayout / kora_chat:setInputLayout path above still applies.
local UI_ID = 'chatInput'
-- The editor box is the input at layoutOrigin, in the shared 1920x1080 root
-- space. The page measures the real box and default spot once it is ready
-- (kora_chat:geometry below); this estimate only covers the first moment.
local function estimatedGeometry()
    local origin = type(Config.chat.layoutOrigin) == 'table' and Config.chat.layoutOrigin or {}
    local position = type(Config.chat.position) == 'table' and Config.chat.position or {}
    local ox, oy = tonumber(origin.x) or 16, tonumber(origin.y) or 16
    local px, py = tonumber(position.x) or 16, tonumber(position.y) or 40
    local history = (tonumber(Config.chat.historyHeight) or tonumber(Config.chat.openHistoryHeight) or 32) / 100 * 1080
    local top = position.anchor == 'bottom' and (1080 - py - 48) or (py + math.min(history, 1080 - py - 48 - 6 - 8) + 6)
    return {
        rect = { x = ox / 1920, y = oy / 1080, w = 480 / 1920, h = 48 / 1080 },
        defaultOffset = { x = (px - ox) / 1920, y = (top - oy) / 1080 },
    }
end
local measured

local function uiEditorWanted()
    return Config.chat.playerSettings ~= false
        and type(GetResourceState) == 'function' and GetResourceState('kora_hud') == 'started'
end

local function registerWithEditor()
    if not uiEditorWanted() then return end
    local geometry = measured or estimatedGeometry()
    pcall(function()
        exports['kora_hud']:registerUiElement({
            id = UI_ID,
            label = Kora.lang('ui.chat'),
            group = Kora.lang('ui.chat'),
            rect = geometry.rect,
            defaultOffset = geometry.defaultOffset,
            origin = 'left top',
            movable = true,
            scalable = true,
            hideable = false,
            scaleMin = 0.75,
            scaleMax = 1.5,
            settings = {
                { key = 'fadeSeconds', label = Kora.lang('ui.fade_messages_after'), type = 'range', min = 0, max = 60, step = 1,
                  default = defaultFadeSeconds(), unit = 's', zeroLabel = Kora.lang('ui.never'),
                  description = Kora.lang('ui.fade_messages_description') },
                { key = 'opacity', label = Kora.lang('ui.background_opacity'), type = 'range', min = 20, max = 100, step = 5,
                  default = defaultOpacity(), unit = '%' },
                { key = 'feedWhenClosed', label = Kora.lang('ui.show_messages_when_closed'), type = 'toggle', default = true },
            },
        })
    end)
end

-- kora_hud tells us where the chat goes: right after registering, while the
-- player drags it in /ui (preview), on Save/Cancel and on reset.
AddEventHandler('kora_hud:ui:apply', function(owner, id, layout)
    if owner ~= GetCurrentResourceName() or id ~= UI_ID or type(layout) ~= 'table' then return end
    setInputLayout({ x = layout.x, y = layout.y, scale = layout.scale })
    setPrefs(layout.settings)
end)

AddEventHandler('kora_hud:ui:ready', registerWithEditor)

local function cleanInput(value)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('[%z\1-\8\11\12\14-\31]', ''):match('^%s*(.-)%s*$')
    if value == '' then return nil end

    local length = utf8.len(value)
    if not length then return nil end
    if length <= Config.chat.maxMessageLength then return value, false end

    local offset = utf8.offset(value, Config.chat.maxMessageLength + 1)
    return offset and value:sub(1, offset - 1) or value, true
end

local function warnPlayer(kind)
    local warnings = Config.chatWarnings
    local text = warnings.enabled and warnings[kind]
    if type(text) ~= 'string' or text == '' then return end
    Kora.notify.send({
        title = warnings.title,
        message = text:format(Config.chat.maxMessageLength),
        type = 'error',
    })
end

local function closeInput()
    inputOpen = false
    SetNuiFocus(false, false)
    -- Closing is intentionally idempotent. The NUI and this client can get
    -- out of sync after a focus hand-off or a restart, so a stale `false`
    -- flag must never leave the composer rendered or keyboard input captured.
    send('kora_chat:close', {})
end

local function setChatEnabled(enabled)
    chatEnabled = enabled == true
    if chatEnabled then return end

    -- Logging out must immediately release NUI focus and must not leave an
    -- attempted open queued for the next NUI-ready handshake.
    pendingOpen = false
    closeInput()
end

-- While /ui is open the HUD holds focus: close the composer and show a
-- preview of the chat block so the player can see what they are moving.
AddEventHandler('kora_hud:ui:editing', function(active)
    editing = active == true
    if editing then
        pendingOpen = false
        if inputOpen then closeInput() end
    end
    if nuiReady then send('kora_chat:editing', editing) end
end)

local function openInput()
    if not chatEnabled then return end
    if editing then return end
    if inputOpen then return end
    if IsNuiFocused and IsNuiFocused() then return end
    if not nuiReady then
        pendingOpen = true
        return
    end

    inputOpen = true
    send('kora_chat:open', {})
    SetNuiFocus(true, false)
end

-- The state bag is the authority for whether this client currently owns a
-- character.  Filter dynamically by server id: client scripts load before a
-- session has an id, so binding once to player:-1 would miss every change.
if type(AddStateBagChangeHandler) == 'function' then
    AddStateBagChangeHandler(LOGIN_STATE, nil, function(bagName, _, value)
        local serverId = PlayerId and GetPlayerServerId(PlayerId())
        if type(serverId) == 'number' and serverId > 0 and bagName == ('player:%s'):format(serverId) then
            setChatEnabled(value == true)
        end
    end)
end

-- Kora.keybind.add takes an options table; a bad call throws at file scope and
-- aborts the NUI callback registrations below.
Kora.keybind.add({
    name = 'kora_chat_open',
    description = Kora.lang('ui.open_chat'),
    defaultKey = Config.chat.defaultKey,
    onPressed = openInput,
})

local function addMessage(message)
    if type(message) == 'string' then message = { args = { message } } end
    if type(message) ~= 'table' then return end
    send('kora_chat:message', message)
end

local function addSuggestion(name, help, params)
    if type(name) ~= 'string' then return end
    local key = name:sub(1, 1) == '/' and name or ('/' .. name)
    removedSuggestions[key:lower()] = nil
    send('kora_chat:suggestionAdd', { name = name, help = help or '', params = params or {} })
end

exports('addMessage', addMessage)
exports('addSuggestion', addSuggestion)
Kora.compat.provideExport('chat', 'addMessage', addMessage)
Kora.compat.provideExport('chat', 'addSuggestion', addSuggestion)

RegisterNetEvent('chatMessage', function(author, color, text)
    local args = author and author ~= '' and { author, text } or { text }
    addMessage({ args = args, color = color, multiline = true })
end)

RegisterNetEvent('chat:addMessage', addMessage)
RegisterNetEvent('chat:addSuggestion', addSuggestion)
RegisterNetEvent('chat:addSuggestions', function(suggestions)
    if type(suggestions) ~= 'table' then return end
    for _, suggestion in ipairs(suggestions) do
        addSuggestion(suggestion.name, suggestion.help, suggestion.params)
    end
end)
RegisterNetEvent('chat:removeSuggestion', function(name)
    if type(name) ~= 'string' then return end
    local key = name:sub(1, 1) == '/' and name or ('/' .. name)
    removedSuggestions[key:lower()] = true
    send('kora_chat:suggestionRemove', name)
end)
RegisterNetEvent('chat:clear', function()
    send('kora_chat:clear', {})
end)
RegisterNetEvent('chat:addTemplate', function(id, template)
    send('kora_chat:templateAdd', { id = id, template = template })
end)
RegisterNetEvent('chat:addMode', function(mode)
    send('kora_chat:typeAdd', mode)
end)
RegisterNetEvent('chat:removeMode', function(name)
    send('kora_chat:typeRemove', type(name) == 'table' and name.name or name)
end)
RegisterNetEvent('kora_chat:typeAdded', function(messageType)
    send('kora_chat:typeAdd', messageType)
end)
RegisterNetEvent('kora_chat:typeRemoved', function(name)
    send('kora_chat:typeRemove', name)
end)
RegisterNetEvent('kora_chat:types', function(types)
    send('kora_chat:types', types)
end)

--- Overhead /me text: the "* " only when Config.chat.showActionAsterisk is on, the author
--- name only when Config.chat.showActionAuthor is on.
local function overheadText(entry)
    local text = entry.message
    if Config.chat.showActionAuthor ~= false then text = ('%s %s'):format(entry.author, text) end
    if Config.chat.showActionAsterisk == true then text = '* ' .. text end
    return text
end

local OVERHEAD_FONT, OVERHEAD_SCALE = 4, 0.31
local overheadStyle, overheadStyleAt

--- A kora_theme colour key or '#RRGGBB' string as r, g, b; nil when unusable.
local function overheadColour(setting, palette)
    if type(setting) ~= 'string' then return nil end
    local hex = palette[setting] or setting
    local r, g, b = hex:match('^#(%x%x)(%x%x)(%x%x)$')
    if not r then return nil end
    return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
end

--- Themed bubble colours, re-read every couple of seconds so /theme changes apply. nil when
--- neither Config.chat.overheadThemed nor a coloured author name is wanted, or kora_theme is
--- unavailable (plain text3d is used then). Without overheadThemed only the name is coloured.
local function getOverheadStyle(now)
    local themed = Config.chat.overheadThemed == true
    if not themed and not (Config.chat.overheadColourName ~= false and Config.chat.showActionAuthor ~= false) then return nil end
    if overheadStyleAt and now - overheadStyleAt < 2000 then return overheadStyle end
    overheadStyleAt = now
    overheadStyle = nil

    local ok, palette = pcall(function()
        return exports.kora_theme:getColours(exports.kora_theme:getPlayerTheme())
    end)
    if not ok or type(palette) ~= 'table' then return nil end

    local style = {}
    style.nameR, style.nameG, style.nameB = overheadColour(Config.chat.overheadNameColour, palette)
    style.textR, style.textG, style.textB = overheadColour(Config.chat.overheadTextColour, palette)
    if themed then style.bgR, style.bgG, style.bgB = overheadColour(Config.chat.overheadBackground, palette) end
    if not themed then style.textR, style.textG, style.textB = nil, nil, nil end
    if not style.nameR then style.nameR, style.nameG, style.nameB = 255, 255, 255 end
    if not style.textR then style.textR, style.textG, style.textB = 255, 255, 255 end
    style.bgA = math.max(0, math.min(255, math.floor(tonumber(Config.chat.overheadBackgroundAlpha) or 170)))
    overheadStyle = style
    return style
end

local function overheadWidth(text)
    SetTextFont(OVERHEAD_FONT)
    SetTextScale(OVERHEAD_SCALE, OVERHEAD_SCALE)
    BeginTextCommandGetWidth('STRING')
    AddTextComponentSubstringPlayerName(text)
    return EndTextCommandGetWidth(true)
end

local function overheadSegment(x, y, text, r, g, b)
    SetTextFont(OVERHEAD_FONT)
    SetTextScale(OVERHEAD_SCALE, OVERHEAD_SCALE)
    SetTextProportional(true)
    SetTextColour(r, g, b, 235)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

--- Themed variant of the overhead draw: optional coloured name, themed text and an optional
--- background box, anchored to the same world position as the plain text3d bubble.
local function drawThemedOverhead(position, entry, style)
    local origin = GetEntityCoords(PlayerPedId())
    if #(origin - vector3(position.x, position.y, position.z)) > Config.chat.localRange then return end
    local onScreen, screenX, screenY = World3dToScreen2d(position.x, position.y, position.z)
    if not onScreen then return end

    local name = Config.chat.showActionAuthor ~= false and entry.author or ''
    local body = Config.chat.showActionAsterisk == true and ('* ' .. entry.message) or entry.message
    local gap = name ~= '' and overheadWidth(' ') or 0
    local nameWidth = name ~= '' and overheadWidth(name) or 0
    local total = nameWidth + gap + overheadWidth(body)
    local height = GetRenderedCharacterHeight(OVERHEAD_SCALE, OVERHEAD_FONT)

    if style.bgR and style.bgA > 0 then
        DrawRect(screenX, screenY, total + 0.008, height + 0.006, style.bgR, style.bgG, style.bgB, style.bgA)
    end

    local left, top = screenX - total / 2, screenY - height / 2
    if name ~= '' then overheadSegment(left, top, name, style.nameR, style.nameG, style.nameB) end
    overheadSegment(left + nameWidth + gap, top, body, style.textR, style.textG, style.textB)
end

local function startOverheadThread()
    if overheadThreadRunning then return end
    overheadThreadRunning = true

    CreateThread(function()
        while next(overhead) do
            local now = GetGameTimer()
            for serverId, messages in pairs(overhead) do
                for index = #messages, 1, -1 do
                    if messages[index].expiresAt <= now then table.remove(messages, index) end
                end

                if #messages == 0 then
                    overhead[serverId] = nil
                else
                    local player = GetPlayerFromServerId(serverId)
                    if player ~= -1 then
                        local ped = GetPlayerPed(player)
                        if ped and ped ~= 0 and DoesEntityExist(ped) then
                            local coords = GetEntityCoords(ped)
                            local style = getOverheadStyle(now)
                            for index, entry in ipairs(messages) do
                                local position = {
                                    x = coords.x,
                                    y = coords.y,
                                    z = coords.z + 1.05 + ((index - 1) * 0.16),
                                }
                                if style then
                                    drawThemedOverhead(position, entry, style)
                                else
                                    Kora.drawing.text3d(position, overheadText(entry), {
                                        maxDistance = Config.chat.localRange,
                                        scale = OVERHEAD_SCALE,
                                    })
                                end
                            end
                        end
                    end
                end
            end
            if next(overhead) then Wait(0) end
        end

        overheadThreadRunning = false
    end)
end

RegisterNetEvent('kora_chat:message', function(payload)
    if type(payload) ~= 'table' then return end
    addMessage(payload)

    if payload.overhead and type(payload.source) == 'number' and type(payload.message) == 'string' then
        local entries = overhead[payload.source] or {}
        overhead[payload.source] = entries
        while #entries >= Config.chat.overheadLimitPerPlayer do table.remove(entries, 1) end
        entries[#entries + 1] = {
            author = tostring(payload.author or ''),
            message = payload.message,
            expiresAt = GetGameTimer() + (tonumber(payload.overheadDuration) or Config.chat.overheadDuration),
        }
        startOverheadThread()
    end
end)

local function refreshNativeCommands()
    if not GetRegisteredCommands then return end
    local suggestions = {}
    for _, command in ipairs(GetRegisteredCommands()) do
        local name = command.name
        local suggestionName = type(name) == 'string' and ('/' .. name) or nil
        if type(name) == 'string' and name ~= '' and name:sub(1, 1) ~= '+' and name:sub(1, 1) ~= '-'
            and name ~= 'kora_chat_open' and not removedSuggestions[suggestionName:lower()]
            and IsAceAllowed(('command.%s'):format(name)) then
            suggestions[#suggestions + 1] = { name = suggestionName, help = '', params = {} }
        end
    end
    send('kora_chat:suggestions', suggestions)
end

local function clearChatCommandName()
    local settings = Config.clearChat
    if type(settings) ~= 'table' or settings.enabled ~= true then return nil end
    local name = type(settings.command) == 'string' and settings.command:gsub('^/+', '') or 'clearchat'
    return name:match('^[%w_:%.%-]+$') and name or 'clearchat'
end

local clearChatName = clearChatCommandName()
if clearChatName then
    RegisterCommand(clearChatName, function()
        send('kora_chat:clearMessages', {})
    end, false)
end

RegisterNUICallback('kora_chat:ready', function(_, cb)
    nuiReady = true
    cb({ ok = true })

    KoraTheme.refresh()
    -- The input caps text at maxMessageLength; allow one extra character so an
    -- over-limit message reaches kora_chat:submit and is rejected/warned instead of
    -- being silently cut in the UI.
    local uiConfig = {}
    for key, value in pairs(Config.chat) do uiConfig[key] = value end
    uiConfig.maxMessageLength = Config.chat.maxMessageLength + 1
    send('kora_chat:init', {
        config = uiConfig,
    })
    loadHudInputLayout()
    send('kora_chat:inputOffset', inputLayout)
    send('kora_chat:prefs', prefs)
    send('kora_chat:editing', editing)
    registerWithEditor()
    refreshNativeCommands()
    if clearChatName then addSuggestion(clearChatName, 'Clear your own chat history', {}) end
    TriggerServerEvent('chat:init')

    if pendingOpen then
        pendingOpen = false
        openInput()
    end
end)

RegisterNUICallback('kora_chat:submit', function(data, cb)
    closeInput()
    cb({ ok = true })
    if not chatEnabled then return end
    if type(data) ~= 'table' or data.cancelled == true or type(data.message) ~= 'string' then return end

    local message, truncated = cleanInput(data.message)
    if not message then return end
    if truncated then
        if Config.chatWarnings.overLimitAction == 'reject' then return warnPlayer('tooLong') end
        warnPlayer('truncated')
    end
    if message:sub(1, 1) == '/' then
        local command = message:sub(2)
        if command ~= '' then ExecuteCommand(command) end
    else
        TriggerServerEvent('kora_chat:send', message)
    end
end)

RegisterNUICallback('kora_chat:suggest', function(data, cb)
    if not chatEnabled then cb({}); return end
    if type(data) ~= 'table' then cb({}); return end
    local result = Kora.callback.trigger(
        'kora_chat:commandSuggestions',
        data.command,
        data.argumentIndex,
        data.query,
        data.args
    )
    cb(type(result) == 'table' and result or {})
end)

-- The page measured the real composer box and its unplaced spot (viewport
-- fractions), so the /ui editor box sits exactly on the chat at this
-- resolution. Sent on ready and after a resize; capped to 2 per second.
local lastGeometryAt = 0
RegisterNUICallback('kora_chat:geometry', function(data, cb)
    cb({ ok = true })
    if type(data) ~= 'table' or type(data.rect) ~= 'table' or type(data.defaultOffset) ~= 'table' then return end
    local now = GetGameTimer()
    if now - lastGeometryAt < 500 then return end
    lastGeometryAt = now
    local function fraction(value, min, max)
        value = tonumber(value)
        if not value or value ~= value then return nil end
        return math.max(min, math.min(max, value))
    end
    local rect = {
        x = fraction(data.rect.x, 0, 1), y = fraction(data.rect.y, 0, 1),
        w = fraction(data.rect.w, 0.01, 1), h = fraction(data.rect.h, 0.01, 1),
    }
    local offset = { x = fraction(data.defaultOffset.x, -1, 1), y = fraction(data.defaultOffset.y, -1, 1) }
    if not (rect.x and rect.y and rect.w and rect.h and offset.x and offset.y) then return end
    measured = { rect = rect, defaultOffset = offset }
    if uiEditorWanted() then
        pcall(function() exports['kora_hud']:updateUiElement(UI_ID, measured) end)
    end
end)

AddEventHandler('onClientResourceStart', function(resource)
    SetTimeout(500, refreshNativeCommands)
    -- kora_hud started after us: register (kora_hud:ui:ready also covers it).
    if resource == 'kora_hud' then SetTimeout(250, registerWithEditor) end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        closeInput()
        pendingOpen = false
        if SetTextChatEnabled then SetTextChatEnabled(true) end
    else
        SetTimeout(500, refreshNativeCommands)
    end
end)
