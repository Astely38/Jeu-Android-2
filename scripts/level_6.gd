extends Node2D
## Chapitre II — Niveau 6 : « Les Rivages de Cendre ».
## Par-delà la mer de brume, Eneko débarque sur une grève de sable noir où
## roule une marée de cendre. À l'horizon, un volcan mort saigne encore de
## braise ; le ciel est bas, gris de suie, et l'air pleut de flocons de
## cendre. Des torii calcinés et du bois flotté jonchent la plage. C'est ici
## que l'Ombre a sa source — et les Masques d'Oni y rôdent, plus nombreux.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const PATROL_SCENE := preload("res://scenes/enemy.tscn")
const SHADOW_SCENE := preload("res://scenes/shadow.tscn")
const MASK_SCENE := preload("res://scenes/split_shade.tscn")
const LEONIE_SCENE := preload("res://scenes/leonie.tscn")

const GROUND_Y := 550.0    # centre vertical des plateformes
const SPAWN_Y := 477.0     # hauteur d'apparition des personnages
const LEVEL_END := 7300.0
const GOAL_X := 6950.0
const LEVEL_ID := "level_6"

const SAND := Color(0.26, 0.24, 0.28)
const SAND_DARK := Color(0.16, 0.15, 0.18)
const EMBER := Color(0.95, 0.45, 0.18)

## Thème du peintre de plateformes : grève de sable noir volcanique, croûte
## de cendre pâle au sommet, veines de braise assoupie.
const PLATFORM_THEME := {
	"top": Color(0.42, 0.4, 0.44),
	"top_light": Color(0.62, 0.44, 0.36),
	"body_a": SAND,
	"body_b": Color(0.22, 0.2, 0.24),
	"dark": SAND_DARK,
	"speck": Color(0.7, 0.34, 0.18),
}

## Plateformes : x = centre, y = demi-largeur. Trous de 140 à 180 px (portée
## de saut max ≈ 190 px) ; deux brèches larges sont franchies par des
## passerelles de bois flotté échoué.
const PLATFORMS := [
	Vector2(230, 230), Vector2(850, 250), Vector2(1470, 230),
	Vector2(2080, 200), Vector2(2680, 240), Vector2(3300, 230),
	Vector2(3920, 210), Vector2(4540, 200), Vector2(5160, 250),
	Vector2(5780, 200), Vector2(6420, 240), Vector2(7040, 280),
]
const CHECKPOINT_XS := [1600.0, 3300.0, 5780.0]
## La plateforme 2440-2920 est le refuge : aucun ennemi ni piège n'y est
## placé (la lueur de Léonie y veille).
const PATROL_XS := [900.0, 1500.0, 3850.0, 5300.0, 6300.0]
const SHADOW_XS := [1420.0, 3350.0, 6450.0]
## Ombre d'élite : rare, deux coups à placer, orbe dorée (3 orbes) à la clé.
const ELITE_XS := [5160.0]
## Masques d'Oni (le nouvel ennemi de flottaison) : au-dessus de plateformes
## dégagées, jamais d'un trou. Ils poursuivent Eneko et se fendent en deux.
const MASK_XS := [2080.0, 4540.0]
const TRAP_XS := [700.0, 2000.0, 3160.0, 4430.0, 5670.0, 6850.0]
## Torii calcinés qui bordent la grève (décor, sans collision).
const TORII_XS := [500.0, 2500.0, 3920.0, 5160.0, 6600.0]
## Passerelles de bois flotté PRATICABLES au-dessus des deux plus grandes
## brèches : x = centre du trou, y = demi-largeur du tablier.
const BRIDGES := [Vector2(1775, 100), Vector2(6100, 110)]
const ORBS := [
	Vector2(320, 420), Vector2(540, 385), Vector2(850, 420),
	Vector2(1150, 385), Vector2(1470, 420), Vector2(1780, 385),
	Vector2(2080, 420), Vector2(2380, 385), Vector2(2680, 420),
	Vector2(3000, 385), Vector2(3300, 420), Vector2(3610, 385),
	Vector2(3920, 420), Vector2(4230, 385), Vector2(4540, 420),
	Vector2(4850, 385), Vector2(5160, 420), Vector2(5470, 385),
	Vector2(5780, 420), Vector2(6100, 385), Vector2(6420, 420),
	# La dernière orbe reste EN DEÇÀ de la porte (GOAL_X=6950) : sinon elle
	# serait piégée derrière le torii de sortie et la Platine deviendrait
	# impossible (elle exige de tout ramasser).
	Vector2(6730, 385), Vector2(6800, 420),
]

