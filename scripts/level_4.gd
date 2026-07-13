extends Node2D
## Niveau 4 : « La Montagne des Brumes ».
## Ascension rocheuse à flanc de montagne, dans une brume dense et un vent
## glacial. Pics enneigés, ponts de corde suspendus, cairns de pierre et
## drapeaux de prière déchirés. Les Ombres s'accrochent aux corniches.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const PATROL_SCENE := preload("res://scenes/enemy.tscn")
const SHADOW_SCENE := preload("res://scenes/shadow.tscn")
const LEONIE_SCENE := preload("res://scenes/leonie.tscn")

const GROUND_Y := 550.0    # centre vertical des plateformes
const SPAWN_Y := 477.0     # hauteur d'apparition des personnages
const LEVEL_END := 7300.0
const GOAL_X := 7000.0
const LEVEL_ID := "level_4"

const ROCK := Color(0.42, 0.42, 0.46)
const ROCK_DARK := Color(0.3, 0.3, 0.34)
const SNOW := Color(0.92, 0.94, 0.98)

## Plateformes : x = centre, y = demi-largeur. L'altitude monte lentement
## (GROUND_Y légèrement variable) pour donner l'impression d'ascension sans
## complexifier la physique. Trous de 140 à 170 px, un cran plus exigeant
## que le niveau 3.
const PLATFORMS := [
	Vector2(230, 230), Vector2(850, 220), Vector2(1470, 210),
	Vector2(2080, 200), Vector2(2680, 220), Vector2(3300, 200),
	Vector2(3920, 210), Vector2(4540, 200), Vector2(5160, 220),
	Vector2(5780, 210), Vector2(6420, 240), Vector2(7040, 280),
]
const CHECKPOINT_XS := [1600.0, 3550.0, 5500.0]
const PATROL_XS := [900.0, 1500.0, 2150.0, 2900.0, 3800.0, 4600.0, 5300.0, 6100.0]
const SHADOW_XS := [1420.0, 2200.0, 3300.0, 4300.0, 5200.0, 6000.0, 6800.0]
const TRAP_XS := [700.0, 2000.0, 3150.0, 4350.0, 5650.0, 6700.0]
const CAIRN_XS := [500.0, 1750.0, 2680.0, 3920.0, 5160.0, 6420.0]
const BRIDGE_XS := [1980.0, 4230.0]  # ponts de corde décoratifs entre deux plateformes
const ORBS := [
	Vector2(320, 420), Vector2(540, 385), Vector2(850, 420),
	Vector2(1150, 385), Vector2(1470, 420), Vector2(1780, 385),
	Vector2(2080, 420), Vector2(2380, 385), Vector2(2680, 420),
	Vector2(3000, 385), Vector2(3300, 420), Vector2(3610, 385),
	Vector2(3920, 420), Vector2(4230, 385), Vector2(4540, 420),
	Vector2(4850, 385), Vector2(5160, 420), Vector2(5470, 385),
	Vector2(5780, 420), Vector2(6100, 385), Vector2(6420, 420),
	Vector2(6730, 385), Vector2(7040, 420),
]

const LEONIE_LINES := [
	{ "name": "Léonie", "text": "La Montagne des Brumes. L'air se raréfie, et les Ombres s'accrochent aux corniches." },
	{ "name": "Léonie", "text": "Tu as traversé la forêt, le temple, le village. Chaque épreuve t'a rendu plus fort." },
	{ "name": "Léonie", "text": "Le sommet cache le dernier sanctuaire. Ce qui t'y attend demandera tout ton courage." },
	{ "name": "Léonie", "text": "Je ne peux pas monter plus haut avec toi. À partir d'ici, tu marches seul, Eneko." },
	{ "name": "Eneko", "text": "Je continuerai. Pour tous ceux que j'ai croisés en chemin." },
]

var sfx_win: AudioStreamPlayer
var mist_wisps: CPUParticles2D
var snow: CPUParticles2D

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var next_button: Button = $WinLabel/NextButton
@onready var dialogue: CanvasLayer = $Dialogue

func _ready() -> void:
	_build_decor()
	_build_platforms()
	_build_cairns()
	_build_bridges()
	_build_checkpoints()
	_build_traps()
	_build_goal()
	_build_kill_zone()
	_spawn_entities()
	_setup_audio()
	win_label.visible = false
	SaveManager.set_last_level(LEVEL_ID)
	Challenge.start_level(LEVEL_ID, ORBS.size())
	dialogue.finished.connect(_on_dialogue_finished)
	menu_button.pressed.connect(_on_menu_pressed)
	var next_scene: String = SaveManager.LEVEL_SCENES.get("level_5", "")
	next_button.visible = next_scene != ""
	if next_scene != "":
		next_button.pressed.connect(func(): get_tree().change_scene_to_file(next_scene))

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	if mist_wisps != null:
		mist_wisps.position = Vector2(player.position.x, player.position.y - 40.0)
	if snow != null:
		snow.position = Vector2(player.position.x, player.position.y - 340.0)

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

