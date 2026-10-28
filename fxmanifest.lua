fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kora_chat'
-- Keep the legacy resource name resolvable for exports['qbchat'] callers.
provide 'qbchat'
author 'Jamie'
version '1.0.0'
description 'Event-driven, qbtheme-styled chat with proximity roleplay messages and command completion'

provide 'chat'

dependency 'kora_theme'
dependency 'kora_lib'
dependency 'kora_core'

shared_script '@kora_lib/init.lua'
shared_script 'config.lua'

client_scripts {
    '@kora_theme/client/bridge.lua',
    'client/main.lua',
}
server_script 'server/main.lua'

ui_page 'web/build/index.html'

files {
    'web/build/index.html',
    'web/build/assets/**/*'
}
