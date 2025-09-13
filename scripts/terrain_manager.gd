extends Node3D

## Plug terrain chunk scene here
@export var chunk_scene: PackedScene
## Plug player scene here (root CharacterBody3D)
@export var player: CharacterBody3D
@export var chunk_size: int = 64
## How many chunks out from player
@export var render_distance: int = 2
## Limit streaming
@export var chunks_per_frame: int = 1

## Toggle collision type: false = Concave, true = HeightMap
@export var use_heightmap_collision: bool = false

## Dictionary of active chunks
## Keys: Vector2i (chunk grid coords), Values: Node3D (terrain_chunk instance)
var chunks: Dictionary[Vector2i, Node3D] = {}

## Queue of chunks waiting to spawn
var spawn_queue: Array[Vector2i] = []


func _ready():
	if player == null:
		push_error("TerrainManager: Could not find player node.")
	else:
		print("TerrainManager: Tracking player at ", player.name)


func _process(_delta: float) -> void:
	update_chunks()
	process_chunk_queue()


func update_chunks() -> void:
	if player == null:
		return

	var player_chunk_x: int = int(floor(player.global_position.x / chunk_size))
	var player_chunk_z: int = int(floor(player.global_position.z / chunk_size))

	# Tracks which chunks we still need this frame
	var needed_chunks: Dictionary[Vector2i, bool] = {}

	for x in range(player_chunk_x - render_distance, player_chunk_x + render_distance + 1):
		for z in range(player_chunk_z - render_distance, player_chunk_z + render_distance + 1):
			var key: Vector2i = Vector2i(x, z)
			needed_chunks[key] = true
			if not chunks.has(key) and not spawn_queue.has(key):
				spawn_queue.append(key)

	# Remove chunks that are no longer needed
	for key in chunks.keys():
		if not needed_chunks.has(key):
			chunks[key].queue_free()
			chunks.erase(key)


func process_chunk_queue() -> void:
	var spawned: int = 0
	while spawned < chunks_per_frame and spawn_queue.size() > 0:
		var key: Vector2i = spawn_queue.pop_front()
		if not chunks.has(key):
			spawn_chunk(key.x, key.y)
			spawned += 1


func spawn_chunk(x: int, z: int) -> void:
	var chunk: Node = chunk_scene.instantiate()
	add_child(chunk)

	# Pass settings to chunk
	chunk.use_heightmap_collision = use_heightmap_collision
	chunk.chunk_size = chunk_size

	# Generate terrain at given coords
	chunk.generate_chunk(x, z)

	# Position chunk in world space
	chunk.global_position = Vector3(x * chunk_size, 0, z * chunk_size)

	chunks[Vector2i(x, z)] = chunk
	
	# Debugging
	#var elapsed_ms: int = Time.get_ticks_msec()
	#print("Spawned chunk at ", x, ", ", z, " | elapsed: ", elapsed_ms / 1000.0, "s")
