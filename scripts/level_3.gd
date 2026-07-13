extends Node2D
## Niveau 3 : « Le Village des Ombres ».
## Un village abandonné au crépuscule rouge sang : maisons aux fenêtres
## luisantes, cordées de lanternes, braseros aux flammes animées, arbres
## morts et brume violette. Les Ombres corrompues y règnent en nombre.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const PATROL_SCENE := preload("res://scenes/enemy.tscn")
const SHADOW_SCENE := preload("res://scenes/shadow.tscn")
const LEONIE_SCENE := preload("res://scenes/leonie.tscn")
const SPIRIT_SCENE := preload("res://scenes/spirit.tscn")

const GROUND_Y := 550.0    # centre vertical des plateformes
const SPAWN_Y := 477.0     # hauteur d'apparition des personnages
const LEVEL_END := 7100.0
const GOAL_X := 6800.0
const LEVEL_ID := "level_3"

const DIRT := Color(0.29, 0.25, 0.24)
const DIRT_DARK := Color(0.2, 0.17, 0.17)
const PATH := Color(0.44, 0.41, 0.42)
const WOOD := Color(0.32, 0.22, 0.15)
const WOOD_DARK := Color(0.24, 0.16, 0.11)

## Plateformes : x = centre, y = demi-largeur. Trous de 140 à 160 px
## (portée de saut max ≈ 190 px) — un cran plus exigeant que le niveau 1.
const PLATFORMS := [
	Vector2(240, 240), Vector2(870, 250), Vector2(1510, 240),
	Vector2(2140, 230), Vector2(2760, 240), Vector2(3400, 260),
	Vector2(4040, 230), Vector2(4670, 240), Vector2(5300, 230),
	Vector2(5930, 250), Vector2(6620, 290),
]
const CHECKPOINT_XS := [1620.0, 3450.0, 5150.0]
const PATROL_XS := [950.0, 1550.0, 2200.0, 2800.0, 4050.0, 4700.0, 5900.0]
const SHADOW_XS := [1400.0, 2650.0, 3350.0, 4600.0, 5350.0, 6100.0, 6600.0]
## Yūrei tireurs : esprits flottants qui crachent des orbes corrompus.
const SPIRIT_XS := [1900.0, 4400.0]
const TRAP_XS := [800.0, 2050.0, 3550.0, 4850.0, 6450.0]
const BRAZIER_XS := [400.0, 1700.0, 2700.0, 3900.0, 5450.0, 6380.0]
const ORBS := [
	Vector2(330, 440), Vector2(560, 405), Vector2(870, 440),
	Vector2(1190, 405), Vector2(1510, 440), Vector2(1830, 405),
	Vector2(2140, 440), Vector2(2450, 405), Vector2(2760, 440),
	Vector2(3080, 405), Vector2(3400, 440), Vector2(3720, 405),
	Vector2(4040, 440), Vector2(4360, 405), Vector2(4670, 440),
	Vector2(4990, 405), Vector2(5300, 440), Vector2(5620, 405),
	Vector2(5930, 440), Vector2(6270, 405), Vector2(6620, 440),
]

const LEONIE_LINES := [
	{ "name": "Léonie", "text": "Le Village des Ombres... autrefois chaleureux et vivant, maintenant rongé par la corruption." },
	{ "name": "Léonie", "text": "Les Ombres y sont nombreuses, mais elles fuient devant la lumière du sabre. Fais briller ta lame." },
	{ "name": "Léonie", "text": "Ma lumière t'entoure. Les esprits des habitants veillent aussi sur toi. Sois courageux." },
	{ "name": "Léonie", "text": "Traverse ce village avec respect. Ramène la paix que les Ombres lui ont volée." },
	{ "name": "Eneko", "text": "Je n'oublierai pas les âmes qui habitent ce lieu." },
]

var sfx_win: AudioStreamPlayer
var wisps: CPUParticles2D
var _flames: Array = []
var _halos: Array = []
var _t := 0.0

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var next_button: Button = $WinLabel/NextButton
@onready var dialogue: CanvasLayer = $Dialogue

