extends LevelBase
## Chapitre III — Niveau 14 : « Le Gouffre aux Anneaux ».
## Un abîme-miroir que nul bond ne franchit : entre des îlots de verre béent de
## larges gouffres, enjambés seulement par des chapelets d'anneaux de lumière.
## Le Fil Spirituel devient la seule voie — on s'élance d'anneau en anneau, le
## souffle (double saut) se renouvelant à chaque prise, jusqu'à la porte.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const LEONIE_SCENE := preload("res://scenes/leonie.tscn")
const PATROL_SCENE := preload("res://scenes/enemy.tscn")

const GROUND_Y := 550.0
const SPAWN_Y := 477.0
const LEVEL_END := 7400.0
const GOAL_X := 6900.0
const LEVEL_ID := "level_14"

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

## Îlots solides (x = centre, y = demi-largeur), séparés par de larges gouffres
## infranchissables au saut.
const ISLANDS := [
	Vector2(230, 260), Vector2(1350, 230), Vector2(2470, 230),
	Vector2(3590, 230), Vector2(4710, 230), Vector2(5830, 230),
	Vector2(6900, 280),
]
## Points de contrôle sur les îlots intermédiaires.
const CHECKPOINT_XS := [1350.0, 2470.0, 3590.0, 4710.0, 5830.0]
## Anneaux du Fil Spirituel : deux par gouffre, chaque bond ≤ 285 px (portée
## du fil 360 px), l'atterrissage à ≤ 160 px de l'îlot suivant.
const ANCHORS := [
	Vector2(705, 315), Vector2(960, 315),
	Vector2(1795, 315), Vector2(2080, 315),
	Vector2(2915, 315), Vector2(3200, 315),
	Vector2(4035, 315), Vector2(4320, 315),
	Vector2(5155, 315), Vector2(5440, 315),
	Vector2(6275, 315), Vector2(6460, 315),
]
## Orbes : une sur chaque îlot, une sous chaque anneau (cueillie en s'élançant).
const ISLAND_ORBS := [
	Vector2(230, 440), Vector2(1350, 440), Vector2(2470, 440),
	Vector2(3590, 440), Vector2(4710, 440), Vector2(5830, 440),
	Vector2(6900, 440),
]
## Onre en faction sur les îlots intermédiaires : le Fil Spirituel reste une
## traversée aérienne sans menace (le risque est déjà la précision des sauts
## au-dessus du vide) ; le danger reprend pied dès l'atterrissage. Décalé du
## centre exact de l'îlot (où tombe le point de contrôle) pour ne jamais se
## superposer visuellement au mât du drapeau.
const PATROL_XS := [1280.0, 2400.0, 3520.0, 4640.0, 5760.0]

const LEONIE_LINES := [
	{ "name": "Léonie", "text": "Devant toi, le vide, Eneko. Aucun bond ne le franchira. Mais vois ces anneaux de lumière suspendus au-dessus du gouffre." },
	{ "name": "Léonie", "text": "Lance ton fil de l'un à l'autre sans toucher terre. À chaque prise, ton souffle se renouvelle — enchaîne le fil et le saut, et tu voleras." },
	{ "name": "Eneko", "text": "Alors je traverserai le vide comme on tisse une toile. D'anneau en anneau, jusqu'à la porte." },
]

var sfx_win: AudioStreamPlayer
var glass_motes: CPUParticles2D
var _shimmers: Array = []
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
	_build_anchors()
	_build_checkpoints()
	_build_tutorial_signs()
	_build_goal()
	_build_kill_zone(LEVEL_END, 760.0)
	_spawn_entities()
	_setup_audio()
	_setup_ambient()
	player.set_land_dust_color(Color(0.7, 0.85, 0.95, 0.7))
	win_label.visible = false
	Music.play_level(LEVEL_ID)
	SaveManager.set_last_level(LEVEL_ID)
	# Relique cachée : au-dessus d'un anneau, décrochée d'un fil puis d'un saut.
	var relic := Relic.new()
	relic.level_id = LEVEL_ID
	relic.position = Vector2(4035, 235)
	add_child(relic)
	Challenge.start_level(LEVEL_ID, ISLAND_ORBS.size() + ANCHORS.size())
	dialogue.finished.connect(_on_dialogue_finished)
	menu_button.pressed.connect(_on_menu_pressed)
	var next_scene: String = SaveManager.LEVEL_SCENES.get("level_15", "")
	next_button.visible = next_scene != ""
	if next_scene != "":
		next_button.pressed.connect(func(): Transition.goto(next_scene))
	player.intro_pan(Vector2(GOAL_X, 330.0))

