# Description:
#   Collect chat stats
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#
# Author:
#   sollaires

REDIS_HOST = process.env.REDISCLOUD_URL

TimeSeries = require('redis-timeseries')
redis = require('redis').createClient(REDIS_HOST)

ts = new TimeSeries(redis, 'slackStats')

module.exports = (robot) ->
  redis.on 'ready', () ->
    console.log 'connected to time series redis'

    robot.hear /(.*)/i, (msg) ->
      console.log msg.message
      username = msg.message.user.name
      room = msg.message.room
      ts.recordHit("spoke:#{username}")
        .recordHit("room:#{room}")
        .recordHit("room:#{room}:#{username}")
        .exec()

      ts.getHits "spoke:#{username}", "1day", 1, (err, data) ->
        if err
          console.log err
        console.log "user messages today"
        console.log data

      ts.getHits "room:#{room}", "1day", 1, (err, data) ->
        if err
          console.log err
        console.log "room messages today"
        console.log data
