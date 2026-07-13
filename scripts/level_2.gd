extends Node2D
## Niveau 2 : « Le Temple Oublié ».
## Version simplifiée pour diagnostic — plateformes + ennemis de base.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const PATROL_SCENE := preload("res://scenes/enemy.tscn")
const SHADOW_SCENE := preload("res://scenes/shadow.tscn")
const LEONIE_SCENE := preload("res://scenes/leonie.tscn")

const LEVEL_ID := "level_2"

## Plateformes : zigzag gauche-droite, montée douce.
const PLATFORMS := [
	Vector2(300, 1900),
	Vector2(160, 1810), Vector2(420, 1730), Vector2(160, 1650), Vector2(420, 1570),
	Vector2(300, 1480),
	Vector2(420, 1390), Vector2(180, 1310), Vector2(420, 1230), Vector2(180, 1150),
	Vector2(300, 1060),
	Vector2(160, 970), Vector2(420, 890), Vector2(160, 810), Vector2(420, 730),
	Vector2(300, 640),
	Vector2(420, 550), Vector2(180, 470), Vector2(420, 390),
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

const PATROL_IDX := [2, 4, 7, 9, 12, 14, 17]
const SHADOW_IDX := [6, 13, 18]
const TRAP_IDX := [3, 8, 11, 16]

const LEONIE_LINES := [
	{ "name": "Léonie", "text": "Tu tiens bon, Eneko. Ce temple était un lieu de recueillement." },
	{ "name": "Léonie", "text": "Le sanctuaire t'attend tout en haut. Les torches guideront ton chemin." },
	{ "name": "Eneko", "text": "Je n'aime pas cet endroit..." },
]

const STONE := Color(0.45, 0.42, 0.38)
const STONE_TOP := Color(0.55, 0.52, 0.46)
const STONE_DARK := Color(0.32, 0.3, 0.26)

var sfx_win: AudioStreamPlayer

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var dialogue: CanvasLayer = $Dialogue

func _ready() -> void:
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

func _poly(parent: Node, points: PackedVector2Array, color: Color, pos := Vector2.ZERO) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.position = pos
	parent.add_child(p)
	return p

func _rect_points(hw: float, top: float, bot: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-hw, top), Vector2(hw, top),
		Vector2(hw, bot), Vector2(-hw, bot),
	])

func _stand_y(idx: int) -> Vector2:
	var p: Vector2 = PLATFORMS[idx]
	return Vector2(p.x, p.y - 73.0)

## Plateformes : dalles de pierre épaisses et visibles.
func _build_platforms() -> void:
	for i in PLATFORMS.size():
		var p: Vector2 = PLATFORMS[i]
		var hw: float = HALF_WIDTHS[i]
		var body := StaticBody2D.new()
		body.position = p
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(hw * 2.0, 24.0)
		shape.shape = rect
		body.add_child(shape)
		# Dalle visible épaisse (60px)
		_poly(body, _rect_points(hw, -12.0, 48.0), STONE)
		_poly(body, _rect_points(hw, -12.0, 0.0), STONE_TOP)
		_poly(body, _rect_points(hw, 30.0, 48.0), STONE_DARK)
		add_child(body)

## Torches sur les murs avec halo lumineux.
func _build_torches() -> void:
	var torch_xs := [50.0, 550.0]
	var y := 1850.0
	while y > 300.0:
		for tx in torch_xs:
			var t := Node2D.new()
			t.position = Vector2(tx, y)
			var dir := 1.0 if tx < 300.0 else -1.0
			var fx := 18.0 * dir
			# Support
			_poly(t, PackedVector2Array([
				Vector2(0, -2), Vector2(fx, -2), Vector2(fx, 2), Vector2(0, 2),
			]), Color(0.4, 0.3, 0.2))
			# Flamme
			_poly(t, PackedVector2Array([
				Vector2(fx - 5, -2), Vector2(fx + 5, -2),
				Vector2(fx + 3, -14), Vector2(fx, -22), Vector2(fx - 3, -14),
			]), Color(1.0, 0.6, 0.15))
			_poly(t, PackedVector2Array([
				Vector2(fx - 2, -4), Vector2(fx + 2, -4),
				Vector2(fx + 1, -12), Vector2(fx, -18), Vector2(fx - 1, -12),
			]), Color(1.0, 0.9, 0.4))
			# Halo
			var halo := Polygon2D.new()
			var pts := PackedVector2Array()
			var k := 0
			while k < 16:
				var a := k * TAU / 16.0
				pts.append(Vector2(cos(a) * 80.0 + fx, sin(a) * 80.0 - 10.0))
				k += 1
			halo.polygon = pts
			halo.color = Color(1.0, 0.7, 0.2, 0.08)
			t.add_child(halo)
			add_child(t)
		y -= 160.0

