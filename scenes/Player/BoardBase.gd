extends RigidBody3D


@onready var air_time_timer: Timer = $AirTimeTimer

var WIND_BOOST := .4

var is_on_ground := false
var was_on_ground := false
var is_in_air_for_long := true

signal has_landed(land_position: Vector3)


func _ready():
	air_time_timer.timeout.connect(_on_air_time_timer_timeout)


func _integrate_forces(state):
	is_on_ground = true if get_contact_count() >= 2 else false
	
	if get_contact_count() >= 1 and is_in_air_for_long:
		has_landed.emit(state.get_contact_collider_position(0))
		is_in_air_for_long = false
	if get_contact_count() == 0:
		if air_time_timer.is_stopped():
			air_time_timer.start()
	else:
		air_time_timer.stop()
	
	if is_on_ground:
		var previous_linear_velocity = state.linear_velocity
		
		state.linear_velocity = (
			previous_linear_velocity.limit_length(previous_linear_velocity.length() * 0.5))
		var drag_direction = Plane(global_basis.x).project(
			Plane(global_basis.y).project(previous_linear_velocity)
		).normalized()
		state.linear_velocity += drag_direction * previous_linear_velocity.length() * 0.5
	
	state.linear_velocity = (state.linear_velocity.normalized() *
		(state.linear_velocity.length() + Global.current_wind_boost * WIND_BOOST))
	
	was_on_ground = is_on_ground


func _on_air_time_timer_timeout():
	is_in_air_for_long = true