func _process(delta: float) -> void:
	_t += delta
	for sh in _shimmers:
		var node: Polygon2D = sh["node"]
		node.modulate.a = 0.3 + 0.5 * (0.5 + 0.5 * sin(_t * 1.8 + float(sh["phase"])))

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
	halo.position = Vector2(720.0, 120.0)
	sky.add_child(halo)
	var moon_pts := PackedVector2Array()
	for i in 22:
		var a := i * TAU / 22.0
		moon_pts.append(Vector2(cos(a) * 46.0, sin(a) * 46.0))
	_poly(sky, moon_pts, Color(0.88, 0.93, 1.0, 0.85), Vector2(720, 120))
	TextureLab.add_clouds(sky, 5, 70.0, 210.0, LEVEL_END, Color(0.6, 0.7, 0.85, 0.14))
	var rays := GodRays.new()
	rays.ray_count = 8
	rays.half_spread = 0.9
	rays.length = 1300.0
	rays.color = Color(0.7, 0.83, 1.0, 0.05)
	rays.position = Vector2(720, 120)
	sky.add_child(rays)

	# Éclats de miroir brisé, en suspension dans le vide, qui dérivent
	# lentement — le vertige du gouffre, mesuré par leur chute sans fin.
	var voidshards := ParallaxLayer.new()
	voidshards.motion_scale = Vector2(0.4, 0.55)
	bg.add_child(voidshards)
	var vx := 200.0
	var vi := 0
	while vx < LEVEL_END:
		var vy := 220.0 + float(vi * 71 % 260)
		var vs := 10.0 + float(vi * 23 % 14)
		var shard := _poly(voidshards, PackedVector2Array([
			Vector2(0, -vs), Vector2(vs * 0.7, 0), Vector2(0, vs), Vector2(-vs * 0.7, 0),
		]), Color(0.55, 0.7, 0.92, 0.4), Vector2(vx, vy))
		var stw := shard.create_tween().set_loops()
		var drop := 30.0 + float(vi % 4) * 14.0
		var dur := 4.0 + float(vi % 3) * 1.4
		stw.tween_property(shard, "position:y", vy + drop, dur).set_trans(Tween.TRANS_SINE)
		stw.parallel().tween_property(shard, "rotation", deg_to_rad(25.0), dur * 2.0)
		stw.tween_property(shard, "position:y", vy - drop, dur).set_trans(Tween.TRANS_SINE)
		vx += 260.0 + float(vi * 43 % 220)
		vi += 1

	# Brume qui sourd du gouffre, tout en bas.
	var deep := ParallaxLayer.new()
	deep.motion_scale = Vector2(0.3, 0.7)
	bg.add_child(deep)
	_poly(deep, PackedVector2Array([
		Vector2(-200, 600), Vector2(LEVEL_END + 400, 600),
		Vector2(LEVEL_END + 400, 900), Vector2(-200, 900),
	]), Color(0.06, 0.08, 0.14, 0.7))

	# Lueurs lointaines, tout au fond du gouffre : le vide n'a pas de fond
	# visible, seulement ces points qui scintillent, minuscules.
	var gx := 150.0
	var gi := 0
	while gx < LEVEL_END:
		var glim := _poly(deep, PackedVector2Array([
			Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2),
		]), Color(0.7, 0.85, 1.0, 0.0), Vector2(gx, 780.0 + float(gi * 37 % 90)))
		var gtw := glim.create_tween().set_loops()
		gtw.tween_property(glim, "modulate:a", 0.5, 1.6 + float(gi % 4) * 0.5).set_trans(Tween.TRANS_SINE)
		gtw.tween_property(glim, "modulate:a", 0.0, 1.6 + float(gi % 4) * 0.5).set_trans(Tween.TRANS_SINE)
		gx += 180.0 + float(gi * 29 % 160)
		gi += 1

	glass_motes = CPUParticles2D.new()
	glass_motes.texture = load("res://assets/leaf.svg")
	glass_motes.amount = 28
	glass_motes.lifetime = 7.0
	glass_motes.preprocess = 7.0
	glass_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	glass_motes.emission_rect_extents = Vector2(560, 200)
	glass_motes.direction = Vector2(0.1, 1.0)
	glass_motes.spread = 20.0
	glass_motes.gravity = Vector2(2, 12)
	glass_motes.initial_velocity_min = 8.0
	glass_motes.initial_velocity_max = 22.0
	glass_motes.scale_amount_min = 0.25
	glass_motes.scale_amount_max = 0.55
	glass_motes.color = Color(0.75, 0.88, 1.0, 0.7)
	add_child(glass_motes)

