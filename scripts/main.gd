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
	for x in range(player_chunk.x - 1, player_chunk.x + 2):
		for z in range(player_chunk.z - 1, player_chunk.z + 2):
			for y in range(0, chunk_manager.WORLD_SIZE_Y_CHUNKS):
				chunk_manager.generate_chunk(Vector3i(x, y, z))

	# Add lighting
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	add_child(light)
