extends Node2D
## Niveau 5 : « Le Sanctuaire Final ».
## Une courte approche à travers un sanctuaire de marbre pâle et d'or, puis
## une arène où Eneko affronte seul le Gardien Corrompu — le boss final.
## Léonie n'apparaît pas ici : elle l'a annoncé au sommet de la montagne,
## Eneko doit terminer le chemin sans elle.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const PATROL_SCENE := preload("res://scenes/enemy.tscn")
const SHADOW_SCENE := preload("res://scenes/shadow.tscn")
const BOSS_SCENE := preload("res://scenes/boss.tscn")

const GROUND_Y := 550.0
const SPAWN_Y := 477.0
const LEVEL_ID := "level_5"

const MARBLE := Color(0.82, 0.8, 0.74)
const MARBLE_DARK := Color(0.62, 0.6, 0.54)
const GOLD_TRIM := Color(0.82, 0.66, 0.28)

## Approche courte (3 plateformes) puis une grande arène unique.
const PLATFORMS := [
	Vector2(230, 230), Vector2(820, 210), Vector2(1400, 220),
	Vector2(2450, 900),  # l'arène du combat final
]
const CHECKPOINT_XS := [1400.0]
const PATROL_XS := [650.0, 1300.0]
const SHADOW_XS := [900.0]
const TRAP_XS := [350.0]
const PILLAR_XS := [1750.0, 2100.0, 2800.0, 3150.0]
const ORBS := [
	Vector2(300, 420), Vector2(500, 385), Vector2(820, 420),
	Vector2(1050, 385), Vector2(1400, 420), Vector2(1600, 385),
]

const ARENA_TRIGGER_X := 1650.0
const ARENA_MIN_X := 1620.0
const ARENA_MAX_X := 3280.0
const BOSS_SPAWN_X := 3100.0
const LEVEL_END := 3650.0

const BOSS_INTRO_LINES := [
	{ "name": "???", "text": "Qui ose troubler le dernier repos du sanctuaire ?" },
	{ "name": "Eneko", "text": "Je suis venu mettre fin à la corruption. Une bonne fois pour toutes." },
	{ "name": "???", "text": "Alors viens. Voyons si ta lame vaut mieux que celles qui l'ont précédée." },
]
const VICTORY_LINE := "La Voie du Sabre est accomplie !"

var sfx_win: AudioStreamPlayer
var motes: CPUParticles2D
var boss: CharacterBody2D = null
var _arena_triggered := false
var _boss_intro_done := false

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var next_button: Button = $WinLabel/NextButton
@onready var dialogue: CanvasLayer = $Dialogue
@onready var boss_ui: CanvasLayer = $BossUI
@onready var boss_bar_fill: Polygon2D = $BossUI/BarFill

func _ready() -> void:
	_build_decor()
	_build_platforms()
	_build_pillars()
	_build_checkpoints()
	_build_traps()
	_build_arena_trigger()
	_build_kill_zone()
	_spawn_entities()
	_spawn_boss()
	_setup_audio()
	win_label.visible = false
	boss_ui.visible = false
	SaveManager.set_last_level(LEVEL_ID)
	Challenge.start_level(LEVEL_ID, ORBS.size())
	dialogue.finished.connect(_on_dialogue_finished)
	menu_button.pressed.connect(_on_menu_pressed)
	var next_scene: String = SaveManager.LEVEL_SCENES.get("level_6", "")
	next_button.visible = next_scene != ""
	if next_scene != "":
		next_button.pressed.connect(func(): get_tree().change_scene_to_file(next_scene))

func _physics_process(_delta: float) -> void:
	if motes != null and is_instance_valid(player):
		motes.position = Vector2(player.position.x, player.position.y - 200.0)

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

