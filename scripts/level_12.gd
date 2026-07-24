extends LevelBase
## Chapitre III — Niveau 12 : « Les Reflets Brisés ».
## Ici, les reflets ne tiennent pas : dès qu'Eneko y pose le pied, les dalles
## de verre TREMBLENT puis S'EFFONDRENT. Le niveau n'est plus un couloir à
## parcourir mais une suite de GANTELETS de plateformes effondrables qu'il
## faut franchir sans s'arrêter, entre des îlots de repos, portés parfois par
## des dalles-miroir mouvantes. Le Double Saut y est vital.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const SHADOW_SCENE := preload("res://scenes/shadow.tscn")
const MASK_SCENE := preload("res://scenes/split_shade.tscn")
const LEONIE_SCENE := preload("res://scenes/leonie.tscn")
const CRUMBLE_SCENE := preload("res://scenes/crumble_platform.tscn")
const LIFT_SCENE := preload("res://scenes/lift_platform.tscn")
const KARASU_SCENE := preload("res://scenes/karasu.tscn")

const GROUND_Y := 550.0
const SPAWN_Y := 477.0
const LEVEL_END := 7100.0
const GOAL_X := 6720.0
const LEVEL_ID := "level_12"

const GLASS := Color(0.1, 0.12, 0.17)
const GLASS_DARK := Color(0.05, 0.06, 0.1)
const SILVER := Color(0.72, 0.8, 0.88)
const CYAN := Color(0.5, 0.85, 0.95)

const PLATFORM_THEME := {
	"top": SILVER,
	"top_light": Color(0.92, 0.96, 1.0),
	"body_a": GLASS,
	"body_b": Color(0.08, 0.1, 0.14),
	"dark": GLASS_DARK,
	"speck": CYAN,
	"cut": true,
}

## Îlots de repos SOLIDES : x = centre, y = demi-largeur. Un point de contrôle
## ou le refuge sur chacun ; ce sont les seuls sols sûrs.
const REST := [
	Vector2(230, 190), Vector2(1500, 150), Vector2(2680, 200),
	Vector2(3900, 150), Vector2(5300, 150), Vector2(6720, 260),
]
## Refuge de Léonie (soin/point de contrôle) sur l'îlot central.
const REFUGE_X := 2680.0
## Points de contrôle sur les autres îlots.
const CHECKPOINT_XS := [1500.0, 3900.0, 5300.0]

## Dalles EFFONDRABLES : x, y (centre), demi-largeur. Regroupées en gantelets
## entre les îlots ; certaines montent en escalier (petites collines).
const CRUMBLES := [
	# Gantelet 1 (plat). Dernière dalle retirée : l'îlot (1500) est le sol
	# d'arrivée, la dalle qui s'y enfonçait faussait le repère.
	Vector3(520, 506, 46), Vector3(690, 506, 46), Vector3(860, 506, 46),
	Vector3(1030, 506, 46), Vector3(1200, 506, 46),
	# Gantelet 2 (colline).
	Vector3(1720, 506, 48), Vector3(1885, 430, 48), Vector3(2050, 360, 48),
	Vector3(2215, 430, 48), Vector3(2380, 506, 48),
	# Gantelet 3 (plat). Dernière dalle retirée (elle mordait sur l'îlot 3900).
	Vector3(2960, 506, 46), Vector3(3125, 506, 46), Vector3(3290, 506, 46),
	Vector3(3455, 506, 46), Vector3(3620, 506, 46),
	# Gantelet 4 (long, léger relief). Dernière dalle retirée (îlot 5300).
	Vector3(4120, 506, 46), Vector3(4285, 470, 46), Vector3(4450, 506, 46),
	Vector3(4615, 470, 46), Vector3(4780, 506, 46), Vector3(4945, 506, 46),
	# Gantelet 5 (final).
	Vector3(5520, 506, 46), Vector3(5685, 506, 46), Vector3(5850, 506, 46),
	Vector3(6015, 470, 46), Vector3(6180, 506, 46), Vector3(6345, 506, 46),
]

## Dalles-miroir mouvantes (ascenseurs) : x, y du point bas. Montent chercher
## une orbe-reflet en hauteur, au-dessus d'un îlot sûr.
const LIFTS := [Vector2(1500, 500), Vector2(5300, 500)]

## Orbes-reflet en hauteur (Double Saut) au-dessus des îlots sûrs.
const HIGH_ORBS := [
	Vector2(2680, 300), Vector2(3900, 320), Vector2(1500, 300), Vector2(5300, 300),
]

