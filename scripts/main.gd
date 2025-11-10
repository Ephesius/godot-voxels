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

	# Create player and spawn at (0, 0) on top of terrain
	var player: Player = Player.new()

	# Get terrain elevation at spawn point (0, 0) using the climate calculator
	var spawn_climate: Dictionary = chunk_manager.climate_calculator.get_climate_at(0, 0)
	var terrain_elevation: int = spawn_climate.elevation

	# Spawn player on top of terrain (elevation + small offset)
	player.position = Vector3(0, terrain_elevation + 1, 0)
	add_child(player)

	# Add lighting
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	add_child(light)