const LEONIE_LINES := [
	{ "name": "Léonie", "text": "Eneko... c'est bien moi. Je devais rejoindre la lumière — mais tant que l'Ombre a une source, je ne peux me reposer." },
	{ "name": "Léonie", "text": "Ce qu'a murmuré le Gardien est vrai. Par-delà la mer de brume, sur ces Rivages de Cendre, quelque chose de plus ancien s'éveille." },
	{ "name": "Léonie", "text": "Prends garde : les Masques d'Oni hantent cette grève. Tranche-les, et ils se fendront en deux — frappe vite, ne les laisse pas t'encercler." },
	{ "name": "Eneko", "text": "Alors nous irons ensemble jusqu'au bout, Léonie. Jusqu'à la source de toute cette Ombre." },
]

var sfx_win: AudioStreamPlayer
var ash_fall: CPUParticles2D
var ember_drift: CPUParticles2D
## Braises du sol qui palpitent au rythme du volcan (voir _process).
var _embers: Array = []
## Nappe de la marée de cendre : elle avance et recule lentement.
var _tide: Polygon2D
var _tide_glow: Sprite2D
var _t := 0.0

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var next_button: Button = $WinLabel/NextButton
@onready var dialogue: CanvasLayer = $Dialogue

func _ready() -> void:
	_build_decor()
	# Voile de suie au premier plan : l'air lui-même est chargé de cendre.
	Atmosphere.add_foreground(self, Color(0.14, 0.1, 0.11, 0.32))
	_build_platforms()
	_build_torii()
	_build_bridges()
	_build_hazards()
	_build_checkpoints()
	_build_traps()
	_build_goal()
	_build_kill_zone()
	_spawn_entities()
	_setup_audio()
	_setup_ambient()
	# Sur le sable noir, Eneko soulève une poussière de cendre grise.
	player.set_land_dust_color(Color(0.5, 0.46, 0.44, 0.8))
	win_label.visible = false
	Music.play_world(2)
	SaveManager.set_last_level(LEVEL_ID)
	# Relique cachée, en hauteur (récompense le Double Saut).
	var relic := Relic.new()
	relic.level_id = LEVEL_ID
	relic.position = Vector2(3300, 300)
	add_child(relic)
	# Les orbes dorées des Ombres d'élite comptent dans le total (3 chacune).
	Challenge.start_level(LEVEL_ID, ORBS.size() + 3 * ELITE_XS.size())
	dialogue.finished.connect(_on_dialogue_finished)
	menu_button.pressed.connect(_on_menu_pressed)
	# Dernier chapitre disponible : aucun niveau suivant pour l'instant.
	var next_scene: String = SaveManager.LEVEL_SCENES.get("level_7", "")
	next_button.visible = next_scene != ""
	if next_scene != "":
		next_button.pressed.connect(func(): Transition.goto(next_scene))
	# Survol d'introduction : du volcan mort jusqu'à Eneko.
	player.intro_pan(Vector2(GOAL_X, 360.0))

func _process(delta: float) -> void:
	_t += delta
	# Palpitation des braises au sol, désynchronisée d'un foyer à l'autre.
	for eb in _embers:
		var node: Polygon2D = eb["node"]
		var ph: float = float(eb["phase"])
		node.modulate.a = 0.35 + 0.45 * (0.5 + 0.5 * sin(_t * 1.6 + ph))
	# La marée de cendre respire : elle avance et recule au ras du sol.
	if _tide != null:
		var breath := sin(_t * 0.5)
		_tide.position.x = breath * 40.0
		_tide.color.a = 0.5 + 0.12 * sin(_t * 0.9)
	if _tide_glow != null:
		_tide_glow.modulate.a = 0.16 + 0.06 * (0.5 + 0.5 * sin(_t * 0.7))

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	if ash_fall != null:
		ash_fall.position = Vector2(player.position.x, player.position.y - 340.0)
	if ember_drift != null:
		ember_drift.position = Vector2(player.position.x, player.position.y + 20.0)

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