## Masques d'Oni : fauteurs de trouble sur les îlots de repos (jamais au
## milieu d'un gantelet). Ombre : une seule, gardienne d'un îlot. Décalés du
## centre exact des îlots (où tombent le point de contrôle / la porte) pour
## ne jamais se superposer visuellement au mât du drapeau.
const MASK_XS := [3830.0, 5230.0]
const SHADOW_XS := [1420.0, 6650.0]
## Karasu-tengu : ils patrouillent en vol AU-DESSUS des gantelets effondrables
## et plongent sur Eneko en pleine traversée — la seule menace qui l'atteigne
## là où le sol se dérobe.
const KARASU_XS := [
	Vector2(860, 360), Vector2(2050, 300), Vector2(3290, 360),
	Vector2(4615, 340), Vector2(6015, 340),
]
## Stèles-miroir décoratives.
const STELE_XS := [500.0, 2680.0, 3900.0, 6600.0]

const LEONIE_LINES := [
	{ "name": "Léonie", "text": "Prends garde, Eneko : ici, rien ne tient. Chaque reflet se brise sous ton poids dès que tu t'attardes." },
	{ "name": "Léonie", "text": "Ne t'arrête jamais sur une dalle qui tremble. Enchaîne les bonds, sers-toi de ton second souffle, et vise l'îlot solide suivant." },
	{ "name": "Léonie", "text": "Les Masques ne rôdent que sur les îlots sûrs — c'est là qu'il faut les défaire, jamais au-dessus du vide." },
	{ "name": "Eneko", "text": "Alors je danserai plus vite que le verre ne se brise. En avant." },
]

var sfx_win: AudioStreamPlayer
var glass_motes: CPUParticles2D
var _shimmers: Array = []
var _reflet: Node2D
var _t := 0.0

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var next_button: Button = $WinLabel/NextButton
@onready var dialogue: CanvasLayer = $Dialogue

func _ready() -> void:
	_build_decor()
	Atmosphere.add_foreground(self, Color(0.06, 0.08, 0.12, 0.32))
	_build_rest_platforms()
	_build_steles()
	_build_crumbles()
	_build_lifts()
	_build_checkpoints()
	_build_goal()
	_build_kill_zone(LEVEL_END, 720.0)
	_spawn_entities()
	_setup_audio()
	_setup_ambient()
	player.set_land_dust_color(Color(0.7, 0.85, 0.95, 0.7))
	win_label.visible = false
	Music.play_level(LEVEL_ID)
	SaveManager.set_last_level(LEVEL_ID)
	# Relique cachée, au-dessus de l'îlot de départ (Double Saut).
	var relic := Relic.new()
	relic.level_id = LEVEL_ID
	relic.position = Vector2(230, 300)
	add_child(relic)
	Challenge.start_level(LEVEL_ID, CRUMBLES.size() + HIGH_ORBS.size())
	dialogue.finished.connect(_on_dialogue_finished)
	menu_button.pressed.connect(_on_menu_pressed)
	var next_scene: String = SaveManager.LEVEL_SCENES.get("level_13", "")
	next_button.visible = next_scene != ""
	if next_scene != "":
		next_button.pressed.connect(func(): Transition.goto(next_scene))
	player.intro_pan(Vector2(GOAL_X, 330.0))

func _process(delta: float) -> void:
	_t += delta
	for sh in _shimmers:
		var node: Polygon2D = sh["node"]
		node.modulate.a = 0.3 + 0.5 * (0.5 + 0.5 * sin(_t * 1.8 + float(sh["phase"])))
	if _reflet != null and is_instance_valid(player):
		var target_x: float = clampf(player.global_position.x, 400.0, LEVEL_END - 200.0)
		_reflet.position.x = lerpf(_reflet.position.x, target_x, 0.02)
		_reflet.position.y = 300.0 + sin(_t * 0.7) * 10.0
		if absf(player.velocity.x) > 20.0:
			_reflet.scale.x = -signf(player.velocity.x) * 1.4
		_reflet.modulate.a = 0.16 + 0.06 * (0.5 + 0.5 * sin(_t * 1.1))

func _physics_process(_delta: float) -> void:
	if glass_motes != null and is_instance_valid(player):
		glass_motes.position = Vector2(player.position.x, player.position.y - 300.0)

# --- Construction ---------------------------------------------------------

