# Description:
#   DCSS Bot Stuff
#
# Commands:
#   hubot steam player <username> - Show player summary (level, games owned, avatar)
#   hubot steam achievements <game> <username> - Game stats for a user
#   hubot steam userid <username> - Get user's Steam ID based on vanity URL
#   hubot steam appid <game> - Get a game's AppId (loaded at startup)

Steam = require 'steam-webapi'
async = require 'async'
_ = require 'lodash'


if not process.env.STEAM_API_KEY
  console.error "No STEAM_API_KEY env var defined, no Steam API for you"
  return

Steam.key = process.env.STEAM_API_KEY

appLookup = {}

module.exports = (robot) ->
  Steam.ready (steamReadyErr) ->
    if steamReadyErr
      console.error "Steam.ready failed!"
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
              msg.send String(err)
            else
              msg.send String(userId) ? "User not found"

        robot.respond /steam player (.*)/i, (msg) ->
          username = msg.match[1]
          console.log "Looking up player summary for #{username}"
          async.auto({
            userId: (cb, results) -> getUserId(steam, username, cb),
            level: ['userId', (cb, results) ->
              getSteamLevel steam, results.userId, cb
            ],
            player: ['userId', (cb, results) ->
              getPlayerSummary steam, results.userId, cb
            ],
            games: ['userId', (cb, results) ->
              getOwnedGames steam, results.userId, null, cb
            ],
          }, (err, results) ->
            {player, level, games} = results

            robot.emit 'slack-attachment', {
              channel: msg.envelope.room
              username: msg.robot.name
              attachments: [{
                color: '#345678'
                title: player.personaname
                title_link: player.profileurl
                thumb_url: player.avatarmedium
                fields: [{
                  title: 'Level'
                  value: level
                  short: true
                }, {
                  title: 'Games Owned'
                  value: Object.keys(games).length
                  short: true
                }]
              }]
            }

          )

        robot.respond /steam stats (.*) (.*)/i, (msg) ->
          appName = msg.match[1]
          userName = msg.match[2]
          console.log "Looking up stats for game ", appName, ", user ", userName
          appId = getGameId(appName)
          async.auto({
            userId: (cb, results) -> getUserId(steam, userName, cb)
            schema: (cb, results) ->
              getSchemaForGame steam, appId, cb
            stats: ['userId', (cb, results) ->
              getUserStatsForGame steam, results.userId, appId, cb
            ],
            playtime: ['userId', (cb, results) ->
              getPlaytime steam, results.userId, appId, cb
            ],
          }, (err, results) ->
            if err
              msg.send String(err)
            else if results.playtime == null
              msg.send "Game not owned"
            else
              numGameCheevos = results?.schema?.game?.availableGameStats?.achievements?.length ? 0
              numUserCheevos = results?.stats?.playerstats?.achievements?.length ? 0

              out = ["Playtime: #{results.playtime}"]
              if numGameCheevos
                out.push("Achievements: #{numUserCheevos} / #{numGameCheevos}")

              msg.send out.join(', ')
          )

getSteamLevel = (steam, userId, cb) ->
  steam.getSteamLevel {steamid: userId}, (err, data) ->
    if err
      cb err
    else
      cb null, data.player_level

getPlayerSummary = (steam, userId, cb) ->
  steam.getPlayerSummaries {steamids: userId}, (err, data) ->
    if err
      cb err
    else
      cb null, data.players.shift()

getPlaytime = (steam, userId, appId, cb) ->
  getOwnedGames steam, userId, appId, (err, owned) ->
    if err
      cb err
    else
      if not owned[appId]
        cb null, null
      else
        minutesPlayed = owned[appId].playtime_forever
        if minutesPlayed > 90
          playtime = Math.round(minutesPlayed / 60) + " hours"
        else
          playtime = minutesPlayed + " minutes"
        cb null, playtime

getOwnedGames = (steam, userId, appId, cb) ->
  opts =
    steamid: userId
    include_appinfo: false
    include_played_free_games: true
    appids_filter: null
  steam.getOwnedGames opts, (err, data) ->
    if err
      console.error 'getOwnedGames error', err
      cb err
    else
      cb null, _.indexBy(data.games, 'appid')

getSchemaForGame = (steam, appId, cb) ->
  steam.getSchemaForGame {appid: appId}, (err, data) ->
    if err
      if err.message.match /HTTP 400/
        cb Error("Game not found"), null
      else
        console.error 'getSchemaForGame error', err
        cb err
    else
      cb null, data

getUserStatsForGame = (steam, userId, appId, cb) ->
  steam.getUserStatsForGame {steamid: userId, appid: appId}, (err, data) ->
    if err
      if err.message.match /HTTP 400/
        # return empty stats
        cb null, null
      else
        console.error 'getUserStatsForGame error', err
        console.error 'getUserStatsForGame data', data
        cb err
    else
      cb null, data

getUserId = (steam, name, cb) ->
  steam.resolveVanityURL {vanityurl: name}, (err, data) ->
    if err
      console.error 'getUserId error', err
      console.error data
      cb err
    else
      if data.message == 'No match'
        cb Error("No such user")
      else
        console.log data
        cb null, data.steamid

getGameId = (name) ->
  if appLookup[name.toLowerCase()]
    return appLookup[name.toLowerCase()].appid
  else
    return null
