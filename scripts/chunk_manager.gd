class_name ChunkManager
extends Node3D

# Dictionary to store chunks: Key = Vector3i(chunk_x, chunk_y, chunk_z), Value = Chunk instance
var chunks: Dictionary = {}

# World dimensions in chunks (not blocks!)
# Your world is 3000x3000x192 blocks, which is 187x187x12 chunks (3000÷16 = 187.5, rounded down)
const WORLD_SIZE_X_CHUNKS: int = 187  # 3000 blocks ÷ 16 blocks per chunk
const WORLD_SIZE_Z_CHUNKS: int = 187  # 3000 blocks ÷ 16 blocks per chunk
const WORLD_SIZE_Y_CHUNKS: int = 12   # 192 blocks ÷ 16 blocks per chunk

# Dynamic chunk loading settings
const RENDER_DISTANCE_CHUNKS: int = 4  # How many chunks to load in each direction
const UPDATE_INTERVAL: float = 0.5  # How often to check for chunk updates (seconds)

# Climate-based terrain generation
var climate_calculator: ClimateCalculator
var biome_selector: BiomeSelector

# Player tracking for dynamic chunk loading
var player: Node3D = null
var last_player_chunk: Vector3i = Vector3i(999999, 999999, 999999)  # Invalid initial position
var time_since_last_update: float = 0.0

func _ready() -> void:
	# Initialize terrain generation systems
	climate_calculator = ClimateCalculator.new(0)  # Use seed 0 for now
	biome_selector = BiomeSelector.new()


## Set the player reference for dynamic chunk loading
func set_player(player_node: Node3D) -> void:
	player = player_node


## Update chunk loading based on player position
func _process(delta: float) -> void:
	if player == null:
		return

	time_since_last_update += delta

	# Only update periodically to avoid performance issues
	if time_since_last_update >= UPDATE_INTERVAL:
		time_since_last_update = 0.0
		_update_chunks_around_player()


## Check player position and load/unload chunks accordingly
func _update_chunks_around_player() -> void:
	# Get player's current chunk position
	var player_world_pos: Vector3i = Vector3i(
		int(player.position.x),
		int(player.position.y),
		int(player.position.z)
	)
	var player_chunk: Vector3i = world_to_chunk_pos(player_world_pos)

	# Only update if player has moved to a different chunk
	if player_chunk == last_player_chunk:
		return

	last_player_chunk = player_chunk

	# Load new chunks around player
	_load_chunks_around_player(player_chunk)

	# Unload chunks that are too far away
	_unload_distant_chunks(player_chunk)

# Generate a chunk at the given chunk coordinates
# chunk_pos is in CHUNK coordinates, not block coordinates
# For example, chunk_pos (1, 0, 2) means the chunk that contains blocks from (16,0,32) to (31,15,47)
func generate_chunk(chunk_pos: Vector3i) -> Chunk:
	# Check if chunk already exists
	if chunks.has(chunk_pos):
		return chunks[chunk_pos]

	# Create new chunk
	var chunk: Chunk = Chunk.new(chunk_pos)

	# Position the chunk in world space
	# Each chunk is 16 blocks, so chunk (1,0,0) should be at world position (16,0,0)
	chunk.position = Vector3(
		chunk_pos.x * Chunk.CHUNK_SIZE,
		chunk_pos.y * Chunk.CHUNK_SIZE,
		chunk_pos.z * Chunk.CHUNK_SIZE
	)

	# Generate the terrain for this chunk using climate-based generation
	_generate_climate_terrain(chunk, chunk_pos)

	# Build the mesh
	chunk.generate_mesh()

	# Add to scene and dictionary
	add_child(chunk)
	chunks[chunk_pos] = chunk

	return chunk


## Generate terrain based on climate data (temperature, humidity, elevation)
func _generate_climate_terrain(chunk: Chunk, chunk_pos: Vector3i) -> void:
	# Calculate the world position for this chunk's origin
	var chunk_world_pos: Vector3i = chunk_to_world_pos(chunk_pos)

	# Iterate through all blocks in this chunk
	for x: int in range(Chunk.CHUNK_SIZE):
		for z: int in range(Chunk.CHUNK_SIZE):
			# Calculate world coordinates for this x,z column
			var world_x: int = chunk_world_pos.x + x
			var world_z: int = chunk_world_pos.z + z

			# Get climate data for this column (same for all y-levels)
			var climate: Dictionary = climate_calculator.get_climate_at(world_x, world_z)
			var temperature: float = climate.temperature
			var humidity: float = climate.humidity
			var elevation: int = climate.elevation

			# Fill the column based on climate and elevation
			for y: int in range(Chunk.CHUNK_SIZE):
				var world_y: int = chunk_world_pos.y + y

				# Select the appropriate block type
				var block_type: Block.Type = biome_selector.select_block(
					temperature,
					humidity,
					elevation,
					world_y
				)

				chunk.set_block(x, y, z, block_type)

