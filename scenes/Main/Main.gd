extends Node3D


@onready var player: Player = $Player


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
