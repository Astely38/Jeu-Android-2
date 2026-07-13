extends Node2D
## Niveau 2 : « Le Temple Oublié ».
## Ascension verticale en zigzag dans les ruines d'un temple de pierre.
## Même schéma data-driven que level.gd (niveau 1) : PLATFORMS liste des
## plateformes à gravir, chacune (x, y, demi-largeur). Les paliers sont
## calibrés pour rester largement atteignables avec le saut d'Eneko (vitesse
## initiale -480, gravité 980 ⇒ portée max ≈ 170-185 px selon la montée) :
## chaque saut ne demande jamais plus de 80 px de décalage horizontal pour
## 60-80 px de montée, soit une marge confortable (35-47 % de la portée max)
## plutôt qu'un timing au pixel près. Les plateformes normales sont larges
## (demi-largeur 110, 220 px de large) et les paliers de repos/checkpoints
## encore plus (demi-largeur 200).

const ORB_SCENE := preload("res://scenes/orb.tscn")
const PATROL_SCENE := preload("res://scenes/enemy.tscn")
const SHADOW_SCENE := preload("res://scenes/shadow.tscn")
const LEONIE_SCENE := preload("res://scenes/leonie.tscn")

const LEVEL_ID := "level_2"
const STAND_OFFSET := 73.0   # écart entre le centre d'une plateforme et la hauteur où se tient un personnage
const COLLISION_H := 6.0     # demi-épaisseur de la collision des plateformes (voir _build_platforms)

const STONE := Color(0.42, 0.44, 0.5)
const STONE_DARK := Color(0.3, 0.32, 0.38)
const STONE_TOP := Color(0.56, 0.58, 0.64)

## Plateformes de pierre, du bas (entrée) vers le haut (sanctuaire).
## x = centre, y = centre vertical, hw = demi-largeur.
const PLATFORMS := [
	Vector2(150, 1900), Vector2(230, 1840), Vector2(150, 1780), Vector2(230, 1720),
	Vector2(310, 1660), Vector2(390, 1580), Vector2(460, 1580), Vector2(380, 1520),
	Vector2(460, 1460), Vector2(380, 1400), Vector2(460, 1340), Vector2(460, 1260),
	Vector2(380, 1200), Vector2(460, 1140), Vector2(380, 1080), Vector2(460, 1020),
	Vector2(460, 940), Vector2(380, 880), Vector2(460, 820), Vector2(380, 760),
	Vector2(440, 680), Vector2(440, 600),
]
const HALF_WIDTHS := [
	220, 110, 110, 110, 110, 200, 110, 110, 110, 110, 110, 200,
	110, 110, 110, 110, 200, 110, 110, 110, 200, 150,
]
const CHECKPOINT_IDX := [5, 11, 16, 20]
const LEONIE_IDX := 11
const TOP_IDX := 21

const PATROL_IDX := [3, 9, 14, 19]
const SHADOW_IDX := [5, 11, 16]
const TRAP_IDX := [7, 13, 18]

const LEONIE_LINES := [
	{ "name": "Léonie", "text": "Tu tiens bon, Eneko. Ce temple était un lieu de recueillement, avant que les ombres n'y montent la garde." },
	{ "name": "Léonie", "text": "Prends garde aux pièges de pierre : les anciens gardiens n'aimaient pas les visiteurs pressés." },
	{ "name": "Léonie", "text": "Le sanctuaire t'attend tout en haut. Ne regarde pas en bas." },
	{ "name": "Eneko", "text": "Trop tard." },
]

var sfx_win: AudioStreamPlayer

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var dialogue: CanvasLayer = $Dialogue

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

# --- Construction du niveau --------------------------------------------

## Colonnes de pierre en parallaxe + brume basse, ambiance de ruine.
func _build_decor() -> void:
	var bg: ParallaxBackground = $ParallaxBackground
	var far := ParallaxLayer.new()
	far.motion_scale = Vector2(0.3, 0.5)
	bg.add_child(far)
	var y := 200.0
	while y < 2000.0:
		_poly(far, _rect_points(14.0, -260.0, 260.0), Color(0.22, 0.22, 0.28, 0.55), Vector2(90.0, y))
		_poly(far, _rect_points(14.0, -260.0, 260.0), Color(0.22, 0.22, 0.28, 0.55), Vector2(870.0, y))
		y += 560.0

## Plateformes de pierre : bloc massif + face plus claire en surface.
## La collision réelle est volontairement fine (12px, ancrée sur la surface
## du dessus) : avec des marches en zigzag rapprochées verticalement, une
## collision aussi épaisse que le bloc visuel (100px) faisait chevaucher la
## plateforme du dessus avec un personnage debout 1-2 marches plus bas,
## le coinçant en étau (bloqué en place malgré une vitesse non nulle).
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
		_poly(body, _rect_points(hw, -50.0, 60.0), STONE)
		_poly(body, _rect_points(hw, 20.0, 60.0), STONE_DARK)
		_poly(body, _rect_points(hw, -50.0, -32.0), STONE_TOP)
		add_child(body)

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
	_poly(goal, PackedVector2Array([Vector2(-40, -60), Vector2(40, -60), Vector2(40, 66), Vector2(-40, 66)]), Color(1, 0.9, 0.5, 0.25))
	_poly(goal, PackedVector2Array([Vector2(-28, -55), Vector2(-20, -55), Vector2(-20, 70), Vector2(-28, 70)]), Color(0.85, 0.2, 0.15))
	_poly(goal, PackedVector2Array([Vector2(20, -55), Vector2(28, -55), Vector2(28, 70), Vector2(20, 70)]), Color(0.85, 0.2, 0.15))
	_poly(goal, PackedVector2Array([Vector2(-42, -70), Vector2(42, -70), Vector2(38, -58), Vector2(-38, -58)]), Color(0.78, 0.16, 0.12))
	_poly(goal, PackedVector2Array([Vector2(-32, -46), Vector2(32, -46), Vector2(32, -38), Vector2(-32, -38)]), Color(0.85, 0.2, 0.15))
	add_child(goal)
	goal.body_entered.connect(_on_goal_body_entered)

## Zone de chute, tout en bas du temple.
func _build_kill_zone() -> void:
	var kz := Area2D.new()
	kz.position = Vector2(350.0, 2150.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(1600, 100)
	shape.shape = rect
	kz.add_child(shape)
	add_child(kz)
	kz.body_entered.connect(_on_kill_zone_body_entered)

func _spawn_entities() -> void:
	for idx in PATROL_IDX:
		var pos := _stand_pos(idx)
		var e := PATROL_SCENE.instantiate()
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
		orb.position = Vector2(p.x, p.y - 110.0)
		add_child(orb)

## Vent ambiant en boucle + son de victoire.
func _setup_audio() -> void:
	var wind := AudioStreamPlayer.new()
	wind.stream = load("res://assets/sfx/wind.wav")
	wind.volume_db = -19.0
	wind.pitch_scale = 0.85
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
