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

	# Position the camera to see multiple chunks
	# We're now looking at a larger area, so move the camera back and up
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(40, 30, 40)  # Higher and further back to see more chunks
	add_child(camera)
	camera.current = true
	camera.look_at(Vector3(0, 2, 0))  # Look at the center of our chunk grid

	# Add lighting
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	add_child(light)
