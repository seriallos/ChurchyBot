Steam = require 'steam-webapi'
_ = require 'lodash'


if not process.env.STEAM_API_KEY
  console.log "No STEAM_API_KEY env var defined, no Steam API for you"
  return

Steam.key = process.env.STEAM_API_KEY

appLookup = {}

module.exports = (robot) ->
  Steam.ready (steamReadyErr) ->
    if steamReadyErr
      console.error steamReadyErr
    else
      console.log "Steam ready"
      steam = new Steam()

      steam.getAppList {}, (appListErr, data) ->
        console.log "Got app list, num apps found: ", data.applist.apps.length
        appLookup = _.indexBy data.applist.apps, (obj) ->
          if obj.name
            return obj.name.toLowerCase()

        robot.respond /steam appid (.*)/i, (msg) ->
          game = msg.match[1]
          console.log "Looking up AppID for ", game
          if appLookup[game.toLowerCase()]
            msg.send String(appLookup[game.toLowerCase()].appid)
          else
            msg.send "Cannot find that game"

