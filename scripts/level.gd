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

## Plateformes : x = centre, y = demi-largeur. Trous de 120 à 150 px
## (portée de saut max ≈ 190 px).
const PLATFORMS := [
	Vector2(250, 250), Vector2(890, 260), Vector2(1520, 250),
	Vector2(2140, 240), Vector2(2760, 230), Vector2(3390, 260),
	Vector2(4010, 240), Vector2(4640, 250), Vector2(5270, 240),
	Vector2(5910, 260), Vector2(6600, 300),
]
const CHECKPOINT_XS := [1650.0, 3400.0, 5100.0]
const PATROL_XS := [1000.0, 1550.0, 2200.0, 2750.0, 3450.0, 4050.0, 4700.0, 5900.0, 6500.0]
const SHADOW_XS := [1600.0, 2560.0, 2850.0, 3820.0, 4100.0, 5300.0, 5680.0, 6480.0]
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

## Pics : petite zone de dégâts posée sur le sol, à contourner ou sauter.
func _build_traps() -> void:
	for i in TRAP_XS.size():
		var x: float = TRAP_XS[i]
		var trap := Area2D.new()
		trap.position = Vector2(x, GROUND_Y - 66.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(44, 24)
		shape.shape = rect
		trap.add_child(shape)
		for k in 3:
			var ox := -16.0 + k * 16.0
			_poly(trap, PackedVector2Array([
				Vector2(ox - 7, 12), Vector2(ox + 7, 12), Vector2(ox, -12),
			]), Color(0.62, 0.6, 0.58))
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

func _on_checkpoint_body_entered(body: Node2D, cp: Area2D, flag: Polygon2D) -> void:
	if body == player:
		player.set_checkpoint(Vector2(cp.global_position.x, SPAWN_Y))
		flag.color = Color(0.35, 0.8, 0.4)

func _on_kill_zone_body_entered(body: Node2D) -> void:
	if body == player:
		player.fall_damage()

func _on_goal_body_entered(body: Node2D) -> void:
	if body == player:
		win_label.visible = true
		player.set_physics_process(false)
		sfx_win.play()
		SaveManager.complete_level(LEVEL_ID, player.orbs)

func _on_leonie_talk(lines: Array) -> void:
	# Pause d'Eneko le temps du dialogue.
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	dialogue.start(lines)

func _on_dialogue_finished() -> void:
	player.set_physics_process(true)

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
