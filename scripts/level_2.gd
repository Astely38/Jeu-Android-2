extends Node2D
## Niveau 2 : « Le Temple Oublié ».
## Ascension dans un temple ancien éclairé par des torches. Les plateformes
## forment un vrai zigzag gauche-droite avec de l'espace pour respirer.
## Morts-vivants squelettiques en guise de gardiens du temple.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const PATROL_SCENE := preload("res://scenes/enemy.tscn")
const SHADOW_SCENE := preload("res://scenes/shadow.tscn")
const LEONIE_SCENE := preload("res://scenes/leonie.tscn")

var UNDEAD_SCENE: PackedScene = null

const LEVEL_ID := "level_2"
const STAND_OFFSET := 73.0
const COLLISION_H := 6.0

const STONE := Color(0.35, 0.32, 0.28)
const STONE_DARK := Color(0.25, 0.22, 0.18)
const STONE_TOP := Color(0.45, 0.42, 0.36)
const MOSS := Color(0.3, 0.4, 0.25, 0.6)

## Plateformes : zigzag large gauche-droite avec de l'espace entre chaque.
## Le temple fait ~600px de large, les plateformes alternent entre x~160
## (gauche) et x~440 (droite), avec ~80px de montée par saut.
const PLATFORMS := [
	# Sol d'entrée (large)
	Vector2(300, 1900),
	# Montée gauche-droite, section 1
	Vector2(160, 1810), Vector2(420, 1730), Vector2(160, 1650), Vector2(420, 1570),
	# Palier checkpoint 1
	Vector2(300, 1480),
	# Section 2 : montée inversée
	Vector2(420, 1390), Vector2(180, 1310), Vector2(420, 1230), Vector2(180, 1150),
	# Palier checkpoint 2 + Léonie
	Vector2(300, 1060),
	# Section 3
	Vector2(160, 970), Vector2(420, 890), Vector2(160, 810), Vector2(420, 730),
	# Palier checkpoint 3
	Vector2(300, 640),
	# Section finale
	Vector2(420, 550), Vector2(180, 470), Vector2(420, 390),
	# Sommet (sanctuaire)
	Vector2(300, 290),
]
const HALF_WIDTHS := [
	240,
	120, 120, 120, 120,
	200,
	120, 120, 120, 120,
	200,
	120, 120, 120, 120,
	200,
	120, 120, 120,
	180,
]
const CHECKPOINT_IDX := [5, 10, 15]
const LEONIE_IDX := 10
const TOP_IDX := 19

const UNDEAD_IDX := [2, 4, 7, 9, 12, 14, 17]
const SHADOW_IDX := [6, 13, 18]
const TRAP_IDX := [3, 8, 11, 16]

## Torches : placées sur les murs du temple, alternant gauche/droite.
## Chaque entrée = (x, y) de la torche.
const TORCHES := [
	Vector2(40, 1830), Vector2(560, 1750),
	Vector2(40, 1670), Vector2(560, 1590),
	Vector2(40, 1500), Vector2(560, 1410),
	Vector2(40, 1330), Vector2(560, 1250),
	Vector2(40, 1170), Vector2(560, 1080),
	Vector2(40, 990), Vector2(560, 910),
	Vector2(40, 830), Vector2(560, 750),
	Vector2(40, 660), Vector2(560, 570),
	Vector2(40, 490), Vector2(560, 410),
	Vector2(300, 310),
]

const LEONIE_LINES := [
	{ "name": "Léonie", "text": "Tu tiens bon, Eneko. Ce temple était un lieu de recueillement, avant que les morts-vivants n'en fassent leur demeure." },
	{ "name": "Léonie", "text": "Ces guerriers squelettiques sont coriaces — il faut les frapper deux fois pour les abattre." },
	{ "name": "Léonie", "text": "Le sanctuaire t'attend tout en haut. Les torches guideront ton chemin." },
	{ "name": "Eneko", "text": "Je n'aime pas cet endroit..." },
]

var sfx_win: AudioStreamPlayer

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var dialogue: CanvasLayer = $Dialogue

func _ready() -> void:
	UNDEAD_SCENE = load("res://scenes/undead.tscn")
	_build_walls()
	_build_platforms()
	_build_torches()
	_build_checkpoints()
	_build_traps()
	_build_goal()
	_build_kill_zone()
	_spawn_entities()
	_setup_audio()
	win_label.visible = false
	SaveManager.set_last_level(LEVEL_ID)
	menu_button.pressed.connect(_on_menu_pressed)
	dialogue.finished.connect(_on_dialogue_finished)

# --- Aides géométriques ----------------------------------------------------

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

func _stand_pos(idx: int) -> Vector2:
	var p: Vector2 = PLATFORMS[idx]
	return Vector2(p.x, p.y - STAND_OFFSET)

# --- Construction du niveau ------------------------------------------------

