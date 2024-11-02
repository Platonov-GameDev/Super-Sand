extends Node


@export var RIDGE_NOISE: FastNoiseLite
@export var RIDGE_HEIGHT_NOISE: FastNoiseLite
@export var STRUCTURE_NOISE: FastNoiseLite
@export var ROCK_NOISE: FastNoiseLite
@export var player_scene: PackedScene

var GENERATOR_RADIUS := 800
var STRUCTURE_SIZE := 150
var RESOLUTION := .5
var HEIGHT_SCALE := 50.0
var MESH_STEP := 1.0 / RESOLUTION
var VERTICE_SIZE := GENERATOR_RADIUS * RESOLUTION
var RIDGE_NOISE_FREQUENCY := 0.003
var RIDGE_HEIGHT_NOISE_FREQUENCY := 0.003
var WIND_CURRENT_COUNT := 1
var ANGLE := 0.6
var ROCK_SPACING := 10

var current_wind_boost := 0.0
var terrain_seed: int
var player: Player
var main: Node3D


func _ready():
	terrain_seed = Time.get_unix_time_from_system()
	
	RIDGE_NOISE.seed = terrain_seed
	RIDGE_HEIGHT_NOISE.seed = terrain_seed
	STRUCTURE_NOISE.seed = terrain_seed
	ROCK_NOISE.seed = terrain_seed
	
	RIDGE_NOISE.frequency = RIDGE_NOISE_FREQUENCY
	RIDGE_HEIGHT_NOISE.frequency = RIDGE_HEIGHT_NOISE_FREQUENCY


func _physics_process(delta):
	current_wind_boost = 0


func reload():
	var player_position = Vector3.ZERO
	if player:
		player.queue_free()
		player_position = player.board_base.global_position
	player_position.y = (
		get_terrain_height_from_x_z(player_position.x, player_position.z)
		+ HEIGHT_SCALE + 20
	)
	
	player = player_scene.instantiate()
	player.position = player_position
	main.add_child(player)


func get_terrain_height_from_x_z(x: float, z: float) -> float:
	var noise_x = -z
	var noise_y = x
	var ridge_noise_value = (1 + RIDGE_NOISE.get_noise_2d(noise_x, noise_y))
	var ridge_height_noise_value = RIDGE_HEIGHT_NOISE.get_noise_2d(noise_x, noise_y) / 2 + 0.5
	return clampf(
		 ridge_noise_value * ridge_height_noise_value,
		0, 1
	) * HEIGHT_SCALE - HEIGHT_SCALE + z * ANGLE


func get_terrain_point_from_x_z(x: float, z: float) -> Vector3:
	var point := Vector3(x, 0, z)
	point.y = get_terrain_height_from_x_z(x, z)
	return point


func get_structure_value_from_x_z(x: float, z: float) -> float:
	return STRUCTURE_NOISE.get_noise_2d(x, z)


func add_quad_to_vertex_array(
	array: PackedVector3Array,
	bot_left: Vector3,
	bot_right: Vector3,
	top_left: Vector3,
	top_right: Vector3,
):
	array.append(bot_left)
	array.append(top_left)
	array.append(top_right)
	
	array.append(bot_left)
	array.append(top_right)
	array.append(bot_right)


func add_quad_to_normals_array(
	array: PackedVector3Array,
	bot_left: Vector3,
	bot_right: Vector3,
	top_left: Vector3,
	top_right: Vector3,
):
	var normal1 = Plane(bot_left, top_left, top_right).normal
	array.append(normal1)
	array.append(normal1)
	array.append(normal1)
	
	var normal2 = Plane(bot_left, top_right, bot_right).normal
	array.append(normal2)
	array.append(normal2)
	array.append(normal2)
