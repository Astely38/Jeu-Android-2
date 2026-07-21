extends LevelBase
## Niveau secret : « Le Jardin Céleste ».
## Découvert en se glissant derrière le vieux torii moussu, tout au début
## de la Clairière des Bambous. Un archipel d'îles flottantes baignées
## d'aube, au-dessus d'une mer de nuages : aucune Ombre, aucun piège —
## uniquement du saut pur, quatre ascenseurs spirituels et la paix.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const LIFT_SCENE := preload("res://scenes/lift_platform.tscn")

const GROUND_Y := 550.0    # centre vertical des plateformes
const SPAWN_Y := 477.0     # hauteur d'apparition des personnages
const LEVEL_END := 4400.0
const GOAL_X := 4200.0
const LEVEL_ID := "level_secret"

## Thème du peintre de plateformes : pierre céleste pâle, presque nacrée.
const PLATFORM_THEME := {
	"top": Color(0.93, 0.9, 0.98),
	"top_light": Color(1.0, 0.97, 0.88),
	"body_a": Color(0.72, 0.74, 0.85),
	"body_b": Color(0.63, 0.66, 0.78),
	"dark": Color(0.5, 0.53, 0.66),
	"speck": Color(0.85, 0.87, 0.95),
}

## Îles : x = centre, y = demi-largeur. Les deux premiers trous (160 px)
## se sautent ; les quatre suivants (200-220 px) dépassent la portée de
## saut (~190 px) et se franchissent en montant sur un ascenseur spirituel.
const PLATFORMS := [
	Vector2(240, 240), Vector2(880, 240), Vector2(1500, 220),
	Vector2(2140, 200), Vector2(2780, 240), Vector2(3400, 180),
	Vector2(4000, 220),
]
const CHECKPOINT_XS := [1500.0, 2780.0]
## Un ascenseur par grand trou, désynchronisés pour varier les attentes.
const LIFTS := [
	Vector2(1830, 470), Vector2(2440, 470), Vector2(3120, 470), Vector2(3680, 470),
]
const LIFT_PHASES := [0.0, 1.9, 3.4, 4.7]
## Chaque ascenseur dessert une orbe à mi-hauteur et une au sommet.
const ORBS := [
	Vector2(330, 440), Vector2(560, 405), Vector2(880, 440),
	Vector2(1180, 405), Vector2(1500, 440), Vector2(2000, 440),
	Vector2(2240, 405), Vector2(2780, 440), Vector2(3260, 440),
	Vector2(3950, 440),
	Vector2(1830, 385), Vector2(1830, 245),
	Vector2(2440, 385), Vector2(2440, 245),
	Vector2(3120, 385), Vector2(3120, 245),
	Vector2(3680, 385), Vector2(3680, 245),
]

const LEONIE_LINES := [
	{ "name": "Léonie", "text": "Eneko... tu as trouvé le Jardin Céleste. Bien peu d'âmes ont marché ici." },
	{ "name": "Léonie", "text": "C'est ici que les esprits apaisés viennent se reposer, au-dessus des nuages." },
	{ "name": "Léonie", "text": "Aucune Ombre ne peut monter jusqu'ici. Respire, contemple. Tu l'as mérité." },
	{ "name": "Eneko", "text": "Alors c'est ça, la paix que nous défendons..." },
]

var sfx_win: AudioStreamPlayer
var petals: CPUParticles2D
## Grues qui planent lentement dans le ciel de l'aube (voir _process).
var _cranes: Array = []
var _t := 0.0

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var next_button: Button = $WinLabel/NextButton
@onready var dialogue: CanvasLayer = $Dialogue
@onready var leonie: Area2D = $Leonie

