extends Node2D
## Chapitre II — Niveau 7 : « La Gorge d'Obsidienne ».
## Passé le torii embrasé des Rivages de Cendre, Eneko s'enfonce dans une
## faille de roche noire vitrifiée qui plonge vers le cœur de l'Ombre. Des
## rivières de lave rougeoient tout au fond, les parois d'obsidienne
## renvoient leur lueur, et une pluie de braises tombe sans fin. Les Masques
## d'Oni y sont légion : on approche de la source.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const PATROL_SCENE := preload("res://scenes/enemy.tscn")
const SHADOW_SCENE := preload("res://scenes/shadow.tscn")
const MASK_SCENE := preload("res://scenes/split_shade.tscn")
const LEONIE_SCENE := preload("res://scenes/leonie.tscn")

const GROUND_Y := 550.0    # centre vertical des plateformes
const SPAWN_Y := 477.0     # hauteur d'apparition des personnages
const LEVEL_END := 7300.0
const GOAL_X := 6950.0
const LEVEL_ID := "level_7"

const OBS := Color(0.14, 0.12, 0.16)
const OBS_DARK := Color(0.08, 0.07, 0.1)
const LAVA := Color(1.0, 0.5, 0.16)

## Thème du peintre de plateformes : obsidienne noire vitrifiée, croûte
## calcinée au sommet, veines de lave qui rougeoient dans la roche.
const PLATFORM_THEME := {
	"top": Color(0.3, 0.16, 0.16),
	"top_light": Color(0.9, 0.4, 0.2),
	"body_a": OBS,
	"body_b": Color(0.11, 0.1, 0.13),
	"dark": OBS_DARK,
	"speck": LAVA,
}

## Plateformes : x = centre, y = demi-largeur. Trous de 140 à 180 px (portée
## de saut max ≈ 190 px) ; deux brèches larges sont franchies par des arches
## d'obsidienne effritée servant de pont.
const PLATFORMS := [
	Vector2(230, 230), Vector2(850, 250), Vector2(1470, 230),
	Vector2(2080, 200), Vector2(2680, 240), Vector2(3300, 230),
	Vector2(3920, 210), Vector2(4540, 200), Vector2(5160, 250),
	Vector2(5780, 200), Vector2(6420, 240), Vector2(7040, 280),
]
const CHECKPOINT_XS := [1600.0, 3300.0, 5780.0]
## La plateforme 2440-2920 est le refuge : aucun ennemi ni piège n'y est
## placé (la lueur de Léonie y veille).
const PATROL_XS := [1380.0, 3900.0, 6300.0]
const SHADOW_XS := [1470.0, 3300.0, 5780.0]
## Ombre d'élite : rare, deux coups à placer, orbe dorée (3 orbes) à la clé.
const ELITE_XS := [5160.0]
## Masques d'Oni : au-dessus de plateformes dégagées (jamais d'un trou). Plus
## nombreux ici — on est proche de la source.
const MASK_XS := [2080.0, 4540.0, 6420.0]
const TRAP_XS := [700.0, 2000.0, 3160.0, 4430.0, 5670.0]
## Arêtes d'obsidienne dressées qui bordent la faille (décor, sans collision).
const SPUR_XS := [500.0, 2500.0, 3920.0, 5160.0, 6600.0]
## Ponts d'obsidienne PRATICABLES au-dessus des deux plus grandes brèches :
## x = centre du trou, y = demi-largeur du tablier.
const BRIDGES := [Vector2(1775, 100), Vector2(6100, 110)]
## La dernière orbe (6820) reste EN DEÇÀ de la porte (GOAL_X=6950) : jamais
## d'orbe piégée derrière le torii de sortie (la Platine exige de tout
## ramasser).
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
	{ "name": "Léonie", "text": "Sens-tu cette chaleur, Eneko ? La roche elle-même a fondu. Nous descendons vers le puits d'où l'Ombre s'écoule." },
	{ "name": "Léonie", "text": "Le Gardien n'était qu'une digue. Ici, plus bas, quelque chose retient toute cette nuit prisonnière — et lutte pour se libérer." },
	{ "name": "Léonie", "text": "Les Masques se pressent : ils protègent la source. Ne t'arrête pas, ne les laisse pas t'entourer sur les ponts." },
	{ "name": "Eneko", "text": "Je descendrai jusqu'au fond de cette faille, Léonie. Et je trancherai l'Ombre à sa racine." },
]

