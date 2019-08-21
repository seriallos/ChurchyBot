
myfetish = [
  "http://giphygifs.s3.amazonaws.com/media/JxFLe8raHIYhy/giphy.gif",
  "http://giphygifs.s3.amazonaws.com/media/41io4H3B7wSti/giphy.gif",
  "http://giphygifs.s3.amazonaws.com/media/2sWVvF0wMkIyQ/giphy.gif",
  "https://media.giphy.com/media/u6MSNuAAIMaWc/giphy.gif",
  "http://giphygifs.s3.amazonaws.com/media/IPgIu0v6z77c4/giphy.gif"
]

module.exports = (robot) ->

# fry shocked
  robot.hear /shocked/i, (msg) ->
    msg.send "https://media.giphy.com/media/AaQYP9zh24UFi/giphy.gif"
    
# fry not sure
  robot.hear /(fry not sure|not sure if)/i, (msg) ->
    msg.send "http://giphygifs.s3.amazonaws.com/media/ANbD1CCdA3iI8/giphy.gif"
    
# tapping head
  robot.hear /tapping/i, (msg) ->
    msg.send "https://media.giphy.com/media/d3mlE7uhX8KFgEmY/giphy.gif"
    
# wiping tears with money
  robot.hear /(money crying|wiping tears)/i, (msg) ->
    msg.send "http://giphygifs.s3.amazonaws.com/media/94EQmVHkveNck/giphy.gif"
    
  robot.hear /my fetish/i, (msg) ->
     msg.send msg.random myfetish    
    
  robot.hear /fillion (facepalm|confused)/i, (msg) ->
    msg.send "https://giphy.com/gifs/story-conversation-topic-vUEznRmVQfG2Q"

  robot.hear /shut up and take my money/i, (msg) ->
    msg.send "http://i.imgur.com/QlmfC.jpg"
