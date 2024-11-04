extends Node3D
class_name DesertTerrain


@export var wind_current_scene: PackedScene
@export var rock_structure_scene: PackedScene
@export var sand_near_material: StandardMaterial3D
@export var sand_far_material: StandardMaterial3D

@onready var mesh_update_area: Area3D = $MeshUpdateArea
@onready var mesh_update_shape: CollisionShape3D = $MeshUpdateArea/MeshUpdateShape
@onready var shape_update_area: Area3D = $ShapeUpdateArea
@onready var shape_update_shape: CollisionShape3D = $ShapeUpdateArea/ShapeUpdateShape
@onready var structure_update_area: Area3D = $StructureUpdateArea
@onready var structure_update_shape: CollisionShape3D = $StructureUpdateArea/StructureUpdateShape
@onready var terrain_body: StaticBody3D = $TerrainBody

var ACTIVE_COLLISION_RADIUS := 6

var current_terrain_near_mesh: MeshInstance3D
var current_terrain_far_mesh: MeshInstance3D
var current_terrain_shape: CollisionShape3D
var current_terrain_structures: Node3D
var thread_pool_task_ids: Array[int] = []
var is_swapping = {
	"near_mesh": false,
	"far_mesh": false,
	"shape": false,
	"structures": false,
}


func _ready():
	mesh_update_area.body_exited.connect(_on_mesh_update_area_body_exited)
	shape_update_area.body_exited.connect(_on_shape_update_area_body_exited)
	structure_update_area.body_exited.connect(_on_structure_update_area_body_exited)
	
	mesh_update_shape.shape.radius = Global.HIGH_POLY_MESH_RADIUS / 2
	shape_update_shape.shape.radius = ACTIVE_COLLISION_RADIUS / 2
	structure_update_shape.shape.radius = Global.ACTIVE_STRUCTURE_RADIUS / 2
	
	thread_pool_task_ids.append(
		WorkerThreadPool.add_task(_swap_terrain_mesh.bind(Vector3.ZERO)))
	thread_pool_task_ids.append(
		WorkerThreadPool.add_task(_swap_terrain_structures.bind(Vector3.ZERO)))
	
	sand_near_material.distance_fade_min_distance = Global.HIGH_POLY_MESH_RADIUS / 2
	sand_near_material.distance_fade_max_distance = (
		sand_near_material.distance_fade_min_distance - 50)
	
	sand_far_material.distance_fade_max_distance = Global.HIGH_POLY_MESH_RADIUS / 2 - 50
	sand_far_material.distance_fade_min_distance = (
		sand_near_material.distance_fade_min_distance - 100)


func _on_mesh_update_area_body_exited(body):
	if Global.is_player_resetting: return
	
	mesh_update_area.global_position = body.global_position
	
	if not is_swapping.near_mesh:
		is_swapping.mesh = true
		
		thread_pool_task_ids.append(
			WorkerThreadPool.add_task(_swap_terrain_mesh.bind(body.global_position, true)))
	if not is_swapping.far_mesh:
		is_swapping.far_mesh = true
		
		thread_pool_task_ids.append(
			WorkerThreadPool.add_task(_swap_terrain_mesh.bind(body.global_position, false)))


func _on_shape_update_area_body_exited(body):
	if Global.is_player_resetting: return
	
	shape_update_area.global_position = body.global_position
	
	if is_swapping.shape: return
	is_swapping.shape = true
	
	_swap_terrain_shape(body.global_position)


func _on_structure_update_area_body_exited(body):
	if Global.is_player_resetting: return
	
	structure_update_area.global_position = body.global_position
	
	if is_swapping.structures: return
	is_swapping.structures = true
	
	thread_pool_task_ids.append(
		WorkerThreadPool.add_task(_swap_terrain_structures.bind(body.global_position)))


func _swap_terrain_mesh(origin: Vector3, is_near_mesh: bool):
	var new_terrain_mesh := MeshInstance3D.new()
	
	var vertex_array := PackedVector3Array()
	var normals_array := PackedVector3Array()
	if is_near_mesh:
		_add_terrain_to_arrays(
			vertex_array,
			-Global.HIGH_POLY_MESH_RADIUS,
			Global.HIGH_POLY_MESH_RADIUS,
			origin,
			normals_array
		)
	else:
		_add_terrain_to_arrays(
			vertex_array,
			-Global.LOW_POLY_MESH_RADIUS,
			Global.LOW_POLY_MESH_RADIUS,
			origin,
			normals_array,
			Global.FAR_MESH_STEP,
		)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
	arrays[Mesh.ARRAY_NORMAL] = normals_array
	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	new_terrain_mesh.mesh = array_mesh
	
	if is_near_mesh:
		new_terrain_mesh.material_override = sand_near_material
		if current_terrain_near_mesh: current_terrain_near_mesh.queue_free()
		current_terrain_near_mesh = new_terrain_mesh
		is_swapping.near_mesh = false
	else:
		new_terrain_mesh.material_override = sand_far_material
		if current_terrain_far_mesh: current_terrain_far_mesh.queue_free()
		current_terrain_far_mesh = new_terrain_mesh
		is_swapping.far_mesh = false
	
	terrain_body.add_child.call_deferred(new_terrain_mesh)


