extends Node3D
class_name Player


@onready var board_base = $BoardBase
@onready var torso_joint: JoltGeneric6DOFJoint3D = $BoardBase/TorsoJoint
@onready var torso: RigidBody3D = $Torso
@onready var left_hand: RigidBody3D = $LeftHand
@onready var right_hand: RigidBody3D = $RightHand
@onready var left_hand_joint: JoltGeneric6DOFJoint3D = $Torso/LeftHandJoint
@onready var right_hand_joint: JoltGeneric6DOFJoint3D = $Torso/RightHandJoint
@onready var cam_arm: Node3D = $BoardBase/CamArm
@onready var camera: Camera3D = $BoardBase/Camera3D
@onready var nitro_mesh: MeshInstance3D = $BoardBase/NitroMesh
@onready var maneuvering_thrusters: Node3D = $BoardBase/ManeuveringThrusters

var LEAN_CONTROL := 20
var TORSO_LEAN_AMOUNT := .5
var SITDOWN_AMOUNT := .1
var HAND_BALANCING_AMOUNT := 1.0
var AIR_HAND_DRAG := 1
var NITRO_BOOST := 100
var MANEUVERING_AMOUNT := 20

var torso_offset: Vector3
var left_hand_offset: Vector3
var right_hand_offset: Vector3
var torso_rotation: Vector3
var left_hand_rotation: Vector3
var right_hand_rotation: Vector3


func _ready():
	Global.player = self
	board_base.linear_velocity.z = -60
	camera.global_position = global_position
	camera.global_position.z += 20
	camera.global_position.y += 3.5
	
	nitro_mesh.visible = false


func _physics_process(delta):
	if Input.is_action_just_pressed("Reload"):
		Global.reload()
	
	if not Global.is_player_alive: return
	
	## Movement
	
	var air_control_input = Input.get_vector("Move right", "Move left", "Move forward", "Move back")
	board_base.apply_torque(board_base.global_basis.x * air_control_input.y * LEAN_CONTROL)
	board_base.apply_torque(board_base.global_basis.z * air_control_input.x * LEAN_CONTROL)
	
	## Body animation
	
	var gyro_rotation = board_base.global_rotation.clampf(-0.5, 0.5)
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
	
	if not board_base.is_on_ground:
		var hand_drag_force = (
			(-(board_base.linear_velocity + torso.global_position) * torso.transform).normalized() * AIR_HAND_DRAG)
		
		left_hand_joint.set_param_x(
			JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_LOWER, hand_drag_force.x)
		left_hand_joint.set_param_x(
			JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_UPPER, hand_drag_force.x)
		left_hand_joint.set_param_y(
			JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_LOWER, hand_drag_force.y)
		left_hand_joint.set_param_y(
			JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_UPPER, hand_drag_force.y)
		left_hand_joint.set_param_z(
			JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_LOWER, hand_drag_force.z)
		left_hand_joint.set_param_z(
			JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_UPPER, hand_drag_force.z)
		
		right_hand_joint.set_param_x(
			JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_LOWER, hand_drag_force.x)
		right_hand_joint.set_param_x(
			JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_UPPER, hand_drag_force.x)
		right_hand_joint.set_param_y(
			JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_LOWER, hand_drag_force.y)
		right_hand_joint.set_param_y(
			JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_UPPER, hand_drag_force.y)
		right_hand_joint.set_param_z(
			JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_LOWER, hand_drag_force.z)
		right_hand_joint.set_param_z(
			JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_UPPER, hand_drag_force.z)
	else:
		left_hand_joint.set_param_x(JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_LOWER, 0.0)
		left_hand_joint.set_param_x(JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_UPPER, 0.0)
		left_hand_joint.set_param_y(JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_LOWER, 0.0)
		left_hand_joint.set_param_y(JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_UPPER, 0.0)
		left_hand_joint.set_param_z(JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_LOWER, 0.0)
		left_hand_joint.set_param_z(JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_UPPER, 0.0)
		
		right_hand_joint.set_param_x(JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_LOWER, 0.0)
		right_hand_joint.set_param_x(JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_UPPER, 0.0)
		right_hand_joint.set_param_y(JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_LOWER, 0.0)
		right_hand_joint.set_param_y(JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_UPPER, 0.0)
		right_hand_joint.set_param_z(JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_LOWER, 0.0)
		right_hand_joint.set_param_z(JoltGeneric6DOFJoint3D.PARAM_LINEAR_LIMIT_UPPER, 0.0)
	
	## Camera interpolation
	
	var lerp_weight := 0.25
	if board_base.is_on_ground:
		cam_arm.position.y = lerp(cam_arm.position.y, 3.5, lerp_weight)
	else:
		cam_arm.position.y = lerp(cam_arm.position.y, 1.5, lerp_weight)
	
	camera.global_position = lerp(camera.global_position, cam_arm.global_position, lerp_weight)
	var cam_lerp_direction = sign(((cam_arm.global_position - camera.global_position).project(-cam_arm.global_basis.z) * cam_arm.global_transform).z)
	
	if cam_lerp_direction < -1:
		camera.global_position = cam_arm.global_position
	
	camera.quaternion = lerp(
		Quaternion.from_euler(camera.global_rotation),
		Quaternion.from_euler(cam_arm.global_rotation),
		lerp_weight
	)
	
	## Crash
	
	# if torso.get_contact_count() > 0:
	# 	Global.is_player_alive = false
	# 	torso_joint.set_flag_x(JoltGeneric6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, false)
	# 	torso_joint.set_flag_y(JoltGeneric6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, false)
	# 	torso_joint.set_flag_z(JoltGeneric6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, false)
	# 	torso_joint.set_flag_x(JoltGeneric6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, false)
	# 	torso_joint.set_flag_y(JoltGeneric6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, false)
	# 	torso_joint.set_flag_z(JoltGeneric6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, false)
	# 	left_hand_joint.set_flag_x(JoltGeneric6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, false)
	# 	left_hand_joint.set_flag_y(JoltGeneric6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, false)
	# 	left_hand_joint.set_flag_z(JoltGeneric6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, false)
	# 	right_hand_joint.set_flag_x(JoltGeneric6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, false)
	# 	right_hand_joint.set_flag_y(JoltGeneric6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, false)
	# 	right_hand_joint.set_flag_z(JoltGeneric6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, false)
	
	## Nitro
	
	if board_base.is_on_ground and Global.nitro_amount > 0:
		board_base.apply_central_force(NITRO_BOOST * -board_base.global_basis.z)
		Global.nitro_amount = clampf(Global.nitro_amount - delta, 0, 5)
		nitro_mesh.visible = true
	elif not board_base.is_on_ground:
		Global.nitro_amount = clampf(Global.nitro_amount + delta, 0, 5)
		nitro_mesh.visible = false
	elif Global.nitro_amount == 0:
		nitro_mesh.visible = false
	
	## Maneuvering
	
	if board_base.is_on_ground:
		maneuvering_thrusters.visible = false
	else:
		board_base.apply_central_force(-board_base.global_basis.z * MANEUVERING_AMOUNT)
		maneuvering_thrusters.visible = true
	
