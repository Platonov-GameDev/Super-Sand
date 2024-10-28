extends Node3D


@export var physics_material: PhysicsMaterial
@export var wind_current_scene: PackedScene

@onready var player_detection_area: Area3D = $PlayerDetectionArea
@onready var player_detection_shape: CollisionShape3D = $PlayerDetectionArea/PlayerDetectionShape

var current_terrain_body: StaticBody3D
var thread_pool_task_id: int


func _ready():
	player_detection_area.body_exited.connect(_on_player_detection_area_body_exited)
	
	player_detection_shape.shape.radius = Global.GENERATOR_RADIUS / 2


func _on_player_detection_area_body_exited(body):
	player_detection_area.global_position = body.global_position
	
	thread_pool_task_id = WorkerThreadPool.add_task(_swap_terrain.bind(body.global_position))


func _swap_terrain(origin: Vector3):
	origin = snapped(origin, Vector3(Global.MESH_STEP, Global.MESH_STEP, Global.MESH_STEP))
	
	var new_terrain_body := StaticBody3D.new()
	var new_terrain_mesh := MeshInstance3D.new()
	var new_terrain_shape := CollisionShape3D.new()
	
	new_terrain_body.add_child(new_terrain_mesh)
	new_terrain_body.add_child(new_terrain_shape)
	
	new_terrain_body.physics_material_override = physics_material
	
	# Generate mesh and shape
	var vertex_array := PackedVector3Array()
	var normals_array := PackedVector3Array()
	for x_offset in range(
		-Global.GENERATOR_RADIUS, Global.GENERATOR_RADIUS, Global.MESH_STEP
	):
		for z_offset in range(
			-Global.GENERATOR_RADIUS, Global.GENERATOR_RADIUS, Global.MESH_STEP
		):
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
			Global.add_quad_to_normals_array(
				normals_array,
				bot_left,
				bot_right,
				top_left,
				top_right
			)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
	arrays[Mesh.ARRAY_NORMAL] = normals_array
	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	new_terrain_mesh.mesh = array_mesh
	
	var concave_shape = ConcavePolygonShape3D.new()
	concave_shape.set_faces(vertex_array)
	new_terrain_shape.shape = concave_shape
	
	# Generate structures
	var structures_origin = snapped(
		Vector2(origin.x, origin.z),
		Vector2(Global.STRUCTURE_SIZE, Global.STRUCTURE_SIZE)
	)
	for x_offset in range(
		-Global.GENERATOR_RADIUS, Global.GENERATOR_RADIUS, Global.STRUCTURE_SIZE
	):
		for z_offset in range(
			-Global.GENERATOR_RADIUS, Global.GENERATOR_RADIUS, Global.STRUCTURE_SIZE
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
				#wind_current.generate_curve()
				new_terrain_body.add_child(wind_current)
	
	# Finish swap
	add_child.call_deferred(new_terrain_body)
	if current_terrain_body: current_terrain_body.queue_free()
	current_terrain_body = new_terrain_body


func _exit_tree() -> void:
	WorkerThreadPool.wait_for_task_completion(thread_pool_task_id)