func _ready() -> void:
	_build_decor()
	_build_platforms()
	_build_braziers()
	_build_checkpoints()
	_build_traps()
	_build_goal()
	_build_kill_zone()
	_spawn_entities()
	_setup_audio()
	win_label.visible = false
	SaveManager.set_last_level(LEVEL_ID)
	Challenge.start_level(LEVEL_ID, ORBS.size())
	_attach_player_glow()
	dialogue.finished.connect(_on_dialogue_finished)
	menu_button.pressed.connect(_on_menu_pressed)
	var next_scene: String = SaveManager.LEVEL_SCENES.get("level_4", "")
	next_button.visible = next_scene != ""
	if next_scene != "":
		next_button.pressed.connect(func(): get_tree().change_scene_to_file(next_scene))
	# Survol d'introduction : du torii, à travers le village, jusqu'à Eneko.
	player.intro_pan(Vector2(GOAL_X, 380.0))

func _process(delta: float) -> void:
	_t += delta
	for i in _flames.size():
		var f: Polygon2D = _flames[i]
		f.scale.y = 1.0 + 0.16 * sin(_t * 8.0 + i * 1.7)
		f.scale.x = 1.0 + 0.1 * sin(_t * 6.3 + i * 2.3)
	for i in _halos.size():
		var h: Sprite2D = _halos[i]
		h.modulate.a = 0.18 + 0.06 * sin(_t * 4.6 + i * 1.3)

func _physics_process(_delta: float) -> void:
	if wisps != null and is_instance_valid(player):
		wisps.position = Vector2(player.position.x, player.position.y - 200.0)

# --- Construction du niveau ---------------------------------------------

## Halo chaud autour d'Eneko : sous la lune de sang, il porte sa propre
## lumière (rendu derrière son sprite).
func _attach_player_glow() -> void:
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(1.0, 0.75, 0.45, 0.15)
	glow.scale = Vector2(3.2, 3.2)
	glow.position = Vector2(0, -10)
	glow.z_index = -1
	player.add_child(glow)

func _poly(parent: Node, points: PackedVector2Array, color: Color, pos := Vector2.ZERO) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.position = pos
	parent.add_child(p)
	return p

func _rect_points(half_w: float, top: float, bottom: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half_w, top), Vector2(half_w, top),
		Vector2(half_w, bottom), Vector2(-half_w, bottom),
	])