## Ciel de suie (posé par le .tscn), volcan mort qui saigne de braise à
## l'horizon, mer de cendre qui roule au loin, torii calcinés en silhouette,
## puis cendre qui tombe et braises qui montent autour d'Eneko.
func _build_decor() -> void:
	var bg: ParallaxBackground = $ParallaxBackground
	var mist_tex: Texture2D = load("res://assets/mist.svg")

	# Lueur du volcan, très haut derrière tout : halo rouge sourd + rais.
	var sky := ParallaxLayer.new()
	sky.motion_scale = Vector2(0.05, 0.05)
	bg.add_child(sky)
	var glow := Sprite2D.new()
	glow.texture = mist_tex
	glow.modulate = Color(0.85, 0.28, 0.12, 0.5)
	glow.scale = Vector2(11.0, 8.0)
	glow.position = Vector2(760.0, 150.0)
	sky.add_child(glow)
	# Rais de chaleur rougeoyants filtrés par la suie.
	var rays := GodRays.new()
	rays.color = Color(1.0, 0.4, 0.18, 0.05)
	rays.length = 1200.0
	rays.half_spread = 1.0
	rays.position = Vector2(760.0, 150.0)
	sky.add_child(rays)
	# Voiles de suie qui dérivent lentement, très pâles.
	TextureLab.add_clouds(sky, 5, 60.0, 200.0, LEVEL_END, Color(0.3, 0.26, 0.28, 0.16))

	# Volcan mort à l'horizon : grande silhouette conique qui saigne de la
	# lave figée, sommet fumant.
	var far := ParallaxLayer.new()
	far.motion_scale = Vector2(0.1, 0.35)
	bg.add_child(far)
	var vx := 700.0
	var vtri := PackedVector2Array([
		Vector2(-460, 0), Vector2(-70, -300), Vector2(70, -300), Vector2(460, 0),
	])
	_poly(far, vtri, Color(0.14, 0.12, 0.15, 0.92), Vector2(vx, 540))
	TextureLab.grain_poly(far, vtri, 0.12, Vector2(vx, 0), Vector2(vx, 540))
	# Coulées de lave figée sur les flancs.
	for si in [-1.0, 1.0]:
		_poly(far, PackedVector2Array([
			Vector2(si * 30, -290), Vector2(si * 46, -290),
			Vector2(si * 150, -30), Vector2(si * 120, -30),
		]), Color(0.7, 0.24, 0.1, 0.75), Vector2(vx, 540))
	# Bouche du cratère, rougeoyante.
	_poly(far, PackedVector2Array([
		Vector2(-70, -300), Vector2(70, -300), Vector2(40, -272), Vector2(-40, -272),
	]), Color(1.0, 0.5, 0.2, 0.85), Vector2(vx, 540))
	# Autres pics morts, plus bas et plus lointains.
	var mx := -200.0
	var mi := 0
	while mx < LEVEL_END + 800.0:
		if absf(mx - vx) > 520.0:
			var mh := 150.0 + float(mi * 61 % 110)
			_poly(far, PackedVector2Array([
				Vector2(-240, 0), Vector2(0, -mh), Vector2(240, 0),
			]), Color(0.17, 0.15, 0.18, 0.7), Vector2(mx, 540))
		mx += 430.0 + float(mi * 47 % 150)
		mi += 1

	# Mer de cendre : large bande sombre au loin, luisant faiblement de braise.
	var sea := ParallaxLayer.new()
	sea.motion_scale = Vector2(0.2, 0.55)
	bg.add_child(sea)
	_tide_glow = Sprite2D.new()
	_tide_glow.texture = mist_tex
	_tide_glow.modulate = Color(0.85, 0.35, 0.15, 0.18)
	_tide_glow.scale = Vector2(60.0, 3.0)
	_tide_glow.position = Vector2(LEVEL_END * 0.5, 452.0)
	sea.add_child(_tide_glow)
	_tide = _poly(sea, PackedVector2Array([
		Vector2(-200, 458), Vector2(LEVEL_END + 400, 458),
		Vector2(LEVEL_END + 400, 620), Vector2(-200, 620),
	]), Color(0.13, 0.11, 0.13, 0.55))
	# Crêtes de vagues de cendre, ourlées de braise.
	var wx := -100.0
	var wi := 0
	while wx < LEVEL_END + 300.0:
		_poly(sea, PackedVector2Array([
			Vector2(-70, 0), Vector2(0, -9), Vector2(70, 0),
		]), Color(0.5, 0.24, 0.12, 0.35), Vector2(wx, 460.0 + float(wi % 3) * 5.0))
		wx += 190.0
		wi += 1

	# Bois flotté et carcasses de barques échouées, en silhouette proche.
	var wreck := ParallaxLayer.new()
	wreck.motion_scale = Vector2(0.5, 0.85)
	bg.add_child(wreck)
	var dx := 360.0
	var di := 0
	while dx < LEVEL_END - 200.0:
		_build_driftwood(wreck, Vector2(dx, 512.0), di)
		dx += 780.0 + float(di * 71 % 220)
		di += 1

	# Cendre qui tombe doucement autour d'Eneko (flocons gris, lents).
	ash_fall = CPUParticles2D.new()
	ash_fall.texture = load("res://assets/leaf.svg")
	ash_fall.amount = 34
	ash_fall.lifetime = 6.5
	ash_fall.preprocess = 6.5
	ash_fall.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash_fall.emission_rect_extents = Vector2(560, 10)
	ash_fall.direction = Vector2(0.2, 1.0)
	ash_fall.spread = 18.0
	ash_fall.gravity = Vector2(10, 22)
	ash_fall.initial_velocity_min = 14.0
	ash_fall.initial_velocity_max = 30.0
	ash_fall.angular_velocity_min = -50.0
	ash_fall.angular_velocity_max = 50.0
	ash_fall.scale_amount_min = 0.3
	ash_fall.scale_amount_max = 0.6
	ash_fall.color = Color(0.55, 0.52, 0.5, 0.7)
	add_child(ash_fall)

	# Braises qui montent en tourbillonnant autour d'Eneko (points orangés).
	ember_drift = CPUParticles2D.new()
	ember_drift.amount = 16
	ember_drift.lifetime = 3.2
	ember_drift.preprocess = 3.2
	ember_drift.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ember_drift.emission_rect_extents = Vector2(520, 30)
	ember_drift.direction = Vector2(0, -1)
	ember_drift.spread = 35.0
	ember_drift.gravity = Vector2(6, -34)
	ember_drift.initial_velocity_min = 20.0
	ember_drift.initial_velocity_max = 48.0
	ember_drift.scale_amount_min = 0.8
	ember_drift.scale_amount_max = 1.8
	ember_drift.color = Color(1.0, 0.55, 0.2, 0.9)
	add_child(ember_drift)