var sfx_win: AudioStreamPlayer
var ember_rain: CPUParticles2D
var spark_rise: CPUParticles2D
## Braises/veines qui palpitent au rythme de la lave (voir _process).
var _embers: Array = []
## Nappe de lave tout au fond de la faille : elle ondule et pulse.
var _lava: Polygon2D
var _lava_glow: Sprite2D
var _t := 0.0

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var next_button: Button = $WinLabel/NextButton
@onready var dialogue: CanvasLayer = $Dialogue

func _ready() -> void:
	_build_decor()
	# Voile de chaleur sombre au premier plan.
	Atmosphere.add_foreground(self, Color(0.16, 0.06, 0.06, 0.34))
	_build_platforms()
	_build_spurs()
	_build_bridges()
	_build_hazards()
	_build_checkpoints()
	_build_traps()
	_build_goal()
	_build_kill_zone()
	_spawn_entities()
	_setup_audio()
	_setup_ambient()
	# Sur l'obsidienne brûlante, Eneko soulève une poussière d'étincelles.
	player.set_land_dust_color(Color(1.0, 0.6, 0.3, 0.8))
	win_label.visible = false
	Music.play_world(2)
	SaveManager.set_last_level(LEVEL_ID)
	Challenge.start_level(LEVEL_ID, ORBS.size() + 3 * ELITE_XS.size())
	dialogue.finished.connect(_on_dialogue_finished)
	menu_button.pressed.connect(_on_menu_pressed)
	# Dernier niveau disponible : pas de niveau suivant pour l'instant.
	var next_scene: String = SaveManager.LEVEL_SCENES.get("level_8", "")
	next_button.visible = next_scene != ""
	if next_scene != "":
		next_button.pressed.connect(func(): get_tree().change_scene_to_file(next_scene))
	# Survol d'introduction : de la porte du fond jusqu'à Eneko.
	player.intro_pan(Vector2(GOAL_X, 340.0))

func _process(delta: float) -> void:
	_t += delta
	for eb in _embers:
		var node: Polygon2D = eb["node"]
		var ph: float = float(eb["phase"])
		node.modulate.a = 0.35 + 0.5 * (0.5 + 0.5 * sin(_t * 1.8 + ph))
	# La lave tout au fond pulse et ondule lentement.
	if _lava != null:
		_lava.color.a = 0.55 + 0.14 * sin(_t * 0.8)
	if _lava_glow != null:
		_lava_glow.modulate.a = 0.2 + 0.09 * (0.5 + 0.5 * sin(_t * 0.6))
		_lava_glow.scale.x = 66.0 + 4.0 * sin(_t * 0.5)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	if ember_rain != null:
		ember_rain.position = Vector2(player.position.x, player.position.y - 340.0)
	if spark_rise != null:
		spark_rise.position = Vector2(player.position.x, player.position.y + 26.0)

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

