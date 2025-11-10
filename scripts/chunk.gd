class_name Chunk
extends MeshInstance3D

const CHUNK_SIZE: int = 16

# 3D array to store block data [x][y][z]
var blocks: Array[Array] = []

# Chunk position in world chunk coordinates
var chunk_position: Vector3i

func _init(pos: Vector3i = Vector3i.ZERO) -> void:
	chunk_position = pos
	_initialize_blocks()

func _initialize_blocks() -> void:
	blocks.clear()
	for x: int in range(CHUNK_SIZE):
		blocks.append([])
		for y: int in range(CHUNK_SIZE):
			blocks[x].append([])
			for z: int in range(CHUNK_SIZE):
				blocks[x][y].append(Block.Type.AIR)

# Get block at local chunk coordinates
func get_block(x: int, y: int, z: int) -> Block.Type:
	if x < 0 or x >= CHUNK_SIZE or \
	y < 0 or y >= CHUNK_SIZE or \
	z < 0 or z >= CHUNK_SIZE:
		return Block.Type.AIR
	return blocks[x][y][z]

# Set block at local chunk coordinates
func set_block(x: int, y: int, z: int, type: Block.Type) -> void:
	if x < 0 or x >= CHUNK_SIZE or \
	y < 0 or y >= CHUNK_SIZE or \
	z < 0 or z >= CHUNK_SIZE:
		return
	blocks[x][y][z] = type

# Generate the mesh using simple face culling (like Minecraft)
func generate_mesh() -> void:
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Loop through every block
	for x: int in range(CHUNK_SIZE):
		for y: int in range(CHUNK_SIZE):
			for z: int in range(CHUNK_SIZE):
				var block_type: Block.Type = blocks[x][y][z]

				# Skip air blocks
				if not Block.is_solid(block_type):
					continue

				var color: Color = Block.get_color(block_type)
				var pos: Vector3 = Vector3(x, y, z)

				# Check each of the 6 faces
				# Top face (+Y)
				if Block.is_transparent(get_block(x, y + 1, z)):
					_add_top_face(surface_tool, pos, color)

				# Bottom face (-Y)
				if Block.is_transparent(get_block(x, y - 1, z)):
					_add_bottom_face(surface_tool, pos, color)

				# Front face (+Z)
				if Block.is_transparent(get_block(x, y, z + 1)):
					_add_front_face(surface_tool, pos, color)

				# Back face (-Z)
				if Block.is_transparent(get_block(x, y, z - 1)):
					_add_back_face(surface_tool, pos, color)

				# Right face (+X)
				if Block.is_transparent(get_block(x + 1, y, z)):
					_add_right_face(surface_tool, pos, color)

				# Left face (-X)
				if Block.is_transparent(get_block(x - 1, y, z)):
					_add_left_face(surface_tool, pos, color)

	# Generate normals and commit
	surface_tool.generate_normals()
	mesh = surface_tool.commit()

	# Only set material if mesh has surfaces (i.e., chunk is not empty)
	if mesh and mesh.get_surface_count() > 0:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		set_surface_override_material(0, material)

# Helper functions to add each face (2 triangles per face)
# All vertices are in counter-clockwise order when viewed from outside

func _add_top_face(surface_tool: SurfaceTool, pos: Vector3, color: Color) -> void:
	# Top face vertices (Y = 1)
	var vertex_0: Vector3 = pos + Vector3(0, 1, 0)
	var vertex_1: Vector3 = pos + Vector3(1, 1, 0)
	var vertex_2: Vector3 = pos + Vector3(1, 1, 1)
	var vertex_3: Vector3 = pos + Vector3(0, 1, 1)

	# Triangle 1
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_0)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_1)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_2)

	# Triangle 2
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_0)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_2)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_3)

func _add_bottom_face(surface_tool: SurfaceTool, pos: Vector3, color: Color) -> void:
	# Bottom face vertices (Y = 0)
	var vertex_0: Vector3 = pos + Vector3(0, 0, 0)
	var vertex_1: Vector3 = pos + Vector3(0, 0, 1)
	var vertex_2: Vector3 = pos + Vector3(1, 0, 1)
	var vertex_3: Vector3 = pos + Vector3(1, 0, 0)

	# Triangle 1
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_0)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_1)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_2)

	# Triangle 2
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_0)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_2)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_3)

func _add_front_face(surface_tool: SurfaceTool, pos: Vector3, color: Color) -> void:
	# Front face vertices (+Z)
	var vertex_0: Vector3 = pos + Vector3(0, 0, 1)
	var vertex_1: Vector3 = pos + Vector3(0, 1, 1)
	var vertex_2: Vector3 = pos + Vector3(1, 1, 1)
	var vertex_3: Vector3 = pos + Vector3(1, 0, 1)

	# Triangle 1
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_0)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_1)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_2)

	# Triangle 2
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_0)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_2)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_3)

func _add_back_face(surface_tool: SurfaceTool, pos: Vector3, color: Color) -> void:
	# Back face vertices (-Z)
	var vertex_0: Vector3 = pos + Vector3(0, 0, 0)
	var vertex_1: Vector3 = pos + Vector3(1, 0, 0)
	var vertex_2: Vector3 = pos + Vector3(1, 1, 0)
	var vertex_3: Vector3 = pos + Vector3(0, 1, 0)

	# Triangle 1
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_0)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_1)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_2)

	# Triangle 2
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_0)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_2)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_3)

func _add_right_face(surface_tool: SurfaceTool, pos: Vector3, color: Color) -> void:
	# Right face vertices (+X)
	var vertex_0: Vector3 = pos + Vector3(1, 0, 0)
	var vertex_1: Vector3 = pos + Vector3(1, 0, 1)
	var vertex_2: Vector3 = pos + Vector3(1, 1, 1)
	var vertex_3: Vector3 = pos + Vector3(1, 1, 0)

	# Triangle 1
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_0)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_1)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_2)

	# Triangle 2
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_0)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_2)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_3)

func _add_left_face(surface_tool: SurfaceTool, pos: Vector3, color: Color) -> void:
	# Left face vertices (-X)
	var vertex_0: Vector3 = pos + Vector3(0, 0, 0)
	var vertex_1: Vector3 = pos + Vector3(0, 1, 0)
	var vertex_2: Vector3 = pos + Vector3(0, 1, 1)
	var vertex_3: Vector3 = pos + Vector3(0, 0, 1)

	# Triangle 1
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_0)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_1)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_2)

	# Triangle 2
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_0)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_2)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_3)