## Une carcasse de bois flotté : quelques planches croisées et brisées,
## silhouette sombre posée sur le sable.
func _build_driftwood(parent: Node, base: Vector2, seed_i: int) -> void:
	var col := Color(0.11, 0.1, 0.11, 0.9)
	var tilt := 0.2 + float(seed_i % 3) * 0.12
	_poly(parent, PackedVector2Array([
		Vector2(-60, -6), Vector2(60, -14), Vector2(62, -6), Vector2(-58, 2),
	]), col, base)
	_poly(parent, PackedVector2Array([
		Vector2(-14, -46), Vector2(-6, -46), Vector2(6, 4), Vector2(-2, 4),
	]), col, base + Vector2(float(seed_i % 30) - 15.0, 0))
	# Membrure courbe d'une barque renversée.
	var ribs := PackedVector2Array()
	for k in 7:
		var a := PI * (0.15 + 0.7 * float(k) / 6.0)
		ribs.append(Vector2(cos(a) * 54.0, -sin(a) * 30.0 * tilt))
	for k in 6:
		_poly(parent, PackedVector2Array([
			ribs[k] + Vector2(0, -2), ribs[k + 1] + Vector2(0, -2),
			ribs[k + 1] + Vector2(0, 2), ribs[k] + Vector2(0, 2),
		]), col, base + Vector2(0, -4))

## Torii calcinés bordant la grève : silhouette noire, montants fendus, à
## demi engloutis par le sable.
func _build_torii() -> void:
	for tx in TORII_XS:
		var torii := Node2D.new()
		torii.position = Vector2(tx, GROUND_Y - 50.0)
		var col := Color(0.1, 0.08, 0.09)
		for side in [-1.0, 1.0]:
			_poly(torii, PackedVector2Array([
				Vector2(side * 34 - 6, 0), Vector2(side * 34 + 6, 0),
				Vector2(side * 34 + 5, -128), Vector2(side * 34 - 5, -128),
			]), col)
		# Linteau supérieur incurvé + entrait.
		_poly(torii, PackedVector2Array([
			Vector2(-58, -128), Vector2(58, -128), Vector2(50, -146), Vector2(-50, -146),
		]), col)
		_poly(torii, PackedVector2Array([
			Vector2(-64, -150), Vector2(64, -150), Vector2(56, -164), Vector2(-56, -164),
		]), col)
		_poly(torii, PackedVector2Array([
			Vector2(-42, -104), Vector2(42, -104), Vector2(42, -94), Vector2(-42, -94),
		]), col)
		# Braise résiduelle qui rougeoie encore dans une fissure du montant.
		var e := _poly(torii, PackedVector2Array([
			Vector2(-3, -70), Vector2(3, -70), Vector2(2, -40), Vector2(-2, -40),
		]), Color(1.0, 0.45, 0.18, 0.0), Vector2(-34, 0))
		_embers.append({"node": e, "phase": float(int(tx) % 628) * 0.01})
		add_child(torii)

