extends Node2D
## Chapitre II — Niveau 8 : « Le Puits de l'Ombre ».
## Sous la Gorge d'Obsidienne s'ouvre le Puits : là où la lave laisse place à
## l'Ombre pure. Un abîme violet où flottent des cristaux corrompus, où des
## tentacules de nuit s'élèvent des profondeurs, et où, tout au fond, bat le
## Cœur de l'Ombre. La lumière de Léonie y vacille. C'est le point le plus
## profond du périple d'Eneko — la source est à portée de lame.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const PATROL_SCENE := preload("res://scenes/enemy.tscn")
const SHADOW_SCENE := preload("res://scenes/shadow.tscn")
const MASK_SCENE := preload("res://scenes/split_shade.tscn")
const LEONIE_SCENE := preload("res://scenes/leonie.tscn")

const GROUND_Y := 550.0    # centre vertical des plateformes
const SPAWN_Y := 477.0     # hauteur d'apparition des personnages
const LEVEL_END := 7300.0
const GOAL_X := 6950.0
const LEVEL_ID := "level_8"

const VOID := Color(0.1, 0.08, 0.14)
const VOID_DARK := Color(0.05, 0.04, 0.08)
const VIOLET := Color(0.55, 0.3, 0.85)

## Thème du peintre de plateformes : pierre de vide, croûte améthyste au
## sommet, veines de nuit violette qui luisent dans la roche.
const PLATFORM_THEME := {
	"top": Color(0.24, 0.16, 0.3),
	"top_light": Color(0.6, 0.35, 0.85),
	"body_a": VOID,
	"body_b": Color(0.08, 0.07, 0.12),
	"dark": VOID_DARK,
	"speck": VIOLET,
}

## Plateformes : x = centre, y = demi-largeur. Trous de 140 à 180 px (portée
## de saut max ≈ 190 px) ; deux brèches larges sont franchies par des dalles
## de vide solidifié servant de pont.
const PLATFORMS := [
	Vector2(230, 230), Vector2(850, 250), Vector2(1470, 230),
	Vector2(2080, 200), Vector2(2680, 240), Vector2(3300, 230),
	Vector2(3920, 210), Vector2(4540, 200), Vector2(5160, 250),
	Vector2(5780, 200), Vector2(6420, 240), Vector2(7040, 280),
]
const CHECKPOINT_XS := [1600.0, 3300.0, 5780.0]
## La plateforme 2440-2920 est le refuge : aucun ennemi ni piège n'y est
## placé (la lueur de Léonie y veille, même affaiblie).
const PATROL_XS := [1500.0, 4600.0]
const SHADOW_XS := [850.0, 3300.0, 5780.0]
## Deux Ombres d'élite ici — le plus profond du périple : deux orbes dorées.
const ELITE_XS := [3920.0, 6420.0]
## Masques d'Oni : au-dessus de plateformes dégagées (jamais d'un trou).
const MASK_XS := [2080.0, 4540.0, 5160.0]
const TRAP_XS := [700.0, 1350.0, 2000.0, 3160.0, 4430.0, 5670.0, 6850.0]
## Monolithes de vide dressés qui bordent le puits (décor, sans collision).
const MONOLITH_XS := [500.0, 2500.0, 3920.0, 5160.0, 6600.0]
## Ponts de vide solidifié PRATICABLES au-dessus des deux brèches larges :
## x = centre du trou, y = demi-largeur du tablier.
const BRIDGES := [Vector2(1775, 100), Vector2(6100, 110)]
## La dernière orbe (6820) reste EN DEÇÀ de la porte (GOAL_X=6950) : jamais
## d'orbe piégée derrière le seuil du Cœur (la Platine exige de tout ramasser).
const ORBS := [
	Vector2(320, 420), Vector2(540, 385), Vector2(850, 420),
	Vector2(1150, 385), Vector2(1470, 420), Vector2(1780, 385),
	Vector2(2080, 420), Vector2(2380, 385), Vector2(2680, 420),
	Vector2(3000, 385), Vector2(3300, 420), Vector2(3610, 385),
	Vector2(3920, 420), Vector2(4230, 385), Vector2(4540, 420),
	Vector2(4850, 385), Vector2(5160, 420), Vector2(5470, 385),
	Vector2(5780, 420), Vector2(6100, 385), Vector2(6420, 420),
	Vector2(6730, 385), Vector2(6820, 420),
]

