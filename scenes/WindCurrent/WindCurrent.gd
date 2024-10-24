extends Node3D
class_name WindCurrent


@onready var curve_mesh_3d: CurveMesh3D = $CurveMesh3D


func set_points(points_array: Array[Vector3]):
	curve_mesh_3d.curve.clear_points()
	for point in points_array:
		curve_mesh_3d.curve.add_point(point)


func _physics_process(_delta):
	var local_player_position = Global.player_position * curve_mesh_3d.global_transform
	var closest_point_to_player = (curve_mesh_3d.curve.get_closest_point(local_player_position))
	var distance_to_player := (local_player_position - closest_point_to_player).length()
	
	if distance_to_player <= 20:
		var boost := pow((20.0 - distance_to_player) / 20.0, 3)
		Global.current_wind_boost += boost