## Plateformes de sable noir : strate volcanique, croûte de cendre au sommet,
## veines de braise assoupie et éclats d'obsidienne.
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
		PlatformPainter.paint(body, p.y, PLATFORM_THEME)

		# Veines de braise qui rougeoient dans la roche.
		var vein_count: int = maxi(1, int(p.y / 120.0))
		for v in vein_count:
			var vx2: float = -p.y + 70.0 + v * ((p.y * 2.0 - 140.0) / maxf(1.0, float(vein_count)))
			var e := _poly(body, PackedVector2Array([
				Vector2(vx2 - 2, 30), Vector2(vx2 + 2, 30),
				Vector2(vx2 + 5, 96), Vector2(vx2 - 1, 104), Vector2(vx2 - 4, 66),
			]), Color(0.9, 0.4, 0.16, 0.0))
			_embers.append({"node": e, "phase": float((v * 53 + pi * 71) % 628) * 0.01})

		# Éclats d'obsidienne noire posés sur la croûte.
		var shard_count: int = maxi(1, int(p.y / 110.0))
		for r in shard_count:
			var rx: float = -p.y + 50.0 + r * ((p.y * 2.0 - 100.0) / maxf(1.0, float(shard_count)))
			_poly(body, PackedVector2Array([
				Vector2(rx - 9, -34), Vector2(rx - 2, -50), Vector2(rx + 8, -36), Vector2(rx, -30),
			]), Color(0.09, 0.08, 0.1))

		add_child(body)

## Passerelles de bois flotté PRATICABLES : tablier avec collision, aligné
## sur le dessus des plateformes, tendu au-dessus des brèches larges.
func _build_bridges() -> void:
	for b in BRIDGES:
		var half: float = b.y
		var body := StaticBody2D.new()
		body.position = Vector2(b.x, GROUND_Y)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(half * 2.0, 12.0)
		shape.shape = rect
		shape.position = Vector2(0, -44.0)
		body.add_child(shape)
		# Planches échouées, teintes de bois brûlé alternées.
		var px := -half
		var pi := 0
		while px < half:
			var pw := minf(22.0, half - px)
			var c := Color(0.24, 0.18, 0.14) if pi % 2 == 0 else Color(0.18, 0.13, 0.1)
			_poly(body, PackedVector2Array([
				Vector2(px, -50), Vector2(px + pw, -50),
				Vector2(px + pw, -38), Vector2(px, -38),
			]), c)
			px += 24.0
			pi += 1
		# Pilotis fichés dans le sable aux deux extrémités.
		for side in [-1.0, 1.0]:
			_poly(body, PackedVector2Array([
				Vector2(side * half - 4, -50), Vector2(side * half + 4, -50),
				Vector2(side * half + 3, 30), Vector2(side * half - 3, 30),
			]), Color(0.14, 0.1, 0.08))
		add_child(body)

## Dangers de la grève : un évent de braise (geyser reskinné) et un lanceur
## de dards de cendre, bien séparés et À L'ÉCART du refuge (2440-2920).
func _build_hazards() -> void:
	var vent := SpiritGeyser.new()
	vent.position = Vector2(3900.0, GROUND_Y - 50.0)
	vent.phase = 0.4
	add_child(vent)
	var dart := DartLauncher.new()
	dart.position = Vector2(1560.0, GROUND_Y - 50.0)
	dart.dir = -1.0
	dart.phase = 0.6
	dart.tint = Color(1.0, 0.55, 0.2)
	add_child(dart)

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
		]), Color(0.22, 0.2, 0.22))
		var flag := _poly(cp, PackedVector2Array([
			Vector2(3, -60), Vector2(40, -50), Vector2(3, -38),
		]), Color(0.9, 0.5, 0.25))
		add_child(cp)
		cp.body_entered.connect(_on_checkpoint_body_entered.bind(cp, flag))