## Lune basse et rouge, collines noires, maisons aux fenêtres luisantes,
## arbres morts, cordées de lanternes et brume violette.
func _build_decor() -> void:
	var bg: ParallaxBackground = $ParallaxBackground
	var mist_tex: Texture2D = load("res://assets/mist.svg")

	# Lune de sang, basse sur l'horizon.
	var sky_layer := ParallaxLayer.new()
	sky_layer.motion_scale = Vector2(0.05, 0.05)
	bg.add_child(sky_layer)
	var moon_glow := Sprite2D.new()
	moon_glow.texture = mist_tex
	moon_glow.modulate = Color(1.0, 0.4, 0.25, 0.4)
	moon_glow.scale = Vector2(8.0, 8.0)
	moon_glow.position = Vector2(700.0, 90.0)
	sky_layer.add_child(moon_glow)
	var moon_pts := PackedVector2Array()
	var k := 0
	while k < 24:
		var a := k * TAU / 24.0
		moon_pts.append(Vector2(cos(a) * 46.0, sin(a) * 46.0))
		k += 1
	_poly(sky_layer, moon_pts, Color(0.95, 0.5, 0.32, 0.9), Vector2(700, 90))
	# Quelques étoiles pâles.
	var si := 0
	while si < 18:
		var sx := 40.0 + float((si * 157) % 880)
		var sy := 20.0 + float((si * 83) % 200)
		_poly(sky_layer, PackedVector2Array([
			Vector2(-1.6, 0), Vector2(0, -1.6), Vector2(1.6, 0), Vector2(0, 1.6),
		]), Color(0.9, 0.8, 0.8, 0.5), Vector2(sx, sy))
		si += 1

	# Collines noires à l'horizon.
	var far := ParallaxLayer.new()
	far.motion_scale = Vector2(0.15, 0.6)
	bg.add_child(far)
	var mx := -200.0
	var mi := 0
	while mx < LEVEL_END + 900.0:
		var mh := 160.0 + float(mi * 47 % 80)
		_poly(far, PackedVector2Array([
			Vector2(-300, 0), Vector2(-100, -mh + 40), Vector2(0, -mh),
			Vector2(140, -mh + 50), Vector2(300, 0),
		]), Color(0.12, 0.08, 0.14, 0.85), Vector2(mx, 580))
		mx += 420.0 + float(mi * 31 % 110)
		mi += 1

	# Maisons abandonnées et arbres morts.
	var mid := ParallaxLayer.new()
	mid.motion_scale = Vector2(0.55, 1)
	bg.add_child(mid)
	var x := 350.0
	var hi := 0
	while x < LEVEL_END:
		if hi % 3 == 2:
			_build_dead_tree(mid, Vector2(x, 512.0), hi)
		else:
			_build_house(mid, Vector2(x, 512.0), hi)
		x += 480.0 + float(hi * 53 % 160)
		hi += 1

	# Cordées de lanternes entre des poteaux.
	var rope := ParallaxLayer.new()
	rope.motion_scale = Vector2(0.75, 1)
	bg.add_child(rope)
	x = 500.0
	while x < LEVEL_END - 400.0:
		_build_lantern_string(rope, Vector2(x, 512.0), mist_tex)
		x += 1250.0

	# Nappes de brume violette au ras du sol.
	var mist_layer := ParallaxLayer.new()
	mist_layer.motion_scale = Vector2(0.5, 1)
	bg.add_child(mist_layer)
	x = 250.0
	while x < LEVEL_END:
		var m := Sprite2D.new()
		m.texture = mist_tex
		m.position = Vector2(x, 500.0)
		m.scale = Vector2(7.0, 2.0)
		m.modulate = Color(0.7, 0.5, 0.85, 0.13)
		mist_layer.add_child(m)
		x += 480.0

	# Volutes sombres qui flottent autour d'Eneko.
	wisps = CPUParticles2D.new()
	wisps.amount = 22
	wisps.lifetime = 7.0
	wisps.preprocess = 7.0
	wisps.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	wisps.emission_rect_extents = Vector2(560, 200)
	wisps.direction = Vector2(0, -1)
	wisps.spread = 40.0
	wisps.gravity = Vector2(-6, -10)
	wisps.initial_velocity_min = 4.0
	wisps.initial_velocity_max = 14.0
	wisps.scale_amount_min = 2.0
	wisps.scale_amount_max = 4.0
	wisps.color = Color(0.4, 0.25, 0.5, 0.3)
	add_child(wisps)

	# Lucioles chaudes qui dansent autour des cordées de lanternes :
	# petites lumières vivantes au milieu du village mort.
	var fx := 600.0
	while fx < LEVEL_END - 300.0:
		var ff := CPUParticles2D.new()
		ff.position = Vector2(fx, 420.0)
		ff.amount = 6
		ff.lifetime = 5.0
		ff.preprocess = 5.0
		ff.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		ff.emission_rect_extents = Vector2(170, 70)
		ff.direction = Vector2(0, -1)
		ff.spread = 180.0
		ff.gravity = Vector2.ZERO
		ff.initial_velocity_min = 4.0
		ff.initial_velocity_max = 11.0
		ff.scale_amount_min = 1.4
		ff.scale_amount_max = 2.4
		ff.color = Color(1.0, 0.85, 0.4, 0.55)
		add_child(ff)
		fx += 950.0

