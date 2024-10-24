extends Node3D
class_name DesertTerrainChunk


@export var RIDGE_NOISE: FastNoiseLite
@export var RIDGE_HEIGHT_NOISE: FastNoiseLite
@export var SIZE := 200
@export var RESOLUTION := .4
@export var HEIGHT_SCALE := 50.0

@onready var mesh_instance_3d = $MeshInstance3D
@onready var collision_shape_3d = $CollisionShape3D
@onready var player_detection_area = $PlayerDetectionArea
@onready var player_detection_collision = $PlayerDetectionArea/PlayerDetectionCollision

var MESH_STEP := 1.0 / RESOLUTION
var VERTICE_SIZE := SIZE * RESOLUTION
var RIDGE_NOISE_FREQUENCY := 0.004
var RIDGE_HEIGHT_NOISE_FREQUENCY := 0.004
var RIDGE_STRETCH := 2.0
var WIND_CURRENT_COUNT := 1

var st = SurfaceTool.new()
var collision_shape_vertices := PackedVector3Array()
var is_next_chunk_generated := false
var chunk_number := 0
var collision_generation_task_id: int
var debug_vertices := PackedVector3Array()
var wind_current_scene = preload("res://scenes/WindCurrent/WindCurrent.tscn")


func _ready():
	player_detection_area.body_entered.connect(_on_player_detection_area_body_entered)
	player_detection_area.body_exited.connect(_on_player_detection_area_body_exited)
	
	player_detection_collision.shape.size.x = SIZE * 2
	player_detection_collision.shape.size.z = SIZE * 2
	player_detection_collision.position.x += SIZE * .5
	player_detection_collision.position.z -= SIZE * .5
	
	RIDGE_NOISE.frequency = RIDGE_NOISE_FREQUENCY
	RIDGE_HEIGHT_NOISE.frequency = RIDGE_HEIGHT_NOISE_FREQUENCY
	RIDGE_NOISE.seed = Global.terrain_seed
	RIDGE_HEIGHT_NOISE.seed = Global.terrain_seed
	
	_generate_terrain()


func _generate_terrain():
	collision_generation_task_id = WorkerThreadPool.add_task(
		_thread_callable_generate_terrain.bind(collision_shape_vertices, transform, debug_vertices)
	)


func _thread_callable_generate_terrain(vertices: PackedVector3Array, transform_copy: Transform3D, debug_vertices_out: PackedVector3Array):
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(1, 0, 0))
	for i in range(0, VERTICE_SIZE - 1):
		for j in range(0, VERTICE_SIZE - 1):
			var bottom_left := _compute_vertex(i, j)
			var top_left := _compute_vertex(i, j + 1)
			var top_right := _compute_vertex(i + 1, j + 1)
			var bottom_right := _compute_vertex(i + 1, j)
			
			debug_vertices_out.append(bottom_left)
			debug_vertices_out.append(bottom_right)
			debug_vertices_out.append(top_left)
			debug_vertices_out.append(top_right)
			
			var plane1 := Plane(bottom_left, top_left, top_right)
			st.set_normal(plane1.normal)
			st.add_vertex(bottom_left)
			st.add_vertex(top_left)
			st.add_vertex(top_right)
			vertices.append(transform_copy * bottom_left)
			vertices.append(transform_copy * top_left)
			vertices.append(transform_copy * top_right)
			
			var plane2 := Plane(bottom_left, top_right, bottom_right)
			st.set_normal(plane2.normal)
			st.add_vertex(bottom_left)
			st.add_vertex(top_right)
			st.add_vertex(bottom_right)
			vertices.append(transform_copy * bottom_left)
			vertices.append(transform_copy * top_right)
			vertices.append(transform_copy * bottom_right)
	mesh_instance_3d.call_deferred("set_mesh", st.commit())
	Global.call_deferred("add_terrain_chunk", self)
	_generate_wind_currents()


func _compute_vertex(i, j) -> Vector3:
	var x = i * MESH_STEP
	var z = -j * MESH_STEP
	
	var y = _get_terrain_height_on_coords(x, z)
	
	return Vector3(x, y, z)


func _on_player_detection_area_body_entered(_body):
	if not is_next_chunk_generated:
		_generate_next_chunk()


func _generate_next_chunk():
	var next_chunk = load("res://scenes/DesertTerrainChunk/DesertTerrainChunk.tscn").instantiate()
	next_chunk.position = position - global_basis.z * (SIZE - 1 / RESOLUTION)
	next_chunk.rotation = rotation
	next_chunk.chunk_number = chunk_number + 1
	add_sibling(next_chunk)
	is_next_chunk_generated = true


func _on_player_detection_area_body_exited(_body):
	queue_free()


func _add_collision_shape_vertex(point: Vector3):
	point = point.rotated(Vector3.RIGHT, rotation.x)
	point = point.rotated(Vector3.UP, rotation.y)
	point = point.rotated(Vector3.BACK, rotation.z)
	point += position
	collision_shape_vertices.append(point)


func _exit_tree():
	Global.remove_terrain_chunk(self)
	WorkerThreadPool.wait_for_task_completion(collision_generation_task_id)


func _generate_wind_currents():
	for i in range(WIND_CURRENT_COUNT):
		var wind_current = wind_current_scene.instantiate() as WindCurrent
		var start_point = _get_random_wind_point_in_chunk()
		var end_point = _get_random_wind_point_in_chunk(start_point)
		var WIND_TESSELATION_INTERVAL = 100
		var segments_count = int((start_point - end_point).length() / WIND_TESSELATION_INTERVAL) + 1
		var tesselation_step_direction = (end_point - start_point).normalized()
		var curve_points_array: Array[Vector3] = []
		for j in range(segments_count):
			if j == 0:
				curve_points_array.append(start_point)
			elif j == segments_count - 1:
				curve_points_array.append(end_point)
			else:
				var new_internal_point = (
					start_point + tesselation_step_direction * WIND_TESSELATION_INTERVAL * j)
				new_internal_point.y = _get_terrain_height_on_coords(
					new_internal_point.x, new_internal_point.z)
				curve_points_array.append(new_internal_point)
		call_deferred("add_child", wind_current)
		wind_current.call_deferred("set_points", curve_points_array)


func _get_random_wind_point_in_chunk(start_point = null):
	var x
	var z
	if not start_point:
		x = randf_range(0, SIZE)
		z = randf_range(-SIZE, 0)
	else:
		x = randf_range(start_point.x - SIZE * 0.5, start_point.x + SIZE * 0.5)
		z = randf_range(start_point.z - SIZE * 1.5, start_point.z - SIZE * 0.5)
	var y = _get_terrain_height_on_coords(x, z)
	return Vector3(x, y, z)


func _get_terrain_height_on_coords(local_x: float, local_z: float):
	var noise_x = (-local_z + chunk_number * (VERTICE_SIZE - 1) * MESH_STEP) / RIDGE_STRETCH
	var noise_y = local_x
	var ridge_noise_value = (1 + RIDGE_NOISE.get_noise_2d(noise_x, noise_y))
	var ridge_height_noise_value = RIDGE_HEIGHT_NOISE.get_noise_2d(noise_x, noise_y) / 2 + 0.5
	return clampf(
		 ridge_noise_value * ridge_height_noise_value,
		0, 1
	) * HEIGHT_SCALE - HEIGHT_SCALE
