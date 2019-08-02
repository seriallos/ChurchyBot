module.exports = (robot) ->
  robot.hear /dad joke/i, (msg) ->
    msg.http("https://icanhazdadjoke.com")
      .header('Accept', 'application/json')
      .get() (err, response, body) ->
        if response.getHeader('Content-Type') isnt 'application/json'
          msg.send "Didn't get back JSON :("
          return
        data = null
        try
          data = JSON.parse body
          msg.send "Parsed JSON"
          msg.send "#{data.joke}"
          return
        catch error
          msg.send "Ran into error parsing JSON :("
          return
