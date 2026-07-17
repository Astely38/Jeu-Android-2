extends Control
## Écran de sélection des niveaux. La liste est construite depuis
## SaveManager.LEVEL_ORDER : ajouter un niveau à SaveManager.LEVEL_SCENES
## suffit à le faire apparaître ici comme jouable.

const GOLD := Color(0.92, 0.65, 0.3)
const GREEN := Color(0.45, 0.75, 0.4)
const CREAM := Color(0.97, 0.93, 0.85)

## Regroupement des niveaux par chapitre dans la liste. Un niveau absent de
## cette table n'affiche pas d'en-tête (il suit le chapitre courant).
const CHAPTER_OF := {
	"level_1": 1, "level_2": 1, "level_3": 1, "level_4": 1, "level_5": 1,
	"level_6": 2, "level_7": 2, "level_8": 2,
}
const CHAPTER_NAMES := {
	1: "Chapitre I — La Voie du Sabre",
	2: "Chapitre II — La Source de l'Ombre",
}

func _ready() -> void:
	_style_button($BackButton, Color(0.6, 0.5, 0.45))
	$BackButton.pressed.connect(_on_back_pressed)
	_build_list()
	UiScroll.make_touch_friendly($Scroll)

func _build_list() -> void:
	var list: VBoxContainer = $Scroll/List
	# Les niveaux sont groupés par chapitre : un en-tête s'insère à chaque
	# changement de chapitre le long de LEVEL_ORDER.
	var cur_chapter := 0
	for level_id in SaveManager.LEVEL_ORDER:
		var ch: int = CHAPTER_OF.get(level_id, cur_chapter)
		if ch != cur_chapter:
			cur_chapter = ch
			list.add_child(_chapter_header(CHAPTER_NAMES.get(ch, "")))
		list.add_child(_build_row(level_id))
	# Le Jardin Céleste n'apparaît qu'une fois découvert en jeu — pas
	# de ligne « Verrouillé » qui vendrait la mèche.
	if SaveManager.is_unlocked("level_secret"):
		list.add_child(_chapter_header("Détour"))
		list.add_child(_build_row("level_secret"))

## En-tête de chapitre : un titre doré discret qui sépare les groupes de
## niveaux dans la liste.
func _chapter_header(text: String) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 2)
	m.add_theme_constant_override("margin_left", 4)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", GOLD)
	m.add_child(l)
	return m

func _build_row(level_id: String) -> Control:
	var has_scene: bool = SaveManager.LEVEL_SCENES.has(level_id)
	var unlocked: bool = SaveManager.is_unlocked(level_id)
	var completed: bool = SaveManager.is_completed(level_id)
	var playable := has_scene and unlocked

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.11, 0.2, 0.85) if playable else Color(1, 1, 1, 0.03)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	style.set_corner_radius_all(10)
	if playable:
		style.border_width_left = 5
		style.border_color = GREEN if completed else GOLD
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
	title.add_theme_color_override("font_color", CREAM if playable else Color(0.55, 0.53, 0.5))
	vbox.add_child(title)

	var sub := Label.new()
	if not has_scene:
		sub.text = "À venir"
	elif not unlocked:
		sub.text = "Verrouillé"
	elif completed:
		sub.text = "Terminé — %d orbes récoltés" % SaveManager.best_orbs(level_id)
		var grade := SaveManager.best_grade(level_id)
		if grade != "":
			sub.text += " — %s" % Challenge.grade_name(grade)
		var bt := SaveManager.best_time(level_id)
		if bt > 0.0:
			sub.text += " — %d:%02d" % [int(bt) / 60, int(bt) % 60]
		if SaveManager.is_kensei_done(level_id):
			sub.text += " — Kensei ✓"
	else:
		sub.text = "Disponible"
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.85))
	vbox.add_child(sub)

	var action := Button.new()
	action.custom_minimum_size = Vector2(130, 46)
	action.add_theme_font_size_override("font_size", 20)
	if playable:
		action.text = "Rejouer" if completed else "Jouer"
		_style_button(action, GREEN if completed else GOLD)
		action.pressed.connect(_on_play_pressed.bind(level_id))
	elif not has_scene:
		action.text = "..."
		action.disabled = true
	else:
		action.text = "Verrouillé"
		action.disabled = true
	hbox.add_child(action)

	# Mode Kensei : débloqué en battant le Gardien. Le Jardin Céleste,
	# détour paisible, n'a pas de variante Kensei.
	if playable and level_id != "level_secret" and SaveManager.kensei_unlocked():
		var kensei_btn := Button.new()
		kensei_btn.custom_minimum_size = Vector2(110, 46)
		kensei_btn.add_theme_font_size_override("font_size", 20)
		kensei_btn.text = "Kensei"
		_style_button(kensei_btn, Color(0.85, 0.35, 0.3))
		kensei_btn.pressed.connect(_on_kensei_pressed.bind(level_id))
		hbox.add_child(kensei_btn)

	return panel

func _style_button(b: Button, accent: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.09, 0.17, 0.88)
	sb.border_color = accent
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(6.0)
	var hov: StyleBoxFlat = sb.duplicate()
	hov.bg_color = Color(0.2, 0.15, 0.22, 0.92)
	var prs: StyleBoxFlat = sb.duplicate()
	prs.bg_color = Color(0.34, 0.2, 0.18, 0.95)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", prs)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color(1, 0.98, 0.92))
	b.add_theme_color_override("font_pressed_color", Color(1, 0.98, 0.92))

func _on_play_pressed(level_id: String) -> void:
	Challenge.kensei = false
	SaveManager.set_last_level(level_id)
	get_tree().change_scene_to_file(SaveManager.LEVEL_SCENES[level_id])

func _on_kensei_pressed(level_id: String) -> void:
	Challenge.kensei = true
	SaveManager.set_last_level(level_id)
	get_tree().change_scene_to_file(SaveManager.LEVEL_SCENES[level_id])

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