func _build_platforms() -> void:
	for pi in ISLANDS.size():
		var p: Vector2 = ISLANDS[pi]
		var body := StaticBody2D.new()
		body.position = Vector2(p.x, GROUND_Y)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(p.y * 2.0, 100.0)
		shape.shape = rect
		body.add_child(shape)
		PlatformPainter.paint(body, p.y, PLATFORM_THEME)
		var e := _poly(body, PackedVector2Array([
			Vector2(-6, 30), Vector2(-1, 30), Vector2(2, 96), Vector2(-4, 104), Vector2(-9, 66),
		]), Color(0.5, 0.85, 0.95, 0.0))
		_shimmers.append({"node": e, "phase": float(pi * 71 % 628) * 0.01})
		add_child(body)
		# Reflet pâle sous l'îlot.
		var refl := _poly(self, PackedVector2Array([
			Vector2(-p.y, 50), Vector2(p.y, 50), Vector2(p.y * 0.7, 150), Vector2(-p.y * 0.7, 150),
		]), Color(0.5, 0.62, 0.78, 0.12), Vector2(p.x, GROUND_Y))
		refl.z_index = -1

func _build_anchors() -> void:
	for p in ANCHORS:
		var a := SpiritAnchor.new()
		a.position = p
		add_child(a)

## Léonie explique déjà le Fil Spirituel en dialogue ; cette pancarte précise
## juste le bouton dédié (facile à manquer, jamais nommé explicitement).
func _build_tutorial_signs() -> void:
	TutorialSign.build(self, 450.0, GROUND_Y - 50.0, "Fil   Bouton dédié, vise un anneau")

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
	Atmosphere.breathe(glow)
	goal.body_entered.connect(_on_goal_body_entered)

func _spawn_entities() -> void:
	# Léonie veille depuis le premier îlot (elle y délivre son enseignement).
	PlatformPainter.build_sanctuary(self, 230.0, GROUND_Y - 50.0)
	var leonie := LEONIE_SCENE.instantiate()
	leonie.position = Vector2(320.0, SPAWN_Y)
	leonie.set_lines(LEONIE_LINES)
	add_child(leonie)
	for o in ISLAND_ORBS:
		var orb := ORB_SCENE.instantiate()
		orb.position = o
		add_child(orb)
	# Une orbe sous chaque anneau : récompense l'élan.
	for a in ANCHORS:
		var orb := ORB_SCENE.instantiate()
		orb.position = Vector2(a.x, a.y + 42.0)
		add_child(orb)
	# Onre en faction sur les îlots intermédiaires, à l'atterrissage.
	for x in PATROL_XS:
		var e := PATROL_SCENE.instantiate()
		e.position = Vector2(x, SPAWN_Y)
		add_child(e)

func _setup_ambient() -> void:
	var amb := AmbientDialogue.new()
	add_child(amb)
	amb.add_line(self, 2470.0, "Eneko", "D'anneau en anneau, sans jamais poser le pied. Le vide ne m'aura pas.")
	amb.add_line(self, 4710.0, "Eneko", "Le fil chante à chaque prise. Je vole, presque.")
	amb.add_line(self, 6300.0, "Eneko", "La porte d'argent, au bout du gouffre. Un dernier élan.")

func _setup_audio() -> void:
	var wind := AudioStreamPlayer.new()
	wind.stream = load("res://assets/sfx/wind.wav")
	wind.volume_db = -14.0
	wind.pitch_scale = 1.1
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
