local messageTypes = {}
local messageHooks = {}
local registeredModes = {}
local commandTypes = {}
local nextHookId = 0
local nextMessageId = 0
local suggestionRate = {}
local messageCooldown = Kora.timers.cooldown(Config.chat.minimumMessageInterval)

local ICONS = {
    message = true,
    action = true,
    globe = true,
    radio = true,
    shield = true,
    info = true,
}

local function cleanMessage(value)
    if type(value) ~= 'string' then return nil end
    value = Kora.util.trim(value:gsub('[%z\1-\8\11\12\14-\31]', ''))
    if value == '' then return nil end
    local length = utf8.len(value)
    if length and length > Config.chat.maxMessageLength then
        return Kora.util.truncateUtf8(value, Config.chat.maxMessageLength), true
    end
    return Kora.util.truncateUtf8(value, Config.chat.maxMessageLength), false
end

local warnCooldown = Kora.timers.cooldown(Config.chatWarnings.interval)

-- kind is a Config.chatWarnings text key; texts may contain %d for the length limit.
local function warnPlayer(source, kind)
    local warnings = Config.chatWarnings
    local text = warnings.enabled and warnings[kind]
    if source == 0 or type(text) ~= 'string' or text == '' then return end
    if not warnCooldown.use(source) then return end
    Kora.notify.send(source, {
        title = warnings.title,
        message = text:format(Config.chat.maxMessageLength),
        type = 'error',
    })
end

local function permissionCheck(source, permission)
    if source == 0 or permission == nil or permission == 'user' then return true end
    local ok, allowed = pcall(function()
        return exports.kora_core:hasPermission(source, permission)
    end)
    return ok and allowed == true
end

local function publicType(name, definition)
    return {
        name = name,
        label = definition.label,
        icon = definition.icon,
        color = definition.color,
        scope = definition.scope,
        overhead = definition.overhead,
    }
end

local function validateDefinition(name, definition)
    assert(type(name) == 'string' and name:match('^[%w_-]+$'), 'Message type name must contain only letters, numbers, underscore, or hyphen.')
    assert(type(definition) == 'table', 'Message type definition must be a table.')

    local normalized = {}
    normalized.label = definition.label or name
    assert(type(normalized.label) == 'string' and normalized.label ~= '', 'Message type label must be a non-empty string.')
    normalized.help = type(definition.help) == 'string' and definition.help or ('Send a %s message'):format(normalized.label)

    if definition.command == false then
        normalized.command = false
    else
        local command = definition.command or name
        assert(type(command) == 'string' and command:match('^[%w_-]+$'), 'Message type command must be a command name or false.')
        normalized.command = command:lower()
    end

    normalized.scope = definition.scope or 'global'
    assert(normalized.scope == 'local' or normalized.scope == 'global', 'Message type scope must be local or global.')
    normalized.range = tonumber(definition.range) or Config.chat.localRange
    assert(normalized.range > 0 and normalized.range <= 1000, 'Message type range must be between 0 and 1000.')

    normalized.identity = definition.identity or 'character'
    assert(normalized.identity == 'character' or normalized.identity == 'account', 'Message type identity must be character or account.')
    normalized.permission = definition.permission or 'user'
    assert(type(normalized.permission) == 'string' and normalized.permission ~= '', 'Message type permission must be a non-empty string.')

    normalized.icon = definition.icon or 'message'
    assert(ICONS[normalized.icon] == true, 'Message type icon is not supported.')
    if definition.color ~= nil then
        assert(type(definition.color) == 'string' and definition.color:match('^#%x%x%x%x%x%x$'), 'Message type color must be #RRGGBB.')
        normalized.color = definition.color:upper()
    end

    normalized.overhead = definition.overhead == true
    normalized.overheadDuration = math.floor(tonumber(definition.overheadDuration) or Config.chat.overheadDuration)
    assert(normalized.overheadDuration > 0 and normalized.overheadDuration <= 30000, 'overheadDuration must be between 1 and 30000ms.')
    normalized.checkPermission = Kora.util.isCallable(definition.checkPermission) and definition.checkPermission or permissionCheck
    normalized.modeCallback = Kora.util.isCallable(definition.modeCallback) and definition.modeCallback or nil
    return normalized