func _ready() -> void:
	_build_decor()
	_build_cranes()
	_build_platforms()
	PlatformPainter.build_sanctuary(self, 3400.0, GROUND_Y - 50.0)
	_build_checkpoints()
	_build_lifts()
	_build_goal()
	_build_kill_zone(LEVEL_END)
	_spawn_orbs()
	_setup_audio()
	win_label.visible = false
	SaveManager.set_last_level(LEVEL_ID)
	Challenge.start_level(LEVEL_ID, ORBS.size())
	leonie.set_lines(LEONIE_LINES)
	dialogue.finished.connect(_on_dialogue_finished)
	menu_button.pressed.connect(_on_menu_pressed)
	# Pas de « niveau suivant » : le jardin est un détour, pas une étape.
	next_button.visible = false
	# Survol d'introduction : du torii doré jusqu'à Eneko.
	player.intro_pan(Vector2(GOAL_X, 380.0))

# --- Construction du niveau ---------------------------------------------

func _poly(parent: Node, points: PackedVector2Array, color: Color, pos := Vector2.ZERO) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.position = pos
	parent.add_child(p)
	return p

## Aube au-dessus des nuages : grand soleil levant, îles lointaines qui
## flottent, dernières étoiles, et une mer de nuages sous les îles.
func _build_decor() -> void:
	var bg: ParallaxBackground = $ParallaxBackground
	var mist_tex: Texture2D = load("res://assets/mist.svg")

	# Soleil levant, énorme et doux, posé sur la mer de nuages.
	var sky_layer := ParallaxLayer.new()
	sky_layer.motion_scale = Vector2(0.04, 0.04)
	bg.add_child(sky_layer)
	var sun_glow := Sprite2D.new()
	sun_glow.texture = mist_tex
	sun_glow.modulate = Color(1.0, 0.8, 0.5, 0.6)
	sun_glow.scale = Vector2(13.0, 13.0)
	sun_glow.position = Vector2(620.0, 400.0)
	sky_layer.add_child(sun_glow)
	var sun_pts := PackedVector2Array()
	for k in 24:
		var a := k * TAU / 24.0
		sun_pts.append(Vector2(cos(a) * 74.0, sin(a) * 74.0))
	_poly(sky_layer, sun_pts, Color(1.0, 0.88, 0.6, 0.9), Vector2(620, 400))

	# Dernières étoiles de la nuit, en haut du ciel.
	var si := 0
	while si < 22:
		var sx := 30.0 + float((si * 167) % 900)
		var sy := 14.0 + float((si * 71) % 150)
		_poly(sky_layer, PackedVector2Array([
			Vector2(-1.7, 0), Vector2(0, -1.7), Vector2(1.7, 0), Vector2(0, 1.7),
		]), Color(1.0, 0.95, 0.85, 0.55), Vector2(sx, sy))
		si += 1
	# Voiles nuageux dorés de l'aube qui dérivent au-dessus de la mer de nuages.
	TextureLab.add_clouds(sky_layer, 5, 130.0, 320.0, LEVEL_END, Color(1.0, 0.88, 0.66, 0.17))

	# Îles lointaines qui flottent à l'horizon, avec leur pointe qui pend.
	var far := ParallaxLayer.new()
	far.motion_scale = Vector2(0.12, 0.3)
	bg.add_child(far)
	var ix := -100.0
	var ii := 0
	while ix < LEVEL_END + 900.0:
		var iw := 90.0 + float(ii * 37 % 60)
		var iy := 180.0 + float(ii * 53 % 140)
		_poly(far, PackedVector2Array([
			Vector2(-iw, 0), Vector2(iw, 0), Vector2(iw * 0.5, 14),
			Vector2(0, iw * 0.7), Vector2(-iw * 0.5, 14),
		]), Color(0.42, 0.38, 0.58, 0.55), Vector2(ix, iy))
		_poly(far, PackedVector2Array([
			Vector2(-iw, 0), Vector2(iw, 0), Vector2(iw - 8, -8), Vector2(-iw + 8, -8),
		]), Color(0.62, 0.55, 0.72, 0.6), Vector2(ix, iy))
		ix += 420.0 + float(ii * 41 % 160)
		ii += 1

	# Mer de nuages, deux bancs superposés qui défilent à des vitesses
	# différentes sous les îles.
	for layer_i in 2:
		var sea := ParallaxLayer.new()
		sea.motion_scale = Vector2(0.35 + 0.25 * float(layer_i), 0.7)
		bg.add_child(sea)
		var cx := -150.0
		var ci := 0
		var base_y := 520.0 + 40.0 * float(layer_i)
		var tint := Color(1, 1, 1, 0.5 + 0.25 * float(layer_i))
		while cx < LEVEL_END + 900.0:
			var cw := 90.0 + float(ci * 31 % 70)
			_poly(sea, PackedVector2Array([
				Vector2(-cw, 26), Vector2(-cw * 0.6, -14), Vector2(-cw * 0.15, -26),
				Vector2(cw * 0.3, -18), Vector2(cw * 0.7, -24), Vector2(cw, 26),
			]), tint, Vector2(cx, base_y + float(ci * 17 % 24)))
			cx += cw * 1.5
			ci += 1

	# Pétales dorés qui dérivent autour d'Eneko.
	petals = CPUParticles2D.new()
	petals.texture = load("res://assets/leaf.svg")
	petals.amount = 20
	petals.lifetime = 9.0
	petals.preprocess = 9.0
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.emission_rect_extents = Vector2(560, 12)
	petals.direction = Vector2(0.2, 1.0)
	petals.spread = 20.0
	petals.gravity = Vector2(4, 12)
	petals.initial_velocity_min = 14.0
	petals.initial_velocity_max = 34.0
	petals.angular_velocity_min = -60.0
	petals.angular_velocity_max = 60.0
	petals.scale_amount_min = 0.5
	petals.scale_amount_max = 0.8
	petals.color = Color(1.0, 0.85, 0.5, 0.9)
	add_child(petals)

