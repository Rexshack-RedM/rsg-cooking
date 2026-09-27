fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

description 'rsg-cooking'
version '2.0.1'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/webhook_config.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/client.lua',
    'client/campfire.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/webhooks.lua',
    'server/server.lua',
    'server/campfire.lua',
    'server/versionchecker.lua',
}

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

dependencies {
    'rsg-core',
    'rsg-inventory',
    'ox_lib',
    'ox_target',
    'oxmysql',
}
