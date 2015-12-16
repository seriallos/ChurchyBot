#
# Description:
#   Get the movie poster and synposis for a given query
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   hubot imdb the matrix
#
# Author:
#   orderedlist

module.exports = (robot) ->
  robot.respond /(imdb|movie)( me)? (.*)/i, (msg) ->
    query = msg.match[3]
    msg.http("http://omdbapi.com/")
      .query({
        t: query
      })
      .get() (err, res, body) ->
        movie = JSON.parse(body)
        console.log movie
        if movie
          text = "#{movie.Title} (#{movie.Year})\n"
          text += "IMDB: #{movie.imdbRating} MS: #{movie.Metascore}\n"
          text += "#{movie.Poster}\n" if movie.Poster
          text += "#{movie.Plot}"

          robot.emit 'slack-attachment', {
            channel: msg.envelope.room
            username: msg.robot.name
            attachments: [{
              title: "#{movie.Title} (#{movie.Year})"
              thumb_url: movie.Poster
              text: movie.Plot
              fields: [{
                title: 'IMDB Rating'
                value: movie.imdbRating
                short: true
              }, {
                title: 'MetaCritic Score'
                value: movie.Metascore
                short: true
              }]
            }]
          }
        else
          msg.send "No movie found"
