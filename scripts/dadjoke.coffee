module.exports = (robot) ->
  robot.hear /dad joke/i, (res) ->
    robot.http("https://icanhazdadjoke.com")
      .header('Accept', 'application/json')
      .get() (err, response, body) ->
        if response.getHeader('Content-Type') isnt 'application/json'
          res.send "Didn't get back JSON :("
          return
        data = null
        try
          data = JSON.parse body
        catch error
          res.send "Ran into error parsing JSON :("
          return
    res.send "#{data.joke}"
