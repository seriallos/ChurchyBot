# Description:
#   Collect chat stats
#
# Dependencies:
#   lodash
#   async
#   redis-timeseries
#   redis
#   get-urls
#
# Configuration:
#   None
#
# Commands:
#   stats for me
#   stats for <user>
#   stats for <user> in <room>
#   stats for <user> in (here|this room|this channel)
#   room stats for this room
#   room stats for <room>
#
# Author:
#   sollaires

DEBUG = process.env.DEBUG
TEAM_ID = process.env.SLACK_TEAM_ID

_ = require 'lodash'
async = require 'async'
Url = require 'url'
TimeSeries = require('redis-timeseries')
getUrls = require 'get-urls'
fetch = require 'node-fetch'
cheerio = require 'cheerio'

REDIS_HOST = process.env.REDISCLOUD_URL

roomsBlacklist = [
    'Shell'
]

usersBlacklist = [
    'Shell'
]

clog = (args...) ->
  console.log(args) if DEBUG

module.exports = (robot) ->
  redisUrl = Url.parse REDIS_HOST

  redis = require('redis').createClient(redisUrl.port, redisUrl.hostname)
  ts = new TimeSeries(redis, 'slackStats')

  if redisUrl.auth
    redis.auth redisUrl.auth.split(":")[1], (err) ->
      if err
        robot.logger.error "Failed to authenticate to Redis"
      else
        robot.logger.info "Successfully authenticated to Redis"

  redis.on 'ready', () ->
    console.log 'connected to time series redis'

    ##################################################################################
    #
    # Stat collector
    #
    ##################################################################################

    # Record stats on chat
    robot.hear /(.*)/i, (msg) ->
      username = msg.message.user.name
      room = msg.message.room
      text = msg.message.text
      isBot = msg.message.user?.slack?.is_bot

      # private message, ignore these
      if !DEBUG and (username == room)
        return

      if isBot
        return

      # track who spoke in which room
      if DEBUG
        console.log "record time series"
      else
        now = Math.floor(Date.now() / 1000)
        ts.recordHit("spoke:#{username}")
          .recordHit("words:#{username}", now, text.split(/\s/).length)
          .recordHit("room:#{room}")
          .recordHit("room:#{room}:#{username}")
          .exec()

      # track words
      if DEBUG
        console.log text.split /\s/

      # add user to user set
      if DEBUG
        console.log "SADD users,", username
        console.log "SADD users#{username}:roomsSpoken,", username
      else
        redis.sadd 'users', username
        redis.sadd "users:#{username}:roomsSpoken", room

      # add room to room set
      if DEBUG
        console.log "SADD to rooms,", room
        console.log "SADD to rooms:#{room}:spoken,", room
      else
        redis.sadd 'rooms', room
        redis.sadd "rooms:#{room}:spoken", username

      # TODO: break this into smaller/reusable functions
      urls = getUrls text
      urls.forEach (url) ->
        console.log "Detected '#{url}' in chat"
        console.log text
        url = transformUrl(url)
        fetch(url, {method: 'head'})
          .then (response) ->
            type = response.headers.get('content-type')
            data = {
              url: url
              who: username
              when: Math.floor(Date.now() / 1000)
              room: room
            }
            if isImage url, response
              if DEBUG
                console.log "lpush to image:", data
              else
                redis.lpush 'images', JSON.stringify(data)
            else
              fetch(url)
                .then (response) ->
                  return response.text()
                .then (body) ->
                  $ = cheerio.load body
                  pageTitle = $('title').text()
                  twitterTitle = $('meta[name="twitter:title"]').attr('content')
                  facebookTitle = $('meta[name="og:title"]').attr('content')
                  data.title = facebookTitle || twitterTitle || pageTitle || null
                  if DEBUG
                    console.log "lpush to url:", data
                  else
                    redis.lpush 'urls', JSON.stringify(data)

    transformUrl = (url) ->
      if isSlackFile url
        return getSlackImageLink url
      return url

    isImage = (url, response) ->
      type = response.headers.get('content-type')
      if type.match /^image/
        return true
      {pathname} = Url.parse(url)
      if pathname.match /(jpe?g|gif|png)$/
        return true
      return false

    slackFilePattern = new RegExp('slack\.com/files/([^/]+)/([^/]+)/([^/]+)', 'i')

    isSlackFile = (url) ->
      if url.match slackFilePattern
        return true
      else
        return false

    getSlackImageLink = (url) ->
      matches = url.match slackFilePattern
      return "https://files.slack.com/files-pri/#{TEAM_ID}-#{matches[2]}/#{matches[3]}"

    ##################################################################################
    #
    # Chat Responders
    #
    ##################################################################################

    # report stats on room
    robot.respond '/room stats for ([a-z0-9_-]+)$/i', (msg) ->
      if msg.match[1] in ['this room', 'here', 'this channel']
        room = msg.message.room
      else
        room = msg.match[1]

      async.auto({
        speakers: (cb) ->
          redis.smembers("rooms:#{room}:spoken", cb)
        roomTotal: (cb) ->
          ts.getHits("room:#{msg.message.room}", '1day', 7, cb)
        users: ['speakers', (cb, results) ->
          async.concat( results.speakers, (user, icb) ->
            ts.getHits "room:#{room}:#{user}", '1day', 7, (err, data) ->
              icb null, {user: user, data: data}
          , cb
          )
        ]
      }, (err, results) ->
        total = _.reduce(results.roomTotal, ((sum, day) -> sum + day[1]), 0)
        userCounts = _.sortBy(_.map(results.users, (u) ->
            {
              user: u.user,
              count: _.reduce(u.data, ((sum, day) -> sum + day[1]), 0)
            }
          )
          , 'count'
        ).reverse()
        userMsgs = _.map(userCounts, (u) -> "• #{u.user}: #{u.count}")
        userMsgs.unshift("#{total} messages in the last week in ##{room}")
        msg.send userMsgs.join("\n")
      )

    # report stats on user with optional room
    robot.respond '/stats for ([a-z0-9_-]+)( in ([a-z0-9-_]+))?$/i', (msg) ->
      username = msg.match[1]
      if username is 'me'
        username = msg.message.user.name
      if msg.match[2]
        room = msg.match[3]
        if room in ['this room', 'here', 'this channel']
          room = msg.message.room
        key =  "room:#{room}:#{username}"
      else
        key = "spoke:#{username}"

      ts.getHits key, '1day', 7, (err, data) ->
        count = _.reduce(data,((sum, day) -> sum + day[1]), 0)
        out = "#{count} messages in the last week from #{username}"
        if room
          out += " in ##{room}"
        msg.send out

    ##################################################################################
    #
    # HTTP Listeners
    #
    ##################################################################################

    robot.router.get '/hubot/stats/room', (req, res) ->
      redis.smembers 'rooms', (err, data) ->
        redis.smembers 'users', (usersErr, usersData) ->
            res.set 'Access-Control-Allow-Origin', '*'
            # remove usernames and blacklisted rooms
            res.send _.sortBy(_.difference(_.difference(data, roomsBlacklist), usersData))

    robot.router.get '/hubot/stats/user', (req, res) ->
      redis.smembers 'users', (err, data) ->
        res.set 'Access-Control-Allow-Origin', '*'
        res.send _.sortBy(_.difference(data, usersBlacklist))

    robot.router.get '/hubot/stats/room/:room', (req, res) ->
      room = req.params.room
      granularity = req.query.granularity ? '1hour'
      count = req.query.count ? 24
      async.auto({
        activity: (cb) -> ts.getHits "room:#{room}", granularity, count, cb
        users: (cb) -> redis.smembers "rooms:#{room}:spoken", cb
        total: ['activity', (cb, results) ->
          cb(null, _.reduce(results.activity, ((sum, chunk) -> sum + chunk[1]), 0))
        ]
      }, (err, results) ->
        res.set 'Access-Control-Allow-Origin', '*'
        res.send results
      )

    robot.router.get '/hubot/stats/user/:user', (req, res) ->
      user = req.params.user
      granularity = req.query.granularity ? '1hour'
      count = req.query.count ? 24
      async.auto({
        activity: (cb) -> ts.getHits "spoke:#{user}", granularity, count, cb
        rooms: (cb) -> redis.smembers "users:#{user}:roomsSpoken", cb
        total: ['activity', (cb, results) ->
          cb(null, _.reduce(results.activity, ((sum, chunk) -> sum + chunk[1]), 0))
        ]
      }, (err, results) ->
        res.set 'Access-Control-Allow-Origin', '*'
        res.send results
      )

    robot.router.get '/hubot/stats/user/:user/room/:room', (req, res) ->
      user = req.params.user
      room = req.params.room
      granularity = req.query.granularity ? '1hour'
      count = req.query.count ? 24
      ts.getHits "room:#{room}:#{user}", granularity, count, (err, results) ->
        res.set 'Access-Control-Allow-Origin', '*'
        res.send results

    robot.router.get '/hubot/stats/url', (req, res) ->
      redis.lrange 'urls', 0, 100, (err, urls) ->
        res.set 'Access-Control-Allow-Origin', '*'
        res.send _.map(urls, JSON.parse)

    robot.router.get '/hubot/stats/image', (req, res) ->
      redis.lrange 'images', 0, 100, (err, images) ->
        res.set 'Access-Control-Allow-Origin', '*'
        res.send _.map(images, JSON.parse)
