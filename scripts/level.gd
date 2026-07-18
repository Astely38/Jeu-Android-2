extends Node2D
## Niveau 1 : « La Clairière des Bambous ».
## Le décor, les plateformes, les checkpoints, le torii, les ennemis et les
## orbes sont générés à partir des tableaux de données ci-dessous : pour
## allonger le niveau, il suffit d'ajouter des entrées.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const PATROL_SCENE := preload("res://scenes/enemy.tscn")
const SHADOW_SCENE := preload("res://scenes/shadow.tscn")
const LIFT_SCENE := preload("res://scenes/lift_platform.tscn")

const GROUND_Y := 550.0    # centre vertical des plateformes
const SPAWN_Y := 477.0     # hauteur d'apparition des personnages
const LEVEL_END := 7000.0
const GOAL_X := 6800.0
const LEVEL_ID := "level_1"

const DIRT := Color(0.36, 0.25, 0.16)
const DIRT_DARK := Color(0.27, 0.18, 0.11)
const GRASS := Color(0.4, 0.62, 0.32)

## Thème du peintre de plateformes (terre et herbe de la clairière).
const PLATFORM_THEME := {
	"top": GRASS,
	"top_light": Color(0.56, 0.78, 0.42),
	"body_a": DIRT,
	"body_b": Color(0.3, 0.2, 0.13),
	"dark": DIRT_DARK,
	"speck": Color(0.46, 0.35, 0.24),
}

const LEONIE_LINES := [
	{ "name": "Léonie", "text": "Eneko, te voilà. La clairière où tu as grandi fut la première que les Ombres ont dévorée." },
	{ "name": "Léonie", "text": "Ces orbes qui luisent sont des éclats de la Flamme d'Aube. Rassemble-les : chacun ravive un peu la lumière." },
	{ "name": "Léonie", "text": "Je ne peux pas me battre. Mais ma clarté te protège un moment — sers-t'en pour avancer." },
	{ "name": "Léonie", "text": "Franchis le torii, au bout du chemin. De sanctuaire en sanctuaire, nous remonterons jusqu'à la Flamme." },
	{ "name": "Eneko", "text": "Alors allons-y. Je leur rendrai la lumière qu'on leur a prise." },
]

## Plateformes : x = centre, y = demi-largeur. Trous de 120 à 150 px
## (portée de saut max ≈ 190 px).
const PLATFORMS := [
	Vector2(250, 250), Vector2(890, 260), Vector2(1520, 250),
	Vector2(2140, 240), Vector2(2760, 230), Vector2(3390, 260),
	Vector2(4010, 240), Vector2(4640, 250), Vector2(5270, 240),
	Vector2(5910, 260), Vector2(6600, 300),
]
const CHECKPOINT_XS := [1650.0, 3400.0, 5100.0]
## La plateforme 2 (630-1150) est le sanctuaire de Léonie : aucun ennemi
## ni piège n'y est placé.
const PATROL_XS := [1550.0, 3450.0, 4700.0, 5900.0]
const SHADOW_XS := [2560.0, 6480.0]
## Ombre d'élite : rare, deux coups à placer, orbe dorée (3 orbes) à la clé.
const ELITE_XS := [4100.0]
## Pièges à pics : proches d'un bord de plateforme, contournables en marchant
## ou en sautant par-dessus (jamais un passage obligé).
## Opener volontairement aéré : trois pieux bien espacés (jamais collés à un
## geyser), pour enseigner l'esquive sans saturer le tout premier niveau.
const TRAP_XS := [2680.0, 3900.0, 6520.0]
## Geysers de flamme spectrale (piège cyclique télégraphié). Placés au large,
## à l'écart des autres dangers : on passe pendant la fenêtre dormante.
const GEYSER_XS := [2050.0, 4520.0]
## Ascenseur spirituel : x = centre, y = dessus de la dalle au point bas
## (atteignable d'un saut depuis le bord du trou). Il monte de 175 px et
## dessert les trois orbes bonus placées en hauteur.
const LIFTS := [Vector2(3060, 470)]
const ORBS := [
	Vector2(350, 440), Vector2(565, 405), Vector2(890, 440),
	Vector2(1210, 405), Vector2(1520, 440), Vector2(1835, 405),
	Vector2(2140, 440), Vector2(2455, 405), Vector2(2760, 440),
	Vector2(3060, 405), Vector2(3390, 440), Vector2(3710, 405),
	Vector2(4010, 440), Vector2(4320, 405), Vector2(4640, 440),
	Vector2(4960, 405), Vector2(5270, 440), Vector2(5580, 405),
	Vector2(5910, 440), Vector2(6235, 405), Vector2(6600, 440),
	# Orbes bonus desservies par l'ascenseur spirituel.
	Vector2(2990, 258), Vector2(3060, 240), Vector2(3130, 258),
]

