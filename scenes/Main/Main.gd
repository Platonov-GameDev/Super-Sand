extends Node3D


@onready var player: Player = $Player
@onready var land_cushion_body: StaticBody3D = $LandCushionBody

var CUSHION_RADIUS := 3

var first_chunk_transform: Transform3D
var cushion_bits: Array[CollisionShape3D] = []


func _ready():
	player.board_base.has_landed.connect(_on_board_base_has_landed)
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	land_cushion_body.transform = first_chunk_transform
	
	for i in range(-CUSHION_RADIUS, CUSHION_RADIUS + 1):
		for j in range(-CUSHION_RADIUS, CUSHION_RADIUS + 1):
			var new_cushion_bit = CollisionShape3D.new()
			new_cushion_bit.shape = ConvexPolygonShape3D.new()
			cushion_bits.append(new_cushion_bit)
			land_cushion_body.add_child(new_cushion_bit)


func _on_board_base_has_landed(land_position: Vector3):
	var cushion_origin_point = land_position * first_chunk_transform
	
	var cushion_bit_counter := 0
	for i in range(-CUSHION_RADIUS, CUSHION_RADIUS + 1):
		for j in range(-CUSHION_RADIUS, CUSHION_RADIUS + 1):
			var bit_x = cushion_origin_point.x + i * Global.MESH_STEP
			var bit_z = cushion_origin_point.z + j * Global.MESH_STEP
			cushion_bit_counter = _generate_cushion_bit(bit_x, bit_z, cushion_bit_counter)


func _generate_cushion_bit(x: float, z: float, bit_index: int):
	var bit_vertices := PackedVector3Array()
	var chunk_number = -int(z / (Global.GENERATOR_RADIUS))
	
	#var bot_left = get_terrain_point_from_x_z(x, z, chunk_number)
	#var bot_right = _get_terrain_point_from_x_z(x + Global.MESH_STEP, z, chunk_number)
	#var top_left = _get_terrain_point_from_x_z(x, z - Global.MESH_STEP, chunk_number)
	#var top_right = _get_terrain_point_from_x_z(x + Global.MESH_STEP, z - Global.MESH_STEP, chunk_number)
	#
	#Global.add_quad_to_vertex_array(
		#bit_vertices,
		#bot_left,
		#bot_right,
		#top_left,
		#top_right
	#)
	#
	#cushion_bits[bit_index].shape.points = bit_vertices
	
	return bit_index + 1
