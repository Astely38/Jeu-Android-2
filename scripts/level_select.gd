extends Control
## Écran de sélection des niveaux. La liste est construite depuis
## SaveManager.LEVEL_ORDER : ajouter un niveau à SaveManager.LEVEL_SCENES
## suffit à le faire apparaître ici comme jouable.

func _ready() -> void:
	$BackButton.pressed.connect(_on_back_pressed)
	_build_list()

func _build_list() -> void:
	var list: VBoxContainer = $Scroll/List
	for level_id in SaveManager.LEVEL_ORDER:
		list.add_child(_build_row(level_id))

func _build_row(level_id: String) -> Control:
	var has_scene: bool = SaveManager.LEVEL_SCENES.has(level_id)
	var unlocked: bool = SaveManager.is_unlocked(level_id)
	var completed: bool = SaveManager.is_completed(level_id)
	var playable := has_scene and unlocked

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.08) if playable else Color(1, 1, 1, 0.03)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(0, 76)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(hbox)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var title := Label.new()
	title.text = SaveManager.LEVEL_NAMES.get(level_id, level_id)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.97, 0.93, 0.85) if playable else Color(0.55, 0.53, 0.5))
	vbox.add_child(title)

	var sub := Label.new()
	if not has_scene:
		sub.text = "À venir"
	elif not unlocked:
		sub.text = "Verrouillé"
	elif completed:
		sub.text = "Terminé — %d orbes récoltés" % SaveManager.best_orbs(level_id)
	else:
		sub.text = "Disponible"
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.85))
	vbox.add_child(sub)

	var action := Button.new()
	action.custom_minimum_size = Vector2(120, 44)
	action.add_theme_font_size_override("font_size", 20)
	if playable:
		action.text = "Rejouer" if completed else "Jouer"
		action.pressed.connect(_on_play_pressed.bind(level_id))
	elif not has_scene:
		action.text = "..."
		action.disabled = true
	else:
		action.text = "Verrouillé"
		action.disabled = true
	hbox.add_child(action)

	return panel

func _on_play_pressed(level_id: String) -> void:
	SaveManager.set_last_level(level_id)
	get_tree().change_scene_to_file(SaveManager.LEVEL_SCENES[level_id])

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