var sfx_win: AudioStreamPlayer
var petals: CPUParticles2D
var pollen: CPUParticles2D
var _portal_used := false
## Touffes d'herbe qui ondulent au vent et frémissent au passage d'Eneko.
var _grass: Array = []
## Oiseaux posés qui s'envolent quand Eneko approche.
var _birds: Array = []
## Papillons qui voltigent en suivant un chemin sinueux.
var _butterflies: Array = []
## Taches de lumière dorée qui dansent au sol sous la frondaison.
var _dapples: Array = []
var _t := 0.0

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var next_button: Button = $WinLabel/NextButton
@onready var dialogue: CanvasLayer = $Dialogue
@onready var leonie: Area2D = $Leonie

func _ready() -> void:
	_build_decor()
	Atmosphere.add_foreground(self, Color(0.06, 0.13, 0.08, 0.34))
	# Fine brume du matin qui traîne au ras de l'herbe.
	TextureLab.add_ground_mist(self, 7, GROUND_Y - 44.0, LEVEL_END,
		Color(0.85, 0.9, 0.85, 0.08), 1)
	_build_platforms()
	PlatformPainter.build_sanctuary(self, 890.0, GROUND_Y - 50.0)
	_build_checkpoints()
	_build_traps()
	_build_geysers()
	_build_lifts()
	_build_goal()
	_build_secret_portal()
	_build_tutorial_signs()
	_build_grass()
	_build_birds()
	_build_dapples()
	_build_butterflies()
	_build_kill_zone()
	_spawn_entities()
	_setup_audio()
	_setup_ambient()
	win_label.visible = false
	SaveManager.set_last_level(LEVEL_ID)
	# Relique cachée, tapie à gauche de l'apparition (on part vers la droite).
	var relic := Relic.new()
	relic.level_id = LEVEL_ID
	relic.position = Vector2(60, 466)
	add_child(relic)
	# Les orbes dorées des Ombres d'élite comptent dans le total (3 chacune).
	Challenge.start_level(LEVEL_ID, ORBS.size() + 3 * ELITE_XS.size())
	leonie.set_lines(LEONIE_LINES)
	dialogue.finished.connect(_on_dialogue_finished)
	menu_button.pressed.connect(_on_menu_pressed)
	var next_scene: String = SaveManager.LEVEL_SCENES.get("level_2", "")
	next_button.visible = next_scene != ""
	if next_scene != "":
		next_button.pressed.connect(func(): Transition.goto(next_scene))
	# Survol d'introduction : du torii jusqu'à Eneko.
	player.intro_pan(Vector2(GOAL_X, 380.0))

# --- Construction du niveau ---------------------------------------------

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

