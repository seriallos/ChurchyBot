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

apps = {}

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
        apps = data.applist.apps

        robot.respond /steam appid (.*)/i, (msg) ->
          name = msg.match[1]
          console.log "Looking up AppID for ", name
          gameIds = getGameIds name
          if gameIds.length == 0
            msg.send "Cannot find that game"
          else if gameIds.length == 1
            msg.send String(gameIds[0])
          else
            msg.send "Multiple IDs found: #{gameIds.join ', '}"

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
            recent: ['userId', (cb, results) ->
              getRecentlyPlayed steam, results.userId, cb
            ],
          }, (err, results) ->
            if err
              msg.send "Error: #{err}"
              return

            {player, level, games, recent} = results
            recentGames = _.map(recent.games, (r) ->
              "#{r.name} (#{humanTime(r.playtime_2weeks)})"
            )

            robot.emit 'slack-attachment', {
              channel: msg.envelope.room
              username: msg.robot.name
              attachments: [{
                color: '#345678'
                title: player.personaname
                title_link: player.profileurl
                thumb_url: player.avatarmedium
                text: "Recently played: #{recentGames.join ', '}"
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
          appIds = getGameIds(appName)

          if appIds.length == 0
            msg.send "Game not found"
            return

          if appIds.length > 1
            msg.send "Multiple games found, try using a specific ID: #{appIds.join ', '}"
            return

          appId = appIds[0]

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

humanTime = (minutes) ->
  if minutes > 90
    hours = Math.round(minutes / 60)
    playtime = "#{hours} hour#{if hours != 1 then 's' else ''}"
  else
    playtime = "#{minutes} minute#{if minutes != 1 then 's' else ''}"
  return playtime

getRecentlyPlayed = (steam, userId, cb) ->
  steam.getRecentlyPlayedGames {steamid: userId, count: 5}, cb

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
        cb null, humanTime(owned[appId].playtime_forever)

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
        cb null, data.steamid

getGameIds = (name) ->
  filtered = _.filter(apps, (app) -> app.name.toLowerCase() == name.toLowerCase())
  if filtered.length > 0
    return _.map(filtered, (app) -> app.appid)
  else
    # try searching by appId instead of name
    filtered = _.find(apps, 'appid', parseInt(name))
    if filtered
      return [ parseInt(name) ]
    else
      return []

