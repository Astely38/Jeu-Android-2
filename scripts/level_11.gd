extends Node2D
## Chapitre III — Niveau 11 : « Le Miroir des Âmes ».
## La source de l'Ombre tarie, un écho a répondu dans le noir. Eneko franchit
## un seuil de verre et débouche dans un royaume-miroir : un sol de verre noir
## qui reflète un ciel d'argent, des flaques-miroir où flottent des reflets
## pâles, et, tout au loin, une silhouette qui répète ses gestes — le Reflet.
## Ici, la bénédiction de Léonie (le Double Saut) ouvre le chemin vers le haut.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const PATROL_SCENE := preload("res://scenes/enemy.tscn")
const SHADOW_SCENE := preload("res://scenes/shadow.tscn")
const MASK_SCENE := preload("res://scenes/split_shade.tscn")
const LEONIE_SCENE := preload("res://scenes/leonie.tscn")

const GROUND_Y := 550.0
const SPAWN_Y := 477.0
const LEVEL_END := 7300.0
const GOAL_X := 6950.0
const LEVEL_ID := "level_11"

const GLASS := Color(0.1, 0.12, 0.17)
const GLASS_DARK := Color(0.05, 0.06, 0.1)
const SILVER := Color(0.72, 0.8, 0.88)
const CYAN := Color(0.5, 0.85, 0.95)

## Thème du peintre de plateformes : verre noir poli, arête d'argent au
## sommet, veines de cyan spectral.
const PLATFORM_THEME := {
	"top": SILVER,
	"top_light": Color(0.92, 0.96, 1.0),
	"body_a": GLASS,
	"body_b": Color(0.08, 0.1, 0.14),
	"dark": GLASS_DARK,
	"speck": CYAN,
	"cut": true,
}

const PLATFORMS := [
	Vector2(230, 230), Vector2(850, 250), Vector2(1470, 230),
	Vector2(2080, 200), Vector2(2680, 240), Vector2(3300, 230),
	Vector2(3920, 210), Vector2(4540, 200), Vector2(5160, 250),
	Vector2(5780, 200), Vector2(6420, 240), Vector2(7040, 280),
]
const CHECKPOINT_XS := [1600.0, 3300.0, 5780.0]
## La plateforme 2440-2920 est le refuge (la lueur de Léonie y veille).
const PATROL_XS := [900.0, 3850.0, 6300.0]
const SHADOW_XS := [1470.0, 3300.0, 5780.0]
const ELITE_XS := [5160.0]
const MASK_XS := [2080.0, 4540.0, 6420.0]
const TRAP_XS := [700.0, 2000.0, 3160.0, 4430.0, 5670.0, 6850.0]
## Stèles-miroir dressées qui bordent le royaume (décor, sans collision).
const STELE_XS := [500.0, 2500.0, 3920.0, 5160.0, 6600.0]
const BRIDGES := [Vector2(1775, 100), Vector2(6100, 110)]
## Orbes du sol (traînée classique) — la dernière reste en deçà de la porte.
const ORBS := [
	Vector2(320, 420), Vector2(540, 385), Vector2(850, 420),
	Vector2(1150, 385), Vector2(1470, 420), Vector2(1780, 385),
	Vector2(2080, 420), Vector2(2380, 385), Vector2(2680, 420),
	Vector2(3000, 385), Vector2(3300, 420), Vector2(3610, 385),
	Vector2(3920, 420), Vector2(4230, 385), Vector2(4540, 420),
	Vector2(4850, 385), Vector2(5160, 420), Vector2(5470, 385),
	Vector2(5780, 420), Vector2(6100, 385), Vector2(6420, 420),
	Vector2(6730, 385), Vector2(6800, 420),
]
## Orbes-REFLET en hauteur : atteignables uniquement au Double Saut, toujours
## au-dessus d'une plateforme. Elles récompensent la bénédiction de Léonie.
const HIGH_ORBS := [
	Vector2(850, 300), Vector2(3300, 300), Vector2(5780, 300),
]
## Ancrages du Fil Spirituel : anneaux de lumière vers lesquels s'élancer.
## Placés au-dessus des orbes-reflet (on les cueille en se hissant) et
## au-dessus des deux brèches (on les franchit d'un trait).
const ANCHOR_POS := [
	Vector2(850, 246), Vector2(1775, 300), Vector2(3300, 236),
	Vector2(5780, 246), Vector2(6100, 316),
]

