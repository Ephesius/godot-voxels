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
const RENDER_DISTANCE_CHUNKS: int = 8  # How many chunks to load in each direction
const UPDATE_INTERVAL: float = 0.5  # How often to check for chunk updates (seconds)
const MAX_CHUNKS_PER_FRAME: int = 20  # Maximum chunk generation tasks to submit per frame
const MAX_CHUNKS_TO_ADD_PER_FRAME: int = 10  # Maximum chunks to add to scene per frame
const COLLISION_RADIUS: int = 1  # Only generate collision within this many chunks of player

# Climate-based terrain generation
var climate_calculator: ClimateCalculator
var biome_selector: BiomeSelector

# Player tracking for dynamic chunk loading
var player: Node3D = null
var last_player_chunk: Vector3i = Vector3i(999999, 999999, 999999)  # Invalid initial position
var time_since_last_update: float = 0.0

# Chunk generation queue and tracking
var chunk_generation_queue: Array[Vector3i] = []
var chunks_being_generated: Dictionary = {}  # Track chunks currently being generated on threads
var completed_chunks_queue: Array = []  # Queue of completed chunk data ready to add to scene
var completed_chunks_mutex: Mutex = Mutex.new()  # Protect completed queue from race conditions

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

	# Process completed chunks from worker threads (add to scene on main thread)
	_process_completed_chunks()

	# Submit new chunk generation tasks to worker threads
	_process_chunk_queue()

	# Update collision every frame (very fast - just adds/removes collision bodies)
	_update_collision_around_player()

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


## Process the chunk generation queue (submit tasks to worker threads)
func _process_chunk_queue() -> void:
	if chunk_generation_queue.is_empty():
		return

	# Get player position for prioritization
	var player_world_pos: Vector3i = Vector3i(
		int(player.position.x),
		int(player.position.y),
		int(player.position.z)
	)
	var player_chunk: Vector3i = world_to_chunk_pos(player_world_pos)

	# Sort queue by distance to player (closest first)
	chunk_generation_queue.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		var dist_a: int = abs(a.x - player_chunk.x) + abs(a.z - player_chunk.z)
		var dist_b: int = abs(b.x - player_chunk.x) + abs(b.z - player_chunk.z)
		return dist_a < dist_b
	)

	# Submit up to MAX_CHUNKS_PER_FRAME tasks to worker threads
	var tasks_submitted: int = 0
	while tasks_submitted < MAX_CHUNKS_PER_FRAME and not chunk_generation_queue.is_empty():
		var chunk_pos: Vector3i = chunk_generation_queue.pop_front()

		# Skip if chunk already exists or is being generated
		if chunks.has(chunk_pos) or chunks_being_generated.has(chunk_pos):
			continue

		# Mark as being generated
		chunks_being_generated[chunk_pos] = true

		# Submit task to worker thread pool
		WorkerThreadPool.add_task(_generate_chunk_on_thread.bind(chunk_pos))
		tasks_submitted += 1


## Process completed chunks from worker threads (add to scene on main thread)
func _process_completed_chunks() -> void:
	# Get completed chunks from queue (thread-safe)
	completed_chunks_mutex.lock()
	var chunks_to_process: Array = completed_chunks_queue.duplicate()
	completed_chunks_queue.clear()
	completed_chunks_mutex.unlock()

	# Add up to MAX_CHUNKS_TO_ADD_PER_FRAME chunks to scene
	var chunks_added: int = 0
	for chunk_data in chunks_to_process:
		if chunks_added >= MAX_CHUNKS_TO_ADD_PER_FRAME:
			# Put remaining chunks back in queue for next frame
			completed_chunks_mutex.lock()
			for i in range(chunks_to_process.find(chunk_data), chunks_to_process.size()):
				completed_chunks_queue.append(chunks_to_process[i])
			completed_chunks_mutex.unlock()
			break

		_add_chunk_to_scene(chunk_data)
		chunks_added += 1


