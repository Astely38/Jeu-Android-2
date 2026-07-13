extends Control
## Menu principal — tableau de crépuscule peint en Polygon2D : soleil couchant
## derrière un torii sur la colline, montagnes, rivière aux reflets dorés,
## bambous en bordure et pétales portés par le vent.

const LEVEL_SELECT := "res://scenes/level_select.tscn"
const CREAM := Color(0.97, 0.93, 0.85)

var _sun_glow: Sprite2D
var _t := 0.0

func _ready() -> void:
	# Garde-fou : si on arrive ici pendant un ralenti (hit-stop, mort du
	# boss), le temps reprend son cours normal.
	Engine.time_scale = 1.0
	_build_scenery()
	$ContinueButton.visible = SaveManager.has_save()
	_style_button($ContinueButton, Color(0.92, 0.65, 0.3))
	_style_button($LevelsButton, Color(0.92, 0.65, 0.3))
	_style_button($QuitButton, Color(0.6, 0.5, 0.45))
	$ContinueButton.pressed.connect(_on_continue_pressed)
	$LevelsButton.pressed.connect(_on_levels_pressed)
	$QuitButton.pressed.connect(_on_quit_pressed)

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

func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file(SaveManager.get_last_level_scene())

func _on_levels_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_SELECT)

func _on_quit_pressed() -> void:
	get_tree().quit()
