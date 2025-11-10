extends Node3D

func _ready() -> void:
	# Create the chunk manager
	var chunk_manager: ChunkManager = ChunkManager.new()
	add_child(chunk_manager)

	# Create player and spawn at (0, 0) on top of terrain
	var player: Player = Player.new()

	# Get terrain elevation at spawn point (0, 0) using the climate calculator
	var spawn_climate: Dictionary = chunk_manager.climate_calculator.get_climate_at(0, 0)
	var terrain_elevation: int = spawn_climate.elevation

	# Spawn player on top of terrain (elevation + small offset)
	player.position = Vector3(0, terrain_elevation + 1, 0)
	add_child(player)

	# Set up dynamic chunk loading
	chunk_manager.set_player(player)

	# Load initial chunks around player's spawn position
	var player_chunk: Vector3i = ChunkManager.world_to_chunk_pos(
		Vector3i(int(player.position.x), int(player.position.y), int(player.position.z))
	)
	chunk_manager.generate_chunks_around(player_chunk, chunk_manager.RENDER_DISTANCE_CHUNKS)

	# Add lighting
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	add_child(light)
