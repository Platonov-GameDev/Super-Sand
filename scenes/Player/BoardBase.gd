extends RigidBody3D


@onready var shape_cast_3d = $ShapeCast3D

var WIND_BOOST := 1

var is_on_ground := false
var last_origin := Vector3.ZERO


func _integrate_forces(state):
	if is_on_ground:
		var previous_linear_velocity = state.linear_velocity
		
		state.linear_velocity = previous_linear_velocity.limit_length(previous_linear_velocity.length() * 0.5)
		var drag_direction = Plane(global_basis.x).project(
			Plane(global_basis.y).project(previous_linear_velocity)
		).normalized()
		state.linear_velocity += drag_direction * previous_linear_velocity.length() * 0.5
	
	state.linear_velocity = (state.linear_velocity.normalized() *
		(state.linear_velocity.length() + Global.current_wind_boost * WIND_BOOST))
	
	shape_cast_3d.global_position = last_origin
	#shape_cast_3d.target_position = state.transform.origin - last_origin
	shape_cast_3d.force_shapecast_update()
	
	#if shape_cast_3d.is_colliding():
		#state.transform.origin = (
			#last_origin +
			#(state.transform.origin - last_origin) * shape_cast_3d.get_closest_collision_safe_fraction()
		#)
	
	last_origin = state.transform.origin
