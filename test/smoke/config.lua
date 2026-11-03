local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local root = scriptDir .. '../../'
package.path = scriptDir .. '../?.lua;' .. package.path
local H = require('harness')

-- F#244: the message type map must default to the authored Config.messageTypes, not a fresh {}.
local mapDefault, authored
_G.Kora = { config = {
    adopt = function(config) return config end,
    object = function(schema) return schema end,
    map = function(default) mapDefault = default; authored = Config.messageTypes; return default end,
} }

H.test('Config.messageTypes is the default handed to Kora.config.map (F#244)', function()
    _G.Config = nil
    dofile(root .. 'config.lua')
    H.truthy(mapDefault ~= nil)
    H.truthy(rawequal(mapDefault, authored))
end)

H.report('config')
