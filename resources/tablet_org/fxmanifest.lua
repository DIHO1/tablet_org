fx_version 'cerulean'

game 'gta5'

lua54 'yes'

ui_page 'html/index.html'

shared_scripts {
  '@es_extended/imports.lua',
  'config.lua'
}

client_scripts {
  'client/main.lua'
}

server_scripts {
  'server/main.lua'
}

dependencies {
  'es_extended',
  'oxmysql'
}

files {
  'html/index.html',
  'html/styles.css',
  'html/tablet.js'
}
