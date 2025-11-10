class_name Chunk
extends MeshInstance3D

const CHUNK_SIZE = 16

# 3D array to store block data [x][y][z]
var blocks: Array = []

# Chunk position in world chunk coordinates
var chunk_position: Vector3i

func _init(pos: Vector3i = Vector3i.ZERO) -> void:
	chunk_position = pos
	_initialize_blocks()

func _initialize_blocks() -> void:
	blocks.clear()
	for x in range(CHUNK_SIZE):
		blocks.append([])
		for y in range(CHUNK_SIZE):
			blocks[x].append([])
			for z in range(CHUNK_SIZE):
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
func generate_mesh():
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Loop through every block
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			for z in range(CHUNK_SIZE):
				var block_type = blocks[x][y][z]

				# Skip air blocks
				if not Block.is_solid(block_type):
					continue

				var color = Block.get_color(block_type)
				var pos = Vector3(x, y, z)

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

	# Create material
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	set_surface_override_material(0, material)

# Helper functions to add each face (2 triangles per face)
# All vertices are in counter-clockwise order when viewed from outside

func _add_top_face(st: SurfaceTool, pos: Vector3, color: Color):
	# Top face vertices (Y = 1)
	var v0 = pos + Vector3(0, 1, 0)
	var v1 = pos + Vector3(1, 1, 0)
	var v2 = pos + Vector3(1, 1, 1)
	var v3 = pos + Vector3(0, 1, 1)

	# Triangle 1
	st.set_color(color)
	st.add_vertex(v0)
	st.set_color(color)
	st.add_vertex(v1)
	st.set_color(color)
	st.add_vertex(v2)

	# Triangle 2
	st.set_color(color)
	st.add_vertex(v0)
	st.set_color(color)
	st.add_vertex(v2)
	st.set_color(color)
	st.add_vertex(v3)

func _add_bottom_face(st: SurfaceTool, pos: Vector3, color: Color):
	# Bottom face vertices (Y = 0)
	var v0 = pos + Vector3(0, 0, 0)
	var v1 = pos + Vector3(0, 0, 1)
	var v2 = pos + Vector3(1, 0, 1)
	var v3 = pos + Vector3(1, 0, 0)

	# Triangle 1
	st.set_color(color)
	st.add_vertex(v0)
	st.set_color(color)
	st.add_vertex(v1)
	st.set_color(color)
	st.add_vertex(v2)

	# Triangle 2
	st.set_color(color)
	st.add_vertex(v0)
	st.set_color(color)
	st.add_vertex(v2)
	st.set_color(color)
	st.add_vertex(v3)

func _add_front_face(st: SurfaceTool, pos: Vector3, color: Color):
	# Front face vertices (+Z)
	var v0 = pos + Vector3(0, 0, 1)
	var v1 = pos + Vector3(0, 1, 1)
	var v2 = pos + Vector3(1, 1, 1)
	var v3 = pos + Vector3(1, 0, 1)

	# Triangle 1
	st.set_color(color)
	st.add_vertex(v0)
	st.set_color(color)
	st.add_vertex(v1)
	st.set_color(color)
	st.add_vertex(v2)

	# Triangle 2
	st.set_color(color)
	st.add_vertex(v0)
	st.set_color(color)
	st.add_vertex(v2)
	st.set_color(color)
	st.add_vertex(v3)

func _add_back_face(st: SurfaceTool, pos: Vector3, color: Color):
	# Back face vertices (-Z)
	var v0 = pos + Vector3(0, 0, 0)
	var v1 = pos + Vector3(1, 0, 0)
	var v2 = pos + Vector3(1, 1, 0)
	var v3 = pos + Vector3(0, 1, 0)

	# Triangle 1
	st.set_color(color)
	st.add_vertex(v0)
	st.set_color(color)
	st.add_vertex(v1)
	st.set_color(color)
	st.add_vertex(v2)

	# Triangle 2
	st.set_color(color)
	st.add_vertex(v0)
	st.set_color(color)
	st.add_vertex(v2)
	st.set_color(color)
	st.add_vertex(v3)

func _add_right_face(st: SurfaceTool, pos: Vector3, color: Color):
	# Right face vertices (+X)
	var v0 = pos + Vector3(1, 0, 0)
	var v1 = pos + Vector3(1, 0, 1)
	var v2 = pos + Vector3(1, 1, 1)
	var v3 = pos + Vector3(1, 1, 0)

	# Triangle 1
	st.set_color(color)
	st.add_vertex(v0)
	st.set_color(color)
	st.add_vertex(v1)
	st.set_color(color)
	st.add_vertex(v2)

	# Triangle 2
	st.set_color(color)
	st.add_vertex(v0)
	st.set_color(color)
	st.add_vertex(v2)
	st.set_color(color)
	st.add_vertex(v3)

func _add_left_face(st: SurfaceTool, pos: Vector3, color: Color):
	# Left face vertices (-X)
	var v0 = pos + Vector3(0, 0, 0)
	var v1 = pos + Vector3(0, 1, 0)
	var v2 = pos + Vector3(0, 1, 1)
	var v3 = pos + Vector3(0, 0, 1)

	# Triangle 1
	st.set_color(color)
	st.add_vertex(v0)
	st.set_color(color)
	st.add_vertex(v1)
	st.set_color(color)
	st.add_vertex(v2)

	# Triangle 2
	st.set_color(color)
	st.add_vertex(v0)
	st.set_color(color)
	st.add_vertex(v2)
	st.set_color(color)
	st.add_vertex(v3)
