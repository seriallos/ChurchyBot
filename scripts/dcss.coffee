# Description:
#   DCSS Bot Stuff
#
# Commands:
#   hubot dcss links - Responds with various links
#   hubot dcss where <username> - Report current .where stats for <username>
#
# Notes:

request = require 'request'
WebSocket = require 'ws'

announceRoom = '#dcss'

DEBUG=process.env.DEBUG

state = {}
activeGames = {}
firstMsg = true
deathLookupWaitSeconds = 30

#{ username: '0xF86B5A89',
#  xl: '18',
#  title: 'Devastator',
#  spectator_count: 0,
#  idle_time: 0,
#  char: 'DgCj',
#  place: 'Elf:3',
#  milestone: 'escaped from the Abyss!',
#  msg: 'lobby_entry',
#  game_id: 'dcss-git',
#  id: 122598 }

host = 'crawl.akrasiac.org'
rawData = "http://#{host}/rawdata"
socketServer = "ws://#{host}:8080/socket"

sequellHost = 'https://loom.shalott.org/api/sequell'

module.exports = (robot) ->
  ws = null

  doPong = ->
    ws?.send {'msg': 'pong'}

  setInterval doPong, 5 * 60 * 1000

  parseWhereTime = (time) ->
    year = time.substring 0, 4
    month = time.substring 4, 6
    day = time.substring 6, 8
    hours = time.substring 8, 10
    minutes = time.substring 10, 12
    seconds = time.substring 12, 14

    return new Date(year, month, day, hours, minutes, seconds)

  formatMorgueTime = (datetime) ->
    year = datetime.getFullYear()
    # add 1 to month, morgue month is NOT UTC
    month = datetime.getMonth() + 1
    month = String('00' + month).slice(-2)
    day = datetime.getDate()
    day = String('00' + day).slice(-2)
    hours = datetime.getHours()
    hours = String('00' + hours).slice(-2)
    minutes = datetime.getMinutes()
    minutes = String('00' + minutes).slice(-2)
    seconds = datetime.getSeconds()
    seconds = String('00' + seconds).slice(-2)

    date = "#{year}#{month}#{day}"
    time = "#{hours}#{minutes}#{seconds}"

    return {date: date, time: time}

  openSocket = ->
    ws = new WebSocket(socketServer, 'no-compression')

    ws.on 'open', ->
      console.log "Socket opened"
      ws.send {msg: 'go_lobby'}

    ws.on 'error', (error) ->
      console.error "WebSocket error: #{error}"

    ws.on 'close', (code, message) ->
      console.log "Socket closed"
      openSocket()

    ws.on 'message', (rawData, flags) ->
      data = JSON.parse(rawData);
      if data.msgs?[0]?.msg is 'ping'
        doPong()
        return
      if firstMsg
        firstMsg = false
        return
      users = ['sollaires','drukna','sieger','apparentbliss','octopanic','beefhammer'];
      if DEBUG
        users.push 'sollairestest'
      msgLen = data.msgs.length;
      if not data.msgs
        console.warn "unknown message: "
        console.warn data
      for msg in data.msgs
        user = msg.username
        if user and user.toLowerCase() in users
          activeGames[msg.id] = user
          prevState = state[user]
          if prevState

            # won the game
            # died

            if msg.milestone and prevState.milestone != msg.milestone
              msgRoom evtMsg(msg, msg.milestone)
            state[user] = msg
          else
            console.log "#{user} started playing DCSS"
            state[user] = msg
        else if not user
          # possible death/win
          if msg.msg is 'lobby_remove' and activeGames[msg.id]
            # get .where file
            user = activeGames[msg.id]
            getWhere user, (err, data) ->
              if err then console.error "get Where error", err
              if data.status in ['dead','won']
                deathMsg = "#{data.name} [#{data.char}, XL #{data.xl}, #{data.place}] "
                if data.status is 'dead'
                  deathMsg += "has died!"
                else if data.status is 'won'
                  deathMsg += "escaped with the orb!\n"
                  deathMsg += "~~~~~~~ Congrats ~~~~~~~~"

                deathMsg += "\n"
                msgRoom deathMsg

                datetime = parseWhereTime data.time
                morgueTime = formatMorgueTime datetime

                getMorgue user, morgueTime.date, morgueTime.time, (err, morgue) ->
                  if err or not morgue.howEnded?
                    # try one second ahead
                    datetimeMinusOne = new Date(datetime.getTime() - 1000)
                    morgueTimeMinusOne = formatMorgueTime datetimeMinusOne
                    d = morgueTimeMinusOne.date
                    t = morgueTimeMinusOne.time
                    getMorgue user, d, t, (err, morgue) ->
                      if err
                        console.error "Could not find morgue file"
                        console.error err
                        msgRoom "Problem finding morgue file"
                      else
                        msgRoom morgue.howEnded.join("\n")
                        msgRoom morgue.url
                  else
                    msgRoom morgue.howEnded.join("\n")
                    msgRoom morgue.url
              else
                console.info "#{activeGames[msg.id]} stopped playing"
              if err then console.error err
          else if msg.msg not in ['lobby_remove','lobby_clear','lobby_complete']
            # message i haven't seen before
            console.info msg

  openSocket()

  msgRoom = (msg) ->
    out = msg
    robot.messageRoom announceRoom, out

  evtMsg = (data, msg) ->
    return "#{data.username} [#{data.char}, XL #{data.xl}, #{data.place}] #{msg}"

  parseWhere = (data) ->
    parsed = {}
    delim = '~~~DELIM-DAVE~~~'
    data = data.trim().replace('::', delim)
    entries = data.split(':')
    for entry in entries
      [key, val] = entry.split('=')
      parsed[key] = val?.replace(delim, ':')
    return parsed

  parseMorgue = (data) ->
    parsed = {}
    lines = data.split "\n"
    gameEndLines = []
    if lines[2].match /^\d+ .* \(level .*HPs\)$/
      i = 2
      while lines[i] != ''
        gameEndLines.push lines[i].trim()
        i++
      parsed.howEnded = gameEndLines
      parsed.status = 'ended'
    else
      parsed.status = 'alive'

    return parsed

  getMorgue = (user, date, time, done) ->
    url = "#{rawData}/#{user}/morgue-#{user}-#{date}-#{time}.txt"
    request url, (err, res, body) ->
      if not err
        morgue = parseMorgue(body)
        morgue.url = url
        done null, morgue
      else
        done err

  getWhere = (user, done) ->
    url = "#{rawData}/#{user}/#{user}.where"
    request url, (err, res, body) ->
      if not err
        done null, parseWhere(body)
      else
        done err

  sequellLastGame = (user, done) ->
    opts =
      url: "#{sequellHost}/game?q=!lg+#{user}"
      json: true
    request opts, (err, res, json) ->
      done(err, json)

  robot.respond /dcss links/i, (msg) ->
    out = """
      http://crawl.akrasiac.org:8080/
      http://menning.me/crawl/
    """
    msg.send out

  robot.respond /dcss where (.*)/i, (msg) ->
    user = msg.match[1]
    getWhere user, (err, data) ->
      if err then console.error err
      out = """
        #{data.name} -- #{data.char}, XL #{data.xl}, #{data.place}, God: #{data.god}
        Turn #{data.turn}
        HP: #{data.hp}/#{data.mhp}, MP: #{data.mp}/#{data.mmp}
        Str: #{data.str}, Int: #{data.int}, Dex: #{data.dex}
        AC: #{data.ac}, EV: #{data.ev}
        Kills: #{data.kills}
        Status: #{data.status}
      """
      msg.send out