## Maison de village : pignon, toit débordant, fenêtre qui luit.
func _build_house(parent: Node, base: Vector2, seed_i: int) -> void:
	var h := 130.0 + float(seed_i * 37 % 60)
	var w := 70.0 + float(seed_i * 23 % 40)
	var body_c := Color(0.15, 0.11, 0.16)
	var roof_c := Color(0.1, 0.07, 0.12)
	_poly(parent, PackedVector2Array([
		Vector2(-w, 0), Vector2(w, 0), Vector2(w, -h), Vector2(-w, -h),
	]), body_c, base)
	_poly(parent, PackedVector2Array([
		Vector2(-w - 16, -h + 4), Vector2(w + 16, -h + 4),
		Vector2(w * 0.4, -h - 44), Vector2(-w * 0.4, -h - 44),
	]), roof_c, base)
	# Fenêtre chaude encore allumée (une maison sur deux).
	if seed_i % 2 == 0:
		_poly(parent, PackedVector2Array([
			Vector2(-14, -h + 40), Vector2(14, -h + 40),
			Vector2(14, -h + 66), Vector2(-14, -h + 66),
		]), Color(0.95, 0.6, 0.25, 0.5), base)
		_poly(parent, PackedVector2Array([
			Vector2(-2, -h + 40), Vector2(2, -h + 40),
			Vector2(2, -h + 66), Vector2(-2, -h + 66),
		]), Color(0.1, 0.07, 0.12, 0.9), base)
	# Porte béante.
	_poly(parent, PackedVector2Array([
		Vector2(-12, 0), Vector2(12, 0), Vector2(12, -38), Vector2(0, -46), Vector2(-12, -38),
	]), Color(0.05, 0.03, 0.07), base)

## Arbre mort : tronc tordu et branches nues.
func _build_dead_tree(parent: Node, base: Vector2, seed_i: int) -> void:
	var h := 200.0 + float(seed_i * 41 % 90)
	var c := Color(0.1, 0.07, 0.11)
	_poly(parent, PackedVector2Array([
		Vector2(-9, 0), Vector2(9, 0), Vector2(4, -h * 0.55), Vector2(8, -h), Vector2(-2, -h * 0.6),
	]), c, base)
	_poly(parent, PackedVector2Array([
		Vector2(2, -h * 0.62), Vector2(46, -h * 0.78), Vector2(44, -h * 0.74), Vector2(3, -h * 0.55),
	]), c, base)
	_poly(parent, PackedVector2Array([
		Vector2(-1, -h * 0.72), Vector2(-40, -h * 0.92), Vector2(-37, -h * 0.87), Vector2(0, -h * 0.66),
	]), c, base)

## Cordée entre deux poteaux, trois lanternes luisantes suspendues.
func _build_lantern_string(parent: Node, base: Vector2, mist_tex: Texture2D) -> void:
	var span := 320.0
	var top := -170.0
	for side in [0.0, 1.0]:
		_poly(parent, PackedVector2Array([
			Vector2(side * span - 4, 0), Vector2(side * span + 4, 0),
			Vector2(side * span + 3, top), Vector2(side * span - 3, top),
		]), Color(0.14, 0.1, 0.13), base)
	# Corde en trois segments qui pendent légèrement.
	var pts := [Vector2(0, top + 4), Vector2(span * 0.25, top + 22), Vector2(span * 0.5, top + 28),
		Vector2(span * 0.75, top + 22), Vector2(span, top + 4)]
	var j := 0
	while j < 4:
		var a: Vector2 = pts[j]
		var b: Vector2 = pts[j + 1]
		_poly(parent, PackedVector2Array([
			a + Vector2(0, -1.5), b + Vector2(0, -1.5), b + Vector2(0, 1.5), a + Vector2(0, 1.5),
		]), Color(0.16, 0.12, 0.14), base)
		j += 1
	# Lanternes aux quarts de corde.
	var li := 1
	while li < 4:
		var lp: Vector2 = pts[li] + Vector2(0, 16)
		var lg := Sprite2D.new()
		lg.texture = mist_tex
		lg.modulate = Color(1.0, 0.68, 0.3, 0.22)
		lg.scale = Vector2(1.8, 1.8)
		lg.position = base + lp
		parent.add_child(lg)
		_halos.append(lg)
		_poly(parent, PackedVector2Array([
			lp + Vector2(-1, -16), lp + Vector2(1, -16), lp + Vector2(1, -8), lp + Vector2(-1, -8),
		]), Color(0.16, 0.12, 0.14), base)
		var lpts := PackedVector2Array()
		var k := 0
		while k < 10:
			var a2 := k * TAU / 10.0
			lpts.append(lp + Vector2(cos(a2) * 7.0, sin(a2) * 9.0))
			k += 1
		_poly(parent, lpts, Color(1.0, 0.6, 0.26, 0.9), base)
		li += 1

