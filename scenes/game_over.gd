extends Control

#@export var level_scene: PackedScene = load("res://scenes/level.tscn")

@onready var score_label: Label = $CenterContainer/VBoxContainer/Label2
@onready var high_score_label: Label = $CenterContainer/VBoxContainer/HighScoreLabel
@onready var mode_label: Label = $CenterContainer/VBoxContainer/ModeLabel
@onready var rank_intro_label: Label = $CenterContainer/VBoxContainer/Label3
@onready var rank_label: Label = $CenterContainer/VBoxContainer/RankLabel

func _ready():
	if str(Global.mode) == "story":
		var reached_phase = clampi(int(Global.story_chapter_id), 1, 6)
		score_label.text = str("You reached\nPhase ", reached_phase, "!")
		high_score_label.visible = false
		mode_label.text = "Story Mode"
		rank_intro_label.visible = false
		rank_label.visible = false
		return

	var new_high_score := Global.record_last_score(Global.score)
	score_label.text = "Score\n" + Global.format_score_value(Global.score)
	if new_high_score:
		high_score_label.text = "New High Score!\n" + Global.format_score_value(Global.high_score)
	else:
		high_score_label.text = "High Score\n" + Global.format_score_value(Global.high_score)
	mode_label.text = "Plants " + Global.mode + " mode"
	var rank_key := Global.get_rank_threshold(Global.score)
	var rank_str = Global.ranks[rank_key]
	
	if(rank_str=="Grassroots Economist"):
		mode_label.text = "You WON! Plants " + Global.mode + " mode"
	
	rank_label.text = rank_str


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("shoot"):
		Global.record_last_score()
		Global.score = 0
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


func _on_button_pressed() -> void:
	Global.record_last_score()
	Global.score = 0
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
