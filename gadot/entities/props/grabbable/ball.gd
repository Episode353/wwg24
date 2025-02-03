extends RigidBody3D

func _ready():
	randomize()  # Initialize the random number generator
	var random_color = Color(randf(), randf(), randf())

	# Get a reference to your CSG sphere node
	var sphere = $CSGSphere3D

	# Check if the sphere already has a material assigned.
	# If not, create a new one.
	var mat: StandardMaterial3D = sphere.material
	if mat == null:
		mat = StandardMaterial3D.new()
		sphere.material = mat
	else:
		# If the material is already in use by others, duplicate it
		mat = mat.duplicate() 
		sphere.material = mat

	# Now assign the random color to the material's albedo_color
	mat.albedo_color = random_color
