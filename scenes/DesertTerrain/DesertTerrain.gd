extends Node3D
class_name DesertTerrain


@export var wind_current_scene: PackedScene
@export var rock_structure_scene: PackedScene
@export var sand_near_material: StandardMaterial3D
@export var sand_far_shader: ShaderMaterial
@export var rock_mesh: Mesh

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
var terrain_gen_mutex = Mutex.new()


func _ready():
	mesh_update_area.body_exited.connect(_on_mesh_update_area_body_exited)
	shape_update_area.body_exited.connect(_on_shape_update_area_body_exited)
	structure_update_area.body_exited.connect(_on_structure_update_area_body_exited)
	
	mesh_update_shape.shape.radius = Global.HIGH_POLY_MESH_RADIUS / 2.0
	shape_update_shape.shape.radius = ACTIVE_COLLISION_RADIUS / 2.0
	structure_update_shape.shape.radius = Global.ACTIVE_STRUCTURE_RADIUS / 2.0
	
	_try_swap_near_terrain_mesh(Vector3.ZERO)
	_try_swap_far_terrain_mesh(Vector3.ZERO)
	is_swapping.structures = true
	thread_pool_task_ids.append(
		WorkerThreadPool.add_task(_swap_terrain_structures.bind(Vector3.ZERO)))
	
	sand_near_material.distance_fade_min_distance = (
		Global.HIGH_POLY_MESH_RADIUS - mesh_update_shape.shape.radius)
	sand_near_material.distance_fade_max_distance = (
		sand_near_material.distance_fade_min_distance - 50)
	
	sand_far_shader.set_shader_parameter(
		"near_to_far_seam_start", sand_near_material.distance_fade_min_distance)
	sand_far_shader.set_shader_parameter(
		"near_to_far_seam_end", sand_near_material.distance_fade_max_distance)


func _on_mesh_update_area_body_exited(body):
	if Global.is_player_resetting: return
	
	mesh_update_area.global_position = body.global_position
	
	_try_swap_near_terrain_mesh(body.global_position)
	_try_swap_far_terrain_mesh(body.global_position)


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


func _try_swap_near_terrain_mesh(spawn_position: Vector3):
	if not is_swapping.near_mesh:
		is_swapping.mesh = true
		
		thread_pool_task_ids.append(
			WorkerThreadPool.add_task(_swap_terrain_mesh.bind(
				spawn_position,
				true,
			)))


func _try_swap_far_terrain_mesh(spawn_position: Vector3):
	if not is_swapping.far_mesh:
		is_swapping.far_mesh = true
		
		thread_pool_task_ids.append(
			WorkerThreadPool.add_task(_swap_terrain_mesh.bind(
				spawn_position,
				false,
			)))


