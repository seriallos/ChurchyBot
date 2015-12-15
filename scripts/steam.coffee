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
          game = getGameId(msg.match[1])
          console.log "Looking up AppID for ", game
          gameId = getGameId game
          if gameId
            msg.send String(gameId)
          else
            msg.send "Cannot find that game"

        robot.respond /steam userid (.*)/i, (msg) ->
          console.log "Looking up userId for ", msg.match[1]
          getUserId steam, msg.match[1], (err, userId) ->
            if err
              msg.send err
            else
              msg.send userId ? "User not found"

getUserId = (steam, name, cb) ->
  steam.resolveVanityURL {vanityurl: name}, (err, data) ->
    if err
      cb err
    else
      cb null, data.steamid ? null

getGameId = (name) ->
  if appLookup[name.toLowerCase()]
    return appLookup[name.toLowerCase()].appid
  else
    return null
