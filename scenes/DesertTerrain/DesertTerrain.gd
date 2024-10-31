extends Node3D


@export var wind_current_scene: PackedScene
@export var rock_structure_scene: PackedScene
@export var sand_material: StandardMaterial3D

@onready var mesh_update_area: Area3D = $MeshUpdateArea
@onready var mesh_update_shape: CollisionShape3D = $MeshUpdateArea/MeshUpdateShape
@onready var shape_update_area: Area3D = $ShapeUpdateArea
@onready var shape_update_shape: CollisionShape3D = $ShapeUpdateArea/ShapeUpdateShape
@onready var structure_update_area: Area3D = $StructureUpdateArea
@onready var structure_update_shape: CollisionShape3D = $StructureUpdateArea/StructureUpdateShape
@onready var terrain_body: StaticBody3D = $TerrainBody

var ACTIVE_COLLISION_RADIUS := 6
var ACTIVE_STRUCTURE_RADIUS := 800

var current_terrain_mesh: MeshInstance3D
var current_terrain_shape: CollisionShape3D
var current_terrain_structures: Node3D
var thread_pool_task_ids: Array[int] = []


func _ready():
	mesh_update_area.body_exited.connect(_on_mesh_update_area_body_exited)
	shape_update_area.body_exited.connect(_on_shape_update_area_body_exited)
	structure_update_area.body_exited.connect(_on_structure_update_area_body_exited)
	
	mesh_update_shape.shape.radius = Global.GENERATOR_RADIUS / 2
	shape_update_shape.shape.radius = ACTIVE_COLLISION_RADIUS / 2
	structure_update_shape.shape.radius = ACTIVE_STRUCTURE_RADIUS / 2
	
	thread_pool_task_ids.append(
		WorkerThreadPool.add_task(_swap_terrain_mesh.bind(Vector3.ZERO)))
	thread_pool_task_ids.append(
		WorkerThreadPool.add_task(_swap_terrain_structures.bind(Vector3.ZERO)))


func _on_mesh_update_area_body_exited(body):
	mesh_update_area.global_position = body.global_position
	
	thread_pool_task_ids.append(
		WorkerThreadPool.add_task(_swap_terrain_mesh.bind(body.global_position)))


func _on_shape_update_area_body_exited(body):
	shape_update_area.global_position = body.global_position
	
	thread_pool_task_ids.append(
		WorkerThreadPool.add_task(_swap_terrain_shape.bind(body.global_position)))


func _on_structure_update_area_body_exited(body):
	structure_update_area.global_position = body.global_position
	
	thread_pool_task_ids.append(
		WorkerThreadPool.add_task(_swap_terrain_structures.bind(body.global_position)))


func _swap_terrain_mesh(origin: Vector3):
	origin = snapped(origin, Vector3(Global.MESH_STEP, Global.MESH_STEP, Global.MESH_STEP))
	
	var new_terrain_mesh := MeshInstance3D.new()
	
	var vertex_array := PackedVector3Array()
	var normals_array := PackedVector3Array()
	_add_terrain_to_arrays(
		vertex_array,
		-Global.GENERATOR_RADIUS,
		Global.GENERATOR_RADIUS,
		origin,
		normals_array
	)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
	arrays[Mesh.ARRAY_NORMAL] = normals_array
	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	new_terrain_mesh.mesh = array_mesh
	
	new_terrain_mesh.material_override = sand_material
	
	terrain_body.add_child.call_deferred(new_terrain_mesh)
	if current_terrain_mesh: current_terrain_mesh.queue_free()
	current_terrain_mesh = new_terrain_mesh


func _swap_terrain_shape(origin: Vector3):
	origin = snapped(origin, Vector3(Global.MESH_STEP, Global.MESH_STEP, Global.MESH_STEP))
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


func _swap_terrain_structures(origin: Vector3):
	var new_terrain_structures := Node3D.new()
	
	var structures_origin = snapped(
		Vector2(origin.x, origin.z),
		Vector2(Global.STRUCTURE_SIZE, Global.STRUCTURE_SIZE)
	)
	for x_offset in range(
		-ACTIVE_STRUCTURE_RADIUS, ACTIVE_STRUCTURE_RADIUS, Global.STRUCTURE_SIZE
	):
		for z_offset in range(
			-ACTIVE_STRUCTURE_RADIUS, ACTIVE_STRUCTURE_RADIUS, Global.STRUCTURE_SIZE
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


func _add_terrain_to_arrays(
	vertex_array: PackedVector3Array,
	range_min: float,
	range_max: float,
	origin: Vector3,
	normals_array = null
):
	for x_offset in range(range_min, range_max, Global.MESH_STEP):
		for z_offset in range(range_min, range_max, Global.MESH_STEP):
			var bot_left = origin
			bot_left.x += x_offset
			bot_left.z += z_offset
			bot_left = Global.get_terrain_point_from_x_z(bot_left.x, bot_left.z)
			
			var bot_right = bot_left
			bot_right.x += Global.MESH_STEP
			bot_right = Global.get_terrain_point_from_x_z(bot_right.x, bot_right.z)
			
			var top_left = bot_left
			top_left.z -= Global.MESH_STEP
			top_left = Global.get_terrain_point_from_x_z(top_left.x, top_left.z)
			
			var top_right = bot_right
			top_right.z -= Global.MESH_STEP
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