## Rue du village : terre sombre, pavés, herbes fanées et clôtures.
func _build_platforms() -> void:
	for pi in PLATFORMS.size():
		var p: Vector2 = PLATFORMS[pi]
		var body := StaticBody2D.new()
		body.position = Vector2(p.x, GROUND_Y)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(p.y * 2.0, 100.0)
		shape.shape = rect
		body.add_child(shape)
		_poly(body, _rect_points(p.y, -50.0, 450.0), DIRT)
		_poly(body, _rect_points(p.y, 250.0, 450.0), DIRT_DARK)
		_poly(body, _rect_points(p.y, -50.0, -38.0), PATH)
		# Pavés irréguliers sur la chaussée.
		var cx := -p.y + 16.0
		var ci := 0
		while cx < p.y - 16.0:
			var cw := 14.0 + float(ci % 3) * 4.0
			_poly(body, PackedVector2Array([
				Vector2(cx - cw * 0.5, -38), Vector2(cx + cw * 0.5, -38),
				Vector2(cx + cw * 0.4, -44), Vector2(cx - cw * 0.4, -44),
			]), Color(0.36, 0.33, 0.35), Vector2(0, 0))
			cx += cw + 8.0
			ci += 1
		# Herbes fanées.
		var tuft_count: int = maxi(2, int(p.y / 80.0))
		for t in tuft_count:
			var tx: float = -p.y + 30.0 + t * ((p.y * 2.0 - 60.0) / maxf(1.0, float(tuft_count - 1)))
			_poly(body, PackedVector2Array([
				Vector2(tx - 5, -50), Vector2(tx - 2, -62), Vector2(tx + 1, -52),
				Vector2(tx + 5, -64), Vector2(tx + 8, -50),
			]), Color(0.45, 0.42, 0.3))
		# Clôture de bois brisée au bord arrière.
		if pi % 2 == 0:
			var fx := -p.y + 40.0
			while fx < p.y - 40.0:
				_poly(body, PackedVector2Array([
					Vector2(fx - 3, -50), Vector2(fx + 3, -50), Vector2(fx + 2, -88), Vector2(fx - 2, -88),
				]), WOOD_DARK)
				fx += 46.0
			_poly(body, _rect_points(p.y - 44.0, -80.0, -74.0), WOOD)
		add_child(body)

## Braseros de rue aux flammes dansantes.
func _build_braziers() -> void:
	var mist_tex: Texture2D = load("res://assets/mist.svg")
	for bx in BRAZIER_XS:
		var b := Node2D.new()
		b.position = Vector2(bx, GROUND_Y - 50.0)
		# Trépied et vasque.
		_poly(b, PackedVector2Array([
			Vector2(-10, 0), Vector2(-16, -26), Vector2(-12, -26),
		]), Color(0.12, 0.1, 0.11))
		_poly(b, PackedVector2Array([
			Vector2(10, 0), Vector2(16, -26), Vector2(12, -26),
		]), Color(0.12, 0.1, 0.11))
		_poly(b, PackedVector2Array([
			Vector2(-16, -26), Vector2(16, -26), Vector2(12, -36), Vector2(-12, -36),
		]), Color(0.2, 0.16, 0.15))
		var halo := Sprite2D.new()
		halo.texture = mist_tex
		halo.modulate = Color(1.0, 0.6, 0.25, 0.2)
		halo.scale = Vector2(2.6, 2.6)
		halo.position = Vector2(0, -46.0)
		b.add_child(halo)
		_halos.append(halo)
		var flame := Polygon2D.new()
		flame.position = Vector2(0, -36.0)
		flame.polygon = PackedVector2Array([
			Vector2(-7, 0), Vector2(7, 0), Vector2(5, -13), Vector2(0, -24), Vector2(-5, -13),
		])
		flame.color = Color(1.0, 0.58, 0.14)
		var inner := Polygon2D.new()
		inner.polygon = PackedVector2Array([
			Vector2(-3, 0), Vector2(3, 0), Vector2(0, -15),
		])
		inner.color = Color(1.0, 0.88, 0.42)
		flame.add_child(inner)
		b.add_child(flame)
		_flames.append(flame)
		add_child(b)