const LEONIE_LINES := [
	{ "name": "Léonie", "text": "Ma lumière... elle faiblit, Eneko. L'Ombre est si dense ici qu'elle m'étouffe presque. Mais je reste. Je reste avec toi." },
	{ "name": "Léonie", "text": "Regarde, tout au fond : ce battement. C'est le Cœur de l'Ombre. Ce n'est pas un simple Gardien qui t'attend — c'est la source elle-même." },
	{ "name": "Léonie", "text": "Ne fixe pas l'abîme trop longtemps, il te reprendrait. Tranche les Masques, garde ta lame haute, et avance sans faiblir." },
	{ "name": "Eneko", "text": "Nous sommes allés trop loin pour reculer, Léonie. Je marche jusqu'au Cœur. Et je l'éteindrai." },
]

var sfx_win: AudioStreamPlayer
var void_motes: CPUParticles2D
var rising_wisps: CPUParticles2D
## Cristaux/veines qui palpitent au rythme du Cœur (voir _process).
var _pulses: Array = []
## Le Cœur de l'Ombre, tout au fond : masse sombre qui bat lentement.
var _heart: Node2D
var _heart_glow: Sprite2D
## Tentacules de nuit qui ondulent au fond du puits (voir _process).
var _tendrils: Array = []
var _t := 0.0

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var next_button: Button = $WinLabel/NextButton
@onready var dialogue: CanvasLayer = $Dialogue

func _ready() -> void:
	_build_decor()
	# Voile d'Ombre au premier plan, plus dense qu'ailleurs.
	Atmosphere.add_foreground(self, Color(0.09, 0.05, 0.14, 0.4))
	_build_platforms()
	_build_monoliths()
	_build_bridges()
	_build_hazards()
	_build_checkpoints()
	_build_traps()
	_build_goal()
	_build_kill_zone()
	_spawn_entities()
	_setup_audio()
	_setup_ambient()
	# Sur la pierre de vide, Eneko soulève une poussière d'améthyste.
	player.set_land_dust_color(Color(0.66, 0.42, 0.9, 0.8))
	win_label.visible = false
	Music.play_level(LEVEL_ID)
	SaveManager.set_last_level(LEVEL_ID)
	# Relique cachée, en hauteur (Double Saut).
	var relic := Relic.new()
	relic.level_id = LEVEL_ID
	relic.position = Vector2(4540, 300)
	add_child(relic)
	Challenge.start_level(LEVEL_ID, ORBS.size() + 3 * ELITE_XS.size())
	dialogue.finished.connect(_on_dialogue_finished)
	menu_button.pressed.connect(_on_menu_pressed)
	# Dernier niveau disponible : pas de niveau suivant pour l'instant.
	var next_scene: String = SaveManager.LEVEL_SCENES.get("level_9", "")
	next_button.visible = next_scene != ""
	if next_scene != "":
		next_button.pressed.connect(func(): Transition.goto(next_scene))
	# Survol d'introduction : du Cœur de l'Ombre jusqu'à Eneko.
	player.intro_pan(Vector2(GOAL_X, 330.0))

func _process(delta: float) -> void:
	_t += delta
	# Le Cœur bat : une pulsation lente qui gouverne cristaux et lueurs.
	var beat := 0.5 + 0.5 * sin(_t * 1.5)
	for pv in _pulses:
		var node: Polygon2D = pv["node"]
		var ph: float = float(pv["phase"])
		node.modulate.a = 0.3 + 0.5 * (0.5 + 0.5 * sin(_t * 1.5 + ph))
	if _heart != null:
		var s := 1.0 + 0.06 * beat
		_heart.scale = Vector2(s, s)
	if _heart_glow != null:
		_heart_glow.modulate.a = 0.22 + 0.16 * beat
		var hs := 9.0 + 1.4 * beat
		_heart_glow.scale = Vector2(hs, hs)
	for td in _tendrils:
		var tn: Polygon2D = td["node"]
		tn.rotation = 0.16 * sin(_t * 0.7 + float(td["phase"]))

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	if void_motes != null:
		void_motes.position = Vector2(player.position.x, player.position.y - 300.0)
	if rising_wisps != null:
		rising_wisps.position = Vector2(player.position.x, player.position.y + 30.0)

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

