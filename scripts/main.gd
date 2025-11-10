extends Node3D

func _ready():
	# Create a test chunk
	var chunk = Chunk.new(Vector3i(0, 0, 0))
	add_child(chunk)
	
	# Fill it with some test blocks to visualize the greedy meshing
	# Create a simple platform
	for x in range(16):
		for z in range(16):
			chunk.set_block(x, 0, z, Block.Type.STONE)
			chunk.set_block(x, 1, z, Block.Type.DIRT)
			chunk.set_block(x, 2, z, Block.Type.GRASS)
	
	# Generate the mesh
	chunk.generate_mesh()
	
	# DEBUG: Print mesh info
	print("Chunk mesh: ", chunk.mesh)
	if chunk.mesh:
		print("Vertex count: ", chunk.mesh.get_faces())
		print("Surface count: ", chunk.mesh.get_surface_count())
	print("Chunk position: ", chunk.position)
	print("Chunk visible: ", chunk.visible)
	
	# Position the camera to see the chunk
	var camera = Camera3D.new()
	camera.position = Vector3(25, 10, 25)
	add_child(camera)
	camera.current = true
	camera.look_at(Vector3(8, 1, 8))
	print("Camera position: ", camera.position)
	print("Camera looking at: ", -camera.global_transform.basis.z)
	
	# Add lighting
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3( -45, 45, 0)
	add_child(light)
