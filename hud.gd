extends Node2D

@onready var player_life_bar = $player_life

var player

func _ready():
	player = get_player()


func get_player():
	var root_i_hope = get_parent()
	while root_i_hope.name != "world":
		root_i_hope = root_i_hope.get_parent()
	return(root_i_hope.find_child("Clownfish"))

func update_player_life():
	if player_life_bar.value != player.life:
		player_life_bar.value = player.life

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	update_player_life()