## Ciel de vide (posé par le .tscn), lueur violette diffuse, Cœur de l'Ombre
## qui bat au fond, cristaux corrompus flottants, tentacules de nuit, et
## poussière de vide + volutes montantes autour d'Eneko.
func _build_decor() -> void:
	var bg: ParallaxBackground = $ParallaxBackground
	var mist_tex: Texture2D = load("res://assets/mist.svg")

	# Lueur violette diffuse qui sourd du fond de l'abîme.
	var sky := ParallaxLayer.new()
	sky.motion_scale = Vector2(0.05, 0.05)
	bg.add_child(sky)
	var aura := Sprite2D.new()
	aura.texture = mist_tex
	aura.modulate = Color(0.42, 0.2, 0.6, 0.4)
	aura.scale = Vector2(16.0, 8.0)
	aura.position = Vector2(480.0, 520.0)
	sky.add_child(aura)
	var rays := GodRays.new()
	rays.color = Color(0.6, 0.35, 0.9, 0.04)
	rays.length = 1200.0
	rays.half_spread = 1.0
	rays.position = Vector2(480.0, 40.0)
	sky.add_child(rays)
	TextureLab.add_clouds(sky, 5, 40.0, 190.0, LEVEL_END, Color(0.2, 0.12, 0.28, 0.16))

	# Cœur de l'Ombre : grande masse sombre nichée à droite, tout au fond,
	# qui bat lentement derrière un halo violet.
	var deep := ParallaxLayer.new()
	deep.motion_scale = Vector2(0.12, 0.4)
	bg.add_child(deep)
	_heart_glow = Sprite2D.new()
	_heart_glow.texture = mist_tex
	_heart_glow.modulate = Color(0.6, 0.2, 0.7, 0.28)
	_heart_glow.scale = Vector2(9.0, 9.0)
	_heart_glow.position = Vector2(GOAL_X, 210.0)
	deep.add_child(_heart_glow)
	_heart = Node2D.new()
	_heart.position = Vector2(GOAL_X, 210.0)
	deep.add_child(_heart)
	var heart_pts := PackedVector2Array()
	var hi := 0
	while hi < 22:
		var a := hi * TAU / 22.0
		var rr := 120.0 + 22.0 * sin(a * 3.0)
		heart_pts.append(Vector2(cos(a) * rr, sin(a) * rr * 0.86))
		hi += 1
	_poly(_heart, heart_pts, Color(0.14, 0.07, 0.2, 0.96))
	# Veines lumineuses qui courent sur le Cœur.
	for vi in 6:
		var va := vi * TAU / 6.0
		var vein := _poly(_heart, PackedVector2Array([
			Vector2(0, 0), Vector2(cos(va) * 60 - 6, sin(va) * 50),
			Vector2(cos(va) * 118, sin(va) * 100), Vector2(cos(va) * 60 + 6, sin(va) * 50),
		]), Color(0.7, 0.3, 0.85, 0.0))
		_pulses.append({"node": vein, "phase": float(vi) * 0.5})

	# Monolithes de vide lointains, silhouettes dressées.
	var far := ParallaxLayer.new()
	far.motion_scale = Vector2(0.18, 0.45)
	bg.add_child(far)
	var mx := -150.0
	var mi := 0
	while mx < LEVEL_END + 700.0:
		if absf(mx - GOAL_X) > 500.0:
			var mh := 220.0 + float(mi * 71 % 160)
			var pts := PackedVector2Array([
				Vector2(-40, 0), Vector2(-30, -mh), Vector2(20, -mh + 30), Vector2(34, 0),
			])
			_poly(far, pts, Color(0.09, 0.07, 0.13, 0.9), Vector2(mx, 560))
			TextureLab.grain_poly(far, pts, 0.1, Vector2(mx, 0), Vector2(mx, 560))
		mx += 320.0 + float(mi * 53 % 150)
		mi += 1

	# Cristaux corrompus flottants, qui luisent de violet et palpitent.
	var crystals := ParallaxLayer.new()
	crystals.motion_scale = Vector2(0.35, 0.7)
	bg.add_child(crystals)
	var cx := 260.0
	var ci := 0
	while cx < LEVEL_END - 100.0:
		var cy := 150.0 + float(ci * 61 % 210)
		var ch := 26.0 + float(ci * 37 % 26)
		var shard := _poly(crystals, PackedVector2Array([
			Vector2(0, -ch), Vector2(9, -ch * 0.25), Vector2(4, ch), Vector2(-4, ch), Vector2(-9, -ch * 0.25),
		]), Color(0.5, 0.28, 0.8, 0.5), Vector2(cx, cy))
		_pulses.append({"node": shard, "phase": float(ci) * 0.7})
		cx += 300.0 + float(ci * 47 % 160)
		ci += 1

	# Tentacules de nuit qui s'élèvent du fond et ondulent lentement.
	var below := ParallaxLayer.new()
	below.motion_scale = Vector2(0.5, 0.9)
	bg.add_child(below)
	var tx := 340.0
	var ti := 0
	while tx < LEVEL_END - 150.0:
		var th := 120.0 + float(ti * 59 % 90)
		var tent := _poly(below, PackedVector2Array([
			Vector2(-10, 0), Vector2(-4, -th * 0.6), Vector2(-8, -th),
			Vector2(0, -th - 10), Vector2(6, -th), Vector2(3, -th * 0.6), Vector2(10, 0),
		]), Color(0.08, 0.06, 0.12, 0.85), Vector2(tx, 600))
		_tendrils.append({"node": tent, "phase": float(ti) * 1.1})
		tx += 460.0 + float(ti * 67 % 200)
		ti += 1

	# Poussière de vide qui dérive doucement autour d'Eneko.
	void_motes = CPUParticles2D.new()
	void_motes.texture = load("res://assets/leaf.svg")
	void_motes.amount = 28
	void_motes.lifetime = 6.5
	void_motes.preprocess = 6.5
	void_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	void_motes.emission_rect_extents = Vector2(560, 200)
	void_motes.direction = Vector2(0, 1)
	void_motes.spread = 180.0
	void_motes.gravity = Vector2(4, 8)
	void_motes.initial_velocity_min = 6.0
	void_motes.initial_velocity_max = 18.0
	void_motes.scale_amount_min = 0.3
	void_motes.scale_amount_max = 0.7
	void_motes.color = Color(0.5, 0.32, 0.72, 0.55)
	add_child(void_motes)

	# Volutes d'Ombre qui remontent en tourbillonnant sous Eneko.
	rising_wisps = CPUParticles2D.new()
	rising_wisps.texture = mist_tex
	rising_wisps.amount = 14
	rising_wisps.lifetime = 3.4
	rising_wisps.preprocess = 3.4
	rising_wisps.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rising_wisps.emission_rect_extents = Vector2(520, 20)
	rising_wisps.direction = Vector2(0, -1)
	rising_wisps.spread = 26.0
	rising_wisps.gravity = Vector2(0, -30)
	rising_wisps.initial_velocity_min = 14.0
	rising_wisps.initial_velocity_max = 34.0
	rising_wisps.scale_amount_min = 1.4
	rising_wisps.scale_amount_max = 2.8
	rising_wisps.color = Color(0.4, 0.22, 0.6, 0.3)
	add_child(rising_wisps)

