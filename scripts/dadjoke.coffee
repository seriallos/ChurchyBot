module.exports = (robot) ->
  robot.hear /dadjoke/i, (res) ->
    robot.http("https://icanhazdadjoke.com/")
      .header('Accept', 'application/json')
      .get() (err, res, body) ->
        # error checking code here

        data = JSON.parse body
        res.send "#{data.joke}
