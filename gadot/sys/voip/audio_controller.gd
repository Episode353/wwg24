# goes onto an audio_controller with an AudioStreamPlayer (mic input) child
extends Node
@onready var input = $Input
var idx : int
var effect : AudioEffectCapture
var playback : AudioStreamGeneratorPlayback
@onready var output = $Output


func _ready() -> void:
	if is_multiplayer_authority():
		input.bus = "Record"  # mic goes to the capture bus
		var rec_idx := AudioServer.get_bus_index("Record")
		AudioServer.set_bus_mute(rec_idx, true)   # don't monitor locally
		input.stream = AudioStreamMicrophone.new()
		input.play()
		effect = AudioServer.get_bus_effect(rec_idx, 0) as AudioEffectCapture

	# output should be an AudioStreamPlayer with an AudioStreamGenerator
	if not output.playing:
		output.play()
	playback = output.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	if not is_multiplayer_authority(): return
	if not Globals.map_loaded: return

	while effect.can_get_buffer(512):
		# send only to remotes; won't execute locally because of call_remote
		send_data.rpc(effect.get_buffer(512))


# if not "call_remote," then the player will hear their own voice
# also don't try and do "unreliable_ordered." didn't work from my experience
@rpc("any_peer", "call_remote", "reliable")
func send_data(data: PackedVector2Array) -> void:
	# runs only on other peers
	for i in data.size():
		playback.push_frame(data[i])