## Generate chunk data on worker thread (thread-safe)
func _generate_chunk_on_thread(chunk_pos: Vector3i) -> void:
	# Calculate the world position for this chunk's origin
	var chunk_world_pos: Vector3i = chunk_to_world_pos(chunk_pos)

	# Create block data array
	var block_data: Array = []
	for x in range(Chunk.CHUNK_SIZE):
		block_data.append([])
		for y in range(Chunk.CHUNK_SIZE):
			block_data[x].append([])
			for z in range(Chunk.CHUNK_SIZE):
				block_data[x][y].append(Block.Type.AIR)

	# Generate terrain using climate-based generation
	for x: int in range(Chunk.CHUNK_SIZE):
		for z: int in range(Chunk.CHUNK_SIZE):
			var world_x: int = chunk_world_pos.x + x
			var world_z: int = chunk_world_pos.z + z

			var climate: Dictionary = climate_calculator.get_climate_at(world_x, world_z)
			var temperature: float = climate.temperature
			var humidity: float = climate.humidity
			var elevation: int = climate.elevation

			for y: int in range(Chunk.CHUNK_SIZE):
				var world_y: int = chunk_world_pos.y + y

				var block_type: Block.Type = biome_selector.select_block(
					temperature,
					humidity,
					elevation,
					world_y
				)

				block_data[x][y][z] = block_type

	# Generate mesh from block data
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	for x: int in range(Chunk.CHUNK_SIZE):
		for y: int in range(Chunk.CHUNK_SIZE):
			for z: int in range(Chunk.CHUNK_SIZE):
				var block_type: Block.Type = block_data[x][y][z]

				if not Block.is_solid(block_type):
					continue

				var color: Color = Block.get_color(block_type)
				var pos: Vector3 = Vector3(x, y, z)

				# Helper function to get block from local data
				var get_local_block = func(lx: int, ly: int, lz: int) -> Block.Type:
					if lx < 0 or lx >= Chunk.CHUNK_SIZE or \
					   ly < 0 or ly >= Chunk.CHUNK_SIZE or \
					   lz < 0 or lz >= Chunk.CHUNK_SIZE:
						return Block.Type.AIR
					return block_data[lx][ly][lz]

				# Add faces using local data
				if Block.is_transparent(get_local_block.call(x, y + 1, z)):
					_add_face_to_surface(surface_tool, pos, color, Vector3(0, 1, 0), "top")
				if Block.is_transparent(get_local_block.call(x, y - 1, z)):
					_add_face_to_surface(surface_tool, pos, color, Vector3(0, -1, 0), "bottom")
				if Block.is_transparent(get_local_block.call(x, y, z + 1)):
					_add_face_to_surface(surface_tool, pos, color, Vector3(0, 0, 1), "front")
				if Block.is_transparent(get_local_block.call(x, y, z - 1)):
					_add_face_to_surface(surface_tool, pos, color, Vector3(0, 0, -1), "back")
				if Block.is_transparent(get_local_block.call(x + 1, y, z)):
					_add_face_to_surface(surface_tool, pos, color, Vector3(1, 0, 0), "right")
				if Block.is_transparent(get_local_block.call(x - 1, y, z)):
					_add_face_to_surface(surface_tool, pos, color, Vector3(-1, 0, 0), "left")

	# Commit mesh
	var generated_mesh: ArrayMesh = surface_tool.commit()

	# Package data and add to completed queue (thread-safe)
	var chunk_data: Dictionary = {
		"chunk_pos": chunk_pos,
		"block_data": block_data,
		"mesh": generated_mesh
	}

	completed_chunks_mutex.lock()
	completed_chunks_queue.append(chunk_data)
	completed_chunks_mutex.unlock()

	# Remove from being_generated tracking
	chunks_being_generated.erase(chunk_pos)


