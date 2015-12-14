Steam = require 'steam-webapi'
_ = require 'lodash'

Steam.key = process.env.STEAM_API_KEY

appLookup = {}


module.exports = (robot) ->
  Steam.ready (err) ->
    if err
      console.error err
    else
      console.log "Steam ready"
      steam = new Steam()

      steam.getAppList {}, (err, data) ->
        appLookup = _.indexBy data.applist.apps, (obj) ->
          return obj.name.toLowerCase()

        robot.respond /steam appid (.*)/i, (msg) ->
          msg.send appLookup[msg.match[1].toLowerCase()].appid

