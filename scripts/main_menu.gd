extends Control
## Menu principal — tableau de crépuscule peint en Polygon2D : soleil couchant
## derrière un torii sur la colline, montagnes, rivière aux reflets dorés,
## bambous en bordure et pétales portés par le vent.

const LEVEL_SELECT := "res://scenes/level_select.tscn"
const CREAM := Color(0.97, 0.93, 0.85)

var _sun_glow: Sprite2D
var _t := 0.0
var _options: Control
var _achievements_panel: Control
var _prologue: Control
var _sfx_click: AudioStreamPlayer

func _ready() -> void:
	# Garde-fou : si on arrive ici pendant un ralenti (hit-stop, mort du
	# boss), le temps reprend son cours normal.
	Engine.time_scale = 1.0
	# Revenir au menu désarme le mode Kensei ; « Continuer » relance donc
	# toujours en mode normal, la sélection de niveaux le réarme au besoin.
	Challenge.kensei = false
	Music.play_world()
	# Clic d'interface : joué à chaque bouton (routé vers le bus « Sons »).
	_sfx_click = AudioStreamPlayer.new()
	_sfx_click.stream = load("res://assets/sfx/ui_click.wav")
	_sfx_click.volume_db = -8.0
	add_child(_sfx_click)
	_build_scenery()
	_show_version()
	_build_options_button()
	_build_achievements_button()
	$ContinueButton.visible = SaveManager.has_save()
	_style_button($ContinueButton, Color(0.92, 0.65, 0.3))
	_style_button($LevelsButton, Color(0.92, 0.65, 0.3))
	_style_button($QuitButton, Color(0.6, 0.5, 0.45))
	$ContinueButton.pressed.connect(_on_continue_pressed)
	$LevelsButton.pressed.connect(_on_levels_pressed)
	$QuitButton.pressed.connect(_on_quit_pressed)
	_build_prologue_button()
	# Prologue au tout premier lancement (une seule fois).
	if not SaveManager.prologue_seen():
		_open_prologue()

func _process(delta: float) -> void:
	_t += delta
	if _sun_glow != null:
		_sun_glow.modulate.a = 0.5 + 0.08 * sin(_t * 1.3)

func _poly(parent: Node, points: PackedVector2Array, color: Color, pos := Vector2.ZERO) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.position = pos
	parent.add_child(p)
	return p

