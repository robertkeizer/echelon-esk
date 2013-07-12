fs	= require "fs"
http	= require "http"
os	= require "os"
async	= require "async"
express	= require "express"
sio	= require "socket.io"
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

		auth	= ( user, pass, cb ) ->
			cb null, ( user is 'user' and pass is 'pass' )

		error_out = ( res, o ) ->
			return res.json { "error": o }

		missing_arg = ( res, arg ) ->
			return error_out res, { "name": "missing_argument", "argument": arg }

		req_interface = ( req, res, cb ) ->
			if not req.query.interface?
				return missing_arg res, "interface"

			if not req.query.interface in os.networkInterfaces( )
				return error_out res, "invalid_interface_specified"

			return cb( null )


		_handle_packet = ( packet ) ->
			# Figure out all the data we'll need
			# from the packet.. also call any socket.io stuff..

		app.use express.logger( )
		app.use express.cookieParser( )
		app.use express.compress( )
		app.use express.session( { "secret": "foooooo you" } )
		app.use express.basicAuth auth
		app.use express.static config.web_root

		pcap_sessions	= { }

		app.get "/start", req_interface, ( req, res ) ->
			# Return true if we're already listening.
			if req.query.interface in pcap_sessions
				return res.json true
	
			log "Starting packet capture on interface " + req.query.interface

			# Start the pcap filtering here.. 
			_session = pcap.createSession req.query.interface, ""

			# Handle packets that get generated. Parse them and move them along.
			_session.on "packet", ( raw_packet ) ->
				_packet = pcap.decode.packet raw_packet
				handle_packet _packet

			# Include new pcap session in pcap_sessions so that we don't start
			# multiples on the same interface when a client asks for an existing one.
			pcap_sessions[req.query.interface] = _session

			res.json true

		app.get "/stop", req_interface, ( req, res ) ->

			# Sanity of not running..
			if req.query.interface not in pcap_sessions
				return error_out res, "not_running"
			
			# Close the listening pcap session..
			pcap_sessions[req.query.interface].close( )
			
			# delete the actual object so that v8 knows to get rid of it.
			del pcap_sessions[req.query.interface]

		app.get "/interfaces", ( req, res ) ->
			res.json os.networkInterfaces( )

		app.get "/", ( req, res ) ->
			res.writeHead 302, { "location": "/index.html" }
			res.end( )

		app.use ( err, req, res, cb ) ->
			res.json { "error": err }

		app.use app.routes

		http_server	= http.createServer app
		io		= sio.listen http_server

		http_server.listen config["port"], ( ) ->
			return cb null, config, app, io

	, ( config, app, io, cb ) ->
		# Setup socket.io handlers here..

		io.sockets.on "connection", ( socket ) ->
			# Do something funky with the socket.
			log "new connection on socket side."
		
		return cb null, { "config": config, "app": app, "io": io }

	], ( err, runtime ) ->
		if err
			log "Fatal error: " + err
			process.exit 1

		log "Listening on port " + runtime.config.port + ".."
