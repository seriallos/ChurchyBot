# Description:
#   Collect chat stats
#
# Dependencies:
#   lodash
#   async
#   redis-timeseries
#   redis
#
# Configuration:
#   None
#
# Commands:
#   stats for me
#   stats for <user>
#   stats for <user> in #<room>
#   stats for <user> in (here|this room|this channel)
#   stats for this room
#   stats for #<room>
#
# Author:
#   sollaires

_ = require 'lodash'
async = require 'async'
Url = require 'url'
TimeSeries = require('redis-timeseries')

REDIS_HOST = process.env.REDISCLOUD_URL

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

    # Record stats on chat
    robot.hear /(.*)/i, (msg) ->
      username = msg.message.user.name
      room = msg.message.room
      # track metrics
      ts.recordHit("spoke:#{username}")
        .recordHit("room:#{room}")
        .recordHit("room:#{room}:#{username}")
        .exec()

      # add user to user set
      redis.sadd 'users', username
      redis.sadd "users:#{username}:roomsSpoken", room

      # add room to room set
      redis.sadd 'rooms', room
      redis.sadd "rooms:#{room}:spoken", username

    # report stats on room
    robot.respond '/stats for (this room|#([a-z0-9_-]+))$/i', (msg) ->
      if msg.match[1] in ['this room', 'here', 'this channel']
        room = msg.message.room
      else
        room = msg.match[2]

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
    robot.respond '/stats for ([a-z0-9_-]+)( in #([a-z0-9-_]+))?$/i', (msg) ->
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

    robot.router.get '/hubot/stats/room/:room', (req, res) ->
      console.log "GET /hubot/stats/room/#{req.params.room}"
      ts.getHits "room:#{req.params.room}", '1hour', 24, (err, data) ->
        res.send data

    robot.router.get '/hubot/stats/user/:user', (req, res) ->
      console.log "GET /hubot/stats/user/#{req.params.user}"
      ts.getHits "spoke:#{req.params.user}", '1hour', 24, (err, data) ->
        res.send data

