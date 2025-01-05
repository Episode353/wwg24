extends Node3D

@onready var player_self = $"../../../../../.."
@onready var keyboard_animation_player = $the_power/keyboard_animation_player

# Map spells to their respective key sequences
var spell_sequences = {
	"fireball": ["C", "CS", "D"],
	"heal": ["DS", "E", "F"],
	"shield": ["FS", "G", "GS"]
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

func _ready():
	_time_since_last_note = 0.0
	
	# Connect the `animation_finished` signal to `_on_animation_finished` using Callable
	keyboard_animation_player.connect("animation_finished", Callable(self, "_on_animation_finished"))


func _process(delta):
	if is_visible_in_tree():
		_time_since_last_note += delta
		handle_keyboard_input()


func handle_keyboard_input():
	# Check for pressed actions to build spell sequences
	for action in numpad_actions:
		if Input.is_action_just_pressed(action):
			print(action + " Pressed")
			if _time_since_last_note <= max_time_between_notes:
				update_key_sequence(action)
			else:
				print("Time exceeded, resetting sequence")
				key_sequence.clear()  # Reset the sequence if time exceeded
			_time_since_last_note = 0.0  # Reset the time tracker after pressing a note
	
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
			if player_self.mana >= 2:
				player_self.rpc("receive_mana", -2)
				print("Casting Fireball!")
			else:
				print("Not enough Mana to cast Fireball")
		"heal":
			if player_self.mana >= 5:
				if player_self.health >= 100:
					print("You already have max Health!")
					return
				print("Casting Heal!")
				player_self.rpc("receive_health", 5)
				player_self.rpc("receive_mana", -5)
			else:
				print("Not enough Mana to cast Heal")
		"shield":
			print("Casting Shield!")