func _build_decor() -> void:
	var bg: ParallaxBackground = $ParallaxBackground
	var mist_tex: Texture2D = load("res://assets/mist.svg")

	var sky := ParallaxLayer.new()
	sky.motion_scale = Vector2(0.05, 0.05)
	bg.add_child(sky)
	var halo := Sprite2D.new()
	halo.texture = mist_tex
	halo.modulate = Color(0.7, 0.82, 0.95, 0.4)
	halo.scale = Vector2(9.0, 9.0)
	halo.position = Vector2(700.0, 120.0)
	sky.add_child(halo)
	var moon_pts := PackedVector2Array()
	for i in 22:
		var a := i * TAU / 22.0
		moon_pts.append(Vector2(cos(a) * 44.0, sin(a) * 44.0))
	_poly(sky, moon_pts, Color(0.88, 0.93, 1.0, 0.85), Vector2(700, 120))
	var rays := GodRays.new()
	rays.color = Color(0.7, 0.85, 1.0, 0.05)
	rays.length = 1300.0
	rays.half_spread = 0.9
	rays.position = Vector2(700.0, 120.0)
	sky.add_child(rays)
	TextureLab.add_clouds(sky, 5, 70.0, 210.0, LEVEL_END, Color(0.6, 0.7, 0.85, 0.14))

	# Colonnades-miroir de fond.
	var gallery := ParallaxLayer.new()
	gallery.motion_scale = Vector2(0.2, 0.45)
	bg.add_child(gallery)
	var gx0 := -100.0
	var gi0 := 0
	while gx0 < LEVEL_END + 400.0:
		var gh := 240.0 + float(gi0 * 53 % 120)
		_poly(gallery, PackedVector2Array([
			Vector2(-16, 0), Vector2(-12, -gh), Vector2(12, -gh), Vector2(16, 0),
		]), Color(0.14, 0.18, 0.26, 0.7), Vector2(gx0, 560))
		var edge := _poly(gallery, PackedVector2Array([
			Vector2(-3, -12), Vector2(1, -12), Vector2(3, -gh + 20), Vector2(-2, -gh + 24),
		]), Color(0.6, 0.8, 1.0, 0.0), Vector2(gx0, 560))
		_shimmers.append({"node": edge, "phase": float(gi0) * 0.6})
		gx0 += 360.0 + float(gi0 * 47 % 160)
		gi0 += 1

	# Le Reflet d'Eneko, qui l'imite.
	var deep := ParallaxLayer.new()
	deep.motion_scale = Vector2(0.35, 0.55)
	bg.add_child(deep)
	_reflet = Node2D.new()
	_reflet.position = Vector2(1000.0, 300.0)
	_reflet.modulate = Color(1, 1, 1, 0.18)
	_reflet.scale = Vector2(1.4, 1.4)
	deep.add_child(_reflet)
	_poly(_reflet, PackedVector2Array([
		Vector2(-10, 40), Vector2(10, 40), Vector2(8, -20), Vector2(0, -34), Vector2(-8, -20),
	]), Color(0.55, 0.72, 0.95))
	_poly(_reflet, PackedVector2Array([
		Vector2(8, -18), Vector2(12, -18), Vector2(32, -74), Vector2(28, -76),
	]), Color(0.8, 0.92, 1.0))

	glass_motes = CPUParticles2D.new()
	glass_motes.texture = load("res://assets/leaf.svg")
	glass_motes.amount = 32
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

## Îlots de repos solides (les seuls sols sûrs).
func _build_rest_platforms() -> void:
	for p in REST:
		var body := StaticBody2D.new()
		body.position = Vector2(p.x, GROUND_Y)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(p.y * 2.0, 100.0)
		shape.shape = rect
		body.add_child(shape)
		PlatformPainter.paint(body, p.y, PLATFORM_THEME)
		var e := _poly(body, PackedVector2Array([
			Vector2(-8, 30), Vector2(-4, 30), Vector2(-1, 100), Vector2(-6, 104), Vector2(-11, 60),
		]), Color(0.5, 0.85, 0.95, 0.0))
		_shimmers.append({"node": e, "phase": float(int(p.x) % 628) * 0.01})
		add_child(body)

