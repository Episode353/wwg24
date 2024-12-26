extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
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

func handle_keyboard_input():
	for action in numpad_actions:
		if Input.is_action_just_pressed(action):
			print(action + " Pressed")
			update_key_sequence(action)

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
			print("Casting Fireball!")
		"heal":
			print("Casting Heal!")
		"shield":
			print("Casting Shield!")
