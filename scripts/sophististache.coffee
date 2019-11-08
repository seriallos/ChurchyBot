
myfetish = [
  "http://giphygifs.s3.amazonaws.com/media/JxFLe8raHIYhy/giphy.gif",
  "http://giphygifs.s3.amazonaws.com/media/41io4H3B7wSti/giphy.gif",
  "http://giphygifs.s3.amazonaws.com/media/2sWVvF0wMkIyQ/giphy.gif",
  "https://media.giphy.com/media/u6MSNuAAIMaWc/giphy.gif",
  "http://giphygifs.s3.amazonaws.com/media/IPgIu0v6z77c4/giphy.gif"
]

rimshots = [
  "http://giphygifs.s3.amazonaws.com/media/SUeUCn53naadO/giphy.gif",
  "http://giphygifs.s3.amazonaws.com/media/1gArwncRlXac8GIhNy8/giphy.gif",
  "https://media.giphy.com/media/AR0MThYLSnmGQ/giphy.gif",
  "http://giphygifs.s3.amazonaws.com/media/ItAmGFb0uiZz2/giphy.gif",
  "https://media.giphy.com/media/fWgPzLGeI4okiaG8QT/giphy.gif",
  "https://media.giphy.com/media/3oFzmhMIcKK846ku5i/giphy.gif",
  "http://giphygifs.s3.amazonaws.com/media/gKYpJXuvVeryo/giphy.gif"
]

module.exports = (robot) ->

  robot.hear /shocked$/i, (msg) ->
    msg.send "https://media.giphy.com/media/AaQYP9zh24UFi/giphy.gif"
    
  robot.hear /(fry not sure|^not sure if)/i, (msg) ->
    msg.send "http://giphygifs.s3.amazonaws.com/media/ANbD1CCdA3iI8/giphy.gif"
    
  robot.hear /tapping/i, (msg) ->
    msg.send "https://media.giphy.com/media/d3mlE7uhX8KFgEmY/giphy.gif"
    
  robot.hear /(money crying|wiping tears)/i, (msg) ->
    msg.send "http://giphygifs.s3.amazonaws.com/media/94EQmVHkveNck/giphy.gif"
    
  robot.hear /my fetish/i, (msg) ->
     msg.send msg.random myfetish    
    
  robot.hear /(fillion|mal) (facepalm|confused|speechless)/i, (msg) ->
    msg.send "https://giphy.com/gifs/story-conversation-topic-vUEznRmVQfG2Q"

  robot.hear /take my money/i, (msg) ->
    msg.send "http://i.imgur.com/QlmfC.jpg"

  robot.hear /wrong\./i, (msg) ->
    msg.send "https://giphy.com/gifs/ceeN6U57leAhi"
    
  robot.hear /what did you think/i, (msg) ->
    msg.send "https://media.giphy.com/media/YP6GvHrK2bo1q/giphy.gif"
  
  robot.hear /rimshot/i, (msg) ->
    msg.send msg.random rimshots    
    
  robot.hear /(tv mount|mission accomplished|job well done)/i, (msg) ->
    msg.send "https://i.imgur.com/ZidtWtL.jpg"

  robot.hear /ChurchyBot are you alive/i, (msg) ->
    msg.send "https://giphy.com/gifs/game-of-thrones-got-arya-stark-9RKLlD2oz5c7m"

  robot.hear /(Turbine|turbine)/i, (msg) ->
    msg.send "POWERED BY OUR FANS" 
    
  robot.hear /so say we all/i, (msg) ->
    msg.send "https://media.giphy.com/media/NM4E1FcXQK6oE/giphy.gif"