const LEONIE_LINES := [
	{ "name": "Léonie", "text": "Nous avons tari la source, Eneko... et pourtant nous voici. Ce lieu est un miroir : il répète, il renvoie, il n'oublie rien." },
	{ "name": "Léonie", "text": "L'écho que nous avons entendu vient d'ici. Là-bas, cette silhouette qui bouge quand tu bouges... c'est un Reflet. Le tien, peut-être." },
	{ "name": "Léonie", "text": "Sers-toi du don que je t'ai laissé : d'un second souffle, bondis vers les hauteurs. Certaines lueurs ne s'atteignent qu'en t'élevant." },
	{ "name": "Eneko", "text": "Un reflet ne me fait pas peur, Léonie. J'irai voir ce qui, dans le noir, ose encore me répondre." },
]

var sfx_win: AudioStreamPlayer
var glass_motes: CPUParticles2D
## Reflets/veines qui scintillent (voir _process).
var _shimmers: Array = []
## Silhouette du Reflet, tout au loin, qui dérive (voir _process).
var _reflet: Node2D
var _t := 0.0

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var next_button: Button = $WinLabel/NextButton
@onready var dialogue: CanvasLayer = $Dialogue

func _ready() -> void:
	_build_decor()
	Atmosphere.add_foreground(self, Color(0.06, 0.08, 0.12, 0.3))
	_build_platforms()
	_build_steles()
	_build_bridges()
	_build_anchors()
	_build_hazards()
	_build_checkpoints()
	_build_traps()
	_build_goal()
	_build_kill_zone()
	_spawn_entities()
	_setup_audio()
	_setup_ambient()
	player.set_land_dust_color(Color(0.7, 0.85, 0.95, 0.7))
	win_label.visible = false
	Music.play_world(2)
	SaveManager.set_last_level(LEVEL_ID)
	# Relique cachée, en hauteur (Double Saut).
	var relic := Relic.new()
	relic.level_id = LEVEL_ID
	relic.position = Vector2(6420, 292)
	add_child(relic)
	# Les orbes-reflet en hauteur comptent aussi dans le total.
	Challenge.start_level(LEVEL_ID, ORBS.size() + HIGH_ORBS.size() + 3 * ELITE_XS.size())
	dialogue.finished.connect(_on_dialogue_finished)
	menu_button.pressed.connect(_on_menu_pressed)
	var next_scene: String = SaveManager.LEVEL_SCENES.get("level_12", "")
	next_button.visible = next_scene != ""
	if next_scene != "":
		next_button.pressed.connect(func(): Transition.goto(next_scene))
	player.intro_pan(Vector2(GOAL_X, 340.0))

func _process(delta: float) -> void:
	_t += delta
	for sh in _shimmers:
		var node: Polygon2D = sh["node"]
		node.modulate.a = 0.3 + 0.5 * (0.5 + 0.5 * sin(_t * 1.8 + float(sh["phase"])))
	if _reflet != null:
		_reflet.position.y = 300.0 + sin(_t * 0.6) * 12.0
		_reflet.modulate.a = 0.14 + 0.06 * (0.5 + 0.5 * sin(_t * 0.9))

func _physics_process(_delta: float) -> void:
	if glass_motes != null and is_instance_valid(player):
		glass_motes.position = Vector2(player.position.x, player.position.y - 300.0)

# --- Construction ---------------------------------------------------------

func _poly(parent: Node, points: PackedVector2Array, color: Color, pos := Vector2.ZERO) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.position = pos
	parent.add_child(p)
	return p

