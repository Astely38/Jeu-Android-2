extends Control
## Menu principal. "Continuer" (visible si une sauvegarde existe) reprend
## au dernier niveau joué ; "Niveaux" ouvre la sélection ; "Quitter" ferme
## le jeu.

const LEVEL_SELECT := "res://scenes/level_select.tscn"

func _ready() -> void:
	$ContinueButton.visible = SaveManager.has_save()
	$ContinueButton.pressed.connect(_on_continue_pressed)
	$LevelsButton.pressed.connect(_on_levels_pressed)
	$QuitButton.pressed.connect(_on_quit_pressed)

func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file(SaveManager.get_last_level_scene())

func _on_levels_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_SELECT)

func _on_quit_pressed() -> void:
	get_tree().quit()