## Pièges : pieux d'obsidienne noire hérissant le sol, teintés de braise.
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
		]), Color(0.12, 0.11, 0.13))
		for k in 4:
			var ox := -24.0 + k * 16.0
			_poly(trap, PackedVector2Array([
				Vector2(ox - 7, 6), Vector2(ox + 7, 6), Vector2(ox, -22),
			]), Color(0.1, 0.09, 0.11))
			_poly(trap, PackedVector2Array([
				Vector2(ox - 3, 2), Vector2(ox + 3, 2), Vector2(ox, -16),
			]), Color(0.75, 0.32, 0.14, 0.85))
		add_child(trap)
		trap.body_entered.connect(_on_trap_body_entered)

func _on_trap_body_entered(body: Node2D) -> void:
	if body == player and body.has_method("take_damage"):
		body.take_damage(1, body.global_position + Vector2(0, 40))

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
	glow.modulate = Color(1.0, 0.55, 0.25, 0.5)
	glow.scale = Vector2(4.5, 4.5)
	goal.add_child(glow)
	# Torii encore debout, embrasé de braise : la porte des terres de l'Ombre.
	_poly(goal, PackedVector2Array([Vector2(-40, -60), Vector2(40, -60), Vector2(40, 66), Vector2(-40, 66)]), Color(1.0, 0.5, 0.2, 0.22))
	_poly(goal, PackedVector2Array([Vector2(-28, -55), Vector2(-20, -55), Vector2(-20, 70), Vector2(-28, 70)]), Color(0.16, 0.12, 0.12))
	_poly(goal, PackedVector2Array([Vector2(20, -55), Vector2(28, -55), Vector2(28, 70), Vector2(20, 70)]), Color(0.16, 0.12, 0.12))
	_poly(goal, PackedVector2Array([Vector2(-42, -70), Vector2(42, -70), Vector2(38, -58), Vector2(-38, -58)]), Color(0.2, 0.14, 0.13))
	_poly(goal, PackedVector2Array([Vector2(-32, -46), Vector2(32, -46), Vector2(32, -38), Vector2(-32, -38)]), Color(0.16, 0.12, 0.12))
	add_child(goal)
	Atmosphere.breathe(glow)
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
	for x in ELITE_XS:
		var el := SHADOW_SCENE.instantiate()
		el.position = Vector2(x, SPAWN_Y)
		add_child(el)
		el.make_elite()
	# Masques d'Oni : au-dessus des plateformes (jamais d'un trou), bien
	# visibles ; ils poursuivent Eneko et se fendent quand on les tranche.
	for x in MASK_XS:
		var m := MASK_SCENE.instantiate()
		m.position = Vector2(x, SPAWN_Y - 70.0)
		add_child(m)
	# Refuge : la lueur de Léonie veille sur la plateforme du milieu.
	PlatformPainter.build_sanctuary(self, 2680.0, GROUND_Y - 50.0)
	var leonie := LEONIE_SCENE.instantiate()
	leonie.position = Vector2(2680.0, SPAWN_Y)
	leonie.set_lines(LEONIE_LINES)
	add_child(leonie)
	for o in ORBS:
		var orb := ORB_SCENE.instantiate()
		orb.position = o
		add_child(orb)

## Ressac lointain de la mer de cendre + répliques d'ambiance (non bloquantes).
func _setup_ambient() -> void:
	var amb := AmbientDialogue.new()
	add_child(amb)
	amb.add_line(self, 850.0, "Eneko", "La mer de brume est derrière moi. Ici, même le sable est de cendre.")
	amb.add_line(self, 3850.0, "Eneko", "Ces masques... ils se dédoublent quand je frappe. Je dois être plus vif.")
	amb.add_line(self, 6300.0, "Eneko", "La porte embrasée. C'est là que commence le cœur de l'Ombre.")

func _setup_audio() -> void:
	var wind := AudioStreamPlayer.new()
	wind.stream = load("res://assets/sfx/wind.wav")
	wind.volume_db = -15.0
	wind.pitch_scale = 0.82
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
		if not cp.has_meta("lit"):
			cp.set_meta("lit", true)
			Atmosphere.spark_burst(self, cp.global_position, Color(1.0, 0.6, 0.3))
		player.set_checkpoint(Vector2(cp.global_position.x, SPAWN_Y))
		flag.color = Color(0.4, 0.9, 0.5, 0.95)

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

func _on_dialogue_finished() -> void:
	player.set_physics_process(true)

func _on_menu_pressed() -> void:
	Transition.goto("res://scenes/main_menu.tscn")