## Ciel d'argent (posé par le .tscn), lune pâle, mer de verre à l'horizon qui
## reflète, silhouette du Reflet au loin, stèles, et poussière de verre.
func _build_decor() -> void:
	var bg: ParallaxBackground = $ParallaxBackground
	var mist_tex: Texture2D = load("res://assets/mist.svg")

	var sky := ParallaxLayer.new()
	sky.motion_scale = Vector2(0.05, 0.05)
	bg.add_child(sky)
	# Lune pâle et son halo froid.
	var halo := Sprite2D.new()
	halo.texture = mist_tex
	halo.modulate = Color(0.7, 0.82, 0.95, 0.4)
	halo.scale = Vector2(9.0, 9.0)
	halo.position = Vector2(720.0, 120.0)
	sky.add_child(halo)
	var moon_pts := PackedVector2Array()
	for i in 22:
		var a := i * TAU / 22.0
		moon_pts.append(Vector2(cos(a) * 46.0, sin(a) * 46.0))
	_poly(sky, moon_pts, Color(0.88, 0.93, 1.0, 0.85), Vector2(720, 120))
	var rays := GodRays.new()
	rays.color = Color(0.7, 0.85, 1.0, 0.05)
	rays.length = 1300.0
	rays.half_spread = 0.9
	rays.position = Vector2(720.0, 120.0)
	sky.add_child(rays)
	TextureLab.add_clouds(sky, 5, 70.0, 210.0, LEVEL_END, Color(0.6, 0.7, 0.85, 0.14))

	# Le Reflet : silhouette d'Eneko, lointaine, qui dérive dans le miroir.
	var deep := ParallaxLayer.new()
	deep.motion_scale = Vector2(0.15, 0.4)
	bg.add_child(deep)
	_reflet = Node2D.new()
	_reflet.position = Vector2(GOAL_X - 200.0, 300.0)
	_reflet.modulate = Color(1, 1, 1, 0.16)
	deep.add_child(_reflet)
	# Corps stylisé (sabreur en silhouette de verre).
	_poly(_reflet, PackedVector2Array([
		Vector2(-10, 40), Vector2(10, 40), Vector2(8, -20), Vector2(0, -34), Vector2(-8, -20),
	]), Color(0.6, 0.75, 0.95))
	_poly(_reflet, PackedVector2Array([  # lame levée
		Vector2(8, -18), Vector2(12, -18), Vector2(30, -70), Vector2(26, -72),
	]), Color(0.8, 0.9, 1.0))

	# Mer de verre lointaine, réfléchissante.
	var sea := ParallaxLayer.new()
	sea.motion_scale = Vector2(0.25, 0.6)
	bg.add_child(sea)
	_poly(sea, PackedVector2Array([
		Vector2(-200, 470), Vector2(LEVEL_END + 400, 470),
		Vector2(LEVEL_END + 400, 640), Vector2(-200, 640),
	]), Color(0.12, 0.16, 0.22, 0.6))
	var gx := -100.0
	var gi := 0
	while gx < LEVEL_END + 300.0:
		var glint := _poly(sea, PackedVector2Array([
			Vector2(-40, 0), Vector2(40, 0), Vector2(30, 3), Vector2(-30, 3),
		]), Color(0.7, 0.85, 1.0, 0.0), Vector2(gx, 484.0 + float(gi % 4) * 6.0))
		_shimmers.append({"node": glint, "phase": float(gi) * 0.5})
		gx += 150.0
		gi += 1

	glass_motes = CPUParticles2D.new()
	glass_motes.texture = load("res://assets/leaf.svg")
	glass_motes.amount = 30
	glass_motes.lifetime = 7.0
	glass_motes.preprocess = 7.0
	glass_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	glass_motes.emission_rect_extents = Vector2(560, 200)
	glass_motes.direction = Vector2(0.1, 1.0)
	glass_motes.spread = 20.0
	glass_motes.gravity = Vector2(2, 12)
	glass_motes.initial_velocity_min = 8.0
	glass_motes.initial_velocity_max = 22.0
	glass_motes.angular_velocity_min = -60.0
	glass_motes.angular_velocity_max = 60.0
	glass_motes.scale_amount_min = 0.25
	glass_motes.scale_amount_max = 0.55
	glass_motes.color = Color(0.75, 0.88, 1.0, 0.7)
	add_child(glass_motes)

