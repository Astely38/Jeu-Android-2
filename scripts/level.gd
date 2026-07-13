extends Node2D
## Niveau 1 : « La Clairière des Bambous ».
## Le décor, les plateformes, les checkpoints, le torii, les ennemis et les
## orbes sont générés à partir des tableaux de données ci-dessous : pour
## allonger le niveau, il suffit d'ajouter des entrées.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const PATROL_SCENE := preload("res://scenes/enemy.tscn")
const SHADOW_SCENE := preload("res://scenes/shadow.tscn")

const GROUND_Y := 550.0    # centre vertical des plateformes
const SPAWN_Y := 477.0     # hauteur d'apparition des personnages
const LEVEL_END := 7000.0
const GOAL_X := 6800.0
const LEVEL_ID := "level_1"

const DIRT := Color(0.36, 0.25, 0.16)
const DIRT_DARK := Color(0.27, 0.18, 0.11)
const GRASS := Color(0.4, 0.62, 0.32)

const LEONIE_LINES := [
	{ "name": "Léonie", "text": "Eneko, c'est bon de te voir." },
	{ "name": "Léonie", "text": "La Clairière des Bambous est belle, mais ses secrets sont anciens et douloureux." },
	{ "name": "Léonie", "text": "Tes ancêtres ont marché sur ce chemin. Ton sabre porte leur force." },
	{ "name": "Léonie", "text": "Traverse cette forêt avec respect. Le torii t'attend." },
	{ "name": "Eneko", "text": "Je suis prêt, Léonie." },
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
const PATROL_XS := [1000.0, 1550.0, 2200.0, 2750.0, 3450.0, 4700.0, 5900.0, 6500.0]
const SHADOW_XS := [1600.0, 2560.0, 4100.0, 5300.0, 6480.0]
## Pièges à pics : proches d'un bord de plateforme, contournables en marchant
## ou en sautant par-dessus (jamais un passage obligé).
const TRAP_XS := [980.0, 2680.0, 3900.0, 5220.0, 6520.0]
const ORBS := [
	Vector2(350, 440), Vector2(565, 405), Vector2(890, 440),
	Vector2(1210, 405), Vector2(1520, 440), Vector2(1835, 405),
	Vector2(2140, 440), Vector2(2455, 405), Vector2(2760, 440),
	Vector2(3060, 405), Vector2(3390, 440), Vector2(3710, 405),
	Vector2(4010, 440), Vector2(4320, 405), Vector2(4640, 440),
	Vector2(4960, 405), Vector2(5270, 440), Vector2(5580, 405),
	Vector2(5910, 440), Vector2(6235, 405), Vector2(6600, 440),
]

var sfx_win: AudioStreamPlayer
var petals: CPUParticles2D

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var next_button: Button = $WinLabel/NextButton
@onready var dialogue: CanvasLayer = $Dialogue
@onready var leonie: Area2D = $Leonie

func _ready() -> void:
	_build_decor()
	_build_platforms()
	_build_checkpoints()
	_build_traps()
	_build_goal()
	_build_kill_zone()
	_spawn_entities()
	_setup_audio()
	win_label.visible = false
	SaveManager.set_last_level(LEVEL_ID)
	Challenge.start_level(LEVEL_ID, ORBS.size())
	leonie.set_lines(LEONIE_LINES)
	leonie.talk.connect(_on_leonie_talk)
	dialogue.finished.connect(_on_dialogue_finished)
	menu_button.pressed.connect(_on_menu_pressed)
	var next_scene: String = SaveManager.LEVEL_SCENES.get("level_2", "")
	next_button.visible = next_scene != ""
	if next_scene != "":
		next_button.pressed.connect(func(): get_tree().change_scene_to_file(next_scene))

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

	# Montagnes lointaines bleutées, avec sommets enneigés.
	var mountains := ParallaxLayer.new()
	mountains.motion_scale = Vector2(0.1, 0.4)
	bg.add_child(mountains)
	var mx := -200.0
	var mi := 0
	while mx < LEVEL_END + 900.0:
		var mh := 220.0 + float(mi * 53 % 100)
		_poly(mountains, PackedVector2Array([
			Vector2(-280, 0), Vector2(0, -mh), Vector2(280, 0),
		]), Color(0.55, 0.62, 0.74, 0.6), Vector2(mx, 560))
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
		_poly(hills, PackedVector2Array([
			Vector2(-240, 0), Vector2(-80, -hh + 30), Vector2(0, -hh),
			Vector2(110, -hh + 40), Vector2(240, 0),
		]), Color(0.44, 0.56, 0.5, 0.55), Vector2(mx, 570))
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
		_poly(body, _rect_points(p.y, -50.0, 450.0), DIRT)
		_poly(body, _rect_points(p.y, 250.0, 450.0), DIRT_DARK)
		_poly(body, _rect_points(p.y, -50.0, -40.0), GRASS)

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
		]), Color(0.38, 0.24, 0.13))
		for k in 3:
			var ox := -16.0 + k * 16.0
			_poly(trap, PackedVector2Array([
				Vector2(ox - 5, 6), Vector2(ox + 5, 6), Vector2(ox, -14),
			]), Color(0.52, 0.34, 0.18))
			_poly(trap, PackedVector2Array([
				Vector2(ox - 2, 2), Vector2(ox + 2, 2), Vector2(ox, -12),
			]), Color(0.6, 0.42, 0.22))
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
	glow.modulate = Color(1.0, 0.85, 0.45, 0.5)
	glow.scale = Vector2(4.5, 4.5)
	goal.add_child(glow)
	_poly(goal, PackedVector2Array([Vector2(-40, -60), Vector2(40, -60), Vector2(40, 66), Vector2(-40, 66)]), Color(1, 0.9, 0.5, 0.25))
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

func _on_checkpoint_body_entered(body: Node2D, cp: Area2D, flag: Polygon2D) -> void:
	if body == player:
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
		damage_label.text = "Dégâts : %d" % results["damage"]
	if time_label:
		time_label.text = "Temps : %s" % _format_time(results["time"])

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
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