## Add completed chunk to scene (main thread only)
func _add_chunk_to_scene(chunk_data: Dictionary) -> void:
	var chunk_pos: Vector3i = chunk_data.chunk_pos
	var block_data: Array = chunk_data.block_data
	var generated_mesh: ArrayMesh = chunk_data.mesh

	# Validate chunk is still within render distance before adding
	if player:
		var player_chunk: Vector3i = world_to_chunk_pos(Vector3i(
			int(player.position.x),
			int(player.position.y),
			int(player.position.z)
		))

		var dx: int = abs(chunk_pos.x - player_chunk.x)
		var dz: int = abs(chunk_pos.z - player_chunk.z)

		# Skip if beyond render distance (player moved away while chunk was generating)
		if dx > RENDER_DISTANCE_CHUNKS or dz > RENDER_DISTANCE_CHUNKS:
			return

	# Create chunk node
	var chunk: Chunk = Chunk.new(chunk_pos)

	# Copy block data (can't directly assign due to type constraints)
	for x in range(Chunk.CHUNK_SIZE):
		for y in range(Chunk.CHUNK_SIZE):
			for z in range(Chunk.CHUNK_SIZE):
				chunk.blocks[x][y][z] = block_data[x][y][z]

	# Position the chunk in world space
	chunk.position = Vector3(
		chunk_pos.x * Chunk.CHUNK_SIZE,
		chunk_pos.y * Chunk.CHUNK_SIZE,
		chunk_pos.z * Chunk.CHUNK_SIZE
	)

	# Set the mesh
	chunk.mesh = generated_mesh

	# Set material if mesh has surfaces
	if generated_mesh and generated_mesh.get_surface_count() > 0:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		chunk.set_surface_override_material(0, material)

	# Add to scene and dictionary
	add_child(chunk)
	chunks[chunk_pos] = chunk


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
	# Load chunks in a radius around the player (with smart Y-level culling)
	for x: int in range(player_chunk.x - RENDER_DISTANCE_CHUNKS, player_chunk.x + RENDER_DISTANCE_CHUNKS + 1):
		for z: int in range(player_chunk.z - RENDER_DISTANCE_CHUNKS, player_chunk.z + RENDER_DISTANCE_CHUNKS + 1):
			# Get terrain elevation for this x,z column
			var world_x: int = x * Chunk.CHUNK_SIZE
			var world_z: int = z * Chunk.CHUNK_SIZE
			var climate: Dictionary = climate_calculator.get_climate_at(world_x, world_z)
			var terrain_elevation: int = climate.elevation

			# Calculate Y-chunk range based on terrain elevation
			# Load from below terrain surface (to show cliff faces) up to above player (for sky)
			# Subtract 2 from min to ensure we capture full terrain column including sides
			var terrain_y_chunk: int = floori(float(terrain_elevation) / Chunk.CHUNK_SIZE)
			var min_y_chunk: int = max(0, terrain_y_chunk - 2)
			var max_y_chunk: int = min(WORLD_SIZE_Y_CHUNKS - 1, player_chunk.y + 2)

			# Only load chunks in the relevant Y range
			for y: int in range(min_y_chunk, max_y_chunk + 1):
				var chunk_pos: Vector3i = Vector3i(x, y, z)

				# Skip if chunk already exists or is already queued
				if chunks.has(chunk_pos) or chunk_generation_queue.has(chunk_pos):
					continue

				# Add to generation queue instead of generating immediately
				chunk_generation_queue.append(chunk_pos)


