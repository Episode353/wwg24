extends Node

@onready var httpRequest: HTTPRequest = $HTTPRequest
@onready var world = $".."




var serverBrowserReached: bool = false



func send_server_info(ip_adress):
	print("sending Server Info")
	var status = httpRequest.get_http_client_status()
	
	if status == HTTPClient.STATUS_DISCONNECTED:
		var request_url: String = "http://%s/register_server" % [Globals.IP_SERVER_BROWSER]

		var map_name = world.map_name if is_instance_valid(world) else "Unknown"
		var num_players = str(get_tree().get_nodes_in_group("players").size())
		print(get_tree().get_nodes_in_group("players"))
		# Optionally, specify your external server port if it's different from the default
		var body = {
			"ip_address": ip_adress,
			"port": Globals.PORT_UDP_COMM,
			"map_name": map_name,
			"num_players": num_players
		}
		
		var error = httpRequest.request(
			request_url,
			[], # headers
			HTTPClient.METHOD_POST,
			JSON.stringify(body)
		)
		
		if error != OK:
			emit_signal("ConsoleMessage", "Error connecting to Server Browser. ErrorCode: %s" % error)
	elif status != HTTPClient.STATUS_CONNECTING:
		if serverBrowserReached:
			emit_signal("ConsoleMessage", "Lost connection to remote Server Browser. Scanning for local servers only.")
			serverBrowserReached = false