## Ciel de faille (posé par le .tscn), lueur de lave qui monte du fond,
## parois d'obsidienne veinées de feu, rivière de lave animée, éperons de
## roche noire, puis pluie de braises et étincelles montantes.
func _build_decor() -> void:
	var bg: ParallaxBackground = $ParallaxBackground
	var mist_tex: Texture2D = load("res://assets/mist.svg")

	# Lueur diffuse rouge qui sourd du fond de la faille.
	var sky := ParallaxLayer.new()
	sky.motion_scale = Vector2(0.05, 0.05)
	bg.add_child(sky)
	var underglow := Sprite2D.new()
	underglow.texture = mist_tex
	underglow.modulate = Color(0.9, 0.3, 0.12, 0.45)
	underglow.scale = Vector2(16.0, 7.0)
	underglow.position = Vector2(480.0, 560.0)
	sky.add_child(underglow)
	# Voiles de chaleur sombres, rougeâtres, qui dérivent.
	TextureLab.add_clouds(sky, 5, 40.0, 190.0, LEVEL_END, Color(0.35, 0.14, 0.14, 0.18))

	# Parois d'obsidienne : hautes lames verticales des deux côtés du champ,
	# veinées de fissures incandescentes.
	var walls := ParallaxLayer.new()
	walls.motion_scale = Vector2(0.12, 0.4)
	bg.add_child(walls)
	var wx := -100.0
	var wi := 0
	while wx < LEVEL_END + 700.0:
		var wh := 240.0 + float(wi * 71 % 150)
		var shard := PackedVector2Array([
			Vector2(-70, 0), Vector2(-30, -wh + 40), Vector2(6, -wh),
			Vector2(40, -wh + 60), Vector2(78, 0),
		])
		_poly(walls, shard, Color(0.1, 0.09, 0.12, 0.9), Vector2(wx, 560))
		TextureLab.grain_poly(walls, shard, 0.1, Vector2(wx, 0), Vector2(wx, 560))
		# Fissure incandescente sur la lame.
		var crack := _poly(walls, PackedVector2Array([
			Vector2(-2, -30), Vector2(4, -30), Vector2(10, -wh + 70),
			Vector2(2, -wh + 60), Vector2(-4, -wh * 0.5),
		]), Color(1.0, 0.42, 0.16, 0.0), Vector2(wx + 6.0, 560))
		_embers.append({"node": crack, "phase": float(int(wx) % 628) * 0.01})
		wx += 300.0 + float(wi * 53 % 140)
		wi += 1

	# Rivière de lave tout au fond de la faille, qui pulse et rougeoie.
	var deep := ParallaxLayer.new()
	deep.motion_scale = Vector2(0.25, 0.6)
	bg.add_child(deep)
	_lava_glow = Sprite2D.new()
	_lava_glow.texture = mist_tex
	_lava_glow.modulate = Color(1.0, 0.42, 0.14, 0.22)
	_lava_glow.scale = Vector2(66.0, 3.4)
	_lava_glow.position = Vector2(LEVEL_END * 0.5, 500.0)
	deep.add_child(_lava_glow)
	_lava = _poly(deep, PackedVector2Array([
		Vector2(-200, 506), Vector2(LEVEL_END + 400, 506),
		Vector2(LEVEL_END + 400, 640), Vector2(-200, 640),
	]), Color(0.85, 0.32, 0.1, 0.55))
	# Remous plus clairs à la surface de la lave.
	var lx := -100.0
	var li := 0
	while lx < LEVEL_END + 300.0:
		_poly(deep, PackedVector2Array([
			Vector2(-60, 0), Vector2(0, -7), Vector2(60, 0),
		]), Color(1.0, 0.62, 0.24, 0.4), Vector2(lx, 508.0 + float(li % 3) * 4.0))
		lx += 170.0
		li += 1

	# Stalagmites / colonnes d'obsidienne proches, en silhouette.
	var near := ParallaxLayer.new()
	near.motion_scale = Vector2(0.5, 0.9)
	bg.add_child(near)
	var nx := 300.0
	var ni := 0
	while nx < LEVEL_END - 150.0:
		var nh := 90.0 + float(ni * 47 % 80)
		_poly(near, PackedVector2Array([
			Vector2(-16, 0), Vector2(-6, -nh), Vector2(4, -nh + 14), Vector2(14, 0),
		]), Color(0.09, 0.08, 0.11, 0.92), Vector2(nx, 540))
		nx += 520.0 + float(ni * 61 % 190)
		ni += 1

	# Pluie de braises dense qui tombe autour d'Eneko.
	ember_rain = CPUParticles2D.new()
	ember_rain.amount = 40
	ember_rain.lifetime = 5.0
	ember_rain.preprocess = 5.0
	ember_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ember_rain.emission_rect_extents = Vector2(560, 10)
	ember_rain.direction = Vector2(0.25, 1.0)
	ember_rain.spread = 16.0
	ember_rain.gravity = Vector2(14, 30)
	ember_rain.initial_velocity_min = 18.0
	ember_rain.initial_velocity_max = 40.0
	ember_rain.scale_amount_min = 0.5
	ember_rain.scale_amount_max = 1.4
	ember_rain.color = Color(1.0, 0.5, 0.2, 0.85)
	add_child(ember_rain)

	# Étincelles qui remontent de la lave en tourbillonnant sous Eneko.
	spark_rise = CPUParticles2D.new()
	spark_rise.amount = 20
	spark_rise.lifetime = 2.8
	spark_rise.preprocess = 2.8
	spark_rise.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	spark_rise.emission_rect_extents = Vector2(520, 24)
	spark_rise.direction = Vector2(0, -1)
	spark_rise.spread = 30.0
	spark_rise.gravity = Vector2(8, -50)
	spark_rise.initial_velocity_min = 26.0
	spark_rise.initial_velocity_max = 60.0
	spark_rise.scale_amount_min = 0.7
	spark_rise.scale_amount_max = 1.6
	spark_rise.color = Color(1.0, 0.68, 0.3, 0.9)
	add_child(spark_rise)

