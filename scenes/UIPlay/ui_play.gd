extends Control


@onready var accumulated_score_label: Label = $AccumulatedScoreLabel
@onready var combo_label: Label = $AccumulatedScoreLabel/ComboLabel
@onready var score_label: Label = $ScoreLabel


func _ready():
	Global.current_score_changed.connect(_on_global_current_score_changed)
	Global.accumulated_score_changed.connect(_on_global_accumulated_score_changed)
	Global.current_combo_changed.connect(_on_global_current_combo_changed)
	Global.started_accumulating_score.connect(_on_global_started_accumulating_score)
	Global.stopped_accumulating_score.connect(_on_global_stopped_accumulating_score)
	
	accumulated_score_label.visible = false
	combo_label.text = ""


func _on_global_current_score_changed(new_value: int):
	score_label.text = str(new_value)


func _on_global_accumulated_score_changed(new_value: int):
	accumulated_score_label.text = str(new_value)


func _on_global_started_accumulating_score():
	accumulated_score_label.visible = true


func _on_global_stopped_accumulating_score():
	accumulated_score_label.visible = false


func _on_global_current_combo_changed(new_value: int):
	if new_value > 1:
		combo_label.text = "x%d" % new_value
	else:
		combo_label.text = ""