func _swap_terrain_shape(origin: Vector3):
	var new_terrain_shape := CollisionShape3D.new()
	
	var vertex_array = PackedVector3Array()
	_add_terrain_to_arrays(
		vertex_array,
		-ACTIVE_COLLISION_RADIUS,
		ACTIVE_COLLISION_RADIUS,
		origin,
	)
	
	var concave_shape = ConcavePolygonShape3D.new()
	concave_shape.set_faces(vertex_array)
	new_terrain_shape.shape = concave_shape
	
	terrain_body.add_child.call_deferred(new_terrain_shape)
	if current_terrain_shape: current_terrain_shape.queue_free()
	current_terrain_shape = new_terrain_shape
	
	is_swapping.shape = false


func _swap_terrain_structures(origin: Vector3):
	var new_terrain_structures := Node3D.new()
	
	var structures_origin = snapped(
		Vector2(origin.x, origin.z),
		Vector2(Global.STRUCTURE_SIZE, Global.STRUCTURE_SIZE)
	)
	for x_offset in range(
		-Global.ACTIVE_STRUCTURE_RADIUS,
		Global.ACTIVE_STRUCTURE_RADIUS,
		Global.STRUCTURE_SIZE
	):
		for z_offset in range(
			-Global.ACTIVE_STRUCTURE_RADIUS,
			Global.ACTIVE_STRUCTURE_RADIUS,
			Global.STRUCTURE_SIZE
		):
			var structure_x_z = structures_origin
			structure_x_z.x += x_offset
			structure_x_z.y += z_offset
			
			var structure_value = Global.get_structure_value_from_x_z(
				structure_x_z.x, structure_x_z.y
			)
			
			var structure_position = Global.get_terrain_point_from_x_z(
				structure_x_z.x, structure_x_z.y)
			
			if structure_value >= 0:
				var wind_current = wind_current_scene.instantiate()
				wind_current.position = structure_position
				wind_current.generate_curve()
				new_terrain_structures.add_child(wind_current)
			
			var rock_structure = rock_structure_scene.instantiate()
			rock_structure.position = structure_position
			rock_structure.generate_rocks()
			new_terrain_structures.add_child(rock_structure)
	
	if current_terrain_structures: current_terrain_structures.queue_free()
	terrain_body.add_child.call_deferred(new_terrain_structures)
	current_terrain_structures = new_terrain_structures
	
	is_swapping.structures = false


func _add_terrain_to_arrays(
	vertex_array: PackedVector3Array,
	range_min: float,
	range_max: float,
	origin: Vector3,
	normals_array = null,
	step := Global.MESH_STEP,
):
	origin = snapped(origin, Vector3(step, step, step))
	
	for x_offset in range(range_min, range_max, step):
		for z_offset in range(range_min, range_max, step):
			var bot_left = origin
			bot_left.x += x_offset
			bot_left.z += z_offset
			bot_left = Global.get_terrain_point_from_x_z(bot_left.x, bot_left.z)
			
			var bot_right = bot_left
			bot_right.x += step
			bot_right = Global.get_terrain_point_from_x_z(bot_right.x, bot_right.z)
			
			var top_left = bot_left
			top_left.z -= step
			top_left = Global.get_terrain_point_from_x_z(top_left.x, top_left.z)
			
			var top_right = bot_right
			top_right.z -= step
			top_right = Global.get_terrain_point_from_x_z(top_right.x, top_right.z)
			
			Global.add_quad_to_vertex_array(
				vertex_array,
				bot_left,
				bot_right,
				top_left,
				top_right
			)
			if normals_array != null:
				Global.add_quad_to_normals_array(
					normals_array,
					bot_left,
					bot_right,
					top_left,
					top_right
				)


func _exit_tree() -> void:
	for task_id in thread_pool_task_ids:
		WorkerThreadPool.wait_for_task_completion(task_id)