func _build_scenery() -> void:
	var sc := Node2D.new()
	add_child(sc)
	move_child(sc, 1)

	# Lueur et disque du soleil couchant
	_sun_glow = Sprite2D.new()
	_sun_glow.texture = load("res://assets/mist.svg")
	_sun_glow.modulate = Color(1.0, 0.72, 0.42, 0.55)
	_sun_glow.scale = Vector2(11.0, 11.0)
	_sun_glow.position = Vector2(250.0, 352.0)
	sc.add_child(_sun_glow)
	var sun_pts := PackedVector2Array()
	for k in 24:
		var a := k * TAU / 24.0
		sun_pts.append(Vector2(cos(a) * 58.0, sin(a) * 58.0))
	_poly(sc, sun_pts, Color(1.0, 0.84, 0.52, 0.95), Vector2(250, 352))
	# Auréole de rayons dorés autour du soleil couchant (derrière le décor).
	var rays := GodRays.new()
	rays.ray_count = 11
	rays.half_spread = 2.7
	rays.length = 560.0
	rays.base_width = 54.0
	rays.color = Color(1.0, 0.82, 0.45, 0.07)
	rays.position = Vector2(250, 352)
	sc.add_child(rays)

	# Oiseaux du soir
	for b in [Vector2(600, 140), Vector2(662, 116), Vector2(568, 100)]:
		_poly(sc, PackedVector2Array([
			Vector2(-10, 0), Vector2(0, -5), Vector2(10, 0), Vector2(0, -2),
		]), Color(0.12, 0.09, 0.18), b)

	# Montagnes lointaines
	_poly(sc, PackedVector2Array([
		Vector2(0, 430), Vector2(70, 336), Vector2(170, 408), Vector2(300, 322),
		Vector2(420, 412), Vector2(540, 340), Vector2(660, 418), Vector2(790, 330),
		Vector2(900, 400), Vector2(960, 372), Vector2(960, 430),
	]), Color(0.32, 0.2, 0.36, 0.85))
	# Crête proche, plus sombre
	_poly(sc, PackedVector2Array([
		Vector2(0, 430), Vector2(120, 386), Vector2(300, 424), Vector2(520, 380),
		Vector2(720, 426), Vector2(870, 392), Vector2(960, 430),
	]), Color(0.2, 0.13, 0.26))

	# Colline du torii
	_poly(sc, PackedVector2Array([
		Vector2(60, 442), Vector2(130, 408), Vector2(240, 396),
		Vector2(350, 410), Vector2(420, 442),
	]), Color(0.14, 0.1, 0.2))

	# Rivière du soir
	_poly(sc, PackedVector2Array([
		Vector2(0, 430), Vector2(960, 430), Vector2(960, 540), Vector2(0, 540),
	]), Color(0.09, 0.08, 0.18))
	# Reflet du soleil dans l'eau
	var ry := 438.0
	var rw := 54.0
	var ra := 0.3
	while ry < 528.0:
		_poly(sc, PackedVector2Array([
			Vector2(250 - rw, ry), Vector2(250 + rw, ry),
			Vector2(250 + rw, ry + 4), Vector2(250 - rw, ry + 4),
		]), Color(1.0, 0.72, 0.4, ra))
		ry += 14.0 + (ry - 430.0) * 0.2
		rw *= 0.82
		ra *= 0.78

	# Torii silhouette sur la colline
	var torii := Node2D.new()
	torii.position = Vector2(240, 398)
	sc.add_child(torii)
	var red := Color(0.62, 0.15, 0.12)
	var red_dark := Color(0.5, 0.11, 0.09)
	_poly(torii, PackedVector2Array([
		Vector2(-50, 0), Vector2(-40, 0), Vector2(-42, -108), Vector2(-52, -108),
	]), red)
	_poly(torii, PackedVector2Array([
		Vector2(40, 0), Vector2(50, 0), Vector2(52, -108), Vector2(42, -108),
	]), red)
	_poly(torii, PackedVector2Array([
		Vector2(-58, -84), Vector2(58, -84), Vector2(58, -74), Vector2(-58, -74),
	]), red)
	_poly(torii, PackedVector2Array([
		Vector2(-62, -112), Vector2(62, -112), Vector2(66, -104), Vector2(-66, -104),
	]), red_dark)
	_poly(torii, PackedVector2Array([
		Vector2(-72, -118), Vector2(-62, -126), Vector2(62, -126), Vector2(72, -118),
		Vector2(66, -112), Vector2(-66, -112),
	]), red_dark)

	# Bambous en bordure d'écran
	var leaf_tex: Texture2D = load("res://assets/leaf.svg")
	for bx in [26.0, 66.0, 906.0, 936.0]:
		var bh := 400.0 + float(int(bx) % 90)
		_poly(sc, PackedVector2Array([
			Vector2(bx - 9, 540), Vector2(bx + 9, 540),
			Vector2(bx + 7, 540 - bh), Vector2(bx - 7, 540 - bh),
		]), Color(0.1, 0.17, 0.13))
		var jy := 490.0
		while jy > 540.0 - bh + 20.0:
			_poly(sc, PackedVector2Array([
				Vector2(bx - 9, jy), Vector2(bx + 9, jy),
				Vector2(bx + 9, jy + 3), Vector2(bx - 9, jy + 3),
			]), Color(0.06, 0.11, 0.08))
			jy -= 64.0
		var dir := 1.0 if int(bx) % 2 == 0 else -1.0
		for k in 3:
			var lf := Sprite2D.new()
			lf.texture = leaf_tex
			lf.position = Vector2(bx + (k - 1) * 16.0 * dir, 540.0 - bh + k * 14.0)
			lf.rotation = (0.5 + k * 0.9) * dir
			lf.scale = Vector2(1.6, 1.6)
			lf.modulate = Color(0.16, 0.26, 0.18)
			sc.add_child(lf)

	# Pétales portés par le vent
	var petals := CPUParticles2D.new()
	petals.texture = leaf_tex
	petals.amount = 26
	petals.lifetime = 11.0
	petals.preprocess = 11.0
	petals.position = Vector2(480, -20)
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.emission_rect_extents = Vector2(540, 12)
	petals.direction = Vector2(0.25, 1.0)
	petals.spread = 15.0
	petals.gravity = Vector2(6, 14)
	petals.initial_velocity_min = 22.0
	petals.initial_velocity_max = 46.0
	petals.angular_velocity_min = -70.0
	petals.angular_velocity_max = 70.0
	petals.scale_amount_min = 0.5
	petals.scale_amount_max = 0.9
	petals.color = Color(0.95, 0.74, 0.78)
	sc.add_child(petals)

	# Grain d'ensemble très discret : voile de matière tuilé sur tout le
	# tableau, comme un léger papier peint, sous les boutons et le titre.
	var grain := Polygon2D.new()
	grain.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(960, 0), Vector2(960, 540), Vector2(0, 540),
	])
	grain.texture = TextureLab.platform_grain()
	grain.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	grain.color = Color(1, 1, 1, 0.06)
	sc.add_child(grain)

