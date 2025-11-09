class_name Chunk extends MeshInstance3D

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

# Generate the mesh using greedy meshing algorithm
func generate_mesh():
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Process each axis for greedy meshing
	_greedy_mesh(surface_tool, Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)) # X-axis faces
	_greedy_mesh(surface_tool, Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0)) # Y-axis faces
	_greedy_mesh(surface_tool, Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(0, 1, 0)) # Z-axis faces
	
	mesh = surface_tool.commit()
	
	# Create a simple material
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	set_surface_override_material(0, material)

# Greedy meshing algorithm
# axis_u and axis_v define the plane we're meshing, axis_n is the normal direction
func _greedy_mesh(surface_tool: SurfaceTool, axis_u: Vector3i, axis_v: Vector3i, axis_n: Vector3i):
	var u_dim = CHUNK_SIZE
	var v_dim = CHUNK_SIZE
	var n_dim = CHUNK_SIZE
	
	# For each slice along the normal axis
	for n in range(n_dim):
		# Create a mask for this slice
		var mask: Array = []
		for u in range(u_dim):
			mask.append([])
			for v in range(v_dim):
				mask[u].append(null)
		
		# Fill the mask by comparing adjacent blocks
		for u in range(u_dim):
			for v in range(v_dim):
				var pos = axis_u * u + axis_v * v + axis_n * n
				var block_type = get_block(pos.x, pos.y, pos.z)
				
				# Check the neighbor in the normal direction
				var neighbor_pos = pos * axis_n
				var neighbor_type = get_block(neighbor_pos.x, neighbor_pos.y, neighbor_pos.z)
				
				# Only create a face if current block is solid and neighbor is transparent
				if Block.is_solid(block_type) and Block.is_transparent(neighbor_type):
					mask[u][v] = block_type
				else:
					mask[u][v] = null
		# Generate mesh from the mask using greedy algorithm
		for u in range(u_dim):
			for v in range(v_dim):
				if mask[u][v] != null:
					var block_type = mask[u][v]
					
					# Compute width (along u axis)
					var width = 1
					while u + width < u_dim and mask[u + width][v] == block_type:
						width += 1
					
					# Compute height (along v axis)
					var height = 1
					var done = false
					while v + height < v_dim and not done:
						for du in range(width):
							if mask[u + du][v + height] != block_type:
								done = true
								break
						if not done:
							height += 1
					
					# Create the quad
					_add_quad(surface_tool, axis_u, axis_v, axis_n, u, v, n, width, height, block_type)
					
					# Clear the mask for the processed area
					for du in range(width):
						for dv in range(height):
							mask[u + du][v + dv] = null

# Add a quad (two triangles) to the mesh
func _add_quad(surface_tool: SurfaceTool, axis_u: Vector3i, axis_v: Vector3i, axis_n: Vector3i,
		u: int, v: int, n: int, width: int, height: int, block_type: Block.Type):
	var offset: Vector3i = axis_n * (n + 1) # +1 to place on the outer edge
	var corner: Vector3 = Vector3(axis_u * u + axis_v * v + offset)
	
	var du: Vector3 = Vector3(axis_u * width)
	var dv: Vector3 = Vector3(axis_v * height)
	
	var color = Block.get_color(block_type)
	
	# Determine if we need to flip the quad based on normal direction
	var flip: bool = (axis_n.x + axis_n.y + axis_n.z) > 0
	
	if flip:
		# Counter-clockwise winding
		surface_tool.set_color(color)
		surface_tool.add_vertex(corner)
		surface_tool.set_color(color)
		surface_tool.add_vertex(corner + du)
		surface_tool.set_color(color)
		surface_tool.add_vertex(corner + du + dv)
		
		surface_tool.set_color(color)
		surface_tool.add_vertex(corner)
		surface_tool.set_color(color)
		surface_tool.add_vertex(corner + du + dv)
		surface_tool.set_color(color)
		surface_tool.add_vertex(corner + dv)
	else:
		# Clockwise winding (flipped)
		surface_tool.set_color(color)
		surface_tool.add_vertex(corner)
		surface_tool.set_color(color)
		surface_tool.add_vertex(corner + dv)
		surface_tool.set_color(color)
		surface_tool.add_vertex(corner + du + dv)
		
		surface_tool.set_color(color)
		surface_tool.add_vertex(corner)
		surface_tool.set_color(color)
		surface_tool.add_vertex(corner + du + dv)
		surface_tool.set_color(color)
		surface_tool.add_vertex(corner + du)
