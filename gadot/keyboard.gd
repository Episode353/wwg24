extends Node3D

@onready var player_self: CharacterBody3D = $"../../../../../.."
@onready var keyboard_animation_player: AnimationPlayer = $the_power/keyboard_animation_player
@onready var main_camera: Camera3D = $"../../.."

var speed_mana_cost: int = 5
var heal_mana_cost: int = 5
var fireball_mana_cost: int = 2
# Map spells to their respective key sequences
var spell_sequences = {
	"fireball": ["C", "CS", "D"],
	"heal": ["DS", "E", "F"],
	"shield": ["FS", "G", "GS"],
	"speed": ["E", "DS", "E"]
}
var key_sequence = []
var max_sequence_length = 3  # Maximum length of key sequence to track

# Predefined list of actions
var numpad_actions = [
	"C", "CS", "D", "DS",
	"E", "F", "FS", "G",
	"GS", "A", "AS", "B"
]

# Time control variables
var _time_since_last_note = 0.0  # Tracks time since the last note was pressed
var max_time_between_notes = 3.0  # Maximum time (in seconds) allowed between notes

# Queue for animations
var _animation_queue: Array[String] = []
var _is_anim_playing: bool = false

# New variable to track if an extra (air) speed boost is available.
var can_air_speed_boost: bool = true

# Synth notes, index matches numpad_actions (C4 up to B4)
const SYNTH_MIX_RATE: int = 44100
const SYNTH_NOTE_LENGTH: float = 0.8
const SYNTH_BASE_FREQUENCY: float = 261.63
static var _note_streams: Array[AudioStreamWAV] = []
var _synth_playback: AudioStreamPlaybackPolyphonic

func _ready():
	_time_since_last_note = 0.0
	# Connect the `animation_finished` signal to `_on_animation_finished` using Callable
	keyboard_animation_player.connect("animation_finished", Callable(self, "_on_animation_finished"))
	_setup_synth()

func _process(delta):
	if is_visible_in_tree() and is_multiplayer_authority() and not player_self.is_bot:
		if player_self.is_dead or Globals.paused:
			return
		_time_since_last_note += delta
		handle_keyboard_input()

func handle_keyboard_input():
	var input_received = false

	if Input.is_action_just_pressed("shoot"):
		activate_spell("fireball")
	if Input.is_action_just_pressed("alt_fire"):
		activate_spell("speed")
	
	# Check for pressed actions to build spell sequences
	for note_index in numpad_actions.size():
		var action = numpad_actions[note_index]
		if Input.is_action_just_pressed(action):
			input_received = true
			rpc("play_note", note_index)
			print(action + " Pressed")
			if _time_since_last_note <= max_time_between_notes:
				update_key_sequence(action)
			else:
				print("Time exceeded, resetting sequence")
				key_sequence.clear()  # Reset the sequence if time exceeded
			_time_since_last_note = 0.0  # Reset the time tracker after pressing a note
	
	# Whenever any key is pressed, check if the player is on the ground.
	# If so, re-enable the air boost (this resets the extra boost whenever the player lands).
	if input_received == false and player_self.is_on_floor():
		can_air_speed_boost = true

	# Now queue up the key activate/deactivate animations
	if Input.is_action_just_pressed("C"):
		queue_animation("key_01_activate")
	if Input.is_action_just_released("C"):
		queue_animation("key_01_deactivate")
	if Input.is_action_just_pressed("CS"):
		queue_animation("key_02_activate")
	if Input.is_action_just_released("CS"):
		queue_animation("key_02_deactivate")
	if Input.is_action_just_pressed("D"):
		queue_animation("key_03_activate")
	if Input.is_action_just_released("D"):
		queue_animation("key_03_deactivate")
	if Input.is_action_just_pressed("DS"):
		queue_animation("key_04_activate")
	if Input.is_action_just_released("DS"):
		queue_animation("key_04_deactivate")
	if Input.is_action_just_pressed("E"):
		queue_animation("key_05_activate")
	if Input.is_action_just_released("E"):
		queue_animation("key_05_deactivate")
	if Input.is_action_just_pressed("F"):
		queue_animation("key_06_activate")
	if Input.is_action_just_released("F"):
		queue_animation("key_06_deactivate")
	if Input.is_action_just_pressed("FS"):
		queue_animation("key_07_activate")
	if Input.is_action_just_released("FS"):
		queue_animation("key_07_deactivate")
	if Input.is_action_just_pressed("G"):
		queue_animation("key_08_activate")
	if Input.is_action_just_released("G"):
		queue_animation("key_08_deactivate")
	if Input.is_action_just_pressed("GS"):
		queue_animation("key_09_activate")
	if Input.is_action_just_released("GS"):
		queue_animation("key_09_deactivate")
	if Input.is_action_just_pressed("A"):
		queue_animation("key_10_activate")
	if Input.is_action_just_released("A"):
		queue_animation("key_10_deactivate")
	if Input.is_action_just_pressed("AS"):
		queue_animation("key_11_activate")
	if Input.is_action_just_released("AS"):
		queue_animation("key_11_deactivate")
	if Input.is_action_just_pressed("B"):
		queue_animation("key_12_activate")
	if Input.is_action_just_released("B"):
		queue_animation("key_12_deactivate")

func update_key_sequence(action: String):
	# Add the action to the sequence
	key_sequence.append(action)
	
	# Trim the sequence if it exceeds the maximum length
	if key_sequence.size() > max_sequence_length:
		key_sequence.pop_front()
	
	# Check if the sequence matches any spell
	check_spell_activation()