## Bambous, soleil, nuages et lanternes en parallaxe, sur toute la longueur.
func _build_decor() -> void:
	var bg: ParallaxBackground = $ParallaxBackground

	# Soleil : lueur douce fixe, loin en arrière-plan.
	var sky_layer := ParallaxLayer.new()
	sky_layer.motion_scale = Vector2(0.05, 0.05)
	bg.add_child(sky_layer)
	var sun := Sprite2D.new()
	sun.texture = load("res://assets/mist.svg")
	sun.modulate = Color(1.0, 0.92, 0.6, 0.55)
	sun.scale = Vector2(9.0, 9.0)
	sun.position = Vector2(700.0, -60.0)
	sky_layer.add_child(sun)
	# Rayons dorés du couchant qui plongent dans la clairière.
	var rays := GodRays.new()
	rays.color = Color(1.0, 0.88, 0.55, 0.06)
	rays.length = 1500.0
	rays.half_spread = 0.7
	rays.position = Vector2(700.0, -60.0)
	sky_layer.add_child(rays)

	# Montagnes lointaines bleutées, avec sommets enneigés.
	var mountains := ParallaxLayer.new()
	mountains.motion_scale = Vector2(0.1, 0.4)
	bg.add_child(mountains)
	var mx := -200.0
	var mi := 0
	while mx < LEVEL_END + 900.0:
		var mh := 220.0 + float(mi * 53 % 100)
		var mtri := PackedVector2Array([
			Vector2(-280, 0), Vector2(0, -mh), Vector2(280, 0),
		])
		_poly(mountains, mtri, Color(0.55, 0.62, 0.74, 0.6), Vector2(mx, 560))
		# Grain rocheux tuilé sur le flanc de la montagne.
		TextureLab.grain_poly(mountains, mtri, 0.1, Vector2(mx, 0), Vector2(mx, 560))
		_poly(mountains, PackedVector2Array([
			Vector2(-34, -mh + 34), Vector2(0, -mh), Vector2(34, -mh + 34), Vector2(0, -mh + 48),
		]), Color(0.92, 0.94, 0.98, 0.55), Vector2(mx, 560))
		mx += 400.0 + float(mi * 41 % 130)
		mi += 1

	# Deuxième crête, plus proche et plus verte.
	var hills := ParallaxLayer.new()
	hills.motion_scale = Vector2(0.18, 0.6)
	bg.add_child(hills)
	mx = -100.0
	mi = 0
	while mx < LEVEL_END + 900.0:
		var hh := 150.0 + float(mi * 37 % 70)
		var htri := PackedVector2Array([
			Vector2(-240, 0), Vector2(-80, -hh + 30), Vector2(0, -hh),
			Vector2(110, -hh + 40), Vector2(240, 0),
		])
		_poly(hills, htri, Color(0.44, 0.56, 0.5, 0.55), Vector2(mx, 570))
		TextureLab.grain_poly(hills, htri, 0.12, Vector2(mx * 0.7, 0), Vector2(mx, 570))
		mx += 340.0 + float(mi * 29 % 90)
		mi += 1

	# Nuages : quelques amas ovales qui dérivent très lentement.
	var clouds := ParallaxLayer.new()
	clouds.motion_scale = Vector2(0.15, 0.15)
	bg.add_child(clouds)
	var cx := 200.0
	var ci := 0
	while cx < LEVEL_END:
		var cy := 60.0 + float(ci % 3) * 40.0
		for k in 3:
			_poly(clouds, PackedVector2Array([
				Vector2(-40 + k * 34, -18), Vector2(-14 + k * 34, -30), Vector2(20 + k * 34, -30),
				Vector2(40 + k * 34, -14), Vector2(30 + k * 34, 4), Vector2(-30 + k * 34, 4),
			]), Color(1, 1, 1, 0.55), Vector2(cx, cy))
		cx += 650.0 + float(ci * 37 % 140)
		ci += 1
	# Voiles nuageux texturés qui dérivent doucement au-dessus des amas.
	TextureLab.add_clouds(clouds, 6, 30.0, 170.0, LEVEL_END, Color(1, 1, 1, 0.16))

	# Vols d'oiseaux : petits chevrons sombres par groupes de trois.
	var bx := 500.0
	var bi := 0
	while bx < LEVEL_END:
		var by := 70.0 + float(bi * 47 % 110)
		for w in 3:
			var off := Vector2(float(w) * 18.0, float(w % 2) * 7.0 - 3.0)
			_poly(clouds, PackedVector2Array([
				Vector2(-7, 0), Vector2(0, -4), Vector2(7, 0), Vector2(0, -1),
			]), Color(0.25, 0.28, 0.32, 0.75), Vector2(bx, by) + off)
		bx += 850.0 + float(bi * 53 % 300)
		bi += 1

	var far := ParallaxLayer.new()
	far.motion_scale = Vector2(0.3, 1)
	bg.add_child(far)
	var x := 80.0
	while x < LEVEL_END:
		var h := 280.0 + float(int(x) * 13 % 120)
		_poly(far, _rect_points(6.0, -h, 0.0), Color(0.52, 0.64, 0.56, 0.6), Vector2(x, 520))
		x += 320.0 + float(int(x) % 60)

	var mid := ParallaxLayer.new()
	mid.motion_scale = Vector2(0.6, 1)
	bg.add_child(mid)
	var lantern_tex: Texture2D = load("res://assets/lantern.svg")
	x = 220.0
	var i := 0
	while x < LEVEL_END:
		var h := 330.0 + float(int(x) * 7 % 90)
		var green := Color(0.35, 0.5, 0.3) if i % 2 == 0 else Color(0.32, 0.47, 0.28)
		_poly(mid, _rect_points(8.0, -h, 0.0), green, Vector2(x, 512))
		# Nœuds du bambou.
		var jy := -60.0
		while jy > -h + 30.0:
			_poly(mid, PackedVector2Array([
				Vector2(-8, jy), Vector2(8, jy), Vector2(8, jy + 3), Vector2(-8, jy + 3),
			]), Color(0.24, 0.36, 0.22), Vector2(x, 512))
			jy -= 74.0
		if i % 2 == 0:
			var side := 1.0 if i % 4 == 0 else -1.0
			_poly(mid, PackedVector2Array([
				Vector2(8 * side, -h + 30), Vector2(44 * side, -h + 8), Vector2(8 * side, -h + 46),
			]), Color(0.42, 0.6, 0.35), Vector2(x, 512))
		x += 440.0 + float(int(x) % 80)
		i += 1
	x = 700.0
	while x < LEVEL_END:
		var s := Sprite2D.new()
		s.texture = lantern_tex
		s.position = Vector2(x, 165.0 + float(int(x) % 50))
		s.scale = Vector2(0.85, 0.85)
		mid.add_child(s)
		x += 620.0

	# Nappes de brume près du sol.
	var mist_layer := ParallaxLayer.new()
	mist_layer.motion_scale = Vector2(0.5, 1)
	bg.add_child(mist_layer)
	var mist_tex: Texture2D = load("res://assets/mist.svg")
	x = 300.0
	while x < LEVEL_END:
		var m := Sprite2D.new()
		m.texture = mist_tex
		m.position = Vector2(x, 495.0)
		m.scale = Vector2(6.5, 1.8)
		m.modulate = Color(1, 1, 1, 0.14)
		mist_layer.add_child(m)
		x += 520.0

	# Pétales de cerisier portés par le vent (suivent le joueur).
	petals = CPUParticles2D.new()
	petals.texture = load("res://assets/leaf.svg")
	petals.amount = 24
	petals.lifetime = 9.0
	petals.preprocess = 9.0
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.emission_rect_extents = Vector2(560, 12)
	petals.direction = Vector2(0.3, 1.0)
	petals.spread = 15.0
	petals.gravity = Vector2(8, 16)
	petals.initial_velocity_min = 24.0
	petals.initial_velocity_max = 50.0
	petals.angular_velocity_min = -70.0
	petals.angular_velocity_max = 70.0
	petals.scale_amount_min = 0.5
	petals.scale_amount_max = 0.9
	petals.color = Color(0.95, 0.74, 0.78)
	add_child(petals)

	# Poussière de pollen dorée en suspension, éclairée par le couchant :
	# de fines lueurs qui flottent lentement et donnent de l'air à la scène.
	pollen = CPUParticles2D.new()
	pollen.amount = 20
	pollen.lifetime = 6.5
	pollen.preprocess = 6.5
	pollen.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	pollen.emission_rect_extents = Vector2(560, 280)
	pollen.direction = Vector2(0.2, -1)
	pollen.spread = 45.0
	pollen.gravity = Vector2(4, -5)
	pollen.initial_velocity_min = 4.0
	pollen.initial_velocity_max = 14.0
	pollen.scale_amount_min = 1.0
	pollen.scale_amount_max = 2.2
	pollen.color = Color(1.0, 0.94, 0.68, 0.5)
	add_child(pollen)

