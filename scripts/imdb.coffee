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
        if movie
          text = "#{movie.Title} (#{movie.Year})\n"
          text += "IMDB: #{movie.imdbRating} MS: #{movie.Metascore}\n"
          text += "#{movie.Poster}\n" if movie.Poster
          text += "#{movie.Plot}"

          msg.send text
        else
          msg.send "That's not a movie, yo."