func _build_steles() -> void:
	for sx in STELE_XS:
		var st := Node2D.new()
		st.position = Vector2(sx, GROUND_Y - 50.0)
		_poly(st, PackedVector2Array([
			Vector2(-16, 0), Vector2(-12, -110), Vector2(0, -126), Vector2(12, -110), Vector2(16, 0),
		]), Color(0.1, 0.13, 0.18))
		var glint := _poly(st, PackedVector2Array([
			Vector2(-2, -20), Vector2(2, -20), Vector2(4, -96), Vector2(-1, -104), Vector2(-4, -60),
		]), Color(0.8, 0.95, 1.0, 0.0))
		_shimmers.append({"node": glint, "phase": float(int(sx) % 628) * 0.012})
		add_child(st)

## Dalles effondrables : cœur du niveau. Teintées de verre (le composant peint
## en pierre pâle par défaut, on ajoute un liseré cyan pour l'ambiance).
func _build_crumbles() -> void:
	for c in CRUMBLES:
		var pad := CRUMBLE_SCENE.instantiate()
		pad.half_width = c.z
		pad.position = Vector2(c.x, c.y)
		add_child(pad)
		# Liseré cyan translucide posé au-dessus (repère « reflet »).
		var glint := _poly(self, PackedVector2Array([
			Vector2(-c.z, -8), Vector2(c.z, -8), Vector2(c.z, -5), Vector2(-c.z, -5),
		]), Color(0.5, 0.85, 0.95, 0.35), Vector2(c.x, c.y))
		glint.z_index = 1

func _build_lifts() -> void:
	for v in LIFTS:
		var lift := LIFT_SCENE.instantiate()
		lift.position = v
		lift.travel = Vector2(0, -150)
		lift.period = 5.0
		add_child(lift)

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
	_poly(goal, PackedVector2Array([Vector2(-40, -60), Vector2(40, -60), Vector2(40, 66), Vector2(-40, 66)]), Color(0.6, 0.8, 1.0, 0.22))
	_poly(goal, PackedVector2Array([Vector2(-28, -55), Vector2(-20, -55), Vector2(-20, 70), Vector2(-28, 70)]), Color(0.14, 0.17, 0.23))
	_poly(goal, PackedVector2Array([Vector2(20, -55), Vector2(28, -55), Vector2(28, 70), Vector2(20, 70)]), Color(0.14, 0.17, 0.23))
	_poly(goal, PackedVector2Array([Vector2(-42, -70), Vector2(42, -70), Vector2(38, -58), Vector2(-38, -58)]), Color(0.5, 0.7, 0.9))
	add_child(goal)
	goal.body_entered.connect(_on_goal_body_entered)

func _spawn_entities() -> void:
	for x in SHADOW_XS:
		var s := SHADOW_SCENE.instantiate()
		s.position = Vector2(x, SPAWN_Y)
		add_child(s)
	for x in MASK_XS:
		var m := MASK_SCENE.instantiate()
		m.position = Vector2(x, SPAWN_Y - 70.0)
		add_child(m)
	for k in KARASU_XS:
		var karasu := KARASU_SCENE.instantiate()
		karasu.position = k
		add_child(karasu)
	# Refuge de Léonie sur l'îlot central.
	PlatformPainter.build_sanctuary(self, REFUGE_X, GROUND_Y - 50.0)
	var leonie := LEONIE_SCENE.instantiate()
	leonie.position = Vector2(REFUGE_X, SPAWN_Y)
	leonie.set_lines(LEONIE_LINES)
	add_child(leonie)
	# Une orbe au-dessus de chaque dalle effondrable (récompense le rythme).
	for c in CRUMBLES:
		var orb := ORB_SCENE.instantiate()
		orb.position = Vector2(c.x, c.y - 40.0)
		add_child(orb)
	for o in HIGH_ORBS:
		var orb := ORB_SCENE.instantiate()
		orb.position = o
		add_child(orb)

func _setup_ambient() -> void:
	var amb := AmbientDialogue.new()
	add_child(amb)
	amb.add_line(self, 700.0, "Eneko", "Le sol se brise à peine posé. Je ne dois pas m'arrêter.")
	amb.add_line(self, 3300.0, "Eneko", "Chaque dalle est un reflet qui refuse de me porter. Plus vite !")
	amb.add_line(self, 6200.0, "Eneko", "L'îlot du bout. La porte d'argent m'y attend enfin.")

func _setup_audio() -> void:
	var wind := AudioStreamPlayer.new()
	wind.stream = load("res://assets/sfx/wind.wav")
	wind.volume_db = -16.0
	wind.pitch_scale = 1.08
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

func _on_goal_body_entered(body: Node2D) -> void:
	_reach_goal(body, LEVEL_ID, sfx_win)
