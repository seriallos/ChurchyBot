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

OMDB_API_KEY = process.env.OMDB_API_KEY

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
        poster = "http://img.omdbapi.com/?i=#{movie.imdbID}&apikey=#{OMDB_API_KEY}"
        if not movie.Error
          robot.emit 'slack-attachment', {
            channel: msg.envelope.room
            username: msg.robot.name
            attachments: [{
              title: "#{movie.Title} (#{movie.Year})"
              title_link: if movie.imdbID then "http://www.imdb.com/title/#{movie.imdbID}" else ''
              thumb_url: if OMDB_API_KEY then poster else ''
              text: movie.Plot
              fields: [{
                title: 'TomatoMeter'
                value: movie.tomatoMeter
                short: true
              }, {
                title: 'MetaCritic'
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
