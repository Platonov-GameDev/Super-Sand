extends Node


@export var RIDGE_NOISE: FastNoiseLite
@export var RIDGE_HEIGHT_NOISE: FastNoiseLite
@export var STRUCTURE_NOISE: FastNoiseLite
@export var ROCK_NOISE: FastNoiseLite
@export var player_scene: PackedScene
@export var rock_material: StandardMaterial3D

@onready var score_accumulation_reset_timer = $ScoreAccumulationResetTimer

var HIGH_POLY_MESH_RADIUS := 800
var LOW_POLY_MESH_RADIUS := 1600
var ACTIVE_STRUCTURE_RADIUS := 800
var STRUCTURE_SIZE := 150
var RESOLUTION := 0.5
var HEIGHT_SCALE := 50.0
var MESH_STEP := 1.0 / RESOLUTION
var FAR_MESH_STEP := 10.0
var VERTICE_SIZE := HIGH_POLY_MESH_RADIUS * RESOLUTION
var RIDGE_NOISE_FREQUENCY := 0.003
var RIDGE_HEIGHT_NOISE_FREQUENCY := 0.003
var WIND_CURRENT_COUNT := 1
var ANGLE := 0.6
var ROCK_SPACING := 10
var RIDGE_STRETCH := 1.5

var current_wind_boost := 0.0
var terrain_seed: int
var player: Player
var main: Node3D
var is_player_resetting := false
var current_score := 0:
	set(value):
		current_score = value
		current_score_changed.emit(value)
var accumulated_score := 0:
	set(value):
		accumulated_score = value
		accumulated_score_changed.emit(value)
var current_combo := 0:
	set(value):
		current_combo = value
		current_combo_changed.emit(value)
var touched_wind_current_ids: Array[String] = []

signal accumulated_score_changed(new_value: int)
signal current_score_changed(new_value: int)
signal current_combo_changed(new_value: int)
signal started_accumulating_score()
signal stopped_accumulating_score()


func _ready():
	score_accumulation_reset_timer.timeout.connect(_on_score_accumulation_reset_timer_timeout)
	
	terrain_seed = int(Time.get_unix_time_from_system())
	
	RIDGE_NOISE.seed = terrain_seed
	RIDGE_HEIGHT_NOISE.seed = terrain_seed
	STRUCTURE_NOISE.seed = terrain_seed
	ROCK_NOISE.seed = terrain_seed
	
	RIDGE_NOISE.frequency = RIDGE_NOISE_FREQUENCY
	RIDGE_HEIGHT_NOISE.frequency = RIDGE_HEIGHT_NOISE_FREQUENCY
	
	rock_material.distance_fade_min_distance = ACTIVE_STRUCTURE_RADIUS / 4.0
	rock_material.distance_fade_max_distance = rock_material.distance_fade_min_distance - 50


func _physics_process(_delta):
	current_wind_boost = 0


func reload():
	is_player_resetting = true
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
	var noise_x = -z / RIDGE_STRETCH
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


func accumulate_score(value: int, wind_current_id: String):
	accumulated_score += value
	started_accumulating_score.emit()
	score_accumulation_reset_timer.start()
	
	if not touched_wind_current_ids.has(wind_current_id):
		touched_wind_current_ids.append(wind_current_id)
		current_combo = touched_wind_current_ids.size()


func _on_score_accumulation_reset_timer_timeout():
	current_score += accumulated_score * current_combo
	accumulated_score = 0
	stopped_accumulating_score.emit()
	
	touched_wind_current_ids.clear()
	current_combo = 0
