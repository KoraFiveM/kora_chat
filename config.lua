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

-- Registers this resource-owned configuration with qblib without changing its public Config table.
if QB and QB.config and QB.config.adopt then Config = QB.config.adopt(Config) end
