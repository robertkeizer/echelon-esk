express	= require "express"
io	= require "socket.io"
pcap	= require "pcap"
log	= require( "logging" ).from __filename

log "Starting up.."
app	= express( )

app.use express.logger( )
app.use express.cookieParser( )
app.use express.compress( )
app.use express.session( { "secret": "foooooo you" } )

app.get "/", ( req, res ) ->
	res.end "What?"

app.use ( err, req, res, cb ) ->
	res.json { "error": err }

app.use app.routes

app.listen 8080, ( ) ->
	log "Listening.."