## Plateformes de verre noir + leur REFLET pâle inversé juste en dessous.
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
		# Veines de cyan spectral.
		var vein_count: int = maxi(1, int(p.y / 130.0))
		for v in vein_count:
			var vx2: float = -p.y + 70.0 + v * ((p.y * 2.0 - 140.0) / maxf(1.0, float(vein_count)))
			var e := _poly(body, PackedVector2Array([
				Vector2(vx2 - 2, 30), Vector2(vx2 + 3, 30),
				Vector2(vx2 + 5, 96), Vector2(vx2 - 1, 104), Vector2(vx2 - 4, 66),
			]), Color(0.5, 0.85, 0.95, 0.0))
			_shimmers.append({"node": e, "phase": float((v * 53 + pi * 71) % 628) * 0.01})
		add_child(body)
		# Reflet inversé, pâle, sous la plateforme (purement décoratif).
		var refl := _poly(self, PackedVector2Array([
			Vector2(-p.y, 50), Vector2(p.y, 50), Vector2(p.y * 0.7, 150), Vector2(-p.y * 0.7, 150),
		]), Color(0.5, 0.62, 0.78, 0.12), Vector2(p.x, GROUND_Y))
		refl.z_index = -1

## Stèles-miroir dressées : lames de verre poli qui renvoient une lueur.
## Ancrages du Fil Spirituel, suspendus dans le royaume-miroir.
func _build_anchors() -> void:
	for p in ANCHOR_POS:
		var a := SpiritAnchor.new()
		a.position = p
		add_child(a)

func _build_steles() -> void:
	for sx in STELE_XS:
		var st := Node2D.new()
		st.position = Vector2(sx, GROUND_Y - 50.0)
		_poly(st, PackedVector2Array([
			Vector2(-16, 0), Vector2(-12, -110), Vector2(0, -126), Vector2(12, -110), Vector2(16, 0),
		]), Color(0.1, 0.13, 0.18))
		_poly(st, PackedVector2Array([
			Vector2(-8, -6), Vector2(-5, -100), Vector2(0, -110), Vector2(3, -100), Vector2(6, -6),
		]), Color(0.4, 0.6, 0.75, 0.5))
		var glint := _poly(st, PackedVector2Array([
			Vector2(-2, -20), Vector2(2, -20), Vector2(4, -96), Vector2(-1, -104), Vector2(-4, -60),
		]), Color(0.8, 0.95, 1.0, 0.0))
		_shimmers.append({"node": glint, "phase": float(int(sx) % 628) * 0.012})
		add_child(st)

## Ponts de verre praticables au-dessus des brèches larges.
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
			var c := Color(0.14, 0.17, 0.23) if pi % 2 == 0 else Color(0.1, 0.12, 0.17)
			_poly(body, PackedVector2Array([
				Vector2(px, -50), Vector2(px + pw, -50),
				Vector2(px + pw, -38), Vector2(px, -38),
			]), c)
			if pi % 2 == 1:
				_poly(body, PackedVector2Array([
					Vector2(px - 1, -49), Vector2(px + 1, -49), Vector2(px + 1, -39), Vector2(px - 1, -39),
				]), Color(0.5, 0.85, 0.95, 0.5))
			px += 26.0
			pi += 1
		for side in [-1.0, 1.0]:
			_poly(body, PackedVector2Array([
				Vector2(side * half - 5, -50), Vector2(side * half + 5, -50),
				Vector2(side * half + 3, 30), Vector2(side * half - 3, 30),
			]), Color(0.12, 0.14, 0.2))
		add_child(body)

## Dangers du miroir : un dard spectral et une presse de verre, à l'écart du
## refuge (2440-2920) et bien séparés.
func _build_hazards() -> void:
	var dart := DartLauncher.new()
	dart.position = Vector2(1560.0, GROUND_Y - 50.0)
	dart.dir = -1.0
	dart.phase = 0.5
	dart.tint = Color(0.55, 0.85, 1.0)
	add_child(dart)
	var crush := SpectralCrusher.new()
	crush.position = Vector2(3950.0, GROUND_Y - 50.0)
	crush.phase = 0.4
	crush.tint = Color(0.6, 0.85, 1.0)
	add_child(crush)

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
		]), Color(0.2, 0.24, 0.3))
		var flag := _poly(cp, PackedVector2Array([
			Vector2(3, -60), Vector2(40, -50), Vector2(3, -38),
		]), Color(0.5, 0.85, 0.95))
		add_child(cp)
		cp.body_entered.connect(_on_checkpoint_body_entered.bind(cp, flag))

