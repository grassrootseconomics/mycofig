extends Control

#@export var level_scene: PackedScene = load("res://scenes/level.tscn")

func _ready():
	$CenterContainer/VBoxContainer/Label2.text = $CenterContainer/VBoxContainer/Label2.text + str(Global.score)
	$CenterContainer/VBoxContainer/ModeLabel.text = Global.mode+" mode"
	var rank_str = Global.ranks[0]
	for ranks in Global.ranks:
		if(Global.score > ranks):
			rank_str = Global.ranks[ranks]
	
	if(rank_str=="Grassroots Economist"):
		$CenterContainer/VBoxContainer/ModeLabel.text = "You WON! "+Global.mode+" mode"
	
	$CenterContainer/VBoxContainer/RankLabel.text = rank_str
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("shoot"):
		Global.score = 0
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
