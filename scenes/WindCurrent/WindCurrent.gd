extends Node3D
class_name WindCurrent


@export var mesh_material: StandardMaterial3D

var TESSELATION_INTERVAL := Global.MESH_STEP

var rng: RandomNumberGenerator
var curve_mesh: CurveMesh3D


func _ready():
	mesh_material.distance_fade_min_distance = Global.ACTIVE_STRUCTURE_RADIUS / 4.0
	mesh_material.distance_fade_max_distance = mesh_material.distance_fade_min_distance - 50


func generate_curve():
	rng = RandomNumberGenerator.new()
	rng.seed = hash("%f %f %d" % [position.x, position.z, Global.terrain_seed])
	
	var start_point = _get_random_wind_point()
	var end_point = _get_random_wind_point(start_point)
	var segments_count = int((start_point - end_point).length() / TESSELATION_INTERVAL) + 1
	var tesselation_step_direction = (end_point - start_point).normalized()
	var curve_points_array: Array[Vector3] = []
	for j in range(segments_count):
		if j == 0:
			curve_points_array.append(start_point)
		elif j == segments_count - 1:
			curve_points_array.append(end_point)
		else:
			var new_internal_point = (
				start_point + tesselation_step_direction * TESSELATION_INTERVAL * j)
			new_internal_point.y = (
				Global.get_terrain_height_from_x_z(
					position.x + new_internal_point.x, position.z + new_internal_point.z)
				- position.y
				)
			curve_points_array.append(new_internal_point)
	
	var curve = Curve3D.new()
	curve.resource_local_to_scene = true
	for point in curve_points_array:
		curve.add_point(point)
	curve_mesh = CurveMesh3D.new()
	curve_mesh.curve = curve
	curve_mesh.curve.bake_interval = TESSELATION_INTERVAL
	curve_mesh.material = mesh_material
	curve_mesh.cm_on_curve_changed()
	add_child(curve_mesh)


func _get_random_wind_point(start_point = null):
	var point = Vector3()
	if not start_point:
		point.x = rng.randf_range(0, Global.STRUCTURE_SIZE)
		point.z = rng.randf_range(0, Global.STRUCTURE_SIZE)
	else:
		point.x = rng.randf_range(start_point.x - Global.STRUCTURE_SIZE * 0.5, start_point.x + Global.STRUCTURE_SIZE * 0.5)
		point.z = rng.randf_range(start_point.z - Global.STRUCTURE_SIZE * 1.5, start_point.z - Global.STRUCTURE_SIZE * 0.5)
	point.y = Global.get_terrain_height_from_x_z(position.x + point.x, position.z + point.z) - position.y
	return point


func _physics_process(_delta):
	var local_player_position = Global.player.board_base.global_position * curve_mesh.global_transform
	var closest_point_to_player = (curve_mesh.curve.get_closest_point(local_player_position))
	var distance_to_player = (local_player_position - closest_point_to_player).length()
	
	if distance_to_player <= 20:
		var boost := pow((20.0 - distance_to_player) / 20.0, 3)
		Global.current_wind_boost += boost