## Pics enneigés lointains, crêtes rocheuses proches, brume dense qui roule
## au ras du sol, et neige qui tombe doucement autour d'Eneko.
func _build_decor() -> void:
	var bg: ParallaxBackground = $ParallaxBackground
	var mist_tex: Texture2D = load("res://assets/mist.svg")

	# Ciel pâle et froid, déjà posé par le sky du .tscn.

	# Pics lointains, bleu-gris, sommets enneigés.
	var far := ParallaxLayer.new()
	far.motion_scale = Vector2(0.1, 0.35)
	bg.add_child(far)
	var mx := -250.0
	var mi := 0
	while mx < LEVEL_END + 900.0:
		var mh := 260.0 + float(mi * 61 % 140)
		_poly(far, PackedVector2Array([
			Vector2(-320, 0), Vector2(0, -mh), Vector2(320, 0),
		]), Color(0.5, 0.56, 0.66, 0.55), Vector2(mx, 540))
		_poly(far, PackedVector2Array([
			Vector2(-42, -mh + 40), Vector2(0, -mh), Vector2(42, -mh + 40), Vector2(0, -mh + 56),
		]), Color(0.95, 0.96, 1.0, 0.75), Vector2(mx, 540))
		mx += 420.0 + float(mi * 43 % 150)
		mi += 1

	# Crête rocheuse proche, plus sombre.
	var near_ridge := ParallaxLayer.new()
	near_ridge.motion_scale = Vector2(0.25, 0.6)
	bg.add_child(near_ridge)
	mx = -150.0
	mi = 0
	while mx < LEVEL_END + 900.0:
		var rh := 170.0 + float(mi * 39 % 90)
		_poly(near_ridge, PackedVector2Array([
			Vector2(-220, 0), Vector2(-60, -rh + 26), Vector2(20, -rh),
			Vector2(100, -rh + 34), Vector2(220, 0),
		]), Color(0.38, 0.4, 0.46, 0.6), Vector2(mx, 560))
		mx += 360.0 + float(mi * 33 % 100)
		mi += 1

	# Drapeaux de prière déchirés, tendus entre des mâts espacés.
	var flags := ParallaxLayer.new()
	flags.motion_scale = Vector2(0.6, 1)
	bg.add_child(flags)
	var fx := 400.0
	var fi := 0
	while fx < LEVEL_END - 300.0:
		_build_prayer_flags(flags, Vector2(fx, 500.0), fi)
		fx += 900.0 + float(fi * 71 % 200)
		fi += 1

	# Nappes de brume denses, en mouvement lent.
	var mist_layer := ParallaxLayer.new()
	mist_layer.motion_scale = Vector2(0.45, 1)
	bg.add_child(mist_layer)
	var x := 200.0
	while x < LEVEL_END:
		var m := Sprite2D.new()
		m.texture = mist_tex
		m.position = Vector2(x, 470.0 + float(int(x) % 60))
		m.scale = Vector2(7.5, 2.4)
		m.modulate = Color(1, 1, 1, 0.22)
		mist_layer.add_child(m)
		x += 380.0

	# Brume qui suit Eneko de près (basse, dense).
	mist_wisps = CPUParticles2D.new()
	mist_wisps.texture = mist_tex
	mist_wisps.amount = 10
	mist_wisps.lifetime = 8.0
	mist_wisps.preprocess = 8.0
	mist_wisps.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	mist_wisps.emission_rect_extents = Vector2(500, 60)
	mist_wisps.direction = Vector2(1, 0)
	mist_wisps.spread = 20.0
	mist_wisps.gravity = Vector2.ZERO
	mist_wisps.initial_velocity_min = 10.0
	mist_wisps.initial_velocity_max = 26.0
	mist_wisps.scale_amount_min = 2.5
	mist_wisps.scale_amount_max = 4.5
	mist_wisps.color = Color(1, 1, 1, 0.16)
	add_child(mist_wisps)

	# Neige qui tombe doucement autour du joueur.
	snow = CPUParticles2D.new()
	snow.texture = load("res://assets/leaf.svg")
	snow.amount = 30
	snow.lifetime = 6.0
	snow.preprocess = 6.0
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(560, 10)
	snow.direction = Vector2(0.1, 1.0)
	snow.spread = 20.0
	snow.gravity = Vector2(4, 26)
	snow.initial_velocity_min = 18.0
	snow.initial_velocity_max = 36.0
	snow.angular_velocity_min = -40.0
	snow.angular_velocity_max = 40.0
	snow.scale_amount_min = 0.35
	snow.scale_amount_max = 0.65
	snow.color = Color(0.96, 0.97, 1.0, 0.85)
	add_child(snow)

