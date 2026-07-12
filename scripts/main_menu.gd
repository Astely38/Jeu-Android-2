extends Control
## Menu principal. Le bouton Jouer charge le niveau 1, Quitter ferme le jeu.

const LEVEL_1 := "res://levels/level_1.tscn"

func _ready() -> void:
	$PlayButton.pressed.connect(_on_play_pressed)
	$QuitButton.pressed.connect(_on_quit_pressed)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_1)

func _on_quit_pressed() -> void:
	get_tree().quit()