## Ciel doré pâle (déjà posé par le .tscn), montagnes lointaines nimbées de
## lumière, bannières blanc et or, et motes de lumière qui suivent Eneko.
func _build_decor() -> void:
	var bg: ParallaxBackground = $ParallaxBackground
	var mist_tex: Texture2D = load("res://assets/mist.svg")

	# Montagnes lointaines, baignées de lumière dorée.
	var far := ParallaxLayer.new()
	far.motion_scale = Vector2(0.1, 0.4)
	bg.add_child(far)
	var mx := -200.0
	var mi := 0
	while mx < LEVEL_END + 700.0:
		var mh := 200.0 + float(mi * 53 % 90)
		_poly(far, PackedVector2Array([
			Vector2(-260, 0), Vector2(0, -mh), Vector2(260, 0),
		]), Color(0.85, 0.78, 0.6, 0.5), Vector2(mx, 540))
		mx += 380.0 + float(mi * 41 % 120)
		mi += 1

	# Grand portique doré en fond, derrière l'arène : dernière image que
	# le joueur voit avant le combat.
	var gate := ParallaxLayer.new()
	gate.motion_scale = Vector2(0.3, 0.6)
	bg.add_child(gate)
	_poly(gate, PackedVector2Array([
		Vector2(-14, 0), Vector2(14, 0), Vector2(14, -260), Vector2(-14, -260),
	]), GOLD_TRIM, Vector2(BOSS_SPAWN_X + 180.0, 540))
	_poly(gate, PackedVector2Array([
		Vector2(-14, 0), Vector2(14, 0), Vector2(14, -260), Vector2(-14, -260),
	]), GOLD_TRIM, Vector2(BOSS_SPAWN_X - 180.0, 540))
	_poly(gate, PackedVector2Array([
		Vector2(-210, -250), Vector2(210, -250), Vector2(190, -280), Vector2(-190, -280),
	]), GOLD_TRIM, Vector2(BOSS_SPAWN_X, 540))
	var gate_glow := Sprite2D.new()
	gate_glow.texture = mist_tex
	gate_glow.modulate = Color(1.0, 0.9, 0.6, 0.35)
	gate_glow.scale = Vector2(9.0, 6.0)
	gate_glow.position = Vector2(BOSS_SPAWN_X, 400.0)
	gate.add_child(gate_glow)

	# Bannières blanc et or au-dessus de l'approche.
	var banners := ParallaxLayer.new()
	banners.motion_scale = Vector2(0.6, 1)
	bg.add_child(banners)
	var bx := 400.0
	while bx < ARENA_TRIGGER_X:
		_poly(banners, PackedVector2Array([
			Vector2(-14, 0), Vector2(14, 0), Vector2(14, 90), Vector2(0, 78), Vector2(-14, 90),
		]), Color(0.95, 0.9, 0.8, 0.85), Vector2(bx, 250.0))
		_poly(banners, _rect_points(2.0, -40.0, 90.0), GOLD_TRIM, Vector2(bx, 250.0))
		bx += 420.0

	# Motes de lumière dorée qui flottent autour d'Eneko.
	motes = CPUParticles2D.new()
	motes.texture = load("res://assets/leaf.svg")
	motes.amount = 20
	motes.lifetime = 6.0
	motes.preprocess = 6.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(500, 160)
	motes.direction = Vector2(0, -1)
	motes.spread = 180.0
	motes.gravity = Vector2(0, -6)
	motes.initial_velocity_min = 6.0
	motes.initial_velocity_max = 16.0
	motes.scale_amount_min = 0.4
	motes.scale_amount_max = 0.8
	motes.color = Color(1.0, 0.92, 0.6, 0.7)
	add_child(motes)

## Plateformes de marbre pâle avec filet d'or ; la dernière (l'arène) est
## une grande dalle continue sans trou.
func _build_platforms() -> void:
	for p in PLATFORMS:
		var body := StaticBody2D.new()
		body.position = Vector2(p.x, GROUND_Y)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(p.y * 2.0, 100.0)
		shape.shape = rect
		body.add_child(shape)
		_poly(body, _rect_points(p.y, -50.0, 450.0), MARBLE)
		_poly(body, _rect_points(p.y, 250.0, 450.0), MARBLE_DARK)
		_poly(body, _rect_points(p.y, -50.0, -40.0), GOLD_TRIM)
		_poly(body, _rect_points(p.y, -40.0, -34.0), MARBLE)
		add_child(body)