## Murs latéraux du temple + fond sombre avec motifs de pierre.
func _build_walls() -> void:
	var bg: ParallaxBackground = $ParallaxBackground

	# Mur gauche
	var wall_layer := ParallaxLayer.new()
	wall_layer.motion_scale = Vector2(0, 0.95)
	bg.add_child(wall_layer)

	# Blocs de pierre irréguliers sur les murs
	var y := 100.0
	while y < 2100.0:
		# Mur gauche
		_poly(wall_layer, _rect_points(20.0, -40.0, 40.0), Color(0.22, 0.2, 0.18), Vector2(20.0, y))
		# Mur droit
		_poly(wall_layer, _rect_points(20.0, -40.0, 40.0), Color(0.22, 0.2, 0.18), Vector2(580.0, y))
		# Joints de pierre
		if int(y) % 160 == 0:
			_poly(wall_layer, PackedVector2Array([
				Vector2(0, -1), Vector2(40, -1), Vector2(40, 1), Vector2(0, 1),
			]), Color(0.15, 0.13, 0.11), Vector2(0, y))
			_poly(wall_layer, PackedVector2Array([
				Vector2(560, -1), Vector2(600, -1), Vector2(600, 1), Vector2(560, 1),
			]), Color(0.15, 0.13, 0.11), Vector2(0, y))
		y += 80.0

	# Colonnes de pierre décoratives en arrière-plan (parallaxe lente)
	var col_layer := ParallaxLayer.new()
	col_layer.motion_scale = Vector2(0.2, 0.6)
	bg.add_child(col_layer)
	for cx in [120.0, 480.0]:
		y = 300.0
		while y < 1800.0:
			_poly(col_layer, _rect_points(18.0, -120.0, 120.0), Color(0.28, 0.26, 0.24, 0.4), Vector2(cx, y))
			# Chapiteau
			_poly(col_layer, _rect_points(24.0, -130.0, -120.0), Color(0.32, 0.3, 0.28, 0.4), Vector2(cx, y))
			y += 320.0

## Plateformes de pierre : dalles fines posées dans le vide, pas de piliers.
func _build_platforms() -> void:
	for i in PLATFORMS.size():
		var p: Vector2 = PLATFORMS[i]
		var hw: float = HALF_WIDTHS[i]
		var body := StaticBody2D.new()
		body.position = p
		var shape := CollisionShape2D.new()
		shape.position = Vector2(0, -50.0 + COLLISION_H)
		var rect := RectangleShape2D.new()
		rect.size = Vector2(hw * 2.0, COLLISION_H * 2.0)
		shape.shape = rect
		body.add_child(shape)
		# Dalle de pierre (épaisseur 30px seulement)
		_poly(body, _rect_points(hw, -50.0, -20.0), STONE)
		# Face supérieure plus claire
		_poly(body, _rect_points(hw, -50.0, -40.0), STONE_TOP)
		# Dessous ombré
		_poly(body, _rect_points(hw, -25.0, -20.0), STONE_DARK)
		# Mousse sur les bords des grands paliers
		if hw >= 180:
			_poly(body, PackedVector2Array([
				Vector2(-hw, -50), Vector2(-hw + 20, -50),
				Vector2(-hw + 16, -54), Vector2(-hw + 4, -52),
			]), MOSS)
			_poly(body, PackedVector2Array([
				Vector2(hw - 20, -50), Vector2(hw, -50),
				Vector2(hw - 4, -54), Vector2(hw - 16, -52),
			]), MOSS)
		add_child(body)

## Torches murales avec flamme animée et halo lumineux.
func _build_torches() -> void:
	for t in TORCHES:
		var torch_node := Node2D.new()
		torch_node.position = t

		# Support mural (bras métallique)
		var is_left := t.x < 300.0
		var arm_dir := 1.0 if is_left else -1.0
		_poly(torch_node, PackedVector2Array([
			Vector2(0, -4), Vector2(20 * arm_dir, -4),
			Vector2(20 * arm_dir, 0), Vector2(0, 0),
		]), Color(0.35, 0.3, 0.25))
		# Bol de la torche
		_poly(torch_node, PackedVector2Array([
			Vector2(20 * arm_dir - 8, -8), Vector2(20 * arm_dir + 8, -8),
			Vector2(20 * arm_dir + 5, 2), Vector2(20 * arm_dir - 5, 2),
		]), Color(0.4, 0.3, 0.2))

		var flame_x := 20.0 * arm_dir

		# Halo lumineux (grand cercle semi-transparent orangé)
		var halo := Polygon2D.new()
		var halo_pts := PackedVector2Array()
		for i in 24:
			var angle := i * TAU / 24.0
			halo_pts.append(Vector2(cos(angle) * 110.0 + flame_x, sin(angle) * 110.0 - 16.0))
		halo.polygon = halo_pts
		halo.color = Color(1.0, 0.7, 0.25, 0.07)
		torch_node.add_child(halo)

		# Halo intérieur plus lumineux
		var halo2 := Polygon2D.new()
		var halo2_pts := PackedVector2Array()
		for i in 16:
			var angle := i * TAU / 16.0
			halo2_pts.append(Vector2(cos(angle) * 50.0 + flame_x, sin(angle) * 50.0 - 16.0))
		halo2.polygon = halo2_pts
		halo2.color = Color(1.0, 0.65, 0.2, 0.12)
		torch_node.add_child(halo2)

		# Flamme (polygone orangé-jaune)
		_poly(torch_node, PackedVector2Array([
			Vector2(flame_x - 6, -6), Vector2(flame_x + 6, -6),
			Vector2(flame_x + 4, -18), Vector2(flame_x, -28),
			Vector2(flame_x - 4, -18),
		]), Color(1.0, 0.6, 0.15))
		# Cœur de flamme jaune
		_poly(torch_node, PackedVector2Array([
			Vector2(flame_x - 3, -8), Vector2(flame_x + 3, -8),
			Vector2(flame_x + 2, -16), Vector2(flame_x, -22),
			Vector2(flame_x - 2, -16),
		]), Color(1.0, 0.9, 0.4))

		add_child(torch_node)