func _style_button(b: Button, accent: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.09, 0.17, 0.88)
	sb.border_color = accent
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(8.0)
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
	b.pressed.connect(func() -> void:
		if _sfx_click != null:
			Sfx.varied(_sfx_click, 0.96, 1.06))

func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file(SaveManager.get_last_level_scene())

func _on_levels_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_SELECT)

## Affiche la version de l'application en bas à gauche du menu (remplie
## automatiquement par le CI : "0.NN" = numéro de build).
func _show_version() -> void:
	var v := str(ProjectSettings.get_setting("application/config/version", "dev"))
	var vl := Label.new()
	vl.text = "v" + v
	vl.position = Vector2(12, 512)
	vl.add_theme_font_size_override("font_size", 14)
	vl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85, 0.55))
	vl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	vl.add_theme_constant_override("shadow_offset_x", 1)
	vl.add_theme_constant_override("shadow_offset_y", 1)
	add_child(vl)

func _on_quit_pressed() -> void:
	get_tree().quit()

## ------------------------------------------------------------------ Réglages

## Petit bouton en bas à droite du menu, en miroir du numéro de version.
func _build_options_button() -> void:
	var b := Button.new()
	b.text = "⚙ Réglages"
	b.add_theme_font_size_override("font_size", 16)
	b.position = Vector2(802, 498)
	b.size = Vector2(146, 36)
	_style_button(b, Color(0.6, 0.5, 0.45))
	b.pressed.connect(_open_options)
	add_child(b)

func _open_options() -> void:
	if _options != null:
		_options.visible = true
		return
	_options = Control.new()
	_options.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_options)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.08, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options.add_child(dim)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.09, 0.17, 0.96)
	sb.border_color = Color(0.92, 0.65, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(24.0)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(330, 28)
	panel.custom_minimum_size = Vector2(300, 0)
	_options.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Réglages"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	# Audio + accessibilité : sept réglages qui tiennent sans défilement.
	box.add_child(_setting_row("Musique", "music"))
	box.add_child(_setting_row("Effets sonores", "sfx"))
	box.add_child(_setting_row("Vibrations", "vibrations"))
	box.add_child(_section_label("Accessibilité"))
	box.add_child(_setting_row("Secousses d'écran", "shake"))
	box.add_child(_setting_row("Flashs lumineux", "flash"))
	box.add_child(_setting_row("Mode détente (+2 cœurs)", "assist", false))

	var close := Button.new()
	close.text = "Fermer"
	close.add_theme_font_size_override("font_size", 20)
	_style_button(close, Color(0.92, 0.65, 0.3))
	close.pressed.connect(func() -> void: _options.visible = false)
	box.add_child(close)

## ----------------------------------------------------------------- Prologue

## Petit bouton « Prologue » pour (re)lire l'introduction quand on veut.
func _build_prologue_button() -> void:
	var b := Button.new()
	b.text = "Prologue"
	b.add_theme_font_size_override("font_size", 14)
	b.position = Vector2(70, 498)
	b.size = Vector2(120, 34)
	_style_button(b, Color(0.6, 0.5, 0.45))
	b.pressed.connect(_open_prologue)
	add_child(b)

func _open_prologue() -> void:
	if _prologue != null:
		_prologue.visible = true
		return
	_prologue = Control.new()
	_prologue.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_prologue)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prologue.add_child(dim)

	# Titre figé en haut : toujours visible, ne défile pas.
	var title := Label.new()
	title.text = "La Voie du Sabre"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(130, 20)
	title.custom_minimum_size = Vector2(700, 0)
	title.size = Vector2(700, 40)
	_prologue.add_child(title)

	# Croix de fermeture en haut à droite : accessible même sans lire.
	var close := Button.new()
	close.text = "✕"
	close.add_theme_font_size_override("font_size", 24)
	close.position = Vector2(872, 14)
	close.custom_minimum_size = Vector2(52, 44)
	_style_button(close, Color(0.55, 0.3, 0.3))
	close.pressed.connect(_close_prologue)
	_prologue.add_child(close)

	# Corps défilable : le texte long ne peut plus cacher le bouton.
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(130, 72)
	scroll.custom_minimum_size = Vector2(700, 400)
	scroll.size = Vector2(700, 400)
	UiScroll.make_touch_friendly(scroll)
	_prologue.add_child(scroll)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size = Vector2(668, 0)
	scroll.add_child(box)

	var story := Label.new()
	story.text = "Jadis, la Flamme d'Aube brûlait au cœur du Sanctuaire, et sa lumière tenait les Ombres loin des vivants.\n\nMais le Gardien qui la veillait a sombré dans le désespoir. La Flamme s'est éteinte — et les Ombres ont submergé la clairière, le temple, le village, la montagne.\n\nLéonie, dernier éclat de cette lumière, a trouvé Eneko : le seul dont la lame porte encore la clarté des aïeux.\n\nTon but : rassembler les éclats de la Flamme dispersés dans les terres souillées, atteindre le Sanctuaire, et délivrer le Gardien de sa corruption pour rallumer la Flamme d'Aube. Telle est la Voie du Sabre."
	story.add_theme_font_size_override("font_size", 20)
	story.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86))
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.custom_minimum_size = Vector2(668, 0)
	box.add_child(story)

	var start := Button.new()
	start.text = "Commencer l'aventure"
	start.add_theme_font_size_override("font_size", 22)
	start.custom_minimum_size = Vector2(668, 52)
	_style_button(start, Color(0.92, 0.65, 0.3))
	start.pressed.connect(_close_prologue)
	box.add_child(start)