## QUEUE-RELATED FUNCTIONS ##

func queue_animation(anim_name: String) -> void:
	# Push the requested animation to the queue
	_animation_queue.append(anim_name)
	# If we're not currently playing any animation, play the next one
	if not _is_anim_playing:
		_play_next_animation()

func _play_next_animation() -> void:
	if _animation_queue.size() == 0:
		return  # Nothing to play
	var next_anim = _animation_queue.pop_front()
	_is_anim_playing = true
	keyboard_animation_player.play(next_anim)

func _on_animation_finished(animation_name: String) -> void:
	# Once an animation is finished, set to not playing
	_is_anim_playing = false
	# Check if there's another animation to play
	_play_next_animation()

## SYNTH FUNCTIONS ##

func _setup_synth() -> void:
	if _note_streams.is_empty():
		for note_index in numpad_actions.size():
			_note_streams.append(_build_note_stream(SYNTH_BASE_FREQUENCY * pow(2.0, note_index / 12.0)))

	var polyphonic := AudioStreamPolyphonic.new()
	polyphonic.polyphony = 24
	var synth_player := AudioStreamPlayer3D.new()
	synth_player.name = "SynthPlayer"
	synth_player.stream = polyphonic
	add_child(synth_player)
	synth_player.play()
	_synth_playback = synth_player.get_stream_playback()

@rpc("authority", "call_local", "unreliable_ordered")
func play_note(note_index: int) -> void:
	if _synth_playback and note_index >= 0 and note_index < _note_streams.size():
		_synth_playback.play_stream(_note_streams[note_index])

# Two detuned saws plus a square an octave down, through a low-pass that closes after the attack
static func _build_note_stream(frequency: float) -> AudioStreamWAV:
	var sample_count := int(SYNTH_MIX_RATE * SYNTH_NOTE_LENGTH)
	var attack_samples := SYNTH_MIX_RATE * 0.005
	var release_start := sample_count - int(SYNTH_MIX_RATE * 0.05)
	var step_a := frequency * 1.003 / SYNTH_MIX_RATE
	var step_b := frequency * 0.997 / SYNTH_MIX_RATE
	var step_sub := frequency * 0.5 / SYNTH_MIX_RATE
	var amp_decay := exp(-3.0 / SYNTH_MIX_RATE)
	var filter_decay := exp(-10.0 / SYNTH_MIX_RATE)

	var phase_a := 0.0
	var phase_b := 0.0
	var phase_sub := 0.0
	var amp := 1.0
	var filter_sweep := 1.0
	var filtered := 0.0
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		phase_a = fmod(phase_a + step_a, 1.0)
		phase_b = fmod(phase_b + step_b, 1.0)
		phase_sub = fmod(phase_sub + step_sub, 1.0)
		var raw := 2.0 * (phase_a + phase_b) - 2.0 + (0.6 if phase_sub < 0.5 else -0.6)
		var w := TAU * (600.0 + 5000.0 * filter_sweep) / SYNTH_MIX_RATE
		filtered += w / (1.0 + w) * (raw - filtered)
		var envelope := amp * minf(i / attack_samples, 1.0)
		if i > release_start:
			envelope *= float(sample_count - i) / (sample_count - release_start)
		data.encode_s16(i * 2, int(clampf(filtered * envelope * 0.3, -1.0, 1.0) * 32767.0))
		amp *= amp_decay
		filter_sweep *= filter_decay

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SYNTH_MIX_RATE
	stream.data = data
	return stream

## SPELL HANDLING FUNCTIONS ##

func check_spell_activation():
	for spell_name in spell_sequences:
		if key_sequence == spell_sequences[spell_name]:
			print("Spell activated: " + spell_name)
			activate_spell(spell_name)
			key_sequence.clear()  # Clear the sequence after activation

func activate_spell(spell_name: String):
	match spell_name:
		"fireball":
			if player_self.mana >= fireball_mana_cost:
				player_self.rpc("receive_mana", -fireball_mana_cost)
				player_self.rpc("launch_fireball")
			else:
				print("Not enough Mana to cast Fireball")
		"heal":
			if player_self.mana >= heal_mana_cost:
				if player_self.health >= 100:
					print("You already have max Health!")
					return
				print("Casting Heal!")
				player_self.rpc("receive_health", heal_mana_cost)
				player_self.rpc("receive_mana", -heal_mana_cost)
			else:
				print("Not enough Mana to cast Heal")
		"shield":
			print("Casting Shield!")
		"speed":
			if player_self.mana >= speed_mana_cost:
				# If the player is on the ground, the boost is always allowed.
				if player_self.is_on_floor():
					# On the ground, we also reset the air boost flag.
					can_air_speed_boost = true
					player_self.rpc("receive_mana", -speed_mana_cost)
					print("Casting Speed (Ground Boost)")
					var impulse_strength = 20
					var forward_direction = -main_camera.global_transform.basis.z.normalized()
					player_self.velocity += forward_direction * impulse_strength
				# If the player is in the air and has not used the extra boost yet...
				elif can_air_speed_boost:
					can_air_speed_boost = false
					player_self.rpc("receive_mana", -speed_mana_cost)
					print("Casting Speed (Air Boost)")
					var impulse_strength = 20
					var forward_direction = -main_camera.global_transform.basis.z.normalized()
					player_self.velocity += forward_direction * impulse_strength
				else:
					print("Speed boost not available mid-air")
			else:
				print("Not enough Mana to cast Speed")
