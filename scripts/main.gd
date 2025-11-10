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
	
	# Add some variation
	#for i in range(5):
		#var x = randi() % 16
		#var z = randi() % 16
		#chunk.set_block(x, 3, z, Block.Type.STONE)
	
	# Generate the mesh
	chunk.generate_mesh()
	
	# Position the camera to see the chunk
	var camera = Camera3D.new()
	camera.position = Vector3(25, 10, 25)
	add_child(camera)
	camera.look_at(Vector3(8, 1, 8))
	
	# Add lighting
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3( -45, 45, 0)
	add_child(light)
