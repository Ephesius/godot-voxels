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

	# Generate immediate chunks around spawn (limited area to avoid freeze)
	# This ensures player has ground to stand on while rest loads via queue
	var player_chunk: Vector3i = ChunkManager.world_to_chunk_pos(
		Vector3i(int(player.position.x), int(player.position.y), int(player.position.z))
	)
	# Only generate a 3x3 area immediately (small enough to be fast)
	# Use smart Y-level culling to only load relevant vertical chunks
	for x in range(player_chunk.x - 1, player_chunk.x + 2):
		for z in range(player_chunk.z - 1, player_chunk.z + 2):
			# Get terrain elevation for this column
			var world_x: int = x * 16  # Chunk.CHUNK_SIZE
			var world_z: int = z * 16
			var climate: Dictionary = chunk_manager.climate_calculator.get_climate_at(world_x, world_z)
			var terrain_elevation: int = climate.elevation

			# Calculate Y-chunk range based on terrain elevation
			var min_y_chunk: int = max(0, int(floor(float(terrain_elevation) / 16.0)))
			var max_y_chunk: int = min(chunk_manager.WORLD_SIZE_Y_CHUNKS - 1, player_chunk.y + 2)

			# Only generate chunks in relevant Y range
			for y in range(min_y_chunk, max_y_chunk + 1):
				chunk_manager.generate_chunk(Vector3i(x, y, z))

	# Add lighting
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	add_child(light)