## Deux mâts de bois reliés par une corde de petits drapeaux carrés.
func _build_prayer_flags(parent: Node, base: Vector2, seed_i: int) -> void:
	var span := 220.0
	var top := -150.0
	for side in [0.0, 1.0]:
		_poly(parent, PackedVector2Array([
			Vector2(side * span - 3, 0), Vector2(side * span + 3, 0),
			Vector2(side * span + 2, top), Vector2(side * span - 2, top),
		]), Color(0.28, 0.22, 0.18), base)
	var colors := [Color(0.7, 0.2, 0.18), Color(0.85, 0.75, 0.3), Color(0.25, 0.4, 0.65), Color(0.9, 0.9, 0.85)]
	var count := 6
	for k in count:
		var t := float(k) / float(count - 1)
		var fx := lerpf(0.0, span, t)
		var fy := top + 6.0 + sin(t * PI) * 14.0
		var c: Color = colors[(seed_i + k) % colors.size()]
		c.a = 0.7
		_poly(parent, PackedVector2Array([
			Vector2(-7, 0), Vector2(7, 0), Vector2(5, 14), Vector2(0, 10), Vector2(-5, 14),
		]), c, base + Vector2(fx, fy))

## Plateformes rocheuses : strate de pierre, neige au sommet, fissures et
## petits cailloux. Pas de terre ni d'herbe : on est en haute montagne.
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
		_poly(body, _rect_points(p.y, -50.0, 450.0), ROCK)
		_poly(body, _rect_points(p.y, 220.0, 450.0), ROCK_DARK)
		_poly(body, _rect_points(p.y, -50.0, -34.0), SNOW)

		# Congères irrégulières sur le bord supérieur.
		var drift_count: int = maxi(2, int(p.y / 90.0))
		for d in drift_count:
			var dx: float = -p.y + 40.0 + d * ((p.y * 2.0 - 80.0) / maxf(1.0, float(drift_count - 1)))
			_poly(body, PackedVector2Array([
				Vector2(dx - 18, -34), Vector2(dx - 8, -46), Vector2(dx + 6, -42),
				Vector2(dx + 18, -34),
			]), Color(1.0, 1.0, 1.0, 0.9))

		# Fissures sombres dans la roche.
		var crack_count: int = maxi(1, int(p.y / 140.0))
		for c in crack_count:
			var cx: float = -p.y + 70.0 + c * ((p.y * 2.0 - 140.0) / maxf(1.0, float(crack_count)))
			_poly(body, PackedVector2Array([
				Vector2(cx - 2, 40), Vector2(cx + 2, 40), Vector2(cx + 5, 120), Vector2(cx - 1, 130), Vector2(cx - 4, 90),
			]), ROCK_DARK)

		# Cailloux épars.
		var rock_count: int = maxi(1, int(p.y / 110.0))
		for r in rock_count:
			var rx: float = -p.y + 50.0 + r * ((p.y * 2.0 - 100.0) / maxf(1.0, float(rock_count)))
			_poly(body, PackedVector2Array([
				Vector2(rx - 10, 90), Vector2(rx, 78), Vector2(rx + 10, 90), Vector2(rx, 102),
			]), Color(0.36, 0.36, 0.4))

		add_child(body)

## Cairns décoratifs (piles de pierres) sur certaines plateformes.
func _build_cairns() -> void:
	for cx in CAIRN_XS:
		var cairn := Node2D.new()
		cairn.position = Vector2(cx, GROUND_Y - 50.0)
		var sizes := [26.0, 20.0, 14.0]
		var y := 0.0
		for s in sizes:
			_poly(cairn, PackedVector2Array([
				Vector2(-s, 0), Vector2(s, 0), Vector2(s * 0.7, -s * 0.8), Vector2(-s * 0.7, -s * 0.8),
			]), Color(0.46, 0.46, 0.5), Vector2(0, y))
			y -= s * 0.8
		add_child(cairn)

