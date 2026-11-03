local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local root = scriptDir .. '../../'
package.path = scriptDir .. '../?.lua;' .. package.path
local H = require('harness')

local netHandlers, eventHandlers, nuiCallbacks = {}, {}, {}
local stateBagHandlers = {}
local nuiMessages, focusCalls, serverEvents, executed = {}, {}, {}, {}
local keybind, clock, thread = nil, 1000, nil
local otherNuiFocused = false
local themeRefreshes = 0

_G.RegisterNetEvent = function(name, cb)
    netHandlers[name] = netHandlers[name] or {}
    if cb then netHandlers[name][#netHandlers[name] + 1] = cb end
end
_G.AddEventHandler = function(name, cb)
    eventHandlers[name] = eventHandlers[name] or {}
    eventHandlers[name][#eventHandlers[name] + 1] = cb
end
_G.SendNUIMessage = function(message) nuiMessages[#nuiMessages + 1] = message end
_G.RegisterNUICallback = function(name, cb) nuiCallbacks[name] = cb end
_G.SetNuiFocus = function(focus, cursor) focusCalls[#focusCalls + 1] = { focus, cursor } end
_G.IsNuiFocused = function() return otherNuiFocused end
_G.TriggerServerEvent = function(name, ...) serverEvents[#serverEvents + 1] = { name = name, ... } end
_G.ExecuteCommand = function(command) executed[#executed + 1] = command end
local registeredCommands = {}
_G.RegisterCommand = function(name, cb) registeredCommands[name] = cb end
_G.GetRegisteredCommands = function()
    return { { name = 'help' }, { name = '+qbchat_open' }, { name = '-qbchat_open' } }
end
_G.IsAceAllowed = function() return true end
_G.GetCurrentResourceName = function() return 'kora_chat' end
_G.PlayerId = function() return 3 end
_G.GetPlayerServerId = function() return 17 end
_G.GetGameTimer = function() return clock end
_G.SetTimeout = function(_, cb) cb() end
_G.GetPlayerFromServerId = function() return 4 end
_G.GetPlayerPed = function() return 44 end
_G.DoesEntityExist = function() return true end
_G.GetEntityCoords = function() return { x = 1, y = 2, z = 3 } end
_G.Wait = function() coroutine.yield() end
_G.CreateThread = function(fn)
    thread = coroutine.create(fn)
    local ok, err = coroutine.resume(thread)
    if not ok then error(err) end
end
_G.LocalPlayer = { state = { ['qbcore:loggedIn'] = true } }
_G.AddStateBagChangeHandler = function(key, bag, cb)
    stateBagHandlers[#stateBagHandlers + 1] = { key = key, bag = bag, callback = cb }
end

local ownExports = {}
_G.exports = setmetatable({}, { __call = function(_, name, fn) ownExports[name] = fn end })
_G.QBTheme = { refresh = function() themeRefreshes = themeRefreshes + 1 end }

local drawCalls = {}
_G.Kora = {
    compat = { provideExport = function(identity, name, fn)
        AddEventHandler(('__cfx_export_%s_%s'):format(identity, name), function(setCB) setCB(fn) end)
    end },
    -- Mirrors kora_lib's real Kora.keybind.add: one options table, same
    -- assertions as modules/keybind/client.lua.
    keybind = { add = function(options)
        assert(type(options) == 'table', 'Kora.keybind.add requires an options table.')
        assert(type(options.name) == 'string' and options.name:match('^[%w_:%.%-]+$'),
            'Keybind name must be a non-empty command name without whitespace.')
        assert(type(options.description) == 'string' and options.description ~= '',
            'Keybind description must be a non-empty string.')
        assert(options.defaultKey == nil or type(options.defaultKey) == 'string',
            'Keybind defaultKey must be a string or nil.')
        keybind = {
            name = options.name,
            label = options.description,
            key = options.defaultKey,
            handler = options.onPressed,
        }
    end },
    drawing = { text3d = function(coords, text) drawCalls[#drawCalls + 1] = { coords = coords, text = text } end },
    callback = { trigger = function() return { { value = 'water' } } end },
}

dofile(root .. 'config.lua')
dofile(root .. 'client/main.lua')

local function fire(name, ...)
    for _, cb in ipairs(netHandlers[name] or {}) do cb(...) end
    for _, cb in ipairs(eventHandlers[name] or {}) do cb(...) end
end

local function latestAction(action)
    for index = #nuiMessages, 1, -1 do
        if nuiMessages[index].action == action then return nuiMessages[index] end
    end
end

local function setLoggedIn(value)
    LocalPlayer.state['qbcore:loggedIn'] = value
    for _, handler in ipairs(stateBagHandlers) do
        if handler.key == 'qbcore:loggedIn' then
            handler.callback('player:17', 'qbcore:loggedIn', value)
        end
    end
end

H.test('T is registered through kora_lib without control polling', function()
    H.equal(keybind.name, 'qbchat_open')
    H.equal(keybind.key, 'T')
    local file = assert(io.open(root .. 'client/main.lua', 'r'))
    local sourceText = file:read('*a')
    file:close()
    H.falsy(sourceText:find('IsControlPressed', 1, true))
    H.falsy(sourceText:find('IsControlJustPressed', 1, true))
end)

H.test('ready handshake refreshes qbtheme/config and completes a pending open', function()
    keybind.handler()
    H.equal(#focusCalls, 0)
    nuiCallbacks['qbchat:ready']({}, function() end)
    H.equal(focusCalls[#focusCalls][1], true)
    H.equal(themeRefreshes, 1)
    H.falsy(latestAction('qbchat:init').data.theme)
    H.equal(latestAction('qbchat:init').data.config.historyHeight, Config.chat.historyHeight)
    H.truthy(Config.chat.historyHeight, 'history height is a documented option')
    H.equal(latestAction('qbchat:init').data.config.historyPlacement, 'auto')
    H.equal(latestAction('qbchat:init').data.config.layoutOrigin.y, 16)
    H.equal(serverEvents[#serverEvents].name, 'chat:init')
    H.equal(latestAction('qbchat:suggestions').data[1].name, '/help')
end)

H.test('chat input is enabled only while a character is logged in', function()
    nuiCallbacks['qbchat:submit']({ cancelled = true }, function() end)
    setLoggedIn(false)
    local before = #focusCalls
    keybind.handler()
    H.equal(#focusCalls, before)

    setLoggedIn(true)
    keybind.handler()
    H.equal(focusCalls[#focusCalls][1], true)

    setLoggedIn(false)
    H.equal(focusCalls[#focusCalls][1], false)
    setLoggedIn(true)
end)

H.test('logout force-closes a desynchronized composer', function()
    -- A prior NUI submit can clear Lua's state before the browser receives
    -- its close event. Logging out must still release focus and tell that
    -- stale browser frame to hide.
    nuiCallbacks['qbchat:submit']({ cancelled = true }, function() end)
    local focusBefore = #focusCalls
    setLoggedIn(false)
    H.equal(focusCalls[focusBefore + 1][1], false)
    H.equal(latestAction('qbchat:close').action, 'qbchat:close')
    setLoggedIn(true)
end)

H.test('the HUD layout event updates and clamps the chat input layout', function()
    -- The composer is in kora_chat's NUI, but /hudlayout persists its position
    -- in kora_hud. This local event is the intentionally small bridge between
    -- those two resource-owned frames.
    fire('qbchat:setInputLayout', { x = 2, y = -2, scale = 2 })
    local layout = latestAction('qbchat:inputOffset').data
    H.equal(layout.x, 0.95)
    H.equal(layout.y, -0.95)
    H.equal(layout.scale, 1.5)

    fire('qbchat:setInputLayout', { x = 'bad', y = 0 })
    layout = latestAction('qbchat:inputOffset').data
    H.equal(layout.x, 0)
    H.equal(layout.y, 0)
    H.equal(layout.scale, 1)
end)

H.test('/clearchat clears only the local feed and is suggested on ready', function()
    H.truthy(registeredCommands.clearchat, 'command registered from Config.clearChat')
    nuiCallbacks['qbchat:ready']({}, function() end)
    local suggestion = latestAction('qbchat:suggestionAdd').data
    H.equal(suggestion.name, 'clearchat')
    registeredCommands.clearchat()
    H.equal(latestAction('qbchat:clearMessages').action, 'qbchat:clearMessages')
end)

H.test('T does not steal focus from another active NUI', function()
    nuiCallbacks['qbchat:submit']({ cancelled = true }, function() end)
    otherNuiFocused = true
    local before = #focusCalls
    keybind.handler()
    H.equal(#focusCalls, before)
    otherNuiFocused = false
end)

H.test('submit releases focus before routing slash and normal input', function()
    keybind.handler()
    nuiCallbacks['qbchat:submit']({ message = '/help now' }, function() end)
    H.equal(focusCalls[#focusCalls][1], false)
    H.equal(executed[#executed], 'help now')

    keybind.handler()
    nuiCallbacks['qbchat:submit']({ message = ' hello ' }, function() end)
    H.equal(serverEvents[#serverEvents].name, 'qbchat:send')
    H.equal(serverEvents[#serverEvents][1], 'hello')
end)

H.test('submit rejects blanks and enforces the configured character limit', function()
    local before = #serverEvents
    keybind.handler()
    nuiCallbacks['qbchat:submit']({ message = '   ' }, function() end)
    H.equal(#serverEvents, before)

    keybind.handler()
    nuiCallbacks['qbchat:submit']({ message = string.rep('x', 450) }, function() end)
    H.equal(utf8.len(serverEvents[#serverEvents][1]), Config.chat.maxMessageLength)
end)

H.test('compatibility messages and suggestions reach the NUI', function()
    fire('chat:addMessage', { args = { 'System' } })
    fire('chat:addSuggestion', '/heal', 'Heal player', { { name = 'id' } })
    H.truthy(latestAction('qbchat:message'))
    H.equal(latestAction('qbchat:suggestionAdd').data.name, '/heal')
end)

H.test('removed kora_lib suggestions are not resurrected by native command refresh', function()
    fire('chat:removeSuggestion', '/help')
    fire('onClientResourceStart', 'some_resource')
    H.equal(#latestAction('qbchat:suggestions').data, 0)

    fire('chat:addSuggestion', '/help', 'Detailed help', {})
    fire('onClientResourceStart', 'some_resource')
    H.equal(latestAction('qbchat:suggestions').data[1].name, '/help')
end)

H.test('a burst of resource starts schedules one native command refresh (F#246)', function()
    local queued = {}
    local realSetTimeout = _G.SetTimeout
    _G.SetTimeout = function(_, cb) queued[#queued + 1] = cb end
    for _ = 1, 10 do fire('onClientResourceStart', 'burst_resource') end
    _G.SetTimeout = realSetTimeout
    H.equal(#queued, 1)
    queued[1]()
    H.truthy(latestAction('qbchat:suggestions'))
end)

H.test('/me overhead text starts only an activity-bound draw thread', function()
    fire('qbchat:message', {
        id = 'me:1', type = 'me', author = 'Character One', message = 'waves', source = 1,
        overhead = true, overheadDuration = 5000,
    })
    H.equal(#drawCalls, 1)
    H.truthy(drawCalls[1].text:find('waves', 1, true))
    clock = 7000
    local ok, err = coroutine.resume(thread)
    if not ok then error(err) end
    H.equal(coroutine.status(thread), 'dead')
end)

H.test('/me overhead stacks only the three newest actions per player', function()
    local before = #drawCalls
    for index = 1, 4 do
        fire('qbchat:message', {
            id = 'stack:' .. index, type = 'me', author = 'Character One', message = 'action ' .. index,
            source = 1, overhead = true, overheadDuration = 5000,
        })
    end

    local ok, err = coroutine.resume(thread)
    if not ok then error(err) end
    H.equal(#drawCalls, before + 4, 'one initial draw plus a frame containing the three retained actions')
    H.truthy(drawCalls[before + 2].text:find('action 2', 1, true))
    H.truthy(drawCalls[before + 4].text:find('action 4', 1, true))

    clock = clock + 6000
    ok, err = coroutine.resume(thread)
    if not ok then error(err) end
    H.equal(coroutine.status(thread), 'dead')
end)

H.test('dynamic NUI suggestions use the kora_lib callback result', function()
    local response
    nuiCallbacks['qbchat:suggest']({ command = 'giveitem', argumentIndex = 1, query = 'wa', args = { 'wa' } }, function(value) response = value end)
    H.equal(response[1].value, 'water')
end)

H.test('resource stop always releases owned focus', function()
    keybind.handler()
    fire('onClientResourceStop', 'kora_chat')
    H.equal(focusCalls[#focusCalls][1], false)
end)

H.report('client')
