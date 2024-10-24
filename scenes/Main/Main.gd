extends Node3D


@onready var terrain_collision_shape = $TerrainCollisionBody/TerrainCollisionShape
@onready var desert_terrain_chunk = $DesertTerrainChunk
@onready var player = $Player


func _ready():
	Global.terrain_collision_shape_updated.connect(_on_global_terrain_collision_shape_updated)
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_global_terrain_collision_shape_updated(collision_shape_vertices: PackedVector3Array):
	terrain_collision_shape.shape.set_faces(collision_shape_vertices)


func _physics_process(_delta):
	Global.player_position = player.board_base.global_position
