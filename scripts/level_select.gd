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
	"level_6": 2, "level_7": 2, "level_8": 2, "level_9": 2, "level_10": 2,
	"level_11": 3, "level_12": 3, "level_13": 3, "level_14": 3, "level_15": 3,
}
const CHAPTER_NAMES := {
	1: "Chapitre I — La Voie du Sabre",
	2: "Chapitre II — La Source de l'Ombre",
	3: "Chapitre III — L'Écho dans le Noir",
	4: "Chapitre IV — Au-delà du Miroir",
}

func _ready() -> void:
	_build_scenery()
	_style_button($BackButton, Color(0.6, 0.5, 0.45))
	$BackButton.pressed.connect(_on_back_pressed)
	_build_list()
	UiScroll.make_touch_friendly($Scroll)
	_build_petals()

func _poly(parent: Node, points: PackedVector2Array, color: Color, pos := Vector2.ZERO) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.position = pos
	parent.add_child(p)
	return p

## Toile de fond peinte, dans la même veine crépusculaire que le menu
## principal : lointaine chaîne de montagnes et torii de pierre, cadrés
## surtout aux marges pour ne jamais gêner la lecture de la liste.
func _build_scenery() -> void:
	var sc := Node2D.new()
	add_child(sc)
	move_child(sc, 1)  # au-dessus du dégradé, sous le titre et la liste

	# Lueur de lune, discrète, en haut à droite (jamais couverte par le titre).
	var moon_glow := Sprite2D.new()
	moon_glow.texture = load("res://assets/mist.svg")
	moon_glow.modulate = Color(0.75, 0.8, 0.95, 0.3)
	moon_glow.scale = Vector2(4.0, 4.0)
	moon_glow.position = Vector2(880.0, 40.0)
	sc.add_child(moon_glow)
	var moon_pts := PackedVector2Array()
	for i in 18:
		var a := i * TAU / 18.0
		moon_pts.append(Vector2(cos(a) * 16.0, sin(a) * 16.0))
	_poly(sc, moon_pts, Color(0.92, 0.94, 1.0, 0.5), Vector2(880, 40))

	# Chaîne de montagnes lointaine, tout en bas — juste une frange visible
	# derrière le bouton Retour et le bord de la liste.
	var mx := -40.0
	var mi := 0
	while mx < 1000.0:
		var mh := 60.0 + float(mi * 53 % 50)
		_poly(sc, PackedVector2Array([
			Vector2(-140, 0), Vector2(0, -mh), Vector2(140, 0),
		]), Color(0.22, 0.15, 0.28, 0.55), Vector2(mx, 560.0))
		mx += 200.0 + float(mi * 37 % 90)
		mi += 1

	# Torii de pierre en silhouette, tout en bas à gauche.
	var torii := Node2D.new()
	torii.position = Vector2(70.0, 552.0)
	torii.modulate = Color(1, 1, 1, 0.4)
	sc.add_child(torii)
	var red := Color(0.42, 0.14, 0.12)
	_poly(torii, PackedVector2Array([
		Vector2(-30, 0), Vector2(-24, 0), Vector2(-25, -64), Vector2(-31, -64),
	]), red)
	_poly(torii, PackedVector2Array([
		Vector2(24, 0), Vector2(30, 0), Vector2(31, -64), Vector2(25, -64),
	]), red)
	_poly(torii, PackedVector2Array([
		Vector2(-35, -50), Vector2(35, -50), Vector2(35, -44), Vector2(-35, -44),
	]), red)
	_poly(torii, PackedVector2Array([
		Vector2(-40, -68), Vector2(40, -68), Vector2(44, -62), Vector2(-44, -62),
	]), Color(0.34, 0.11, 0.09))

## Pétales portés par le vent, en surcouche légère sur toute l'interface —
## le même souffle que le menu principal, pour relier visuellement les deux
## écrans. Faible densité : ne doit jamais nuire à la lecture de la liste.
func _build_petals() -> void:
	var petals := CPUParticles2D.new()
	petals.texture = load("res://assets/leaf.svg")
	petals.amount = 10
	petals.lifetime = 12.0
	petals.preprocess = 12.0
	petals.position = Vector2(480, -20)
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.emission_rect_extents = Vector2(500, 10)
	petals.direction = Vector2(0.25, 1.0)
	petals.spread = 15.0
	petals.gravity = Vector2(5, 12)
	petals.initial_velocity_min = 16.0
	petals.initial_velocity_max = 32.0
	petals.angular_velocity_min = -50.0
	petals.angular_velocity_max = 50.0
	petals.scale_amount_min = 0.4
	petals.scale_amount_max = 0.7
	petals.color = Color(0.95, 0.74, 0.78, 0.55)
	add_child(petals)

func _build_list() -> void:
	var list: VBoxContainer = $Scroll/List
	# Les niveaux sont groupés par chapitre : un en-tête s'insère à chaque
	# changement de chapitre le long de LEVEL_ORDER.
	# Compteur de reliques : n'apparaît qu'une fois la première dénichée
	# (sinon on vendrait l'existence du secret).
	if SaveManager.relics_found() > 0:
		list.add_child(_relic_counter())
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

## Bandeau du nombre de reliques déjà réunies (sur douze).
func _relic_counter() -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 4)
	m.add_theme_constant_override("margin_bottom", 6)
	m.add_theme_constant_override("margin_left", 4)
	var l := Label.new()
	l.text = "✦ Reliques   %d / %d" % [SaveManager.relics_found(), SaveManager.TOTAL_RELICS]
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
	m.add_child(l)
	return m

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

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)
	var title := Label.new()
	title.text = SaveManager.LEVEL_NAMES.get(level_id, level_id)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", CREAM if playable else Color(0.55, 0.53, 0.5))
	title_row.add_child(title)
	# Sceau doré : le niveau a livré sa relique cachée.
	if SaveManager.has_relic(level_id):
		var seal := Label.new()
		seal.text = "✦"
		seal.add_theme_font_size_override("font_size", 22)
		seal.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
		title_row.add_child(seal)

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
	Transition.goto(SaveManager.LEVEL_SCENES[level_id])

func _on_back_pressed() -> void:
	Transition.goto("res://scenes/main_menu.tscn")