func _swap_terrain_mesh(
	origin: Vector3,
	is_near_mesh: bool,
):
	var new_terrain_mesh := MeshInstance3D.new()
	
	var range_min
	var range_max
	var step
	if is_near_mesh:
		range_min = -Global.HIGH_POLY_MESH_RADIUS
		range_max = Global.HIGH_POLY_MESH_RADIUS
		step = Global.MESH_STEP
	else:
		range_min = -Global.LOW_POLY_MESH_RADIUS
		range_max = Global.LOW_POLY_MESH_RADIUS
		step = Global.FAR_MESH_STEP
	
	# Add input fields
	var input_array := PackedFloat32Array()
	var heights_array := _create_terrain_heights_array(
		range_min,
		range_max,
		origin,
		step
	)
	input_array.append(heights_array.size())
	input_array.append_array(heights_array)
	
	input_array.append(range_min)
	input_array.append(range_max)
	var snapped_origin = snapped(
		origin, Vector3(step, step, step))
	input_array.append(snapped_origin.x)
	input_array.append(snapped_origin.y)
	input_array.append(snapped_origin.z)
	input_array.append(step)
	
	# Add output fields
	var output_arrays_size = heights_array.size() * 3 * 6
	input_array.resize(input_array.size() + output_arrays_size * 2)
	
	# Compute
	var side_point_count = (range_max - range_min) / step;
	var output_array := TerrainMeshComputer.compute_mesh(
		input_array, side_point_count - 1)
	
	# Process results
	var vertex_array := PackedVector3Array()
	vertex_array.resize(output_arrays_size / 3.0)
	var vertex_array_offset = 1 + heights_array.size() + 6
	for i in range(vertex_array_offset, vertex_array_offset + output_arrays_size, 3):
		var new_point := Vector3()
		new_point.x = output_array[i]
		new_point.y = output_array[i + 1]
		new_point.z = output_array[i + 2]
		vertex_array.append(new_point)
	
	var normals_array := PackedVector3Array()
	normals_array.resize(output_arrays_size / 3.0)
	var normals_array_offset = 1 + heights_array.size() + 6 + output_arrays_size
	for i in range(normals_array_offset, normals_array_offset + output_arrays_size, 3):
		var new_point := Vector3()
		new_point.x = output_array[i]
		new_point.y = output_array[i + 1]
		new_point.z = output_array[i + 2]
		normals_array.append(new_point)
	
	# Set meshes
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
	arrays[Mesh.ARRAY_NORMAL] = normals_array
	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	new_terrain_mesh.mesh = array_mesh
	
	if is_near_mesh:
		terrain_gen_mutex.lock()
		new_terrain_mesh.material_override = sand_near_material
		terrain_gen_mutex.unlock()
		if current_terrain_near_mesh: current_terrain_near_mesh.queue_free()
		current_terrain_near_mesh = new_terrain_mesh
		is_swapping.near_mesh = false
	else:		
		var rocks_origin = snapped(
			Vector2(origin.x, origin.z),
			Vector2(Global.STRUCTURE_SIZE, Global.STRUCTURE_SIZE)
		)
		var rock_transforms: PackedVector3Array = []
		for x_offset in range(
			range_min,
			range_max,
			Global.STRUCTURE_SIZE
		):
			for z_offset in range(
				range_min,
				range_max,
				Global.STRUCTURE_SIZE
			):
				var structure_x_z = rocks_origin
				structure_x_z.x += x_offset
				structure_x_z.y += z_offset
				
				var structure_position = Global.get_terrain_point_from_x_z(
					structure_x_z.x, structure_x_z.y)
				
				var rock_structure = rock_structure_scene.instantiate()
				rock_structure.position = structure_position
				rock_transforms.append_array(
					rock_structure.generate_rock_mesh_transforms())
		
		terrain_gen_mutex.lock()
		var rock_multimesh = MultiMesh.new()
		rock_multimesh.mesh = rock_mesh
		rock_multimesh.transform_format = MultiMesh.TRANSFORM_3D
		rock_multimesh.instance_count = rock_transforms.size() / 4.0
		rock_multimesh.transform_array = rock_transforms
		
		var rock_multimesh_instance = MultiMeshInstance3D.new()
		rock_multimesh_instance.multimesh = rock_multimesh
		rock_multimesh_instance.material_override = Global.rock_material
		new_terrain_mesh.add_child(rock_multimesh_instance)
		
		new_terrain_mesh.material_override = sand_far_shader
		if current_terrain_far_mesh: current_terrain_far_mesh.call_deferred("queue_free")
		current_terrain_far_mesh = new_terrain_mesh
		is_swapping.far_mesh = false
		terrain_gen_mutex.unlock()
	
	terrain_body.add_child.call_deferred(new_terrain_mesh)


func _swap_terrain_shape(origin: Vector3):
	var new_terrain_shape := CollisionShape3D.new()
	
	var vertex_array = PackedVector3Array()
	var range_min = -ACTIVE_COLLISION_RADIUS
	var range_max = ACTIVE_COLLISION_RADIUS
	var step = Global.MESH_STEP
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
			rock_structure.generate_rock_shapes()
			new_terrain_structures.add_child(rock_structure)
	
	if current_terrain_structures: current_terrain_structures.queue_free()
	terrain_body.add_child.call_deferred(new_terrain_structures)
	current_terrain_structures = new_terrain_structures
	
	is_swapping.structures = false


func _create_terrain_heights_array(
	range_min: float,
	range_max: float,
	origin: Vector3,
	step := Global.MESH_STEP,
) -> PackedFloat32Array:
	origin = snapped(origin, Vector3(step, step, step))
	var heights_array := PackedFloat32Array()

	for x_offset in range(range_min, range_max, step):
		for z_offset in range(range_min, range_max, step):
			var height_position = origin
			height_position.x += x_offset
			height_position.z += z_offset
			heights_array.append(
				Global.get_terrain_height_from_x_z(height_position.x, height_position.z))
	
	return heights_array
	


func _exit_tree() -> void:
	for task_id in thread_pool_task_ids:
		WorkerThreadPool.wait_for_task_completion(task_id)
