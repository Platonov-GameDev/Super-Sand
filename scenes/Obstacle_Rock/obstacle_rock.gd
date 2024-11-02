extends StaticBody3D


@onready var stone_5: MeshInstance3D = $Stone_5


func _ready():
	stone_5.set_surface_override_material(0, Global.rock_material)
