
myfetish = [
  "http://giphygifs.s3.amazonaws.com/media/JxFLe8raHIYhy/giphy.gif"
]

module.exports = (robot) ->

# fry shocked
  robot.hear /match this expression/i, (msg) ->
    msg.send "URL GOES HERE"
    
# fry not sure
  robot.hear /match this expression/i, (msg) ->
    msg.send "URL GOES HERE"
    
# tapping head
  robot.hear /match this expression/i, (msg) ->
    msg.send "URL GOES HERE"
    
# wiping tears with money
  robot.hear /match this expression/i, (msg) ->
    msg.send "URL GOES HERE"
    
  robot.hear /my fetish/i, (msg) ->
     msg.send msg.random myfetish    
    
  robot.hear /fillion (facepalm|confused)/i, (msg) ->
    msg.send "https://giphy.com/gifs/story-conversation-topic-vUEznRmVQfG2Q"

  robot.hear /shut up and take my money/i, (msg) ->
    msg.send "http://i.imgur.com/QlmfC.jpg"
