# Description:
#   Retrieves random dad joke.
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   hubot dadjoke - Reply back with random dad joke.
#
# Author:
#   jwinget

module.exports = (robot) ->
	robot.respond /dadjoke$/i, (msg) ->
		msg.http('https://icanhazdadjoke.com')
            .header('Accept', 'application/json')
            .get() (error, response, body) ->
                # passes back the complete reponse
                response = JSON.parse(body)
                if response.success == "true"
                	msg.send response.joke[0]
                else
                	msg.send "Unable to get dad jokes right now."
                  
