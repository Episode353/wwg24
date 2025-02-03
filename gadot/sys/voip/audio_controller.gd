# goes onto an audio_controller with an AudioStreamPlayer (mic input) child
extends Node
@onready var input = $Input
var idx : int
var effect : AudioEffectCapture
var playback : AudioStreamGeneratorPlayback
@onready var output = $Output


func _ready() -> void:
	# we only want to initalize the mic for the peer using it
	if (is_multiplayer_authority()):
		input.stream = AudioStreamMicrophone.new()
		input.play()
		idx = AudioServer.get_bus_index("Record")
		effect = AudioServer.get_bus_effect(idx, 0)
		# replace 0 with whatever index the capture effect is
			
	# playback variable will be needed for playback on other peers	
	playback = output.get_stream_playback()

func _process(delta: float) -> void:
	if (not is_multiplayer_authority()): return
	if (effect.can_get_buffer(512) && playback.can_push_buffer(512)):
		send_data.rpc(effect.get_buffer(512))
	effect.clear_buffer()

# if not "call_remote," then the player will hear their own voice
# also don't try and do "unreliable_ordered." didn't work from my experience
@rpc("any_peer", "call_remote", "reliable")
func send_data(data : PackedVector2Array):
	for i in range(0,512):
		playback.push_frame(data[i])
