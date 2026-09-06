fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qbchat'
author 'Jamie'
version '1.0.0'
description 'Event-driven, qbtheme-styled chat with proximity roleplay messages and command completion'

provide 'chat'

dependency 'qbtheme'
dependency 'qblib'
dependency 'qbcore'

shared_script '@qblib/init.lua'
shared_script 'config.lua'

client_scripts {
    '@qbtheme/client/bridge.lua',
    'client/main.lua',
}
server_script 'server/main.lua'

ui_page 'web/build/index.html'

files {
    'web/build/index.html',
    'web/build/assets/**/*'
}