# Generate chunks in a square area around a center point
# This is what you'd call when the player moves or when the world first loads
# radius = number of chunks in each direction from center (inclusive)
# Example: radius=2 around (0,0,0) generates chunks from (-2,-2) to (2,2) = 5×5 = 25 chunks
func generate_chunks_around(center_chunk: Vector3i, radius: int = RENDER_DISTANCE_CHUNKS) -> void:
	for x: int in range(center_chunk.x - radius, center_chunk.x + radius + 1):
		for z: int in range(center_chunk.z - radius, center_chunk.z + radius + 1):
			# Generate vertical chunks from y=0 to y=11 to cover terrain from y=0 to y=192
			# This ensures we capture underground (y=0-40), terrain (y=40-150), and sky (y=150-192)
			for y: int in range(0, WORLD_SIZE_Y_CHUNKS):
				var chunk_pos: Vector3i = Vector3i(x, y, z)

				# Optional: Check world bounds if you want a limited world size
				# For now, we'll allow negative coordinates (chunks west/north of origin)
				# Uncomment these lines if you want to enforce world boundaries:
				# if x < 0 or x >= WORLD_SIZE_X_CHUNKS or z < 0 or z >= WORLD_SIZE_Z_CHUNKS:
				#     continue

				generate_chunk(chunk_pos)


## Load chunks around the player's current position
func _load_chunks_around_player(player_chunk: Vector3i) -> void:
	# Load chunks in a radius around the player
	for x: int in range(player_chunk.x - RENDER_DISTANCE_CHUNKS, player_chunk.x + RENDER_DISTANCE_CHUNKS + 1):
		for z: int in range(player_chunk.z - RENDER_DISTANCE_CHUNKS, player_chunk.z + RENDER_DISTANCE_CHUNKS + 1):
			# Generate all vertical chunks for this x,z column
			for y: int in range(0, WORLD_SIZE_Y_CHUNKS):
				var chunk_pos: Vector3i = Vector3i(x, y, z)

				# Skip if chunk already exists
				if chunks.has(chunk_pos):
					continue

				# Generate the chunk
				generate_chunk(chunk_pos)


## Unload chunks that are too far from the player
func _unload_distant_chunks(player_chunk: Vector3i) -> void:
	# Create a list of chunks to unload (can't modify dictionary while iterating)
	var chunks_to_unload: Array[Vector3i] = []

	# Check each loaded chunk
	for chunk_pos: Vector3i in chunks.keys():
		# Calculate horizontal distance (ignore y-axis for distance check)
		var dx: int = abs(chunk_pos.x - player_chunk.x)
		var dz: int = abs(chunk_pos.z - player_chunk.z)

		# Unload if beyond render distance (with a bit of buffer to avoid thrashing)
		var unload_distance: int = RENDER_DISTANCE_CHUNKS + 2
		if dx > unload_distance or dz > unload_distance:
			chunks_to_unload.append(chunk_pos)

	# Unload the distant chunks
	for chunk_pos: Vector3i in chunks_to_unload:
		unload_chunk(chunk_pos)


# Get a chunk at the given chunk coordinates (returns null if doesn't exist)
func get_chunk(chunk_pos: Vector3i) -> Chunk:
	return chunks.get(chunk_pos, null)

# Unload a chunk (for later when we implement chunk loading/unloading based on distance)
func unload_chunk(chunk_pos: Vector3i) -> void:
	if chunks.has(chunk_pos):
		var chunk: Chunk = chunks[chunk_pos]
		chunks.erase(chunk_pos)
		chunk.queue_free()

# Clear all chunks (useful for regenerating the world)
func clear_all_chunks() -> void:
	for chunk: Chunk in chunks.values():
		chunk.queue_free()
	chunks.clear()

# Helper: Convert world position (in blocks) to chunk position
static func world_to_chunk_pos(world_pos: Vector3i) -> Vector3i:
	return Vector3i(
		floori(float(world_pos.x) / Chunk.CHUNK_SIZE),
		floori(float(world_pos.y) / Chunk.CHUNK_SIZE),
		floori(float(world_pos.z) / Chunk.CHUNK_SIZE)
	)

# Helper: Convert chunk position to world position (returns the corner of the chunk)
static func chunk_to_world_pos(chunk_pos: Vector3i) -> Vector3i:
	return Vector3i(
		chunk_pos.x * Chunk.CHUNK_SIZE,
		chunk_pos.y * Chunk.CHUNK_SIZE,
		chunk_pos.z * Chunk.CHUNK_SIZE
	)
