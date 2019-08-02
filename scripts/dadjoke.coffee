module.exports = (robot) ->
  robot.hear /dadjoke/i, (res) ->
    res.send "Did someone ask for a dadjoke?"