## Plateformes : collision + pilier de terre profond (fini le sol flottant),
## avec touffes d'herbe et cailloux pour casser la platitude des blocs.
func _build_platforms() -> void:
	for p in PLATFORMS:
		var body := StaticBody2D.new()
		body.position = Vector2(p.x, GROUND_Y)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(p.y * 2.0, 100.0)
		shape.shape = rect
		body.add_child(shape)
		PlatformPainter.paint(body, p.y, PLATFORM_THEME)

		# Touffes d'herbe le long du bord supérieur.
		var tuft_count: int = maxi(2, int(p.y / 55.0))
		for t in tuft_count:
			var tx: float = -p.y + 30.0 + t * ((p.y * 2.0 - 60.0) / maxf(1.0, float(tuft_count - 1)))
			_poly(body, PackedVector2Array([
				Vector2(tx - 6, -40), Vector2(tx - 2, -54), Vector2(tx + 2, -42),
				Vector2(tx + 6, -56), Vector2(tx + 10, -40),
			]), Color(0.46, 0.68, 0.36))

		# Fleurs sauvages parmi l'herbe.
		var flower_count: int = maxi(1, int(p.y / 150.0))
		for f in flower_count:
			var fx: float = -p.y + 70.0 + f * ((p.y * 2.0 - 140.0) / maxf(1.0, float(flower_count)))
			_poly(body, PackedVector2Array([
				Vector2(fx - 1, -40), Vector2(fx + 1, -40), Vector2(fx + 1, -54), Vector2(fx - 1, -54),
			]), Color(0.36, 0.52, 0.3))
			var petal_pts := PackedVector2Array()
			for k in 6:
				var a := k * TAU / 6.0
				petal_pts.append(Vector2(fx + cos(a) * 6.0, -58.0 + sin(a) * 6.0))
			_poly(body, petal_pts, Color(0.95, 0.66, 0.72))
			var core_pts := PackedVector2Array()
			for k in 6:
				var a := k * TAU / 6.0
				core_pts.append(Vector2(fx + cos(a) * 2.5, -58.0 + sin(a) * 2.5))
			_poly(body, core_pts, Color(1.0, 0.85, 0.4))

		# Petits cailloux dans la terre.
		var rock_count: int = maxi(1, int(p.y / 110.0))
		for r in rock_count:
			var rx: float = -p.y + 50.0 + r * ((p.y * 2.0 - 100.0) / maxf(1.0, float(rock_count)))
			_poly(body, PackedVector2Array([
				Vector2(rx - 9, 90), Vector2(rx, 82), Vector2(rx + 9, 90), Vector2(rx, 100),
			]), Color(0.42, 0.4, 0.38))

		add_child(body)

