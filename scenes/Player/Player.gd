extends Node3D
class_name Player


@onready var board_base = $BoardBase
@onready var torso_joint: JoltGeneric6DOFJoint3D = $BoardBase/TorsoJoint
@onready var torso: RigidBody3D = $Torso
@onready var left_hand: RigidBody3D = $LeftHand
@onready var right_hand: RigidBody3D = $RightHand
@onready var left_hand_joint: JoltGeneric6DOFJoint3D = $Torso/LeftHandJoint
@onready var right_hand_joint: JoltGeneric6DOFJoint3D = $Torso/RightHandJoint

var LEAN_CONTROL := 20
var TORSO_LEAN_AMOUNT := .5
var SITDOWN_AMOUNT := .1
var HAND_BALANCING_AMOUNT := 1.0

var torso_offset: Vector3
var left_hand_offset: Vector3
var right_hand_offset: Vector3
var torso_rotation: Vector3
var left_hand_rotation: Vector3
var right_hand_rotation: Vector3


func _ready():
	Global.player = self
	board_base.linear_velocity.z = -60


func _physics_process(_delta):
	var air_control_input = Input.get_vector("Move right", "Move left", "Move forward", "Move back")
	board_base.apply_torque(board_base.global_basis.x * air_control_input.y * LEAN_CONTROL)
	board_base.apply_torque(board_base.global_basis.z * air_control_input.x * LEAN_CONTROL)
	
	var gyro_rotation = board_base.global_rotation
	if not board_base.is_on_ground:
		gyro_rotation = Vector3.ZERO
	
	var steer_lean_amount = TORSO_LEAN_AMOUNT * -air_control_input.x
	torso_joint.set_param_x(
		JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_LOWER, steer_lean_amount * 2 + gyro_rotation.x)
	torso_joint.set_param_x(
		JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_UPPER, steer_lean_amount * 2 + gyro_rotation.x)
	
	torso_joint.set_param_z(
		JoltGeneric6DOFJoint3D.PARAM_ANGULAR_LIMIT_LOWER, -steer_lean_amount + gyro_rotation.z)
	torso_joint.set_param_z(
		JoltGeneric6DOFJoint3D.PARAM_ANGULAR_LIMIT_UPPER, -steer_lean_amount + gyro_rotation.z)
	
	var hand_balancing_angle = HAND_BALANCING_AMOUNT * -air_control_input.x
	if (
		left_hand_joint.get_param_y(JoltGeneric6DOFJoint3D.PARAM_ANGULAR_LIMIT_LOWER)
		!= hand_balancing_angle
	):
		left_hand_joint.set_param_y(
			JoltGeneric6DOFJoint3D.PARAM_ANGULAR_LIMIT_LOWER, hand_balancing_angle)
		left_hand_joint.set_param_y(
			JoltGeneric6DOFJoint3D.PARAM_ANGULAR_LIMIT_UPPER, hand_balancing_angle)
		right_hand_joint.set_param_y(
			JoltGeneric6DOFJoint3D.PARAM_ANGULAR_LIMIT_LOWER, hand_balancing_angle)
		right_hand_joint.set_param_y(
			JoltGeneric6DOFJoint3D.PARAM_ANGULAR_LIMIT_UPPER, hand_balancing_angle)
	
	var forward_lean_amount = TORSO_LEAN_AMOUNT * abs(air_control_input.y)
	if not board_base.is_on_ground:
		forward_lean_amount = TORSO_LEAN_AMOUNT
	torso_joint.set_param_x(
		JoltGeneric6DOFJoint3D.PARAM_ANGULAR_LIMIT_LOWER, forward_lean_amount)
	torso_joint.set_param_x(
		JoltGeneric6DOFJoint3D.PARAM_ANGULAR_LIMIT_UPPER, forward_lean_amount)
	
	var forward_move_amount = TORSO_LEAN_AMOUNT * air_control_input.y
	torso_joint.set_param_z(
		JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_LOWER, forward_move_amount)
	torso_joint.set_param_z(
		JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_UPPER, forward_move_amount)
	
	var sitdown_amount = (
		-SITDOWN_AMOUNT * clampf(abs(air_control_input.x) + abs(air_control_input).y, 0, 1)
		+ TORSO_LEAN_AMOUNT
	)
	if not board_base.is_on_ground:
		sitdown_amount = 0
	elif air_control_input.x < 0:
		sitdown_amount += TORSO_LEAN_AMOUNT
	
	torso_joint.set_param_y(JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_LOWER, sitdown_amount)
	torso_joint.set_param_y(JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_UPPER, sitdown_amount)
	
	if Input.is_action_just_pressed("Reload"):
		Global.reload()