## Éperons d'obsidienne dressés qui bordent la faille : lames noires
## luisantes, fendues d'une veine incandescente.
func _build_spurs() -> void:
	for sx in SPUR_XS:
		var spur := Node2D.new()
		spur.position = Vector2(sx, GROUND_Y - 50.0)
		var col := Color(0.1, 0.09, 0.12)
		_poly(spur, PackedVector2Array([
			Vector2(-22, 0), Vector2(-8, -74), Vector2(6, -96), Vector2(16, -60), Vector2(24, 0),
		]), col)
		_poly(spur, PackedVector2Array([
			Vector2(-10, 0), Vector2(-2, -50), Vector2(8, -34), Vector2(14, 0),
		]), Color(0.13, 0.11, 0.15))
		# Veine incandescente qui court dans la lame.
		var v := _poly(spur, PackedVector2Array([
			Vector2(-2, -6), Vector2(3, -6), Vector2(6, -70), Vector2(0, -84), Vector2(-4, -44),
		]), Color(1.0, 0.46, 0.18, 0.0), Vector2(0, 0))
		_embers.append({"node": v, "phase": float(int(sx) % 628) * 0.013})
		add_child(spur)

## Plateformes d'obsidienne : strate de roche noire vitrifiée, croûte
## calcinée au sommet, veines de lave et éclats tranchants.
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

		# Veines de lave qui rougeoient dans la roche.
		var vein_count: int = maxi(1, int(p.y / 120.0))
		for v in vein_count:
			var vx2: float = -p.y + 70.0 + v * ((p.y * 2.0 - 140.0) / maxf(1.0, float(vein_count)))
			var e := _poly(body, PackedVector2Array([
				Vector2(vx2 - 2, 26), Vector2(vx2 + 3, 26),
				Vector2(vx2 + 6, 92), Vector2(vx2 - 1, 104), Vector2(vx2 - 5, 60),
			]), Color(1.0, 0.45, 0.16, 0.0))
			_embers.append({"node": e, "phase": float((v * 61 + pi * 47) % 628) * 0.01})

		# Éclats d'obsidienne tranchants sur la croûte.
		var shard_count: int = maxi(1, int(p.y / 110.0))
		for r in shard_count:
			var rx: float = -p.y + 50.0 + r * ((p.y * 2.0 - 100.0) / maxf(1.0, float(shard_count)))
			_poly(body, PackedVector2Array([
				Vector2(rx - 8, -34), Vector2(rx - 1, -52), Vector2(rx + 9, -36), Vector2(rx, -30),
			]), Color(0.07, 0.06, 0.09))

		add_child(body)

## Ponts d'obsidienne PRATICABLES : tablier avec collision au niveau du sol,
## tendu au-dessus des brèches larges.
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
		# Dalles d'obsidienne jointes, teintes sombres alternées.
		var px := -half
		var pi := 0
		while px < half:
			var pw := minf(24.0, half - px)
			var c := Color(0.13, 0.11, 0.15) if pi % 2 == 0 else Color(0.09, 0.08, 0.11)
			_poly(body, PackedVector2Array([
				Vector2(px, -50), Vector2(px + pw, -50),
				Vector2(px + pw, -38), Vector2(px, -38),
			]), c)
			# Joint incandescent entre deux dalles.
			if pi % 2 == 1:
				_poly(body, PackedVector2Array([
					Vector2(px - 1, -49), Vector2(px + 1, -49), Vector2(px + 1, -39), Vector2(px - 1, -39),
				]), Color(1.0, 0.45, 0.18, 0.5))
			px += 26.0
			pi += 1
		# Piliers d'appui fichés vers le fond aux deux extrémités.
		for side in [-1.0, 1.0]:
			_poly(body, PackedVector2Array([
				Vector2(side * half - 5, -50), Vector2(side * half + 5, -50),
				Vector2(side * half + 3, 34), Vector2(side * half - 3, 34),
			]), Color(0.1, 0.09, 0.12))
		add_child(body)

