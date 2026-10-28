Config = Config or {}

Config.chat = {
    defaultKey = 'T',
    localRange = 20.0,
    maxMessageLength = 400,
    minimumMessageInterval = 500,
    messageLimit = 200,
    historyLimit = 50,
    fadeTimeout = 8000,
    overheadDuration = 5000,
    overheadLimitPerPlayer = 3,
    suggestionLimit = 8,
    suggestionResultLimit = 20,
    suggestionDebounce = 125,
    suggestionRequestsPerSecond = 10,
}

-- Additional declarative types use the same schema as the
-- registerMessageType server export. Built-ins (say, me, ooc) are registered
-- by server/main.lua so their behavior cannot drift from the documented API.
Config.messageTypes = {}

-- Registers this resource-owned configuration with kora_lib without changing its public Config table.
if QB and QB.config and QB.config.adopt then
    Config.messageTypes = QB.config.map({}, QB.config.object({}), {
        label = 'Message types',
        description = 'Defines custom chat message types by command name. Each key becomes the command identifier and its value supplies the authored presentation data used when that message type is registered.',
    })
    Config = QB.config.adopt(Config)
end
