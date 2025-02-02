extends Resource

class_name Weapon_Resource

# General weapon properties
@export var weapon_name: String # Name of the weapon

# Animation names for different actions related to the weapon
@export var activate_anim: String # Animation played when weapon is activated
@export var shoot_anim: String # Animation played when weapon is fired
@export var reload_anim: String # Animation played when weapon is reloaded
@export var deactivate_anim: String # Animation played when weapon is deactivated
@export var out_of_ammo_anim: String # Animation played when the weapon is out of ammo
@export var wall_raise_anim: String # Animation played when weapon is raised near a wall
@export var wall_lower_anim: String # Animation played when weapon is lowered away from a wall
@export var has_idle_anim: bool # Flag to enable/disable idle animation
@export var idle_anim: String # Animation played when weapon is idle

# Ammo properties
@export var current_ammo: int # Current ammo in the weapon
@export var current_ammo_default: int # Default amount of ammo in the weapon
@export var reserve_ammo: int # Ammo in reserve
@export var reserve_ammo_default: int # Default amount of reserve ammo
@export var mag_ammo: int # Maximum ammo in a magazine
@export var mag_ammo_default: int # Default magazine capacity
@export var max_ammo: int # Maximum ammo the weapon can hold
@export var damage: int # Damage dealt by the weapon
@export var weapon_range: int # Effective range of the weapon (for hitscan weapons)

# Weapon type properties
@export var auto_fire: bool # If true, weapon can fire automatically
@export var disable_wall_prox: bool # If true, weapon proximity to walls is disabled
@export var disable_ammo: bool # If true, weapon does not use ammo
@export var is_gun: bool # If true, weapon is a gun
@export var is_spell: bool # If true, weapon is a spell
@export var is_projectile_launcher: bool # If true, weapon launches a projectile



# Area damage properties (e.g., flamethrowers or distance-based spells)
@export var use_area_damage_collision: bool # If true, weapon uses area damage collision
@export var area_damage_radius: int # Radius for area damage
@export var skip_animation_on_fire: bool # If true, skips the shoot animation when firing
@export var fire_rate: float # Rate of fire for the weapon

# Sound files
@export var reload_sound: AudioStream  # The audio stream to play when reloading
@export var fire_sound: AudioStream    # The audio stream to play when firing
@export var hit_wall: AudioStream    # The audio stream to play when firing
@export var hit_player: AudioStream    # The audio stream to play when firing