## Colonnes de marbre décoratives bordant l'arène (sans collision).
func _build_pillars() -> void:
	for x in PILLAR_XS:
		var pillar := Node2D.new()
		pillar.position = Vector2(x, GROUND_Y - 50.0)
		_poly(pillar, _rect_points(16.0, -220.0, 0.0), MARBLE)
		_poly(pillar, _rect_points(20.0, -230.0, -216.0), GOLD_TRIM)
		_poly(pillar, _rect_points(20.0, 0.0, 10.0), GOLD_TRIM)
		add_child(pillar)

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
		]), MARBLE_DARK)
		var flag := _poly(cp, PackedVector2Array([
			Vector2(3, -60), Vector2(40, -50), Vector2(3, -38),
		]), GOLD_TRIM)
		add_child(cp)
		cp.body_entered.connect(_on_checkpoint_body_entered.bind(cp, flag))

func _build_traps() -> void:
	for x in TRAP_XS:
		var trap := Area2D.new()
		trap.position = Vector2(x, GROUND_Y - 54.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(44, 24)
		shape.shape = rect
		trap.add_child(shape)
		_poly(trap, PackedVector2Array([
			Vector2(-22, 18), Vector2(22, 18), Vector2(22, 6), Vector2(-22, 6),
		]), MARBLE_DARK)
		for k in 3:
			var ox := -16.0 + k * 16.0
			_poly(trap, PackedVector2Array([
				Vector2(ox - 5, 6), Vector2(ox + 5, 6), Vector2(ox, -14),
			]), Color(0.55, 0.15, 0.15))
		add_child(trap)
		trap.body_entered.connect(_on_trap_body_entered)

func _on_trap_body_entered(body: Node2D) -> void:
	if body == player and body.has_method("take_damage"):
		body.take_damage(1, body.global_position + Vector2(0, 40))

## Zone d'entrée dans l'arène : déclenche le dialogue d'intro puis réveille
## le boss une fois la dernière réplique lue.
func _build_arena_trigger() -> void:
	var trigger := Area2D.new()
	trigger.position = Vector2(ARENA_TRIGGER_X, SPAWN_Y)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 200)
	shape.shape = rect
	trigger.add_child(shape)
	add_child(trigger)
	trigger.body_entered.connect(_on_arena_trigger_body_entered)

func _on_arena_trigger_body_entered(body: Node2D) -> void:
	if _arena_triggered or body != player:
		return
	_arena_triggered = true
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	dialogue.start(BOSS_INTRO_LINES)

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

func _spawn_boss() -> void:
	boss = BOSS_SCENE.instantiate()
	boss.position = Vector2(BOSS_SPAWN_X, SPAWN_Y)
	boss.set_arena_bounds(ARENA_MIN_X, ARENA_MAX_X)
	boss.health_changed.connect(_on_boss_health_changed)
	boss.phase_changed.connect(_on_boss_phase_changed)
	boss.defeated.connect(_on_boss_defeated)
	add_child(boss)

## Vent ambiant, plus doux et plus clair que dans les niveaux précédents.
func _setup_audio() -> void:
	var wind := AudioStreamPlayer.new()
	wind.stream = load("res://assets/sfx/wind.wav")
	wind.volume_db = -20.0
	wind.pitch_scale = 0.9
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

func _on_dialogue_finished() -> void:
	player.set_physics_process(true)
	if _arena_triggered and not _boss_intro_done:
		_boss_intro_done = true
		boss_ui.visible = true
		if is_instance_valid(boss):
			boss.activate()

func _on_boss_health_changed(current: int, max_health: int) -> void:
	boss_bar_fill.scale.x = float(current) / float(max_health)

func _on_boss_phase_changed(_new_phase: int) -> void:
	# Le Gardien entre en rage : deux Ombres viennent renforcer l'arène.
	for x in [ARENA_MIN_X + 90.0, ARENA_MAX_X - 90.0]:
		var s := SHADOW_SCENE.instantiate()
		s.position = Vector2(x, SPAWN_Y)
		add_child(s)

func _on_boss_defeated() -> void:
	player.set_physics_process(false)
	sfx_win.play()
	boss_ui.visible = false
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

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
