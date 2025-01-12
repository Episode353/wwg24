extends Node

@onready var http_request = $HTTPRequest
@onready var menu_nodes = $"../MenuNodes"
@onready var server_browser = $"../MenuNodes/CanvasLayer/MainMenu/MarginContainer/VBoxContainer/ServerBrowser"
@onready var servers = $"../MenuNodes/CanvasLayer/MainMenu/MarginContainer/VBoxContainer/ServerBrowser/Servers"


# We'll store a reference to our Timer
var server_list_timer: Timer

func _ready():
	# We immediately fetch once at startup
	print("Immediate fetch_server_list()")
	fetch_server_list()

	# Then set up a timer to periodically fetch the list
	setup_server_list_timer()

# Create the timer, connect it, and start it
func setup_server_list_timer():
	server_list_timer = Timer.new()
	server_list_timer.wait_time = 5.0  # Fetch every 10 seconds, adjust as needed
	server_list_timer.one_shot = false
	server_list_timer.connect("timeout", Callable(self, "_on_server_list_timer_timeout"))
	add_child(server_list_timer)
	server_list_timer.start()

func _on_server_list_timer_timeout():
	# Called every time the timer fires
	fetch_server_list()

func fetch_server_list():
	var request: String = "http://%s/list_servers" % [Globals.IP_SERVER_BROWSER]
	var error = http_request.request(request, [], false)  # 'false' for no SSL
	if error != OK:
		print("Error fetching server list. ErrorCode: %s" % error)

func _on_http_request_request_completed(_result, _response_code, _headers, body):
	var json = JSON.new()
	var parse_error = json.parse(body.get_string_from_utf8())

	if parse_error == OK:
		var parsed_data = json.get_data()
		if "servers" in parsed_data:
			var server_list = parsed_data["servers"]
			servers.clear()  # Clear any existing items

			for server_data in server_list:
				var ip_address = server_data.get("ip_address", "Unknown")
				var map_name = server_data.get("map_name", "Unknown")
				var players = server_data.get("num_players", "0")

				var server_label = "%s:%s | %s players | Map: %s" % [
					ip_address, Globals.PORT_UDP_COMM, players, map_name
				]

				var idx = servers.add_item(server_label)
				var address = "%s:%s" % [ip_address, Globals.PORT_UDP_COMM]
				servers.set_item_metadata(idx, address)
		else:
			print("No 'servers' field in the response.")
	else:
		print("Error parsing server list response. Code: %s" % parse_error)
		print("Response Body: %s" % body.get_string_from_utf8())

func _on_servers_item_activated(index):
	var address = servers.get_item_metadata(index)
	menu_nodes.switch_scene_and_run_func("res://world.tscn", "start_join", address)

func _exit_tree():
	# Optionally stop/free the timer if you want to stop polling
	if server_list_timer and server_list_timer.is_inside_tree():
		server_list_timer.stop()
		server_list_timer.queue_free()
		server_list_timer = null
