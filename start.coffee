fs	= require "fs"

async	= require "async"
express	= require "express"
io	= require "socket.io"
pcap	= require "pcap"
log	= require( "logging" ).from __filename

log "Starting up.."

async.waterfall [
	( cb ) ->
		# Load up the config and parse it.
		async.waterfall [
			( cb ) ->
				fs.exists "config.json", ( exists ) ->
					if not exists
						return cb "Couldn't find config.json"
					return cb null
			, ( cb ) ->
				fs.readFile "config.json", ( err, data ) ->
					if err
						return cb "Couldn't open config file: " + err
					cb null, data
			, ( data, cb ) ->
				try
					config = JSON.parse data
				catch err
					return cb "Unable to parse config file: " + err
				cb null, config
			], ( err, config ) ->
				if err
					log err
					process.exit 1

				cb null, config
	, ( config, cb ) ->
		# Verify that all the required configuration values are defined.

		for req in [ "port", "web_root" ]
			if not config[req]?
				return cb "'" + req + "' wasn't defined in the configuration."
		return cb null, config

	, ( config, cb ) ->
		# Setup express and listen on the correct port.

		app	= express( )

		app.use express.logger( )
		app.use express.cookieParser( )
		app.use express.compress( )
		app.use express.session( { "secret": "foooooo you" } )
		app.use express.static config.web_root

		app.get "/", ( req, res ) ->
			res.writeHead 302, { "location": "/index.html" }
			res.end( )

		app.use ( err, req, res, cb ) ->
			res.json { "error": err }

		app.use app.routes

		app.listen config["port"], ( ) ->
			return cb null, { "config": config, "app": app }

	], ( err, startup ) ->
		if err
			log "Fatal error: " + err
			process.exit 1

		log "Listening on port " + startup.config.port + ".."