func _build_checkpoints() -> void:
	for idx in CHECKPOINT_IDX:
		var p: Vector2 = PLATFORMS[idx]
		var cp := Area2D.new()
		cp.position = Vector2(p.x, p.y - 120.0)
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

## Pièges en bois : pieux taillés près du bord d'une plateforme.
func _build_traps() -> void:
	for idx in TRAP_IDX:
		var p: Vector2 = PLATFORMS[idx]
		var hw: float = HALF_WIDTHS[idx]
		var side := 1.0 if idx % 2 == 0 else -1.0
		var trap := Area2D.new()
		trap.position = Vector2(p.x + side * (hw - 28.0), p.y - 54.0)
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

func _build_goal() -> void:
	var top: Vector2 = PLATFORMS[TOP_IDX]
	var goal := Area2D.new()
	goal.position = Vector2(top.x, top.y - 130.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 140)
	shape.shape = rect
	goal.add_child(shape)
	# Torii sacré au sommet
	_poly(goal, PackedVector2Array([Vector2(-40, -60), Vector2(40, -60), Vector2(40, 66), Vector2(-40, 66)]), Color(1, 0.9, 0.5, 0.25))
	_poly(goal, PackedVector2Array([Vector2(-28, -55), Vector2(-20, -55), Vector2(-20, 70), Vector2(-28, 70)]), Color(0.85, 0.2, 0.15))
	_poly(goal, PackedVector2Array([Vector2(20, -55), Vector2(28, -55), Vector2(28, 70), Vector2(20, 70)]), Color(0.85, 0.2, 0.15))
	_poly(goal, PackedVector2Array([Vector2(-42, -70), Vector2(42, -70), Vector2(38, -58), Vector2(-38, -58)]), Color(0.78, 0.16, 0.12))
	_poly(goal, PackedVector2Array([Vector2(-32, -46), Vector2(32, -46), Vector2(32, -38), Vector2(-32, -38)]), Color(0.85, 0.2, 0.15))
	add_child(goal)
	goal.body_entered.connect(_on_goal_body_entered)

func _build_kill_zone() -> void:
	var kz := Area2D.new()
	kz.position = Vector2(300.0, 2150.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(1600, 100)
	shape.shape = rect
	kz.add_child(shape)
	add_child(kz)
	kz.body_entered.connect(_on_kill_zone_body_entered)

func _spawn_entities() -> void:
	var enemy_scene: PackedScene = UNDEAD_SCENE if UNDEAD_SCENE != null else PATROL_SCENE
	for idx in UNDEAD_IDX:
		var pos := _stand_pos(idx)
		var e := enemy_scene.instantiate()
		e.patrol_distance = maxf(30.0, HALF_WIDTHS[idx] - 45.0)
		e.position = pos
		add_child(e)
	for idx in SHADOW_IDX:
		var s := SHADOW_SCENE.instantiate()
		s.position = _stand_pos(idx)
		add_child(s)

	var leonie := LEONIE_SCENE.instantiate()
	leonie.position = _stand_pos(LEONIE_IDX) + Vector2(60, 0)
	leonie.set_lines(LEONIE_LINES)
	leonie.talk.connect(_on_leonie_talk)
	add_child(leonie)

	for i in range(1, PLATFORMS.size() - 1):
		if i in CHECKPOINT_IDX or i == TOP_IDX:
			continue
		var p: Vector2 = PLATFORMS[i]
		var orb := ORB_SCENE.instantiate()
		orb.position = Vector2(p.x, p.y - 100.0)
		add_child(orb)

func _setup_audio() -> void:
	var wind := AudioStreamPlayer.new()
	wind.stream = load("res://assets/sfx/wind.wav")
	wind.volume_db = -22.0
	wind.pitch_scale = 0.7
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
		player.set_checkpoint(Vector2(cp.global_position.x, cp.global_position.y + 47.0))
		flag.color = Color(0.35, 0.8, 0.4)

func _on_trap_body_entered(body: Node2D) -> void:
	if body == player and body.has_method("take_damage"):
		body.take_damage(1, body.global_position + Vector2(0, 40))

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
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	dialogue.start(lines)

func _on_dialogue_finished() -> void:
	player.set_physics_process(true)

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