func _close_prologue() -> void:
	SaveManager.set_prologue_seen()
	if _prologue != null:
		_prologue.visible = false

## ------------------------------------------------------------------- Succès

func _build_achievements_button() -> void:
	var b := Button.new()
	b.text = "🏆 Succès"
	b.add_theme_font_size_override("font_size", 16)
	b.position = Vector2(642, 498)
	b.size = Vector2(146, 36)
	_style_button(b, Color(0.92, 0.65, 0.3))
	b.pressed.connect(_open_achievements)
	add_child(b)

func _open_achievements() -> void:
	if _achievements_panel != null:
		_achievements_panel.visible = true
		return
	_achievements_panel = Control.new()
	_achievements_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_achievements_panel)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.08, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_achievements_panel.add_child(dim)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.09, 0.17, 0.96)
	sb.border_color = Color(0.92, 0.65, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(150, 30)
	panel.custom_minimum_size = Vector2(660, 0)
	_achievements_panel.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Succès — %d/%d" % [Achievements.unlocked_count(), Achievements.DEFS.size()]
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 330)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for d in Achievements.DEFS:
		list.add_child(_achievement_row(d))
	UiScroll.make_touch_friendly(scroll)

	var close := Button.new()
	close.text = "Fermer"
	close.add_theme_font_size_override("font_size", 18)
	_style_button(close, Color(0.92, 0.65, 0.3))
	close.pressed.connect(func() -> void: _achievements_panel.visible = false)
	box.add_child(close)

func _achievement_row(d: Dictionary) -> Control:
	var unlocked := Achievements.is_unlocked(String(d["id"]))
	var secret := bool(d.get("secret", false))
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.13, 0.22, 0.9) if unlocked else Color(1, 1, 1, 0.04)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8.0)
	if unlocked:
		sb.border_width_left = 4
		sb.border_color = Color(1.0, 0.82, 0.35)
	row.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	row.add_child(v)
	var name_l := Label.new()
	name_l.text = "? ? ?" if (secret and not unlocked) else String(d["name"])
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.add_theme_color_override("font_color",
		Color(1.0, 0.88, 0.5) if unlocked else Color(0.65, 0.62, 0.6))
	v.add_child(name_l)
	var desc_l := Label.new()
	desc_l.text = "Un secret attend les plus curieux…" if (secret and not unlocked) else String(d["desc"])
	desc_l.add_theme_font_size_override("font_size", 14)
	desc_l.add_theme_color_override("font_color",
		Color(0.85, 0.83, 0.8, 0.85) if unlocked else Color(0.6, 0.58, 0.56, 0.85))
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc_l)
	return row

## Petit intertitre de section dans les réglages.
func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.92, 0.65, 0.3))
	return l

func _setting_row(label_text: String, key: String, default_on: bool = true) -> HBoxContainer:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 19)
	lbl.add_theme_color_override("font_color", CREAM)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var check := CheckButton.new()
	check.button_pressed = SaveManager.setting_on(key, default_on)
	check.toggled.connect(func(on: bool) -> void:
		SaveManager.set_setting(key, on)
		Music.apply_settings()
		if key == "vibrations" and on:
			Input.vibrate_handheld(30)
	)
	row.add_child(check)
	return row
