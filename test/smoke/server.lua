local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local root = scriptDir .. '../../'
package.path = scriptDir .. '../?.lua;' .. package.path
local H = require('harness')

local netHandlers, eventHandlers, commands, callbacks = {}, {}, {}, {}
local clientEvents, ownExports, aliasExports = {}, {}, {}
local clock, invokingResource = 1000, nil
local missingPedSource = nil

_G.source = 1
_G.RegisterNetEvent = function(name, cb)
    netHandlers[name] = netHandlers[name] or {}
    if cb then netHandlers[name][#netHandlers[name] + 1] = cb end
end
_G.AddEventHandler = function(name, cb)
    eventHandlers[name] = eventHandlers[name] or {}
    eventHandlers[name][#eventHandlers[name] + 1] = cb
end
_G.TriggerEvent = function(name, ...)
    for _, cb in ipairs(eventHandlers[name] or {}) do cb(...) end
    for _, cb in ipairs(netHandlers[name] or {}) do cb(...) end
end
_G.TriggerClientEvent = function(name, target, ...)
    clientEvents[#clientEvents + 1] = { name = name, target = target, ... }
end
_G.RegisterCommand = function(name, cb) commands[name] = cb end
_G.GetGameTimer = function() return clock end
_G.GetInvokingResource = function() return invokingResource end
_G.GetCurrentResourceName = function() return 'qbchat' end
_G.GetPlayers = function() return { '1', '2', '3', '4' } end
_G.GetPlayerName = function(src) return ({ [1] = 'Account One', [2] = 'Account Two', [3] = 'Account Three', [4] = 'Account Four' })[tonumber(src)] end
_G.GetPlayerPed = function(src) return tonumber(src) == missingPedSource and 0 or tonumber(src) end
_G.DoesEntityExist = function(entity) return entity ~= 0 end
_G.GetEntityCoords = function(entity) return { x = entity * 10, y = 0, z = 0 } end
_G.IsPlayerAceAllowed = function() return true end
_G.WasEventCanceled = function() return false end

local qbcore = {}
function qbcore:getPlayerData(src) return src == 1 and 'Character One' or nil end
function qbcore:hasPermission(_, permission) return permission ~= 'denied' end
_G.exports = setmetatable({ qbcore = qbcore }, {
    __call = function(_, name, fn) ownExports[name] = fn end,
})

local tracked = {}
_G.QB = {
    compat = { provideExport = function(identity, name, fn)
        AddEventHandler(('__cfx_export_%s_%s'):format(identity, name), function(setCB) setCB(fn) end)
    end },
    util = {
        isCallable = function(value)
            if type(value) == 'function' then return true end
            local mt = type(value) == 'table' and getmetatable(value) or nil
            return mt ~= nil and mt.__call ~= nil
        end,
        trim = function(value) return type(value) == 'string' and value:match('^%s*(.-)%s*$') or value end,
        truncateUtf8 = function(value, maximum)
            local length = utf8.len(value)
            if not length or length <= maximum then return length and value or nil end
            local offset = utf8.offset(value, maximum + 1)
            return value:sub(1, offset - 1)
        end,
    },
    resources = {
        serverRegistry = function(dispose)
            AddEventHandler('onResourceStop', function(resource)
                local owned = {}
                for id, entry in pairs(tracked) do
                    if entry.resource == resource then owned[#owned + 1] = id end
                end
                for _, id in ipairs(owned) do
                    tracked[id] = nil
                    dispose(id)
                end
            end)
            return {
                track = function(resource, id) tracked[id] = { resource = resource, dispose = dispose } end,
                untrack = function(id) local owner = tracked[id] and tracked[id].resource; tracked[id] = nil; return owner end,
                owner = function(id) return tracked[id] and tracked[id].resource end,
            }
        end,
    },
    timers = {
        cooldown = function(interval)
            local usedAt = {}
            return {
                use = function(key)
                    local previous = usedAt[key]
                    if previous and clock - previous < interval then return false end
                    usedAt[key] = clock
                    return true
                end,
                reset = function(key) usedAt[key] = nil end,
            }
        end,
    },
    distance = {
        player = function(target, coords, range)
            local targetCoords = GetEntityCoords(GetPlayerPed(target))
            local dx, dy, dz = targetCoords.x - coords.x, targetCoords.y - coords.y, targetCoords.z - coords.z
            return math.sqrt(dx * dx + dy * dy + dz * dz) <= range
        end,
    },
    commands = {
        add = function(name, help, args, required, handler, opts)
            commands[name] = handler
            commands[name .. ':definition'] = { help = help, args = args, required = required, opts = opts }
        end,
        remove = function(name) commands[name] = nil end,
        refresh = function() end,
        suggest = function(_, command) return { { value = command .. '-value' } } end,
    },
    callback = {
        register = function(name, handler) callbacks[name] = handler end,
    },
}

dofile(root .. 'config.lua')
dofile(root .. 'server/main.lua')

for name, handlers in pairs(eventHandlers) do
    if name:match('^__cfx_export_chat_') then
        handlers[1](function(fn) aliasExports[name:match('^__cfx_export_chat_(.+)$')] = fn end)
    end
end

local function fireNet(name, src, ...)
    _G.source = src
    for _, cb in ipairs(netHandlers[name] or {}) do cb(...) end
end

local function latest(name)
    for index = #clientEvents, 1, -1 do
        if clientEvents[index].name == name then return clientEvents[index] end
    end
end

H.test('built-in types register me and ooc commands with message arguments', function()
    H.truthy(commands.me)
    H.truthy(commands.ooc)
    H.equal(commands['me:definition'].args[1].name, 'message')
end)

H.test('normal chat uses character identity and local routing', function()
    fireNet('qbchat:send', 1, 'hello nearby')
    local sends = {}
    for _, event in ipairs(clientEvents) do
        if event.name == 'qbchat:message' and event[1].message == 'hello nearby' then sends[event.target] = event[1] end
    end
    H.truthy(sends[1])
    H.truthy(sends[2])
    H.truthy(sends[3], 'a player exactly at the range boundary should be included')
    H.falsy(sends[4])
    H.equal(sends[1].author, 'Character One')
end)

H.test('character identity falls back to the account name', function()
    fireNet('qbchat:send', 2, 'fallback name')
    local ownEvent
    for _, event in ipairs(clientEvents) do
        if event.name == 'qbchat:message' and event.target == 2 and event[1].message == 'fallback name' then ownEvent = event end
    end
    H.truthy(ownEvent)
    H.equal(ownEvent[1].author, 'Account Two')
end)

H.test('local routing always includes the sender when coordinates are unavailable', function()
    missingPedSource = 3
    fireNet('qbchat:send', 3, 'no coordinates')
    missingPedSource = nil
    local sends = {}
    for _, event in ipairs(clientEvents) do
        if event.name == 'qbchat:message' and event[1].message == 'no coordinates' then sends[event.target] = true end
    end
    H.truthy(sends[3])
    H.falsy(sends[1])
    H.falsy(sends[2])
    H.falsy(sends[4])
end)

H.test('message rate limiting rejects a rapid repeat', function()
    local before = #clientEvents
    fireNet('qbchat:send', 1, 'too fast')
    H.equal(#clientEvents, before)
    clock = clock + Config.chat.minimumMessageInterval
    fireNet('qbchat:send', 1, 'allowed now')
    H.truthy(latest('qbchat:message'))
end)

H.test('/me is local, character-named, and marked for overhead drawing', function()
    clock = clock + Config.chat.minimumMessageInterval
    commands.me(1, { 'waves' }, 'me waves at everyone')
    local event = latest('qbchat:message')
    H.equal(event[1].type, 'me')
    H.equal(event[1].author, 'Character One')
    H.truthy(event[1].overhead)
    H.equal(event[1].message, 'waves at everyone')
end)

H.test('/ooc is global and uses the account identity', function()
    clock = clock + Config.chat.minimumMessageInterval
    commands.ooc(1, { 'hello' }, 'ooc hello world')
    local event = latest('qbchat:message')
    H.equal(event.target, -1)
    H.equal(event[1].author, 'Account One')
    H.equal(event[1].type, 'ooc')
end)

H.test('player messages are truncated to the configured character limit', function()
    clock = clock + Config.chat.minimumMessageInterval
    fireNet('qbchat:send', 1, string.rep('x', 450))
    H.equal(utf8.len(latest('qbchat:message')[1].message), Config.chat.maxMessageLength)
end)

H.test('custom type exports register commands and direct sends', function()
    invokingResource = 'radio_resource'
    H.truthy(ownExports.registerMessageType('radio', {
        label = 'Radio', command = 'radio', scope = 'global', icon = 'radio',
    }))
    invokingResource = nil
    H.truthy(commands.radio)
    H.truthy(ownExports.sendMessage(-1, 'radio', 'respond', { author = 'Dispatch' }))
    local event = latest('qbchat:message')
    H.equal(event[1].author, 'Dispatch')
    H.equal(event[1].type, 'radio')
    invokingResource = 'radio_resource'
    H.truthy(ownExports.unregisterMessageType('radio'))
    invokingResource = nil
    H.falsy(commands.radio)
end)

H.test('custom types are removed when their owning resource stops', function()
    invokingResource = 'temporary_messages'
    ownExports.registerMessageType('temporary', {
        label = 'Temporary', command = 'temporary', scope = 'global', icon = 'info',
    })
    invokingResource = nil
    H.truthy(commands.temporary)

    TriggerEvent('onResourceStop', 'temporary_messages')
    H.falsy(commands.temporary)
    H.equal(latest('qbchat:typeRemoved')[1], 'temporary')
end)

H.test('direct sends validate target lists and provide a server identity fallback', function()
    H.falsy(pcall(ownExports.sendMessage, { 1, 'invalid' }, 'say', 'bad targets'))
    H.truthy(ownExports.sendMessage({ 1, 2 }, 'say', 'server notice'))
    local event = latest('qbchat:message')
    H.equal(event[1].author, 'Local')
    H.equal(event.target, 2)
end)

H.test('custom type definitions reject unsafe presentation values', function()
    H.falsy(pcall(ownExports.registerMessageType, 'unsafe_icon', { label = 'Unsafe', icon = 'javascript' }))
    H.falsy(pcall(ownExports.registerMessageType, 'unsafe_color', { label = 'Unsafe', color = 'url(evil)' }))
end)

H.test('custom types cannot take over another resource owner or command', function()
    invokingResource = 'hostile_resource'
    H.falsy(pcall(ownExports.registerMessageType, 'me', { label = 'Stolen', command = 'me' }))
    H.falsy(pcall(ownExports.registerMessageType, 'other_me', { label = 'Stolen', command = 'me' }))
    H.falsy(ownExports.unregisterMessageType('ooc'))
    invokingResource = nil
    H.truthy(commands.me)
    H.truthy(commands.ooc)
end)

H.test('stock chat aliases expose server compatibility functions', function()
    H.truthy(aliasExports.addMessage)
    H.truthy(aliasExports.registerMessageHook)
    H.truthy(aliasExports.registerMode)
    aliasExports.addMessage(2, { args = { 'compat' } })
    H.equal(latest('chat:addMessage').target, 2)
end)

H.test('stock message hooks can merge params, replace the default template, and rewrite args', function()
    invokingResource = 'hook_resource'
    aliasExports.registerMessageHook(function(_, _, hookRef)
        hookRef.updateMessage({
            args = { 'Hooked', 'changed' },
            template = '<strong>{}</strong>',
            params = { channel = 'test' },
        })
    end)
    invokingResource = nil

    ownExports.sendMessage(1, 'say', 'original')
    local message = latest('qbchat:message')[1]
    H.equal(message.author, 'Hooked')
    H.equal(message.message, 'changed')
    H.equal(message.template, '<strong>@default</strong>')
    H.equal(message.params.channel, 'test')
    TriggerEvent('onResourceStop', 'hook_resource')
end)

H.test('stock modes become typed commands and announce lifecycle events', function()
    invokingResource = 'mode_resource'
    H.truthy(aliasExports.registerMode({
        name = 'staff', displayName = 'Staff', isGlobal = true,
        color = '#f00', cb = function() end,
    }))
    invokingResource = nil

    H.truthy(commands.staff)
    H.equal(latest('chat:addMode')[1].name, 'staff')
    H.equal(latest('chat:addMode')[1].displayName, 'Staff')
    H.equal(latest('chat:addMode')[1].color, '#FF0000')

    TriggerEvent('onResourceStop', 'mode_resource')
    H.falsy(commands.staff)
    H.equal(latest('chat:removeMode')[1].name, 'staff')
end)

H.test('dynamic suggestion callback delegates and rate limits safely', function()
    local result = callbacks['qbchat:commandSuggestions'](1, 'giveitem', 1, 'wa', { 'wa' })
    H.equal(result[1].value, 'giveitem-value')
    H.equal(#callbacks['qbchat:commandSuggestions'](1, string.rep('x', 65), 1, '', {}), 0)
    H.equal(#callbacks['qbchat:commandSuggestions'](1, 'giveitem', 0, '', {}), 0)

    for _ = 2, Config.chat.suggestionRequestsPerSecond do
        H.truthy(callbacks['qbchat:commandSuggestions'](1, 'giveitem', 1, '', {})[1])
    end
    H.equal(#callbacks['qbchat:commandSuggestions'](1, 'giveitem', 1, '', {}), 0)

    clock = clock + 1000
    H.truthy(callbacks['qbchat:commandSuggestions'](1, 'giveitem', 1, '', {})[1])
end)

H.report('server')
