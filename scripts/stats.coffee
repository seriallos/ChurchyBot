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