end

local removeMessageType
local typeOwnership = Kora.resources.serverRegistry(function(name)
    removeMessageType(name)
end)

local function rateAllowed(source)
    if source == 0 then return true end
    return messageCooldown.use(source)
end

local function characterName(source)
    local name = exports.kora_core:getPlayerData(source, { 'name' })
    if type(name) == 'string' and name ~= '' then return name end
    return GetPlayerName(source) or ('Player %d'):format(source)
end

local function authorFor(source, definition)
    if source == 0 then return definition.label or 'System' end
    if definition.identity == 'account' then
        return GetPlayerName(source) or ('Player %d'):format(source)
    end
    return characterName(source)
end

local function localTargets(source, range)
    local result = { source }
    local included = { [source] = true }
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or (DoesEntityExist and not DoesEntityExist(ped)) then return result end

    local coords = GetEntityCoords(ped)
    if not coords then return result end
    local bucket = GetPlayerRoutingBucket(source)

    for _, rawTarget in ipairs(GetPlayers()) do
        local target = tonumber(rawTarget)
        if target and not included[target] and GetPlayerRoutingBucket(target) == bucket then
            local targetPed = GetPlayerPed(target)
            if targetPed and targetPed ~= 0 and (not DoesEntityExist or DoesEntityExist(targetPed)) then
                local ok, nearby = pcall(Kora.distance.player, target, coords, range)
                if ok and nearby then
                    included[target] = true
                    result[#result + 1] = target
                end
            end
        end
    end
    return result
end

local function sendTargets(targets, payload)
    if type(targets) ~= 'table' then targets = { targets } end
    for _, rawTarget in ipairs(targets) do
        local target = tonumber(rawTarget)
        if target then TriggerClientEvent('qbchat:message', target, payload) end
    end
end

local function buildHookRef(state)
    return {
        updateMessage = function(update)
            if type(update) ~= 'table' then return end
            for key, value in pairs(update) do
                if key == 'template' and type(value) == 'string' then
                    state.payload.template = value:gsub('%{%}', state.payload.template or '@default')
                elseif key == 'params' and type(value) == 'table' then
                    state.payload.params = state.payload.params or {}
                    for param, paramValue in pairs(value) do state.payload.params[param] = paramValue end
                else
                    state.payload[key] = value
                end
            end
        end,
        cancel = function() state.cancelled = true end,
        setSeObject = function(object)
            local targets = {}
            for _, rawTarget in ipairs(GetPlayers()) do
                if IsPlayerAceAllowed(rawTarget, object) then targets[#targets + 1] = tonumber(rawTarget) end
            end
            state.targets = targets
        end,
        setRouting = function(targets) state.targets = targets end,
    }
end

local function dispatchMessage(source, typeName, rawMessage, options)
    local definition = messageTypes[typeName]
    local message, truncated = cleanMessage(rawMessage)
    if not definition or not message then return false, 'invalid message' end
    options = options or {}

    if not options.trusted then
        local allowed = definition.checkPermission(source, definition.permission)
        if not allowed then return false, 'permission denied' end
        if truncated then
            if Config.chatWarnings.overLimitAction == 'reject' then
                warnPlayer(source, 'tooLong')
                return false, 'message too long'
            end
            warnPlayer(source, 'truncated')
        end
        if not rateAllowed(source) then
            warnPlayer(source, 'rateLimited')
            return false, 'rate limited'
        end
    end

    nextMessageId = nextMessageId + 1
    local author = options.author or authorFor(source, definition)
    local targets = options.targets
    if targets == nil then
        targets = definition.scope == 'local' and localTargets(source, definition.range) or -1
    end

    local payload = {
        id = ('%d:%d'):format(GetGameTimer(), nextMessageId),
        type = typeName,
        messageType = publicType(typeName, definition),
        author = tostring(author),
        message = message,
        source = tonumber(options.source) or source,
        timestamp = os.time(),
        overhead = definition.overhead,
        overheadDuration = definition.overheadDuration,
        args = { tostring(author), message },
    }
    local state = { payload = payload, targets = targets, cancelled = false }
    local hookRef = buildHookRef(state)

    for _, hook in pairs(messageHooks) do
        local ok, err = pcall(hook.fn, source, state.payload, hookRef)
        if not ok then print(('^3[qbchat]^7 message hook errored: %s'):format(tostring(err))) end
    end

    if definition.modeCallback then
        local ok, err = pcall(definition.modeCallback, source, state.payload, hookRef)
        if not ok then print(('^3[qbchat]^7 mode callback for %s errored: %s'):format(typeName, tostring(err))) end
    end

    if state.cancelled then return false, 'cancelled' end

    if type(state.payload.args) == 'table' and #state.payload.args > 0 then
        state.payload.author = #state.payload.args > 1 and tostring(state.payload.args[1] or '') or ''
        state.payload.message = tostring(state.payload.args[#state.payload.args] or state.payload.message)
    end

    TriggerEvent('chatMessage', source, state.payload.author, state.payload.message)
    if WasEventCanceled and WasEventCanceled() then return false, 'cancelled' end

    sendTargets(state.targets, state.payload)
    return true
end

local function registerMessageType(name, definition, explicitOwner)
    name = type(name) == 'string' and name:lower() or name
    local normalized = validateDefinition(name, definition)
    local owner = explicitOwner or GetInvokingResource() or GetCurrentResourceName()
    local existing = messageTypes[name]
    local existingOwner = typeOwnership.owner(name)
    assert(not existingOwner or existingOwner == owner,
        ("Message type '%s' is owned by '%s'."):format(name, tostring(existingOwner)))
    if normalized.command then
        local commandOwner = commandTypes[normalized.command]
        assert(not commandOwner or commandOwner == name,
            ("Message command '/%s' is already used by type '%s'."):format(normalized.command, tostring(commandOwner)))
    end
    if existing and existing.command then
        commandTypes[existing.command] = nil
        Kora.commands.remove(existing.command)
    end
    if registeredModes[name] then
        registeredModes[name] = nil
        TriggerClientEvent('chat:removeMode', -1, { name = name })
    end

    messageTypes[name] = normalized
    typeOwnership.track(owner, name)

    if normalized.command then
        commandTypes[normalized.command] = name
        local commandName = normalized.command
        Kora.commands.add(commandName, normalized.help, {
            { name = 'message', help = ('Message to send as %s'):format(normalized.label) },
        }, false, function(source, _, raw)
            -- argsRequired is off so an empty message gets chat's own wording instead of
            -- kora_lib's generic "Missing arguments" text; kora_lib still checks permission first.
            local message = raw:match('^%S+%s+(.+)$')
            if not message or not message:find('%S') then
                local text = Config.chat.missingMessageText
                if type(text) ~= 'string' or text == '' then text = 'Missing arguments for /%s' end
                Kora.notify.send(source, { message = text:format(commandName), type = 'error' })
                return
            end
            dispatchMessage(source, name, message)
        end, {
            permission = normalized.permission,
            resource = owner,
            checkPermission = normalized.checkPermission,
        })
    end

    TriggerClientEvent('qbchat:typeAdded', -1, publicType(name, normalized))
    return true
end

removeMessageType = function(name)
    local definition = messageTypes[name]
    if not definition then return false end
    messageTypes[name] = nil
    typeOwnership.untrack(name)
    if definition.command then
        commandTypes[definition.command] = nil
        Kora.commands.remove(definition.command)
    end
    if registeredModes[name] then
        registeredModes[name] = nil
        TriggerClientEvent('chat:removeMode', -1, { name = name })
    end
    TriggerClientEvent('qbchat:typeRemoved', -1, name)
    return true
end

local function sendMessage(target, typeName, message, options)
    assert(target == -1 or type(target) == 'number' or type(target) == 'table', 'target must be -1, a player id, or an array of player ids')
    assert(type(typeName) == 'string', 'typeName must be a string')
    assert(options == nil or type(options) == 'table', 'opts must be a table')

    local normalizedTargets = target
    if type(target) == 'table' then
        normalizedTargets = {}
        for index, rawTarget in ipairs(target) do
            local playerId = tonumber(rawTarget)
            assert(playerId and playerId % 1 == 0, ('target at index %d must be a player id'):format(index))
            normalizedTargets[#normalizedTargets + 1] = playerId
        end
    else
        assert(target % 1 == 0, 'target must be an integer player id')
    end

    local dispatchOptions = {}
    for key, value in pairs(options or {}) do dispatchOptions[key] = value end
    dispatchOptions.trusted = true
    dispatchOptions.targets = normalizedTargets
    local source = tonumber(dispatchOptions.source) or 0
    return dispatchMessage(source, typeName:lower(), message, dispatchOptions)
end

local function unregisterMessageType(name, explicitOwner)
    assert(type(name) == 'string', 'name must be a string')
    name = name:lower()
    local owner = typeOwnership.owner(name)
    local caller = explicitOwner or GetInvokingResource() or GetCurrentResourceName()
    if owner and owner ~= caller then return false end
    return removeMessageType(name)
end

exports('registerMessageType', function(name, definition)
    return registerMessageType(name, definition, GetInvokingResource() or GetCurrentResourceName())
end)
exports('unregisterMessageType', function(name)
    return unregisterMessageType(name, GetInvokingResource() or GetCurrentResourceName())
end)
exports('sendMessage', sendMessage)

local function addCompatMessage(target, message)
    if message == nil then message, target = target, -1 end
    if target == nil or message == nil then return false end
    TriggerClientEvent('chat:addMessage', target, message)
    return true
end

local function registerMessageHook(hook)
    assert(Kora.util.isCallable(hook), 'hook must be callable')
    nextHookId = nextHookId + 1
    messageHooks[nextHookId] = {
        fn = hook,
        resource = GetInvokingResource() or GetCurrentResourceName(),
    }
    return nextHookId
end

local function registerMode(modeData)
    if type(modeData) ~= 'table' or type(modeData.name) ~= 'string'
        or type(modeData.displayName) ~= 'string' or not Kora.util.isCallable(modeData.cb) then
        return false
    end

    local owner = GetInvokingResource() or GetCurrentResourceName()
    local checkPermission
    if modeData.seObject then
        checkPermission = function(source) return IsPlayerAceAllowed(source, modeData.seObject) end
    end

    local modeColor = modeData.color
    if type(modeColor) == 'string' and modeColor:match('^#%x%x%x$') then
        modeColor = ('#%s%s%s%s%s%s'):format(
            modeColor:sub(2, 2), modeColor:sub(2, 2),
            modeColor:sub(3, 3), modeColor:sub(3, 3),
            modeColor:sub(4, 4), modeColor:sub(4, 4)
        )
    elseif type(modeColor) ~= 'string' or not modeColor:match('^#%x%x%x%x%x%x$') then
        modeColor = nil
    end

    local modeName = modeData.name:lower()
    registerMessageType(modeName, {
        label = modeData.displayName,
        help = ('Send a message in %s'):format(modeData.displayName),
        command = modeName,
        scope = modeData.isGlobal and 'global' or 'local',
        identity = 'account',
        color = modeColor,
        icon = 'message',
        permission = modeData.seObject or 'user',
        checkPermission = checkPermission,
        modeCallback = modeData.cb,
    }, owner)

    local clientMode = {
        name = modeName,
        displayName = modeData.displayName,
        color = messageTypes[modeName].color or '#FFFFFF',
        isChannel = modeData.isChannel,
        isGlobal = modeData.isGlobal,
    }
    registeredModes[modeName] = { resource = owner }

    if modeData.seObject then
        for _, rawTarget in ipairs(GetPlayers()) do
            if IsPlayerAceAllowed(rawTarget, modeData.seObject) then
                TriggerClientEvent('chat:addMode', tonumber(rawTarget), clientMode)
            end
        end
    else
        TriggerClientEvent('chat:addMode', -1, clientMode)
    end
    return true
end

exports('addMessage', addCompatMessage)
exports('registerMessageHook', registerMessageHook)
exports('registerMode', registerMode)
Kora.compat.provideExport('chat', 'addMessage', addCompatMessage)
Kora.compat.provideExport('chat', 'registerMessageHook', registerMessageHook)
Kora.compat.provideExport('chat', 'registerMode', registerMode)

RegisterNetEvent('qbchat:send', function(message)
    dispatchMessage(source, 'say', message)
end)

RegisterNetEvent('_chat:messageEntered', function(_, _, message, mode)
    local typeName = type(mode) == 'string' and mode:lower() or nil
    dispatchMessage(source, typeName and messageTypes[typeName] and typeName or 'say', message)
end)

RegisterNetEvent('chat:init', function()
    local src = source
    Kora.commands.refresh(src)
    local types = {}
    for name, definition in pairs(messageTypes) do types[#types + 1] = publicType(name, definition) end
    TriggerClientEvent('qbchat:types', src, types)
end)

-- Register the standard server-side event names so legacy resources can rely
-- on their presence. Client presentation handlers live in client/main.lua.
RegisterNetEvent('chat:addTemplate')
RegisterNetEvent('chat:addMessage')
RegisterNetEvent('chat:addSuggestion')
RegisterNetEvent('chat:addSuggestions')
RegisterNetEvent('chat:addMode')
RegisterNetEvent('chat:removeMode')
RegisterNetEvent('chat:removeSuggestion')
RegisterNetEvent('chat:clear')

RegisterCommand('say', function(source, _, raw)
    local message = raw:match('^%S+%s+(.+)$')
    if not message then return end
    if source == 0 then
        sendMessage(-1, 'ooc', message, { author = 'console', source = 0 })
    else
        dispatchMessage(source, 'say', message)
    end
end, false)

Kora.callback.register('qbchat:commandSuggestions', function(source, command, argumentIndex, query, parsedArgs)
    if type(command) ~= 'string' or #command > 64 or type(argumentIndex) ~= 'number'
        or type(query) ~= 'string' or #query > 128 or type(parsedArgs) ~= 'table' or #parsedArgs > 16 then
        return {}
    end
    if argumentIndex % 1 ~= 0 or argumentIndex < 1 or argumentIndex > 16 then return {} end
    for _, argument in ipairs(parsedArgs) do
        if type(argument) ~= 'string' or #argument > 128 then return {} end
    end

    local now = GetGameTimer()
    local rate = suggestionRate[source]
    if not rate or now - rate.startedAt >= 1000 then
        rate = { startedAt = now, count = 0 }
        suggestionRate[source] = rate
    end
    rate.count = rate.count + 1
    if rate.count > Config.chat.suggestionRequestsPerSecond then return {} end

    local results = Kora.commands.suggest(source, command, argumentIndex, query, parsedArgs)
    while #results > Config.chat.suggestionResultLimit do results[#results] = nil end
    return results
end)

AddEventHandler('playerDropped', function()
    messageCooldown.reset(source)
    warnCooldown.reset(source)
    suggestionRate[source] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    for id, hook in pairs(messageHooks) do
        if hook.resource == resource then messageHooks[id] = nil end
    end
end)

registerMessageType('say', {
    label = 'Local', command = false, scope = 'local', range = Config.chat.localRange,
    identity = 'character', icon = 'message', permission = 'user',
}, GetCurrentResourceName())

registerMessageType('me', {
    label = 'Action', help = 'Describe a nearby character action', command = 'me',
    scope = 'local', range = Config.chat.localRange, identity = 'character',
    icon = 'action', permission = 'user', overhead = true,
    overheadDuration = Config.chat.overheadDuration,
}, GetCurrentResourceName())

registerMessageType('ooc', {
    label = 'OOC', help = 'Send a global out-of-character message', command = 'ooc',
    scope = 'global', identity = 'account', icon = 'globe', permission = 'user',
}, GetCurrentResourceName())

for name, definition in pairs(Config.messageTypes or {}) do
    registerMessageType(name, definition, GetCurrentResourceName())
end
