@tool
extends EditorPlugin

# Must match $Port in trenchbroom/launch_godot.ps1
const PORT: int = 6018
# Must match the env var read in sys/globals.gd
const LAUNCH_MAP_ENV := "WWG_LAUNCH_MAP"

var _server := TCPServer.new()
var _clients: Array[StreamPeerTCP] = []
var _buffers: Dictionary = {}


func _enter_tree() -> void:
	var err := _server.listen(PORT, "127.0.0.1")
	if err != OK:
		push_warning("TrenchBroom Launch: could not listen on 127.0.0.1:%d (error %d)" % [PORT, err])


func _exit_tree() -> void:
	for client in _clients:
		client.disconnect_from_host()
	_clients.clear()
	_buffers.clear()
	_server.stop()


func _process(_delta: float) -> void:
	while _server.is_connection_available():
		var client := _server.take_connection()
		_clients.append(client)
		_buffers[client] = ""

	for client: StreamPeerTCP in _clients.duplicate():
		client.poll()
		if client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_drop_client(client)
			continue

		var available := client.get_available_bytes()
		if available > 0:
			_buffers[client] += client.get_utf8_string(available)

		var message: String = _buffers[client]
		if message.contains("\n"):
			var map_name := message.get_slice("\n", 0).strip_edges()
			client.put_data("OK\n".to_utf8_buffer())
			_drop_client(client)
			_play_map(map_name)


func _drop_client(client: StreamPeerTCP) -> void:
	client.disconnect_from_host()
	_clients.erase(client)
	_buffers.erase(client)


func _play_map(map_name: String) -> void:
	if map_name.is_empty():
		return

	print("TrenchBroom Launch: playing '%s' in offline mode" % map_name)
	# The game process inherits the editor's environment. Godot 4.6 ignores
	# runtime changes to editor/run/main_run_args, so an env var is used instead.
	OS.set_environment(LAUNCH_MAP_ENV, map_name)
	EditorInterface.play_main_scene()

	# Only set for this launch so the normal Play button is unaffected.
	await get_tree().create_timer(2.0).timeout
	OS.unset_environment(LAUNCH_MAP_ENV)
