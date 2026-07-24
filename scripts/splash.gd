extends Control
## Écran de démarrage : le titre du jeu et Eneko, samouraï, sur un crépuscule
## peint — dans la même veine que le menu principal. S'affiche à chaque
## lancement, avant le menu ; un tap ou quelques secondes suffisent à passer.

const MAIN_MENU := "res://scenes/main_menu.tscn"
const AUTO_ADVANCE := 3.2

const SAMURAI := "res://assets/character/samurai/"

var _advanced := false
var _t := 0.0
var _sun_glow: Sprite2D
var _prompt: Label

func _ready() -> void:
	_build_scenery()
	_build_samurai()
	_build_title()
	_build_prompt()
	get_tree().create_timer(AUTO_ADVANCE).timeout.connect(_advance)

func _process(delta: float) -> void:
	_t += delta
	if _sun_glow != null:
		_sun_glow.modulate.a = 0.5 + 0.08 * sin(_t * 1.3)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey:
		if event.is_pressed():
			_advance()

func _advance() -> void:
	if _advanced:
		return
	_advanced = true
	Transition.goto(MAIN_MENU)

func _poly(parent: Node, points: PackedVector2Array, color: Color, pos := Vector2.ZERO) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.position = pos
	parent.add_child(p)
	return p

## Crépuscule peint : lune pâle, montagnes lointaines, pétales au vent — dans
## la continuité visuelle du menu principal, en plus sombre (rideau d'ouverture).
func _build_scenery() -> void:
	var sc := Node2D.new()
	add_child(sc)  # au-dessus du dégradé de fond, sous le titre et Eneko

	# Décalée du centre (pas derrière le titre, qui y est centré) — un coin de
	# ciel dégagé plutôt que pile au-dessus d'Eneko.
	var moon_pos := Vector2(790.0, 110.0)
	_sun_glow = Sprite2D.new()
	_sun_glow.texture = load("res://assets/mist.svg")
	_sun_glow.modulate = Color(0.75, 0.7, 0.95, 0.5)
	_sun_glow.scale = Vector2(9.5, 9.5)
	_sun_glow.position = moon_pos
	sc.add_child(_sun_glow)
	var moon_pts := PackedVector2Array()
	for i in 22:
		var a := i * TAU / 22.0
		moon_pts.append(Vector2(cos(a) * 42.0, sin(a) * 42.0))
	_poly(sc, moon_pts, Color(0.92, 0.9, 1.0, 0.9), moon_pos)
	var rays := GodRays.new()
	rays.ray_count = 10
	rays.half_spread = 2.6
	rays.length = 480.0
	rays.color = Color(0.7, 0.65, 0.95, 0.05)
	rays.position = moon_pos
	sc.add_child(rays)

	# Montagnes lointaines, dentelées.
	var mx := -40.0
	var mi := 0
	while mx < 1000.0:
		var mh := 90.0 + float(mi * 53 % 90)
		_poly(sc, PackedVector2Array([
			Vector2(-160, 0), Vector2(-30, -mh + 24), Vector2(0, -mh),
			Vector2(50, -mh + 40), Vector2(160, 0),
		]), Color(0.14, 0.1, 0.2, 0.9), Vector2(mx, 480.0))
		mx += 220.0 + float(mi * 37 % 120)
		mi += 1

	# Sol.
	_poly(sc, PackedVector2Array([
		Vector2(-40, 0), Vector2(1000, 0), Vector2(1000, 80), Vector2(-40, 80),
	]), Color(0.08, 0.06, 0.13, 1.0), Vector2(0, 480))

	# Pétales portés par le vent.
	var petals := CPUParticles2D.new()
	petals.texture = load("res://assets/leaf.svg")
	petals.amount = 12
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
	petals.color = Color(0.85, 0.78, 0.95, 0.55)
	sc.add_child(petals)

## Eneko, en grand, planté au premier plan — le visage du jeu.
func _build_samurai() -> void:
	var wrap := Node2D.new()
	wrap.position = Vector2(480, 470)
	add_child(wrap)

	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(0.95, 0.8, 0.55, 0.3)
	glow.scale = Vector2(4.5, 3.0)
	glow.position = Vector2(0, -90)
	glow.z_index = -1
	wrap.add_child(glow)

	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = SpriteSheet.build([
		{"name": "idle", "path": SAMURAI + "Idle.png", "frames": 6, "fps": 8.0, "loop": true},
	])
	anim.position = Vector2(0, -100)
	anim.scale = Vector2(2.3, 2.3)
	anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wrap.add_child(anim)
	anim.play("idle")

func _build_title() -> void:
	var title := Label.new()
	title.text = "Eneko\nla Voie du Sabre"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = 40.0
	title.offset_bottom = 190.0
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color(0.98, 0.94, 0.86))
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.1))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "~ Un conte de sabre et d'esprits ~"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.anchor_left = 0.0
	subtitle.anchor_right = 1.0
	subtitle.offset_top = 196.0
	subtitle.offset_bottom = 226.0
	subtitle.add_theme_font_size_override("font_size", 19)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.78, 0.95, 0.9))
	subtitle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	subtitle.add_theme_constant_override("shadow_offset_x", 2)
	subtitle.add_theme_constant_override("shadow_offset_y", 2)
	add_child(subtitle)

## Invite discrète, qui pulse doucement — le joueur peut aussi bien attendre
## que passer d'un tap.
func _build_prompt() -> void:
	_prompt = Label.new()
	_prompt.text = "Touchez l'écran pour continuer"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_top = -56.0
	_prompt.offset_bottom = -20.0
	_prompt.add_theme_font_size_override("font_size", 16)
	_prompt.add_theme_color_override("font_color", Color(0.9, 0.88, 0.95))
	_prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	_prompt.add_theme_constant_override("shadow_offset_x", 1)
	_prompt.add_theme_constant_override("shadow_offset_y", 2)
	_prompt.modulate.a = 0.0
	add_child(_prompt)
	var t := create_tween()
	t.tween_interval(0.6)
	t.tween_property(_prompt, "modulate:a", 0.85, 0.8)
	# Pulsation douce (Atmosphere.breathe est typé Node2D ; _prompt est un Control).
	t.tween_callback(func() -> void:
		var pulse := _prompt.create_tween().set_loops()
		pulse.tween_property(_prompt, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(_prompt, "modulate:a", 0.6, 0.9).set_trans(Tween.TRANS_SINE))