## Grues blanches qui planent en travers du ciel, réparties sur toute la
## largeur : elles dérivent lentement, ondulent en altitude et battent des
## ailes de temps à autre, puis reparaissent de l'autre côté.
func _build_cranes() -> void:
	var body_c := Color(0.98, 0.98, 1.0, 0.92)
	var tip_c := Color(0.2, 0.2, 0.26, 0.9)
	var cx := 200.0
	var ci := 0
	while cx < LEVEL_END:
		var c := Node2D.new()
		c.position = Vector2(cx, 70.0 + float(ci * 53 % 150))
		c.z_index = 0
		var sc := 0.8 + float(ci % 3) * 0.25
		c.scale = Vector2(sc, sc)
		add_child(c)
		# Corps effilé et long cou tendu vers l'avant.
		_poly(c, PackedVector2Array([
			Vector2(-10, 0), Vector2(12, -2), Vector2(20, 0), Vector2(12, 2),
		]), body_c)
		_poly(c, PackedVector2Array([
			Vector2(-10, 0), Vector2(-18, 1), Vector2(-10, 2),
		]), body_c)
		# Ailes déployées (pivotent au battement).
		var lw := _poly(c, PackedVector2Array([
			Vector2(2, -1), Vector2(-8, -16), Vector2(6, -2),
		]), body_c)
		var rw := _poly(c, PackedVector2Array([
			Vector2(2, 1), Vector2(-8, 16), Vector2(6, 2),
		]), body_c)
		# Bout des ailes sombre.
		_poly(lw, PackedVector2Array([
			Vector2(-8, -16), Vector2(-3, -12), Vector2(-2, -15),
		]), tip_c)
		_poly(rw, PackedVector2Array([
			Vector2(-8, 16), Vector2(-3, 12), Vector2(-2, 15),
		]), tip_c)
		_cranes.append({
			"node": c, "lw": lw, "rw": rw,
			"x": cx, "base_y": c.position.y,
			"spd": 10.0 + float(ci % 3) * 5.0, "phase": float(ci) * 1.1,
			"flap": 0.9 + float(ci % 4) * 0.2,
		})
		cx += 620.0 + float(ci * 47 % 260)
		ci += 1

