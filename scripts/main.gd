extends Node3D

func _ready() -> void:
	# Create the chunk manager
	var chunk_manager: ChunkManager = ChunkManager.new()
	add_child(chunk_manager)

	# Generate a small grid of chunks around the origin (0, 0, 0)
	# This will create a 5x5 grid of chunks (radius of 2 means 2 chunks in each direction)
	# That's 5 chunks × 5 chunks = 25 chunks total
	# Each chunk is 16 blocks, so this creates an 80x80 block area
	chunk_manager.generate_chunks_around(Vector3i(0, 0, 0), 2)

	# Create flying camera for player control
	var camera: FlyingCamera = FlyingCamera.new()
	camera.position = Vector3(0, 10, 20)  # Start above the terrain, looking toward center
	camera.rotation_degrees = Vector3(-20, 0, 0)  # Angle down slightly
	add_child(camera)

	# Add lighting
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	add_child(light)
