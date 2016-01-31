# Description:
#   Collect chat stats
#
# Dependencies:
#   lodash
#   redis-timeseries
#   redis
#
# Configuration:
#   None
#
# Commands:
#   stats for <user>
#   stats for <user> in <room>
#   stats for <user> in this room
#   stats for this room
#
# Author:
#   sollaires

_ = require 'lodash'
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
      console.log msg.message
      username = msg.message.user.name
      room = msg.message.room
      ts.recordHit("spoke:#{username}")
        .recordHit("room:#{room}")
        .recordHit("room:#{room}:#{username}")
        .exec()

    # report stats on room
    robot.respond '/stats for this room$/i', (msg) ->
      room = msg.message.room
      ts.getHits "room:#{msg.message.room}", '1day', 7, (err, data) ->
        console.log data
        count = _.reduce(data,((sum, day) -> sum + day[1]), 0)
        msg.send "#{count} messages in the last week in ##{room}"

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
