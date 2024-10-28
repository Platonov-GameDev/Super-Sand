extends Node3D
class_name Player


@onready var board_base = $BoardBase

var LEAN_CONTROL := 20


func _physics_process(_delta):	
	var air_control_input = Input.get_vector("Move right", "Move left", "Move forward", "Move back")
	board_base.apply_torque(board_base.global_basis.x * air_control_input.y * LEAN_CONTROL)
	board_base.apply_torque(board_base.global_basis.z * air_control_input.x * LEAN_CONTROL)
	
	if Input.is_action_just_pressed("Reload"):
		Global.reload()