## Monolithes de vide dressés qui bordent le puits : blocs noirs luisant
## d'une arête violette.
func _build_monoliths() -> void:
	for mx in MONOLITH_XS:
		var mono := Node2D.new()
		mono.position = Vector2(mx, GROUND_Y - 50.0)
		_poly(mono, PackedVector2Array([
			Vector2(-18, 0), Vector2(-14, -100), Vector2(10, -116), Vector2(20, -90), Vector2(22, 0),
		]), Color(0.08, 0.07, 0.11))
		_poly(mono, PackedVector2Array([
			Vector2(-8, 0), Vector2(-4, -70), Vector2(6, -58), Vector2(12, 0),
		]), Color(0.12, 0.1, 0.16))
		# Arête améthyste qui luit et palpite.
		var edge := _poly(mono, PackedVector2Array([
			Vector2(-2, -8), Vector2(2, -8), Vector2(8, -96), Vector2(2, -104), Vector2(-4, -60),
		]), Color(0.66, 0.34, 0.9, 0.0), Vector2(0, 0))
		_pulses.append({"node": edge, "phase": float(int(mx) % 628) * 0.012})
		add_child(mono)

## Plateformes de pierre de vide : strate sombre, croûte améthyste au sommet,
## veines de nuit et éclats de cristal.
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

		# Veines de nuit violette qui luisent dans la roche.
		var vein_count: int = maxi(1, int(p.y / 120.0))
		for v in vein_count:
			var vx2: float = -p.y + 70.0 + v * ((p.y * 2.0 - 140.0) / maxf(1.0, float(vein_count)))
			var e := _poly(body, PackedVector2Array([
				Vector2(vx2 - 2, 28), Vector2(vx2 + 3, 28),
				Vector2(vx2 + 6, 94), Vector2(vx2 - 1, 104), Vector2(vx2 - 5, 62),
			]), Color(0.62, 0.32, 0.88, 0.0))
			_pulses.append({"node": e, "phase": float((v * 61 + pi * 47) % 628) * 0.01})

		# Éclats de cristal sombre sur la croûte.
		var shard_count: int = maxi(1, int(p.y / 110.0))
		for r in shard_count:
			var rx: float = -p.y + 50.0 + r * ((p.y * 2.0 - 100.0) / maxf(1.0, float(shard_count)))
			_poly(body, PackedVector2Array([
				Vector2(rx - 8, -34), Vector2(rx - 1, -54), Vector2(rx + 9, -36), Vector2(rx, -30),
			]), Color(0.16, 0.1, 0.22))

		add_child(body)

