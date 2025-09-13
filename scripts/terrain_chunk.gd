extends MeshInstance3D

@export var chunk_size: int = 64
@export var subdivisions: int = 64
@export var noise_scale: float = 20.0
@export var height_scale: float = 15.0
@export var custom_seed: int = 1337

## Controlled externally by terrain_manager
var use_heightmap_collision: bool = false

## Noise generator
var noise: FastNoiseLite = FastNoiseLite.new()

## Physics members
var static_body: StaticBody3D
var collision_shape: CollisionShape3D


func _ready() -> void:
	# Configure noise
	noise.seed = custom_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.05

	# Set up physics once
	static_body = StaticBody3D.new()
	collision_shape = CollisionShape3D.new()
	static_body.add_child(collision_shape)
	add_child(static_body)


func generate_chunk(chunk_x: int, chunk_z: int) -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(chunk_size, chunk_size)
	plane.subdivide_depth = subdivisions
	plane.subdivide_width = subdivisions

	var st: SurfaceTool = SurfaceTool.new()
	st.create_from(plane, 0)
	var array_mesh: ArrayMesh = st.commit()

	var mdt: MeshDataTool = MeshDataTool.new()
	mdt.create_from_surface(array_mesh, 0)

	for i: int in range(mdt.get_vertex_count()):
		var v: Vector3 = mdt.get_vertex(i)
	
		# PlaneMesh vertices are centered at (0,0), range is (-chunk_size/2 .. +chunk_size/2)
		var world_x: float = v.x + float(chunk_x * chunk_size) + chunk_size * 0.5
		var world_z: float = v.z + float(chunk_z * chunk_size) + chunk_size * 0.5

		var height: float = noise.get_noise_2d(world_x / noise_scale, world_z / noise_scale) * height_scale
		v.y = height
		mdt.set_vertex(i, v)

	var new_mesh: ArrayMesh = ArrayMesh.new()
	mdt.commit_to_surface(new_mesh)
	mesh = new_mesh

	update_collision(new_mesh)


func update_collision(new_mesh: ArrayMesh) -> void:
	if use_heightmap_collision:
		var arrays: Array = new_mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]

		var size: int = subdivisions + 1
		var heights: PackedFloat32Array = PackedFloat32Array()
		heights.resize(size * size)

		for i: int in range(vertices.size()):
			var v: Vector3 = vertices[i]
			var grid_x: int = int(round((v.x + chunk_size * 0.5) / (chunk_size / float(subdivisions))))
			var grid_z: int = int(round((v.z + chunk_size * 0.5) / (chunk_size / float(subdivisions))))
			if grid_x >= 0 and grid_x < size and grid_z >= 0 and grid_z < size:
				heights[grid_z * size + grid_x] = v.y

		var shape: HeightMapShape3D = HeightMapShape3D.new()
		shape.map_width = size
		shape.map_depth = size
		shape.map_data = heights
		collision_shape.shape = shape
	else:
		# Concave fallback
		var arrays: Array = new_mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

		var triangles: PackedVector3Array = PackedVector3Array()
		if indices.is_empty():
			triangles = vertices
		else:
			for i: int in indices:
				triangles.append(vertices[i])

		var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		shape.data = triangles
		collision_shape.shape = shape