func _build_checkpoints() -> void:
	for x in CHECKPOINT_XS:
		var cp := Area2D.new()
		cp.position = Vector2(x, 430.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(60, 120)
		shape.shape = rect
		cp.add_child(shape)
		_poly(cp, PackedVector2Array([
			Vector2(-3, -60), Vector2(3, -60), Vector2(3, 70), Vector2(-3, 70),
		]), Color(0.35, 0.28, 0.2))
		var flag := _poly(cp, PackedVector2Array([
			Vector2(3, -60), Vector2(40, -50), Vector2(3, -38),
		]), Color(0.85, 0.75, 0.35))
		add_child(cp)
		cp.body_entered.connect(_on_checkpoint_body_entered.bind(cp, flag))

## Pièges en bois : pieux taillés plantés dans le sol.
## Ascenseurs spirituels : dalles flottantes qui desservent les orbes bonus.
func _build_lifts() -> void:
	for i in LIFTS.size():
		var v: Vector2 = LIFTS[i]
		var lift := LIFT_SCENE.instantiate()
		lift.position = v
		add_child(lift)

func _build_traps() -> void:
	for i in TRAP_XS.size():
		var x: float = TRAP_XS[i]
		var trap := Area2D.new()
		trap.position = Vector2(x, GROUND_Y - 54.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(66, 34)
		shape.shape = rect
		trap.add_child(shape)
		_poly(trap, PackedVector2Array([
			Vector2(-33, 22), Vector2(33, 22), Vector2(33, 6), Vector2(-33, 6),
		]), Color(0.38, 0.24, 0.13))
		for k in 4:
			var ox := -24.0 + k * 16.0
			_poly(trap, PackedVector2Array([
				Vector2(ox - 7, 6), Vector2(ox + 7, 6), Vector2(ox, -22),
			]), Color(0.52, 0.34, 0.18))
			_poly(trap, PackedVector2Array([
				Vector2(ox - 3, 2), Vector2(ox + 3, 2), Vector2(ox, -18),
			]), Color(0.6, 0.42, 0.22))
		add_child(trap)
		trap.body_entered.connect(_on_trap_body_entered)

func _on_trap_body_entered(body: Node2D) -> void:
	if body == player and body.has_method("take_damage"):
		body.take_damage(1, body.global_position + Vector2(0, 40))

## Geysers de flamme spectrale, désynchronisés par une phase différente.
func _build_geysers() -> void:
	for i in GEYSER_XS.size():
		var g := SpiritGeyser.new()
		g.position = Vector2(GEYSER_XS[i], GROUND_Y - 50.0)
		g.phase = float(i) * (SpiritGeyser.PERIOD / float(GEYSER_XS.size())) + 0.4
		add_child(g)

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
	glow.modulate = Color(1.0, 0.85, 0.45, 0.5)
	glow.scale = Vector2(4.5, 4.5)
	goal.add_child(glow)
	_poly(goal, PackedVector2Array([Vector2(-40, -60), Vector2(40, -60), Vector2(40, 66), Vector2(-40, 66)]), Color(1, 0.9, 0.5, 0.25))
	_poly(goal, PackedVector2Array([Vector2(-28, -55), Vector2(-20, -55), Vector2(-20, 70), Vector2(-28, 70)]), Color(0.85, 0.2, 0.15))
	_poly(goal, PackedVector2Array([Vector2(20, -55), Vector2(28, -55), Vector2(28, 70), Vector2(20, 70)]), Color(0.85, 0.2, 0.15))
	_poly(goal, PackedVector2Array([Vector2(-42, -70), Vector2(42, -70), Vector2(38, -58), Vector2(-38, -58)]), Color(0.78, 0.16, 0.12))
	_poly(goal, PackedVector2Array([Vector2(-32, -46), Vector2(32, -46), Vector2(32, -38), Vector2(-32, -38)]), Color(0.85, 0.2, 0.15))
	add_child(goal)
	Atmosphere.breathe(glow)
	goal.body_entered.connect(_on_goal_body_entered)

## Portail secret : un vieux torii de pierre moussu, à contre-sens du
## chemin (tout à gauche du départ, derrière Eneko). S'y glisser révèle
## le Jardin Céleste. Quelques lucioles dorées récompensent la curiosité.
func _build_secret_portal() -> void:
	var portal := Area2D.new()
	portal.position = Vector2(36.0, 430.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(46, 130)
	shape.shape = rect
	portal.add_child(shape)
	var stone := Color(0.5, 0.55, 0.5)
	var stone_dark := Color(0.4, 0.45, 0.42)
	var moss := Color(0.35, 0.5, 0.3, 0.9)
	_poly(portal, PackedVector2Array([
		Vector2(-24, 70), Vector2(-16, 70), Vector2(-18, -40), Vector2(-26, -40),
	]), stone)
	_poly(portal, PackedVector2Array([
		Vector2(16, 70), Vector2(24, 70), Vector2(26, -40), Vector2(18, -40),
	]), stone)
	_poly(portal, PackedVector2Array([
		Vector2(-32, -44), Vector2(32, -44), Vector2(34, -52), Vector2(-34, -52),
	]), stone_dark)
	_poly(portal, PackedVector2Array([
		Vector2(-28, -34), Vector2(28, -34), Vector2(28, -28), Vector2(-28, -28),
	]), stone)
	_poly(portal, PackedVector2Array([
		Vector2(-26, -40), Vector2(-14, -40), Vector2(-20, -30),
	]), moss)
	_poly(portal, PackedVector2Array([
		Vector2(18, 10), Vector2(26, 6), Vector2(26, 26), Vector2(18, 22),
	]), moss)
	_poly(portal, PackedVector2Array([
		Vector2(-26, 40), Vector2(-16, 44), Vector2(-16, 60), Vector2(-26, 58),
	]), moss)
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(1.0, 0.9, 0.6, 0.14)
	glow.scale = Vector2(1.6, 2.2)
	glow.position = Vector2(0, 10)
	portal.add_child(glow)
	var fireflies := CPUParticles2D.new()
	fireflies.amount = 7
	fireflies.lifetime = 3.2
	fireflies.preprocess = 3.2
	fireflies.position = Vector2(0, 10)
	fireflies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fireflies.emission_rect_extents = Vector2(20, 46)
	fireflies.direction = Vector2(0, -1)
	fireflies.spread = 60.0
	fireflies.gravity = Vector2.ZERO
	fireflies.initial_velocity_min = 4.0
	fireflies.initial_velocity_max = 12.0
	fireflies.scale_amount_min = 1.2
	fireflies.scale_amount_max = 2.0
	fireflies.color = Color(1.0, 0.9, 0.5, 0.8)
	portal.add_child(fireflies)
	add_child(portal)
	portal.body_entered.connect(_on_secret_portal_body_entered)

func _on_secret_portal_body_entered(body: Node2D) -> void:
	if _portal_used or body != player:
		return
	_portal_used = true
	SaveManager.discover_secret()
	Transition.goto("res://levels/level_secret.tscn")

## Panneaux d'apprentissage en bois plantés au long de la première clairière :
## ils enseignent les commandes au bon moment, sans bloquer le jeu.
func _build_tutorial_signs() -> void:
	var signs := [
		{"x": 150.0, "text": "◄  ►   Se déplacer"},
		{"x": 470.0, "text": "▲   Sauter"},
		{"x": 1270.0, "text": "Épée   Trancher les esprits"},
		{"x": 1500.0, "text": "Ruée   Traverse les ennemis"},
	]
	for s in signs:
		_build_sign(float(s["x"]), String(s["text"]))

func _build_sign(x: float, text: String) -> void:
	var surf := GROUND_Y - 50.0
	var post := Node2D.new()
	post.position = Vector2(x, surf)
	add_child(post)
	var wood := Color(0.44, 0.3, 0.17)
	var wood_dark := Color(0.32, 0.21, 0.12)
	# Poteau planté dans le sol.
	_poly(post, PackedVector2Array([
		Vector2(-4, 0), Vector2(4, 0), Vector2(4, -72), Vector2(-4, -72),
	]), wood_dark)
	# Planche gravée, cerclée d'un liseré plus sombre.
	_poly(post, PackedVector2Array([
		Vector2(-104, -72), Vector2(104, -72), Vector2(104, -108), Vector2(-104, -108),
	]), wood)
	_poly(post, PackedVector2Array([
		Vector2(-104, -72), Vector2(104, -72), Vector2(104, -76), Vector2(-104, -76),
	]), wood_dark)
	_poly(post, PackedVector2Array([
		Vector2(-104, -104), Vector2(104, -104), Vector2(104, -108), Vector2(-104, -108),
	]), wood_dark)
	var lbl := Label.new()
	lbl.text = text
	lbl.size = Vector2(208, 36)
	lbl.position = Vector2(-104, -108)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.99, 0.93, 0.8))
	lbl.add_theme_color_override("font_outline_color", Color(0.18, 0.1, 0.05))
	lbl.add_theme_constant_override("outline_size", 4)
	post.add_child(lbl)

## Répliques d'ambiance d'Eneko au fil de la clairière (non bloquantes).
func _setup_ambient() -> void:
	var amb := AmbientDialogue.new()
	add_child(amb)
	amb.add_line(self, 2200.0, "Eneko", "J'ai grandi dans ces bambous. Les voir se faner me serre le cœur.")
	amb.add_line(self, 3900.0, "Eneko", "Chaque esprit tranché est une âme rendue au repos.")
	amb.add_line(self, 5600.0, "Eneko", "Le torii, enfin. La clairière retrouvera la paix.")

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
	for x in ELITE_XS:
		var el := SHADOW_SCENE.instantiate()
		el.position = Vector2(x, SPAWN_Y)
		add_child(el)
		el.make_elite()
	for o in ORBS:
		var orb := ORB_SCENE.instantiate()
		orb.position = o
		add_child(orb)

## Vent ambiant en boucle + son de victoire.
func _setup_audio() -> void:
	var wind := AudioStreamPlayer.new()
	wind.stream = load("res://assets/sfx/wind.wav")
	wind.volume_db = -16.0
	add_child(wind)
	wind.finished.connect(wind.play)
	wind.play()
	sfx_win = AudioStreamPlayer.new()
	sfx_win.stream = load("res://assets/sfx/win.wav")
	sfx_win.volume_db = -4.0
	add_child(sfx_win)

# --- Déroulement ----------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if petals != null and is_instance_valid(player):
		petals.position = Vector2(player.position.x, player.position.y - 340.0)
	if pollen != null and is_instance_valid(player):
		pollen.position = Vector2(player.position.x, player.position.y - 120.0)

## Touffes d'herbe : ondulation lente au vent + frémissement quand Eneko
## passe à proximité (elles se penchent dans le sens opposé à son passage).
func _build_grass() -> void:
	var green := Color(0.36, 0.56, 0.28)
	var green_hi := Color(0.5, 0.72, 0.36)
	for p in PLATFORMS:
		for side in [-1.0, 1.0]:
			var cx: float = p.x + float(side) * (p.y - 60.0)
			var clump := Node2D.new()
			clump.position = Vector2(cx, GROUND_Y - 50.0)
			clump.z_index = 1
			add_child(clump)
			var bi := 0
			while bi < 5:
				var bx := -12.0 + float(bi) * 6.0
				var bh := 20.0 + float((bi * 7 + int(cx)) % 14)
				var lean := (float(bi) - 2.0) * 3.0
				var col := green_hi if bi % 2 == 0 else green
				_poly(clump, PackedVector2Array([
					Vector2(bx - 2.5, 0), Vector2(bx + 2.5, 0),
					Vector2(bx + lean, -bh),
				]), col)
				bi += 1
			_grass.append({"node": clump, "base_x": cx, "phase": cx * 0.02})

## Oiseaux noirs posés au sol le long du chemin.
func _build_birds() -> void:
	var bird_c := Color(0.14, 0.1, 0.15)
	for bx in [720.0, 2000.0, 3300.0, 4650.0, 5950.0]:
		var b := Node2D.new()
		b.position = Vector2(float(bx), GROUND_Y - 52.0)
		b.z_index = 1
		_poly(b, PackedVector2Array([
			Vector2(-6, 0), Vector2(6, 0), Vector2(5, -7), Vector2(-4, -6),
		]), bird_c)
		_poly(b, PackedVector2Array([
			Vector2(3, -6), Vector2(9, -9), Vector2(4, -3),
		]), bird_c)
		_poly(b, PackedVector2Array([
			Vector2(-6, -5), Vector2(-14, -7), Vector2(-5, -2),
		]), bird_c)
		add_child(b)
		_birds.append({"node": b, "base_x": float(bx), "flown": false})

## Taches de soleil filtrées par les feuilles : ovales dorés très diffus posés
## au sol, qui dérivent lentement et respirent en intensité.
func _build_dapples() -> void:
	var tex: Texture2D = load("res://assets/mist.svg")
	var dx := 300.0
	var di := 0
	while dx < LEVEL_END:
		var s := Sprite2D.new()
		s.texture = tex
		s.modulate = Color(1.0, 0.9, 0.55, 0.14)
		var sc := 1.4 + float(di % 3) * 0.5
		s.scale = Vector2(sc, sc * 0.4)
		s.position = Vector2(dx, GROUND_Y - 46.0 - float(di % 2) * 8.0)
		s.z_index = 0
		add_child(s)
		_dapples.append({
			"node": s, "base_x": dx, "phase": dx * 0.01,
			"amp": 24.0 + float(di % 3) * 12.0, "a0": 0.14,
		})
		dx += 420.0 + float(di * 53 % 160)
		di += 1

## Papillons : deux ailes triangulaires qui battent, portés sur un vol sinueux
## autour d'un point d'attache le long du chemin.
func _build_butterflies() -> void:
	var cols := [
		Color(0.98, 0.72, 0.3), Color(0.95, 0.5, 0.55),
		Color(0.85, 0.85, 0.95), Color(0.7, 0.55, 0.85),
	]
	var bx := 620.0
	var bi := 0
	while bx < LEVEL_END:
		var col: Color = cols[bi % cols.size()]
		var b := Node2D.new()
		b.position = Vector2(bx, GROUND_Y - 150.0 - float(bi % 3) * 40.0)
		b.z_index = 3
		add_child(b)
		var lw := _poly(b, PackedVector2Array([
			Vector2(0, 0), Vector2(-11, -8), Vector2(-9, 6),
		]), col)
		var rw := _poly(b, PackedVector2Array([
			Vector2(0, 0), Vector2(11, -8), Vector2(9, 6),
		]), col)
		_poly(b, PackedVector2Array([
			Vector2(-1, -5), Vector2(1, -5), Vector2(1, 6), Vector2(-1, 6),
		]), Color(0.15, 0.1, 0.12))
		_butterflies.append({
			"node": b, "lw": lw, "rw": rw,
			"base": b.position, "phase": bx * 0.03,
			"rx": 90.0 + float(bi % 3) * 30.0, "ry": 34.0 + float(bi % 2) * 16.0,
			"spd": 0.5 + float(bi % 3) * 0.18,
		})
		bx += 780.0 + float(bi * 47 % 260)
		bi += 1

func _process(delta: float) -> void:
	_t += delta
	var px := player.position.x if is_instance_valid(player) else -100000.0
	for g in _grass:
		var node: Node2D = g["node"]
		var wind := 0.09 * sin(_t * 1.8 + float(g["phase"]))
		var dx: float = float(g["base_x"]) - px
		var near := clampf((90.0 - absf(dx)) / 90.0, 0.0, 1.0)
		node.rotation = wind + 0.5 * near * signf(dx)
	for bd in _birds:
		if bool(bd["flown"]):
			continue
		if absf(float(bd["base_x"]) - px) < 130.0:
			bd["flown"] = true
			_fly_away(bd["node"], px)
	for dp in _dapples:
		var dn: Sprite2D = dp["node"]
		var ph: float = float(dp["phase"])
		dn.position.x = float(dp["base_x"]) + float(dp["amp"]) * sin(_t * 0.35 + ph)
		var a: float = float(dp["a0"]) * (0.6 + 0.4 * sin(_t * 0.8 + ph * 1.7))
		dn.modulate.a = a
	for bf in _butterflies:
		var bn: Node2D = bf["node"]
		var ph2: float = float(bf["phase"])
		var spd: float = float(bf["spd"])
		var base: Vector2 = bf["base"]
		var nx := base.x + float(bf["rx"]) * sin(_t * spd + ph2)
		var ny := base.y + float(bf["ry"]) * sin(_t * spd * 2.0 + ph2) * 0.6
		bn.position = Vector2(nx, ny)
		# Face au sens du vol.
		bn.scale.x = 1.0 if cos(_t * spd + ph2) >= 0.0 else -1.0
		# Battement d'ailes.
		var flap := 0.55 + 0.45 * sin(_t * 14.0 + ph2)
		var lw: Polygon2D = bf["lw"]
		var rw: Polygon2D = bf["rw"]
		lw.scale.x = flap
		rw.scale.x = flap

## Envol effarouché : l'oiseau file vers le haut, à l'opposé d'Eneko, en
## battant des ailes, puis disparaît.
func _fly_away(node: Node2D, px: float) -> void:
	var dir := signf(node.position.x - px)
	if dir == 0.0:
		dir = 1.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(node, "position", node.position + Vector2(dir * 300.0, -260.0), 1.3)
	t.tween_property(node, "modulate:a", 0.0, 1.3)
	t.chain().tween_callback(node.queue_free)
	var flap := node.create_tween()
	flap.set_loops(7)
	flap.tween_property(node, "rotation", 0.3 * dir, 0.09)
	flap.tween_property(node, "rotation", -0.1 * dir, 0.09)

func _on_checkpoint_body_entered(body: Node2D, cp: Area2D, flag: Polygon2D) -> void:
	if body == player:
		if not cp.has_meta("lit"):
			cp.set_meta("lit", true)
			Atmosphere.spark_burst(self, cp.global_position, Color(0.5, 1.0, 0.6))
		player.set_checkpoint(Vector2(cp.global_position.x, SPAWN_Y))
		flag.color = Color(0.35, 0.8, 0.4)

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
		damage_label.text = "Dégâts : %d   •   Esprits vaincus : %d" % [results["damage"], results["kills"]]
		if int(results["combo"]) >= 2:
			damage_label.text += "   •   Combo ×%d" % int(results["combo"])
	if time_label:
		time_label.text = "Temps : %s" % _format_time(results["time"])
	# Élargit le panneau pour que la ligne la plus longue (celle du combo)
	# reste à l'intérieur : le VBox est recentré et le fond suit.
	var stats_half := 150.0
	for child in challenge_stats.get_children():
		if child is Label:
			stats_half = maxf(stats_half, (child as Label).get_minimum_size().x * 0.5 + 10.0)
	challenge_stats.offset_left = -stats_half
	challenge_stats.offset_right = stats_half
	var stats_bg = win_label.find_child("StatsBG", true, false)
	if stats_bg != null:
		stats_bg.offset_left = -stats_half - 30.0
		stats_bg.offset_right = stats_half + 30.0

func _format_time(seconds: float) -> String:
	var mins: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	return "%d:%02d" % [mins, secs]

func _on_leonie_talk(lines: Array) -> void:
	# Pause d'Eneko le temps du dialogue.
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	dialogue.start(lines)

func _on_dialogue_finished() -> void:
	player.set_physics_process(true)

func _on_menu_pressed() -> void:
	Transition.goto("res://scenes/main_menu.tscn")
