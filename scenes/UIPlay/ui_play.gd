extends Control

@onready var nitro_bar: ProgressBar = $NitroBar


func _ready():
	Global.nitro_amount_changed.connect(_on_global_nitro_amount_changed)


func _on_global_nitro_amount_changed(new_value):
	nitro_bar.value = new_value * 100 / 5
