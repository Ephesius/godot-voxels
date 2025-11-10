class_name ChunkManager
extends Node3D

# Dictionary to store chunks: Key = Vector3i(chunk_x, chunk_y, chunk_z), Value = Chunk instance
var chunks: Dictionary = {}

# World dimensions in chunks (not blocks!)
# Your world is 3000x3000x192 blocks, which is 187x187x12 chunks (3000÷16 = 187.5, rounded down)
const WORLD_SIZE_X_CHUNKS = 187  # 3000 blocks ÷ 16 blocks per chunk
const WORLD_SIZE_Z_CHUNKS = 187  # 3000 blocks ÷ 16 blocks per chunk
const WORLD_SIZE_Y_CHUNKS = 12   # 192 blocks ÷ 16 blocks per chunk

# For now, we'll just generate a small area for testing
# Later this will be dynamic based on player position
const RENDER_DISTANCE_CHUNKS = 4  # How many chunks to load in each direction

func _ready():
	pass

# Generate a chunk at the given chunk coordinates
# chunk_pos is in CHUNK coordinates, not block coordinates
# For example, chunk_pos (1, 0, 2) means the chunk that contains blocks from (16,0,32) to (31,15,47)
func generate_chunk(chunk_pos: Vector3i) -> Chunk:
	# Check if chunk already exists
	if chunks.has(chunk_pos):
		return chunks[chunk_pos]

	# Create new chunk
	var chunk = Chunk.new(chunk_pos)

	# Position the chunk in world space
	# Each chunk is 16 blocks, so chunk (1,0,0) should be at world position (16,0,0)
	chunk.position = Vector3(
		chunk_pos.x * Chunk.CHUNK_SIZE,
		chunk_pos.y * Chunk.CHUNK_SIZE,
		chunk_pos.z * Chunk.CHUNK_SIZE
	)

	# Generate the terrain for this chunk
	# For now, we'll use simple test terrain
	# Later, this will call your world generation system
	_generate_test_terrain(chunk, chunk_pos)

	# Build the mesh
	chunk.generate_mesh()

	# Add to scene and dictionary
	add_child(chunk)
	chunks[chunk_pos] = chunk

	return chunk

# Temporary function to generate test terrain
# This creates a simple flat platform so we can see multiple chunks
func _generate_test_terrain(chunk: Chunk, chunk_pos: Vector3i):
	# Create a simple ground layer
	# We'll make layers at y=0 (stone), y=1 (dirt), y=2 (grass)
	for x in range(Chunk.CHUNK_SIZE):
		for z in range(Chunk.CHUNK_SIZE):
			# Calculate the absolute world Y position for this chunk
			var world_y_base = chunk_pos.y * Chunk.CHUNK_SIZE

			# Only generate terrain in the bottom chunks (y=0)
			if chunk_pos.y == 0:
				chunk.set_block(x, 0, z, Block.Type.STONE)
				chunk.set_block(x, 1, z, Block.Type.DIRT)
				chunk.set_block(x, 2, z, Block.Type.GRASS)

# Generate chunks in a square area around a center point
# This is what you'd call when the player moves or when the world first loads
func generate_chunks_around(center_chunk: Vector3i, radius: int = RENDER_DISTANCE_CHUNKS):
	for x in range(center_chunk.x - radius, center_chunk.x + radius):
		for z in range(center_chunk.z - radius, center_chunk.z + radius):
			# For now, only generate ground level chunks (y = 0)
			# Later we'll expand this to handle vertical chunks too
			var chunk_pos = Vector3i(x, 0, z)

			# Check world bounds (optional - remove if you want infinite terrain)
			if x < 0 or x >= WORLD_SIZE_X_CHUNKS or z < 0 or z >= WORLD_SIZE_Z_CHUNKS:
				continue

			generate_chunk(chunk_pos)

# Get a chunk at the given chunk coordinates (returns null if doesn't exist)
func get_chunk(chunk_pos: Vector3i) -> Chunk:
	return chunks.get(chunk_pos, null)

# Unload a chunk (for later when we implement chunk loading/unloading based on distance)
func unload_chunk(chunk_pos: Vector3i):
	if chunks.has(chunk_pos):
		var chunk = chunks[chunk_pos]
		chunks.erase(chunk_pos)
		chunk.queue_free()

# Clear all chunks (useful for regenerating the world)
func clear_all_chunks():
	for chunk in chunks.values():
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
