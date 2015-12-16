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
        t: query,
        tomatoes: true
      })
      .get() (err, res, body) ->
        movie = JSON.parse(body)
        console.log movie
        if not movie.Error
          robot.emit 'slack-attachment', {
            channel: msg.envelope.room
            username: msg.robot.name
            attachments: [{
              title: "#{movie.Title} (#{movie.Year})"
              title_url: "http://www.imdb.com/title/#{movie.imdbID}" if movie.imdbID else ''
              icon_url: movie.Poster
              text: movie.Plot
              fields: [{
                title: 'IMDB Rating'
                value: movie.imdbRating
                short: true
              }, {
                title: 'MetaCritic Score'
                value: movie.Metascore
                short: true
              }, {
                title: 'Rated'
                value: movie.Rated
                short: true
              }, {
                title: 'Runtime'
                value: movie.Runtime
                short: true
              }]
            }]
          }
        else
          msg.send "No movie found"
