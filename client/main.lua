local inputOpen = false
local nuiReady = false
local pendingOpen = false
local overhead = {}
local overheadThreadRunning = false
local removedSuggestions = {}
local inputLayout = { x = 0, y = 0, scale = 1 }
local LOGIN_STATE = 'qbcore:loggedIn'
-- This is replicated by qbcore and survives a qbchat restart, unlike the
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

    if nuiReady then send('qbchat:inputOffset', inputLayout) end
end

AddEventHandler('qbchat:setInputLayout', setInputLayout)

local function loadHudInputLayout()
    if type(GetResourceState) ~= 'function' or GetResourceState('qbhud') ~= 'started' then return end
    local ok, layout = pcall(function() return exports['qbhud']:getLayout() end)
    if ok and type(layout) == 'table' then
        local offset = layout.offsets and layout.offsets.chatInput or {}
        setInputLayout({ x = offset.x or 0, y = offset.y or 0, scale = layout.scales and layout.scales.chatInput })
    end
end

local function cleanInput(value)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('[%z\1-\8\11\12\14-\31]', ''):match('^%s*(.-)%s*$')
    if value == '' then return nil end

    local ok, length = pcall(utf8.len, value)
    if not ok or not length then return nil end
    if length <= Config.chat.maxMessageLength then return value end

    local offset = utf8.offset(value, Config.chat.maxMessageLength + 1)
    return offset and value:sub(1, offset - 1) or value
end

local function closeInput()
    inputOpen = false
    SetNuiFocus(false, false)
    -- Closing is intentionally idempotent. The NUI and this client can get
    -- out of sync after a focus hand-off or a restart, so a stale `false`
    -- flag must never leave the composer rendered or keyboard input captured.
    send('qbchat:close', {})
end

local function setChatEnabled(enabled)
    chatEnabled = enabled == true
    if chatEnabled then return end

    -- Logging out must immediately release NUI focus and must not leave an
    -- attempted open queued for the next NUI-ready handshake.
    pendingOpen = false
    closeInput()
end

local function openInput()
    if not chatEnabled then return end
    if inputOpen then return end
    if IsNuiFocused and IsNuiFocused() then return end
    if not nuiReady then
        pendingOpen = true
        return
    end

    inputOpen = true
    send('qbchat:open', {})
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

-- QB.keybind.add takes a single OPTIONS TABLE, not positional arguments. The
-- positional form asserted inside qblib, and because this is file scope the
-- throw aborted the rest of this chunk -- so RegisterNUICallback('qbchat:ready')
-- below never ran and the NUI's ready ping 404'd, which is what actually broke
-- chat rather than the keybind alone.
QB.keybind.add({
    name = 'qbchat_open',
    description = 'Open chat',
    defaultKey = Config.chat.defaultKey,
    onPressed = openInput,
})

local function addMessage(message)
    if type(message) == 'string' then message = { args = { message } } end
    if type(message) ~= 'table' then return end
    send('qbchat:message', message)
end

local function addSuggestion(name, help, params)
    if type(name) ~= 'string' then return end
    local key = name:sub(1, 1) == '/' and name or ('/' .. name)
    removedSuggestions[key:lower()] = nil
    send('qbchat:suggestionAdd', { name = name, help = help or '', params = params or {} })
end

exports('addMessage', addMessage)
exports('addSuggestion', addSuggestion)
QB.compat.provideExport('chat', 'addMessage', addMessage)
QB.compat.provideExport('chat', 'addSuggestion', addSuggestion)

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
    send('qbchat:suggestionRemove', name)
end)
RegisterNetEvent('chat:clear', function()
    send('qbchat:clear', {})
end)
RegisterNetEvent('chat:addTemplate', function(id, template)
    send('qbchat:templateAdd', { id = id, template = template })
end)
RegisterNetEvent('chat:addMode', function(mode)
    send('qbchat:typeAdd', mode)
end)
RegisterNetEvent('chat:removeMode', function(name)
    send('qbchat:typeRemove', type(name) == 'table' and name.name or name)
end)
RegisterNetEvent('qbchat:typeAdded', function(messageType)
    send('qbchat:typeAdd', messageType)
end)
RegisterNetEvent('qbchat:typeRemoved', function(name)
    send('qbchat:typeRemove', name)
end)
RegisterNetEvent('qbchat:types', function(types)
    send('qbchat:types', types)
end)

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
                            for index, entry in ipairs(messages) do
                                QB.drawing.text3d({
                                    x = coords.x,
                                    y = coords.y,
                                    z = coords.z + 1.05 + ((index - 1) * 0.16),
                                }, ('* %s %s'):format(entry.author, entry.message), {
                                    maxDistance = Config.chat.localRange,
                                    scale = 0.31,
                                })
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

RegisterNetEvent('qbchat:message', function(payload)
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
            and name ~= 'qbchat_open' and not removedSuggestions[suggestionName:lower()]
            and IsAceAllowed(('command.%s'):format(name)) then
            suggestions[#suggestions + 1] = { name = suggestionName, help = '', params = {} }
        end
    end
    send('qbchat:suggestions', suggestions)
end

RegisterNUICallback('qbchat:ready', function(_, cb)
    nuiReady = true
    cb({ ok = true })

    QBTheme.refresh()
    send('qbchat:init', {
        config = Config.chat,
    })
    loadHudInputLayout()
    send('qbchat:inputOffset', inputLayout)
    refreshNativeCommands()
    TriggerServerEvent('chat:init')

    if pendingOpen then
        pendingOpen = false
        openInput()
    end
end)

RegisterNUICallback('qbchat:submit', function(data, cb)
    closeInput()
    cb({ ok = true })
    if not chatEnabled then return end
    if type(data) ~= 'table' or data.cancelled == true or type(data.message) ~= 'string' then return end

    local message = cleanInput(data.message)
    if not message then return end
    if message:sub(1, 1) == '/' then
        local command = message:sub(2)
        if command ~= '' then ExecuteCommand(command) end
    else
        TriggerServerEvent('qbchat:send', message)
    end
end)

RegisterNUICallback('qbchat:suggest', function(data, cb)
    if not chatEnabled then cb({}); return end
    if type(data) ~= 'table' then cb({}); return end
    local result = QB.callback.trigger(
        'qbchat:commandSuggestions',
        data.command,
        data.argumentIndex,
        data.query,
        data.args
    )
    cb(type(result) == 'table' and result or {})
end)

AddEventHandler('onClientResourceStart', function()
    SetTimeout(500, refreshNativeCommands)
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