## Ponts de vide solidifié PRATICABLES : tablier avec collision au niveau du
## sol, tendu au-dessus des brèches larges.
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
		var px := -half
		var pi := 0
		while px < half:
			var pw := minf(24.0, half - px)
			var c := Color(0.13, 0.1, 0.18) if pi % 2 == 0 else Color(0.09, 0.07, 0.13)
			_poly(body, PackedVector2Array([
				Vector2(px, -50), Vector2(px + pw, -50),
				Vector2(px + pw, -38), Vector2(px, -38),
			]), c)
			if pi % 2 == 1:
				_poly(body, PackedVector2Array([
					Vector2(px - 1, -49), Vector2(px + 1, -49), Vector2(px + 1, -39), Vector2(px - 1, -39),
				]), Color(0.6, 0.3, 0.85, 0.5))
			px += 26.0
			pi += 1
		for side in [-1.0, 1.0]:
			_poly(body, PackedVector2Array([
				Vector2(side * half - 5, -50), Vector2(side * half + 5, -50),
				Vector2(side * half + 3, 34), Vector2(side * half - 3, 34),
			]), Color(0.1, 0.08, 0.14))
		add_child(body)

## Dangers du puits : un fléau d'Ombre qui balaie (pendule violet) et une
## presse spectrale qui écrase (violette), bien séparés et À L'ÉCART du
## refuge (2440-2920) ; aucun piège dans l'arc du pendule.
func _build_hazards() -> void:
	var pd := SpectralPendulum.new()
	pd.position = Vector2(1000.0, GROUND_Y - 50.0)
	pd.arm_len = 150.0
	pd.phase = 0.8
	pd.tint = Color(0.66, 0.34, 0.95)
	add_child(pd)
	var crusher := SpectralCrusher.new()
	crusher.position = Vector2(5250.0, GROUND_Y - 50.0)
	crusher.phase = 0.5
	crusher.tint = Color(0.62, 0.3, 0.9)
	add_child(crusher)

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
		]), Color(0.2, 0.16, 0.26))
		var flag := _poly(cp, PackedVector2Array([
			Vector2(3, -60), Vector2(40, -50), Vector2(3, -38),
		]), Color(0.7, 0.4, 0.95))
		add_child(cp)
		cp.body_entered.connect(_on_checkpoint_body_entered.bind(cp, flag))

