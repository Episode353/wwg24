extends Node3D
@onready var player_self = $"../../../../../.."

# Called when the node enters the scene tree for the first time.
func _ready():
	_time_since_last_note = 0.0  # Initialize elapsed time since the last note press
	max_time_between_notes = 3.0  # Maximum time (in seconds) between note presses

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	_time_since_last_note += delta  # Increment elapsed time
	handle_keyboard_input()

# Predefined list of actions
var numpad_actions = [
	"C", "CS", "D", "DS",
	"E", "F", "FS", "G",
	"GS", "A", "AS", "B"
]

# Map spells to their respective key sequences
var spell_sequences = {
	"fireball": ["C", "CS", "D"],
	"heal": ["DS", "E", "F"],
	"shield": ["FS", "G", "GS"]
}

# Track the sequence of pressed keys
var key_sequence = []
var max_sequence_length = 3  # Maximum length of key sequence to track

# Time control variables
var _time_since_last_note = 0.0  # Tracks time since the last note was pressed
var max_time_between_notes = 3.0  # Maximum time (in seconds) allowed between notes

func handle_keyboard_input():
	for action in numpad_actions:
		if Input.is_action_just_pressed(action):
			print(action + " Pressed")
			if _time_since_last_note <= max_time_between_notes:
				update_key_sequence(action)
			else:
				print("Time exceeded, resetting sequence")
				key_sequence.clear()  # Reset the sequence if time exceeded
			_time_since_last_note = 0.0  # Reset the time tracker after pressing a note

func update_key_sequence(action: String):
	# Add the action to the sequence
	key_sequence.append(action)
	
	# Trim the sequence if it exceeds the maximum length
	if key_sequence.size() > max_sequence_length:
		key_sequence.pop_front()
	
	# Check if the sequence matches any spell
	check_spell_activation()

func check_spell_activation():
	for spell_name in spell_sequences:
		if key_sequence == spell_sequences[spell_name]:
			print("Spell activated: " + spell_name)
			activate_spell(spell_name)
			key_sequence.clear()  # Clear the sequence after activation

func activate_spell(spell_name: String):
	# Perform spell-specific actions here
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