## Unload chunks that are too far from the player
func _unload_distant_chunks(player_chunk: Vector3i) -> void:
	# Create a list of chunks to unload (can't modify dictionary while iterating)
	var chunks_to_unload: Array[Vector3i] = []

	# Check each loaded chunk
	for chunk_pos: Vector3i in chunks.keys():
		# Calculate horizontal distance
		var dx: int = abs(chunk_pos.x - player_chunk.x)
		var dz: int = abs(chunk_pos.z - player_chunk.z)

		# Unload if beyond render distance (with buffer to avoid thrashing)
		var unload_distance: int = RENDER_DISTANCE_CHUNKS + 2
		if dx > unload_distance or dz > unload_distance:
			chunks_to_unload.append(chunk_pos)
			continue

		# Also unload chunks that are far below terrain or far above player
		var world_x: int = chunk_pos.x * Chunk.CHUNK_SIZE
		var world_z: int = chunk_pos.z * Chunk.CHUNK_SIZE
		var climate: Dictionary = climate_calculator.get_climate_at(world_x, world_z)
		var terrain_elevation: int = climate.elevation
		var terrain_y_chunk: int = floori(float(terrain_elevation) / Chunk.CHUNK_SIZE)
		var min_y_chunk: int = max(0, terrain_y_chunk - 2)

		# Unload if chunk is well below terrain or too far above player
		if chunk_pos.y < min_y_chunk or chunk_pos.y > player_chunk.y + 3:
			chunks_to_unload.append(chunk_pos)

	# Unload the distant chunks
	for chunk_pos: Vector3i in chunks_to_unload:
		unload_chunk(chunk_pos)


## Update collision for chunks based on player distance
func _update_collision_around_player() -> void:
	# Get player's current chunk position
	var player_world_pos: Vector3i = Vector3i(
		int(player.position.x),
		int(player.position.y),
		int(player.position.z)
	)
	var player_chunk: Vector3i = world_to_chunk_pos(player_world_pos)

	# Check all loaded chunks
	for chunk_pos: Vector3i in chunks.keys():
		var chunk: Chunk = chunks[chunk_pos]

		# Calculate distance to player (using Chebyshev distance / max of differences)
		var dx: int = abs(chunk_pos.x - player_chunk.x)
		var dy: int = abs(chunk_pos.y - player_chunk.y)
		var dz: int = abs(chunk_pos.z - player_chunk.z)
		var distance: int = max(dx, max(dy, dz))

		# Add collision if within radius and doesn't have it
		if distance <= COLLISION_RADIUS:
			if not chunk.has_collision:
				chunk.add_collision()
		# Remove collision if beyond radius and has it
		else:
			if chunk.has_collision:
				chunk.remove_collision()


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


## Helper: Add a face to surface tool with flat normals (used in threaded mesh generation)
func _add_face_to_surface(surface_tool: SurfaceTool, pos: Vector3, color: Color, normal: Vector3, face_type: String) -> void:
	var vertices: Array[Vector3] = []

	match face_type:
		"top":
			vertices = [
				pos + Vector3(0, 1, 0),
				pos + Vector3(1, 1, 0),
				pos + Vector3(1, 1, 1),
				pos + Vector3(0, 1, 1)
			]
		"bottom":
			vertices = [
				pos + Vector3(0, 0, 0),
				pos + Vector3(0, 0, 1),
				pos + Vector3(1, 0, 1),
				pos + Vector3(1, 0, 0)
			]
		"front":
			vertices = [
				pos + Vector3(0, 0, 1),
				pos + Vector3(0, 1, 1),
				pos + Vector3(1, 1, 1),
				pos + Vector3(1, 0, 1)
			]
		"back":
			vertices = [
				pos + Vector3(0, 0, 0),
				pos + Vector3(1, 0, 0),
				pos + Vector3(1, 1, 0),
				pos + Vector3(0, 1, 0)
			]
		"right":
			vertices = [
				pos + Vector3(1, 0, 0),
				pos + Vector3(1, 0, 1),
				pos + Vector3(1, 1, 1),
				pos + Vector3(1, 1, 0)
			]
		"left":
			vertices = [
				pos + Vector3(0, 0, 0),
				pos + Vector3(0, 1, 0),
				pos + Vector3(0, 1, 1),
				pos + Vector3(0, 0, 1)
			]

	# Triangle 1
	surface_tool.set_normal(normal)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertices[0])
	surface_tool.set_normal(normal)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertices[1])
	surface_tool.set_normal(normal)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertices[2])

	# Triangle 2
	surface_tool.set_normal(normal)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertices[0])
	surface_tool.set_normal(normal)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertices[2])
	surface_tool.set_normal(normal)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertices[3])