func _build_checkpoints() -> void:
	for idx in CHECKPOINT_IDX:
		var p: Vector2 = PLATFORMS[idx]
		var cp := Area2D.new()
		cp.position = Vector2(p.x, p.y - 80.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(60, 120)
		shape.shape = rect
		cp.add_child(shape)
		_poly(cp, PackedVector2Array([
			Vector2(-3, -60), Vector2(3, -60), Vector2(3, 60), Vector2(-3, 60),
		]), Color(0.35, 0.28, 0.2))
		var flag := _poly(cp, PackedVector2Array([
			Vector2(3, -60), Vector2(40, -50), Vector2(3, -38),
		]), Color(0.85, 0.75, 0.35))
		add_child(cp)
		cp.body_entered.connect(_on_checkpoint.bind(cp, flag))

func _build_traps() -> void:
	for idx in TRAP_IDX:
		var p: Vector2 = PLATFORMS[idx]
		var hw: float = HALF_WIDTHS[idx]
		var side := 1.0 if idx % 2 == 0 else -1.0
		var trap := Area2D.new()
		trap.position = Vector2(p.x + side * (hw - 28.0), p.y - 18.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(44, 24)
		shape.shape = rect
		trap.add_child(shape)
		_poly(trap, PackedVector2Array([
			Vector2(-22, 12), Vector2(22, 12), Vector2(22, 4), Vector2(-22, 4),
		]), Color(0.38, 0.24, 0.13))
		var j := 0
		while j < 3:
			var ox := -16.0 + j * 16.0
			_poly(trap, PackedVector2Array([
				Vector2(ox - 5, 4), Vector2(ox + 5, 4), Vector2(ox, -10),
			]), Color(0.52, 0.34, 0.18))
			j += 1
		add_child(trap)
		trap.body_entered.connect(_on_trap)

func _build_goal() -> void:
	var top: Vector2 = PLATFORMS[TOP_IDX]
	var goal := Area2D.new()
	goal.position = Vector2(top.x, top.y - 90.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 120)
	shape.shape = rect
	goal.add_child(shape)
	_poly(goal, PackedVector2Array([
		Vector2(-28, -50), Vector2(-20, -50), Vector2(-20, 60), Vector2(-28, 60),
	]), Color(0.85, 0.2, 0.15))
	_poly(goal, PackedVector2Array([
		Vector2(20, -50), Vector2(28, -50), Vector2(28, 60), Vector2(20, 60),
	]), Color(0.85, 0.2, 0.15))
	_poly(goal, PackedVector2Array([
		Vector2(-34, -58), Vector2(34, -58), Vector2(30, -48), Vector2(-30, -48),
	]), Color(0.78, 0.16, 0.12))
	add_child(goal)
	goal.body_entered.connect(_on_goal)

func _build_kill_zone() -> void:
	var kz := Area2D.new()
	kz.position = Vector2(300.0, 2100.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(1600, 100)
	shape.shape = rect
	kz.add_child(shape)
	add_child(kz)
	kz.body_entered.connect(_on_kill)

func _spawn_entities() -> void:
	for idx in PATROL_IDX:
		var e := PATROL_SCENE.instantiate()
		e.patrol_distance = maxf(30.0, HALF_WIDTHS[idx] - 45.0)
		e.position = _stand_y(idx)
		add_child(e)
	for idx in SHADOW_IDX:
		var s := SHADOW_SCENE.instantiate()
		s.position = _stand_y(idx)
		add_child(s)
	var leonie := LEONIE_SCENE.instantiate()
	leonie.position = _stand_y(LEONIE_IDX) + Vector2(60, 0)
	leonie.set_lines(LEONIE_LINES)
	leonie.talk.connect(_on_leonie_talk)
	add_child(leonie)
	var i := 1
	while i < PLATFORMS.size() - 1:
		if not (i in CHECKPOINT_IDX) and i != TOP_IDX:
			var orb := ORB_SCENE.instantiate()
			orb.position = Vector2(PLATFORMS[i].x, PLATFORMS[i].y - 80.0)
			add_child(orb)
		i += 1

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

func _on_checkpoint(body: Node2D, cp: Area2D, flag: Polygon2D) -> void:
	if body == player:
		player.set_checkpoint(Vector2(cp.global_position.x, cp.global_position.y + 30.0))
		flag.color = Color(0.35, 0.8, 0.4)

func _on_trap(body: Node2D) -> void:
	if body == player and body.has_method("take_damage"):
		body.take_damage(1, body.global_position + Vector2(0, 40))

func _on_kill(body: Node2D) -> void:
	if body == player:
		player.fall_damage()

func _on_goal(body: Node2D) -> void:
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
