extends Node3D
class_name Player


@onready var board_base = $BoardBase
@onready var torso_joint: JoltGeneric6DOFJoint3D = $BoardBase/TorsoJoint
@onready var torso: RigidBody3D = $Torso
@onready var head: RigidBody3D = $Head
@onready var left_hand: RigidBody3D = $LeftHand
@onready var right_hand: RigidBody3D = $RightHand

var LEAN_CONTROL := 20
var TORSO_LEAN_AMOUNT := .5


func _ready():
	Global.player = self
	reposition()


func _physics_process(_delta):
	var air_control_input = Input.get_vector("Move right", "Move left", "Move forward", "Move back")
	board_base.apply_torque(board_base.global_basis.x * air_control_input.y * LEAN_CONTROL)
	board_base.apply_torque(board_base.global_basis.z * air_control_input.x * LEAN_CONTROL)
	
	var steer_lean_amount = TORSO_LEAN_AMOUNT * -air_control_input.x
	torso_joint.set_param_z(
		JoltGeneric6DOFJoint3D.PARAM_ANGULAR_LIMIT_LOWER, steer_lean_amount)
	torso_joint.set_param_z(
		JoltGeneric6DOFJoint3D.PARAM_ANGULAR_LIMIT_UPPER, steer_lean_amount)
	
	var forward_lean_amount = TORSO_LEAN_AMOUNT * abs(air_control_input.y)
	torso_joint.set_param_x(
		JoltGeneric6DOFJoint3D.PARAM_ANGULAR_LIMIT_LOWER, forward_lean_amount)
	torso_joint.set_param_x(
		JoltGeneric6DOFJoint3D.PARAM_ANGULAR_LIMIT_UPPER, forward_lean_amount)
	var forward_move_amount = TORSO_LEAN_AMOUNT * air_control_input.y
	torso_joint.set_param_z(
		JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_LOWER, forward_move_amount)
	torso_joint.set_param_z(
		JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_UPPER, forward_move_amount)
	
	if Input.is_action_just_pressed("Reload"):
		Global.reload()


func reposition():	
	var board_position = board_base.position
	
	board_base.position.y = (
		Global.get_terrain_height_from_x_z(board_position.x, board_position.z) + 15)
	board_base.linear_velocity = Vector3.ZERO
	board_base.linear_velocity.z = -60
	board_base.rotation = Vector3.ZERO
	
	torso.position = board_base.position
	torso.position.y += 1.2
	
	head.position = board_base.position
	head.position.y += 2
	
	left_hand.position = torso.position
	right_hand.position = torso.position
	left_hand.position.x -= 1
	right_hand.position.x += 1