## Dangers de la faille : deux geysers de lave (geyser reskinné) et un
## encensoir en fusion qui balaie (pendule rouge), bien séparés et À L'ÉCART
## du refuge (2440-2920).
func _build_hazards() -> void:
	# Geyser sur la plateforme 7, à l'écart de la patrouille (3900) et de tout
	# piège (aucun sur cette plateforme).
	var vent := SpiritGeyser.new()
	vent.position = Vector2(4050.0, GROUND_Y - 50.0)
	vent.phase = 0.3
	add_child(vent)
	# Encensoir en fusion sur la plateforme 2 : posé en x=1000 pour que son
	# arc de balayage (850-1150) ne recouvre JAMAIS le pieu en x=700 — pas de
	# pièges empilés qui poussent le joueur de l'un dans l'autre.
	var pd := SpectralPendulum.new()
	pd.position = Vector2(1000.0, GROUND_Y - 50.0)
	pd.arm_len = 150.0
	pd.phase = 0.9
	pd.tint = Color(1.0, 0.42, 0.2)
	add_child(pd)

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
		]), Color(0.2, 0.18, 0.22))
		var flag := _poly(cp, PackedVector2Array([
			Vector2(3, -60), Vector2(40, -50), Vector2(3, -38),
		]), Color(1.0, 0.55, 0.25))
		add_child(cp)
		cp.body_entered.connect(_on_checkpoint_body_entered.bind(cp, flag))

## Pièges : pointes d'obsidienne hérissant le sol, ourlées de lave.
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
		]), Color(0.1, 0.09, 0.11))
		for k in 4:
			var ox := -24.0 + k * 16.0
			_poly(trap, PackedVector2Array([
				Vector2(ox - 7, 6), Vector2(ox + 7, 6), Vector2(ox, -22),
			]), Color(0.08, 0.07, 0.09))
			_poly(trap, PackedVector2Array([
				Vector2(ox - 3, 2), Vector2(ox + 3, 2), Vector2(ox, -15),
			]), Color(1.0, 0.42, 0.16, 0.8))
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
	glow.modulate = Color(0.7, 0.2, 0.5, 0.55)
	glow.scale = Vector2(4.8, 4.8)
	goal.add_child(glow)
	# Porte d'obsidienne fendue, où bat une lueur d'Ombre pourpre : l'entrée
	# du puits, seuil du cœur de l'Ombre (à franchir au chapitre suivant).
	_poly(goal, PackedVector2Array([Vector2(-40, -60), Vector2(40, -60), Vector2(40, 66), Vector2(-40, 66)]), Color(0.5, 0.15, 0.4, 0.25))
	_poly(goal, PackedVector2Array([Vector2(-30, -58), Vector2(-20, -58), Vector2(-20, 70), Vector2(-30, 70)]), Color(0.1, 0.08, 0.12))
	_poly(goal, PackedVector2Array([Vector2(20, -58), Vector2(30, -58), Vector2(30, 70), Vector2(20, 70)]), Color(0.1, 0.08, 0.12))
	_poly(goal, PackedVector2Array([Vector2(-44, -70), Vector2(44, -70), Vector2(38, -56), Vector2(-38, -56)]), Color(0.14, 0.1, 0.14))
	_poly(goal, PackedVector2Array([Vector2(-6, -52), Vector2(6, -52), Vector2(4, 64), Vector2(-4, 64)]), Color(0.8, 0.25, 0.55, 0.4))
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

## Grondement sourd de la lave + répliques d'ambiance (non bloquantes).
func _setup_ambient() -> void:
	var amb := AmbientDialogue.new()
	add_child(amb)
	amb.add_line(self, 850.0, "Eneko", "La chaleur me brûle jusqu'aux os. Chaque pas me rapproche du puits.")
	amb.add_line(self, 3900.0, "Eneko", "Les Masques ne cessent d'affluer. La source est proche, c'est certain.")
	amb.add_line(self, 6300.0, "Eneko", "Cette porte... l'Ombre bat derrière, comme un cœur. C'est là que tout se joue.")

func _setup_audio() -> void:
	var rumble := AudioStreamPlayer.new()
	rumble.stream = load("res://assets/sfx/wind.wav")
	rumble.volume_db = -13.0
	rumble.pitch_scale = 0.68
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
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