## Pièges : éclats de verre tranchants hérissant le sol.
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
		]), Color(0.12, 0.15, 0.2))
		for k in 4:
			var ox := -24.0 + k * 16.0
			_poly(trap, PackedVector2Array([
				Vector2(ox - 7, 6), Vector2(ox + 7, 6), Vector2(ox, -22),
			]), Color(0.2, 0.3, 0.4, 0.9))
			_poly(trap, PackedVector2Array([
				Vector2(ox - 3, 2), Vector2(ox + 3, 2), Vector2(ox, -16),
			]), Color(0.75, 0.92, 1.0, 0.9))
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
	glow.modulate = Color(0.6, 0.85, 1.0, 0.5)
	glow.scale = Vector2(4.5, 4.5)
	goal.add_child(glow)
	# Porte-miroir : un cadre de verre où bat une lueur d'argent.
	_poly(goal, PackedVector2Array([Vector2(-40, -60), Vector2(40, -60), Vector2(40, 66), Vector2(-40, 66)]), Color(0.6, 0.8, 1.0, 0.22))
	_poly(goal, PackedVector2Array([Vector2(-28, -55), Vector2(-20, -55), Vector2(-20, 70), Vector2(-28, 70)]), Color(0.14, 0.17, 0.23))
	_poly(goal, PackedVector2Array([Vector2(20, -55), Vector2(28, -55), Vector2(28, 70), Vector2(20, 70)]), Color(0.14, 0.17, 0.23))
	_poly(goal, PackedVector2Array([Vector2(-42, -70), Vector2(42, -70), Vector2(38, -58), Vector2(-38, -58)]), Color(0.5, 0.7, 0.9))
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
	for x in ELITE_XS:
		var el := SHADOW_SCENE.instantiate()
		el.position = Vector2(x, SPAWN_Y)
		add_child(el)
		el.make_elite()
	for x in MASK_XS:
		var m := MASK_SCENE.instantiate()
		m.position = Vector2(x, SPAWN_Y - 70.0)
		add_child(m)
	PlatformPainter.build_sanctuary(self, 2680.0, GROUND_Y - 50.0)
	var leonie := LEONIE_SCENE.instantiate()
	leonie.position = Vector2(2680.0, SPAWN_Y)
	leonie.set_lines(LEONIE_LINES)
	add_child(leonie)
	for o in ORBS:
		var orb := ORB_SCENE.instantiate()
		orb.position = o
		add_child(orb)
	# Orbes-reflet en hauteur (Double Saut).
	for o in HIGH_ORBS:
		var orb := ORB_SCENE.instantiate()
		orb.position = o
		add_child(orb)

func _setup_ambient() -> void:
	var amb := AmbientDialogue.new()
	add_child(amb)
	amb.add_line(self, 620.0, "Léonie", "Ces anneaux de lumière, Eneko : lance ton fil spirituel, ils te hisseront vers les hauteurs.")
	amb.add_line(self, 900.0, "Eneko", "Le sol me renvoie mon propre visage. Ce monde ne fait que répéter.")
	amb.add_line(self, 3900.0, "Eneko", "Ce Reflet, là-bas... il lève sa lame quand je lève la mienne. Qui est-il ?")
	amb.add_line(self, 6300.0, "Eneko", "La porte d'argent. C'est par là que l'écho m'appelle.")

func _setup_audio() -> void:
	var wind := AudioStreamPlayer.new()
	wind.stream = load("res://assets/sfx/wind.wav")
	wind.volume_db = -16.0
	wind.pitch_scale = 1.05
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
			Atmosphere.spark_burst(self, cp.global_position, Color(0.5, 0.9, 1.0))
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