## Pièges : lames de cristal noir hérissant le sol, ourlées de violet.
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
		]), Color(0.1, 0.08, 0.14))
		for k in 4:
			var ox := -24.0 + k * 16.0
			_poly(trap, PackedVector2Array([
				Vector2(ox - 7, 6), Vector2(ox + 7, 6), Vector2(ox, -22),
			]), Color(0.08, 0.06, 0.12))
			_poly(trap, PackedVector2Array([
				Vector2(ox - 3, 2), Vector2(ox + 3, 2), Vector2(ox, -15),
			]), Color(0.66, 0.34, 0.92, 0.85))
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
	glow.modulate = Color(0.6, 0.2, 0.75, 0.6)
	glow.scale = Vector2(5.0, 5.0)
	goal.add_child(glow)
	# Seuil du Cœur : une faille verticale de nuit qui bat, encadrée de
	# cristal noir — l'entrée du Cœur de l'Ombre (à affronter plus tard).
	_poly(goal, PackedVector2Array([Vector2(-40, -60), Vector2(40, -60), Vector2(40, 66), Vector2(-40, 66)]), Color(0.4, 0.14, 0.5, 0.25))
	_poly(goal, PackedVector2Array([Vector2(-30, -58), Vector2(-20, -58), Vector2(-20, 70), Vector2(-30, 70)]), Color(0.1, 0.08, 0.14))
	_poly(goal, PackedVector2Array([Vector2(20, -58), Vector2(30, -58), Vector2(30, 70), Vector2(20, 70)]), Color(0.1, 0.08, 0.14))
	_poly(goal, PackedVector2Array([Vector2(-44, -70), Vector2(44, -70), Vector2(38, -56), Vector2(-38, -56)]), Color(0.14, 0.1, 0.18))
	var rift := _poly(goal, PackedVector2Array([Vector2(-7, -54), Vector2(7, -54), Vector2(4, 66), Vector2(-4, 66)]), Color(0.75, 0.35, 0.95, 0.5))
	_pulses.append({"node": rift, "phase": 0.0})
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

## Grondement d'abîme + répliques d'ambiance (non bloquantes).
func _setup_ambient() -> void:
	var amb := AmbientDialogue.new()
	add_child(amb)
	amb.add_line(self, 850.0, "Eneko", "Le froid de l'Ombre me traverse. Ici, la lumière n'est plus qu'un souvenir.")
	amb.add_line(self, 3900.0, "Eneko", "Deux Ombres d'élite... la source défend farouchement son puits.")
	amb.add_line(self, 6300.0, "Eneko", "Le Cœur bat juste devant moi. Un pas de plus, et je toucherai la source de tout ce mal.")

func _setup_audio() -> void:
	var rumble := AudioStreamPlayer.new()
	rumble.stream = load("res://assets/sfx/wind.wav")
	rumble.volume_db = -12.0
	rumble.pitch_scale = 0.6
	add_child(rumble)
	rumble.finished.connect(rumble.play)
	rumble.play()
	sfx_win = AudioStreamPlayer.new()
	sfx_win.stream = load("res://assets/sfx/win.wav")
	sfx_win.volume_db = -4.0
	add_child(sfx_win)

# --- Déroulement ----------------------------------------------------------

func _on_checkpoint_body_entered(body: Node2D, cp: Area2D, flag: Polygon2D) -> void:
	if body == player:
		if not cp.has_meta("lit"):
			cp.set_meta("lit", true)
			Atmosphere.spark_burst(self, cp.global_position, Color(0.7, 0.45, 1.0))
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