## Points de contrôle : lanternes de pierre (tōrō) dont la flamme
## s'allume en vert au passage d'Eneko.
func _build_checkpoints() -> void:
	for x in CHECKPOINT_XS:
		var cp := Area2D.new()
		cp.position = Vector2(x, 430.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(60, 120)
		shape.shape = rect
		cp.add_child(shape)
		var stone := Color(0.4, 0.38, 0.4)
		var stone_dark := Color(0.3, 0.28, 0.3)
		# Socle et pied.
		_poly(cp, PackedVector2Array([
			Vector2(-16, 70), Vector2(16, 70), Vector2(13, 60), Vector2(-13, 60),
		]), stone_dark)
		_poly(cp, PackedVector2Array([
			Vector2(-5, 60), Vector2(5, 60), Vector2(5, 6), Vector2(-5, 6),
		]), stone)
		# Boîte à lumière.
		_poly(cp, PackedVector2Array([
			Vector2(-14, 6), Vector2(14, 6), Vector2(14, -22), Vector2(-14, -22),
		]), stone)
		var flag := _poly(cp, PackedVector2Array([
			Vector2(-8, 0), Vector2(8, 0), Vector2(8, -16), Vector2(-8, -16),
		]), Color(0.95, 0.66, 0.28, 0.9))
		# Chapeau de pierre.
		_poly(cp, PackedVector2Array([
			Vector2(-20, -22), Vector2(20, -22), Vector2(12, -34), Vector2(-12, -34),
		]), stone_dark)
		_poly(cp, PackedVector2Array([
			Vector2(-4, -34), Vector2(4, -34), Vector2(2, -42), Vector2(-2, -42),
		]), stone)
		add_child(cp)
		cp.body_entered.connect(_on_checkpoint_body_entered.bind(cp, flag))

## Pièges en bois : pieux taillés plantés dans le sol.
func _build_traps() -> void:
	for i in TRAP_XS.size():
		var x: float = TRAP_XS[i]
		var trap := Area2D.new()
		trap.position = Vector2(x, GROUND_Y - 54.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(44, 24)
		shape.shape = rect
		trap.add_child(shape)
		_poly(trap, PackedVector2Array([
			Vector2(-22, 18), Vector2(22, 18), Vector2(22, 6), Vector2(-22, 6),
		]), Color(0.3, 0.19, 0.11))
		for k in 3:
			var ox := -16.0 + k * 16.0
			_poly(trap, PackedVector2Array([
				Vector2(ox - 5, 6), Vector2(ox + 5, 6), Vector2(ox, -14),
			]), Color(0.44, 0.28, 0.15))
			_poly(trap, PackedVector2Array([
				Vector2(ox - 2, 2), Vector2(ox + 2, 2), Vector2(ox, -12),
			]), Color(0.54, 0.36, 0.2))
		add_child(trap)
		trap.body_entered.connect(_on_trap_body_entered)

func _build_goal() -> void:
	var goal := Area2D.new()
	goal.position = Vector2(GOAL_X, 430.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 140)
	shape.shape = rect
	goal.add_child(shape)
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(1.0, 0.8, 0.45, 0.5)
	glow.scale = Vector2(4.5, 4.5)
	goal.add_child(glow)
	_poly(goal, PackedVector2Array([Vector2(-40, -60), Vector2(40, -60), Vector2(40, 66), Vector2(-40, 66)]), Color(1, 0.85, 0.5, 0.22))
	_poly(goal, PackedVector2Array([Vector2(-28, -55), Vector2(-20, -55), Vector2(-20, 70), Vector2(-28, 70)]), Color(0.85, 0.2, 0.15))
	_poly(goal, PackedVector2Array([Vector2(20, -55), Vector2(28, -55), Vector2(28, 70), Vector2(20, 70)]), Color(0.85, 0.2, 0.15))
	_poly(goal, PackedVector2Array([Vector2(-42, -70), Vector2(42, -70), Vector2(38, -58), Vector2(-38, -58)]), Color(0.78, 0.16, 0.12))
	_poly(goal, PackedVector2Array([Vector2(-32, -46), Vector2(32, -46), Vector2(32, -38), Vector2(-32, -38)]), Color(0.85, 0.2, 0.15))
	add_child(goal)
	goal.body_entered.connect(_on_goal_body_entered)

func _build_kill_zone() -> void:
	var kz := Area2D.new()
	kz.position = Vector2(LEVEL_END / 2.0, 700.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(LEVEL_END + 800.0, 100.0)
	shape.shape = rect
	kz.add_child(shape)
	add_child(kz)
	kz.body_entered.connect(_on_kill_zone_body_entered)

func _spawn_entities() -> void:
	for x in PATROL_XS:
		var e := PATROL_SCENE.instantiate()
		e.position = Vector2(x, SPAWN_Y)
		add_child(e)
	for x in SHADOW_XS:
		var s := SHADOW_SCENE.instantiate()
		s.position = Vector2(x, SPAWN_Y)
		add_child(s)
	for x in SPIRIT_XS:
		var sp := SPIRIT_SCENE.instantiate()
		sp.position = Vector2(x, SPAWN_Y - 130.0)
		add_child(sp)
	var leonie := LEONIE_SCENE.instantiate()
	leonie.position = Vector2(3550.0, SPAWN_Y)
	leonie.set_lines(LEONIE_LINES)
	add_child(leonie)
	for o in ORBS:
		var orb := ORB_SCENE.instantiate()
		orb.position = o
		add_child(orb)

## Vent ambiant grave + son de victoire.
func _setup_audio() -> void:
	var wind := AudioStreamPlayer.new()
	wind.stream = load("res://assets/sfx/wind.wav")
	wind.volume_db = -18.0
	wind.pitch_scale = 0.8
	add_child(wind)
	wind.finished.connect(wind.play)
	wind.play()
	sfx_win = AudioStreamPlayer.new()
	sfx_win.stream = load("res://assets/sfx/win.wav")
	sfx_win.volume_db = -4.0
	add_child(sfx_win)

# --- Déroulement ----------------------------------------------------------

func _on_checkpoint_body_entered(body: Node2D, cp: Area2D, flag: Polygon2D) -> void:
	if body == player:
		player.set_checkpoint(Vector2(cp.global_position.x, SPAWN_Y))
		flag.color = Color(0.4, 0.9, 0.5, 0.95)

func _on_trap_body_entered(body: Node2D) -> void:
	if body == player and body.has_method("take_damage"):
		body.take_damage(1, body.global_position + Vector2(0, 40))

func _on_kill_zone_body_entered(body: Node2D) -> void:
	if body == player:
		player.fall_damage()

func _on_goal_body_entered(body: Node2D) -> void:
	if body == player:
		player.set_physics_process(false)
		sfx_win.play()
		SaveManager.complete_level(LEVEL_ID, player.orbs)
		_display_challenge_results()
		win_label.visible = true

func _display_challenge_results() -> void:
	var results := Challenge.finish_level()

	var challenge_stats = win_label.find_child("ChallengeStats", true, false)
	if challenge_stats == null:
		return

	var grade_label = challenge_stats.find_child("Grade", true, false)
	var orbs_label = challenge_stats.find_child("Orbs", true, false)
	var damage_label = challenge_stats.find_child("Damage", true, false)
	var time_label = challenge_stats.find_child("Time", true, false)

	if grade_label:
		grade_label.text = "Grade : %s" % Challenge.grade_name(results["grade"])
		grade_label.add_theme_color_override("font_color", Challenge.grade_color(results["grade"]))
	if orbs_label:
		orbs_label.text = "Orbes : %d/%d" % [results["orbs"], results["total_orbs"]]
	if damage_label:
		damage_label.text = "Dégâts : %d" % results["damage"]
	if time_label:
		time_label.text = "Temps : %s" % _format_time(results["time"])

func _format_time(seconds: float) -> String:
	var mins: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	return "%d:%02d" % [mins, secs]

func _on_leonie_talk(lines: Array) -> void:
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	dialogue.start(lines)

func _on_dialogue_finished() -> void:
	player.set_physics_process(true)

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