func _process(delta: float) -> void:
	_t += delta
	for cr in _cranes:
		var cn: Node2D = cr["node"]
		var ph: float = float(cr["phase"])
		# Dérive lente vers la gauche, réapparition à droite.
		var x: float = float(cr["x"]) - float(cr["spd"]) * delta
		if x < -120.0:
			x = LEVEL_END + 120.0
		cr["x"] = x
		var y := float(cr["base_y"]) + 12.0 * sin(_t * 0.4 + ph)
		cn.position = Vector2(x, y)
		# Battement d'ailes lent, planant.
		var fl := 0.35 * sin(_t * float(cr["flap"]) + ph)
		var lw: Polygon2D = cr["lw"]
		var rw: Polygon2D = cr["rw"]
		lw.rotation = fl
		rw.rotation = -fl

func _build_platforms() -> void:
	for i in PLATFORMS.size():
		var p: Vector2 = PLATFORMS[i]
		var body := StaticBody2D.new()
		body.position = Vector2(p.x, GROUND_Y)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(p.y * 2.0, 100.0)
		shape.shape = rect
		body.add_child(shape)
		PlatformPainter.paint(body, p.y, PLATFORM_THEME)
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
		]), Color(0.6, 0.58, 0.7))
		var flag := _poly(cp, PackedVector2Array([
			Vector2(3, -60), Vector2(40, -50), Vector2(3, -38),
		]), Color(0.95, 0.85, 0.5))
		add_child(cp)
		cp.body_entered.connect(_on_checkpoint_body_entered.bind(cp, flag))

## Ascenseurs spirituels : un par grand trou, chacun avec sa phase.
func _build_lifts() -> void:
	for i in LIFTS.size():
		var v: Vector2 = LIFTS[i]
		var lift := LIFT_SCENE.instantiate()
		lift.position = v
		lift.phase = float(LIFT_PHASES[i])
		add_child(lift)

## Torii doré du jardin : même silhouette que les autres, en or et nacre.
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
	glow.modulate = Color(1.0, 0.9, 0.55, 0.6)
	glow.scale = Vector2(5.0, 5.0)
	goal.add_child(glow)
	var gold := Color(0.92, 0.74, 0.3)
	var gold_dark := Color(0.8, 0.6, 0.22)
	_poly(goal, PackedVector2Array([Vector2(-40, -60), Vector2(40, -60), Vector2(40, 66), Vector2(-40, 66)]), Color(1, 0.92, 0.6, 0.25))
	_poly(goal, PackedVector2Array([Vector2(-28, -55), Vector2(-20, -55), Vector2(-20, 70), Vector2(-28, 70)]), gold)
	_poly(goal, PackedVector2Array([Vector2(20, -55), Vector2(28, -55), Vector2(28, 70), Vector2(20, 70)]), gold)
	_poly(goal, PackedVector2Array([Vector2(-42, -70), Vector2(42, -70), Vector2(38, -58), Vector2(-38, -58)]), gold_dark)
	_poly(goal, PackedVector2Array([Vector2(-32, -46), Vector2(32, -46), Vector2(32, -38), Vector2(-32, -38)]), gold)
	add_child(goal)
	goal.body_entered.connect(_on_goal_body_entered)

func _spawn_orbs() -> void:
	for o in ORBS:
		var orb := ORB_SCENE.instantiate()
		orb.position = o
		add_child(orb)

## Vent léger d'altitude + son de victoire.
func _setup_audio() -> void:
	var wind := AudioStreamPlayer.new()
	wind.stream = load("res://assets/sfx/wind.wav")
	wind.volume_db = -20.0
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

func _on_checkpoint_body_entered(body: Node2D, cp: Area2D, flag: Polygon2D) -> void:
	if body == player:
		player.set_checkpoint(Vector2(cp.global_position.x, SPAWN_Y))
		flag.color = Color(0.35, 0.8, 0.4)

func _on_goal_body_entered(body: Node2D) -> void:
	_reach_goal(body, LEVEL_ID, sfx_win)
