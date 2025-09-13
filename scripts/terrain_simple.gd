extends MeshInstance3D

@export var noise_scale: float = 10.0
@export var height_scale: float = 10.0
@export var custom_seed: int = 1337

var noise := FastNoiseLite.new()

func _ready():
	# Configure noise
	noise.seed = custom_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.05
	
	# Convert PrimitiveMesh (PlaneMesh) → ArrayMesh
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)   # take the mesh set in inspector
	var array_mesh := st.commit()
	mesh = array_mesh
	
	# Deform terrain
	_generate_terrain(array_mesh)


func _generate_terrain(array_mesh: ArrayMesh):
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(array_mesh, 0)

	for i in range(mdt.get_vertex_count()):
		var v = mdt.get_vertex(i)
		var height = noise.get_noise_2d(v.x / noise_scale, v.z / noise_scale) * height_scale
		v.y = height
		mdt.set_vertex(i, v)

	# Build new mesh
	var new_mesh := ArrayMesh.new()
	mdt.commit_to_surface(new_mesh)
	mesh = new_mesh

	# Add collision
	_create_collision(new_mesh)


func _create_collision(new_mesh: ArrayMesh):
	var arrays = new_mesh.surface_get_arrays(0)
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	var indices = arrays[Mesh.ARRAY_INDEX]

	# Build triangle array
	var triangles = PackedVector3Array()
	if indices.is_empty():
		# No index array → assume vertices are already ordered as triangles
		triangles = vertices
	else:
		for i in indices:
			triangles.append(vertices[i])

	# Create shape
	var shape = ConcavePolygonShape3D.new()
	shape.data = triangles

	# Create static body + collision shape
	var body = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	collision.shape = shape

	body.add_child(collision)
	add_child(body)