## Ponts de corde décoratifs tendus entre deux plateformes voisines (pas de
## collision propre : ils flottent visuellement au-dessus du vide).
func _build_bridges() -> void:
	for bx in BRIDGE_XS:
		var bridge := Node2D.new()
		bridge.position = Vector2(bx, GROUND_Y - 40.0)
		var half := 90.0
		# Deux cordes porteuses qui pendent légèrement.
		for row in [-14.0, 14.0]:
			var pts := PackedVector2Array()
			var steps := 8
			for k in steps + 1:
				var t := float(k) / float(steps)
				var px := lerpf(-half, half, t)
				var py := float(row) + sin(t * PI) * 16.0
				pts.append(Vector2(px, py))
			for k in steps:
				_poly(bridge, PackedVector2Array([
					pts[k] + Vector2(0, -1.5), pts[k + 1] + Vector2(0, -1.5),
					pts[k + 1] + Vector2(0, 1.5), pts[k] + Vector2(0, 1.5),
				]), Color(0.32, 0.24, 0.16))
		# Planches transversales.
		var plank_count := 7
		for k in plank_count:
			var t := float(k) / float(plank_count - 1)
			var px := lerpf(-half, half, t)
			var py := sin(t * PI) * 16.0
			_poly(bridge, _rect_points(10.0, -3.0, 3.0), Color(0.4, 0.3, 0.2), Vector2(px, py))
		add_child(bridge)

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
		]), Color(0.3, 0.3, 0.34))
		var flag := _poly(cp, PackedVector2Array([
			Vector2(3, -60), Vector2(40, -50), Vector2(3, -38),
		]), Color(0.7, 0.78, 0.9))
		add_child(cp)
		cp.body_entered.connect(_on_checkpoint_body_entered.bind(cp, flag))

## Pièges : stalactites de glace pointant du sol plutôt que des pieux de bois.
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
		]), Color(0.5, 0.55, 0.62))
		for k in 3:
			var ox := -16.0 + k * 16.0
			_poly(trap, PackedVector2Array([
				Vector2(ox - 5, 6), Vector2(ox + 5, 6), Vector2(ox, -14),
			]), Color(0.72, 0.82, 0.92, 0.85))
			_poly(trap, PackedVector2Array([
				Vector2(ox - 2, 2), Vector2(ox + 2, 2), Vector2(ox, -12),
			]), Color(0.85, 0.92, 0.98, 0.9))
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
	glow.modulate = Color(0.8, 0.9, 1.0, 0.5)
	glow.scale = Vector2(4.5, 4.5)
	goal.add_child(glow)
	_poly(goal, PackedVector2Array([Vector2(-40, -60), Vector2(40, -60), Vector2(40, 66), Vector2(-40, 66)]), Color(0.85, 0.92, 1.0, 0.25))
	_poly(goal, PackedVector2Array([Vector2(-28, -55), Vector2(-20, -55), Vector2(-20, 70), Vector2(-28, 70)]), Color(0.5, 0.56, 0.66))
	_poly(goal, PackedVector2Array([Vector2(20, -55), Vector2(28, -55), Vector2(28, 70), Vector2(20, 70)]), Color(0.5, 0.56, 0.66))
	_poly(goal, PackedVector2Array([Vector2(-42, -70), Vector2(42, -70), Vector2(38, -58), Vector2(-38, -58)]), Color(0.42, 0.48, 0.58))
	_poly(goal, PackedVector2Array([Vector2(-32, -46), Vector2(32, -46), Vector2(32, -38), Vector2(-32, -38)]), Color(0.5, 0.56, 0.66))
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
	var leonie := LEONIE_SCENE.instantiate()
	leonie.position = Vector2(3550.0, SPAWN_Y)
	leonie.set_lines(LEONIE_LINES)
	leonie.talk.connect(_on_leonie_talk)
	add_child(leonie)
	for o in ORBS:
		var orb := ORB_SCENE.instantiate()
		orb.position = o
		add_child(orb)

## Vent glacial, plus fort et plus aigu que dans les niveaux précédents.
func _setup_audio() -> void:
	var wind := AudioStreamPlayer.new()
	wind.stream = load("res://assets/sfx/wind.wav")
	wind.volume_db = -12.0
	wind.pitch_scale = 1.15
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
	var results := Challenge.get_results()

	var challenge_stats = win_label.find_child("ChallengeStats", true, false)
	if challenge_stats == null:
		return

	var grade_label = challenge_stats.find_child("Grade", true, false)
	var orbs_label = challenge_stats.find_child("Orbs", true, false)
	var damage_label = challenge_stats.find_child("Damage", true, false)
	var time_label = challenge_stats.find_child("Time", true, false)

	if grade_label:
		grade_label.text = "Grade: %s" % results["grade"]
	if orbs_label:
		orbs_label.text = "Orbes: %d/%d" % [results["orbs"], results["total_orbs"]]
	if damage_label:
		damage_label.text = "Dégâts: %d" % results["damage"]
	if time_label:
		time_label.text = "Temps: %s" % _format_time(results["time"])

	Challenge.reset()

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
