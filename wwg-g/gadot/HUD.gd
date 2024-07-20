extends CanvasLayer

@onready var current_weapon_label: Label = $VBoxContainer/HBoxContainer/CurrentWeapon
@onready var current_ammo_label: Label = $VBoxContainer/HBoxContainer2/CurrentAmmo
@onready var weapon_stack_label: Label = $VBoxContainer/HBoxContainer3/WeaponStack

func _on_weapons_manager_update_ammo(Ammo: Array[int]) -> void:
	current_ammo_label.set_text(str(Ammo[0]) + "/" + str(Ammo[1]))

func _on_weapons_manager_update_weapon_stack(Weapon_Stack: Array[String]) -> void:
	weapon_stack_label.set_text("")
	for i in Weapon_Stack:
		weapon_stack_label.text += "\n" + i

func _on_weapons_manager_weapon_changed(weapon_name: String) -> void:
	current_weapon_label.set_text(weapon_name)
