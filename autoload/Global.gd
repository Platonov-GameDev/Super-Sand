extends Node


var terrain_chunks: Array[DesertTerrainChunk] = []
var player_position: Vector3
var current_wind_boost := 0.0

var terrain_seed: int

signal terrain_collision_shape_updated(new_collision_shape_vertices)


func _ready():
	reset()


func add_terrain_chunk(chunk: DesertTerrainChunk):
	terrain_chunks.append(chunk)
	_generate_new_terrain_collision_shape()


func remove_terrain_chunk(chunk: DesertTerrainChunk):
	terrain_chunks.erase(chunk)
	_generate_new_terrain_collision_shape()


func _generate_new_terrain_collision_shape():
	var collision_shape_vertices = PackedVector3Array()
	for chunk in terrain_chunks:
		collision_shape_vertices.append_array(chunk.collision_shape_vertices)
	
	var concave_polygon_shape = ConcavePolygonShape3D.new()
	concave_polygon_shape.set_faces(collision_shape_vertices)
	terrain_collision_shape_updated.emit(collision_shape_vertices)


func _physics_process(delta):
	current_wind_boost = 0


func reset():
	terrain_seed = Time.get_unix_time_from_system()


func reload():
	reset()
	get_tree().reload_current_scene()
