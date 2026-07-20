extends Node2D
## Chapitre II — Niveau 10 : « Le Cœur de l'Ombre » (BOSS FINAL du chapitre).
## Au plus profond du Puits, Eneko affronte enfin la source de toute l'Ombre :
## une masse de nuit battante, protégée d'un bouclier, qui ne s'expose qu'en
## plongeant. Le vaincre tarit la source et clôt le Chapitre II.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const LEONIE_SCENE := preload("res://scenes/leonie.tscn")
const BOSS_SCENE := preload("res://scenes/coeur_ombre.tscn")
const MASK_SCENE := preload("res://scenes/split_shade.tscn")

const GROUND_Y := 550.0
const SPAWN_Y := 477.0
const LEVEL_END := 4500.0
const LEVEL_ID := "level_10"

const VOID := Color(0.1, 0.08, 0.14)
const VOID_DARK := Color(0.05, 0.04, 0.08)
const VIOLET := Color(0.55, 0.3, 0.85)

const PLATFORM_THEME := {
	"top": Color(0.24, 0.16, 0.3),
	"top_light": Color(0.6, 0.35, 0.85),
	"body_a": VOID,
	"body_b": Color(0.08, 0.07, 0.12),
	"dark": VOID_DARK,
	"speck": VIOLET,
}

const PLATFORMS := [
	Vector2(230, 230), Vector2(760, 210), Vector2(1300, 220),
	Vector2(1850, 210), Vector2(3100, 900),
]
const CHECKPOINT_XS := [1300.0]
const ORBS := [
	Vector2(330, 420), Vector2(560, 385), Vector2(760, 420),
	Vector2(1030, 385), Vector2(1300, 420), Vector2(1570, 385),
	Vector2(1850, 420), Vector2(2040, 385),
]

const ARENA_TRIGGER_X := 2280.0
const ARENA_MIN_X := 2240.0
const ARENA_MAX_X := 3960.0
const BOSS_SPAWN_X := 3100.0

const BOSS_INTRO_LINES := [
	{ "name": "Léonie", "text": "Le voilà, Eneko. Le Cœur de l'Ombre. Toutes ces âmes perdues, toute cette nuit... la source est là, devant toi." },
	{ "name": "L'Ombre", "text": "Tu as tranché mes masques et brûlé mes rivages. Approche donc, petite flamme. Je te reprendrai, comme j'ai repris tous les autres." },
	{ "name": "Léonie", "text": "Il est invulnérable tant qu'il plane, protégé par son bouclier. Ce n'est qu'en PLONGEANT qu'il s'expose : saute ses ondes, esquive ses orbes, et frappe-le pendant qu'il est à terre !" },
	{ "name": "Eneko", "text": "Pour toi, Léonie. Pour toutes les âmes. Ombre — ton règne s'achève ici." },
]

var sfx_win: AudioStreamPlayer
var void_motes: CPUParticles2D
var boss: CharacterBody2D = null
var _arena_triggered := false
var _boss_intro_done := false
var _barriers: Array = []
var _pulses: Array = []
var _t := 0.0

@onready var player: CharacterBody2D = $Player
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var next_button: Button = $WinLabel/NextButton
@onready var win_label: CanvasLayer = $WinLabel
@onready var dialogue: CanvasLayer = $Dialogue
@onready var boss_ui: CanvasLayer = $BossUI
@onready var boss_bar_fill: Polygon2D = $BossUI/BarFill

func _ready() -> void:
	_build_decor()
	Atmosphere.add_foreground(self, Color(0.09, 0.05, 0.14, 0.42))
	_build_platforms()
	_build_checkpoints()
	_build_arena_trigger()
	_build_kill_zone()
	_spawn_entities()
	_spawn_boss()
	_setup_audio()
	_setup_ambient()
	player.set_land_dust_color(Color(0.66, 0.42, 0.9, 0.8))
	win_label.visible = false
	boss_ui.visible = false
	Music.play_world(2)
	SaveManager.set_last_level(LEVEL_ID)
	# Relique cachée, tapie à gauche de l'apparition.
	var relic := Relic.new()
	relic.level_id = LEVEL_ID
	relic.position = Vector2(60, 466)
	add_child(relic)
	Challenge.start_level(LEVEL_ID, ORBS.size())
	dialogue.finished.connect(_on_dialogue_finished)
	menu_button.pressed.connect(_on_menu_pressed)
	next_button.visible = false
	player.intro_pan(Vector2(BOSS_SPAWN_X, 260.0), 2.4)

func _process(delta: float) -> void:
	_t += delta
	for pv in _pulses:
		var node: Polygon2D = pv["node"]
		node.modulate.a = 0.3 + 0.5 * (0.5 + 0.5 * sin(_t * 1.5 + float(pv["phase"])))

func _physics_process(_delta: float) -> void:
	if void_motes != null and is_instance_valid(player):
		void_motes.position = Vector2(player.position.x, player.position.y - 200.0)

# --- Construction ---------------------------------------------------------

func _poly(parent: Node, points: PackedVector2Array, color: Color, pos := Vector2.ZERO) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.position = pos
	parent.add_child(p)
	return p

func _build_decor() -> void:
	var bg: ParallaxBackground = $ParallaxBackground
	var mist_tex: Texture2D = load("res://assets/mist.svg")
	var sky := ParallaxLayer.new()
	sky.motion_scale = Vector2(0.05, 0.05)
	bg.add_child(sky)
	var aura := Sprite2D.new()
	aura.texture = mist_tex
	aura.modulate = Color(0.42, 0.2, 0.6, 0.42)
	aura.scale = Vector2(18.0, 9.0)
	aura.position = Vector2(480.0, 500.0)
	sky.add_child(aura)
	TextureLab.add_clouds(sky, 4, 40.0, 190.0, LEVEL_END, Color(0.2, 0.12, 0.28, 0.18))

	var crystals := ParallaxLayer.new()
	crystals.motion_scale = Vector2(0.35, 0.7)
	bg.add_child(crystals)
	var cx := 240.0
	var ci := 0
	while cx < LEVEL_END - 80.0:
		var cy := 140.0 + float(ci * 61 % 220)
		var ch := 28.0 + float(ci * 37 % 30)
		var shard := _poly(crystals, PackedVector2Array([
			Vector2(0, -ch), Vector2(10, -ch * 0.25), Vector2(4, ch), Vector2(-4, ch), Vector2(-10, -ch * 0.25),
		]), Color(0.5, 0.28, 0.8, 0.5), Vector2(cx, cy))
		_pulses.append({"node": shard, "phase": float(ci) * 0.7})
		cx += 300.0 + float(ci * 47 % 150)
		ci += 1

	void_motes = CPUParticles2D.new()
	void_motes.texture = load("res://assets/leaf.svg")
	void_motes.amount = 28
	void_motes.lifetime = 6.5
	void_motes.preprocess = 6.5
	void_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	void_motes.emission_rect_extents = Vector2(520, 200)
	void_motes.direction = Vector2(0, 1)
	void_motes.spread = 180.0
	void_motes.gravity = Vector2(4, 8)
	void_motes.initial_velocity_min = 6.0
	void_motes.initial_velocity_max = 18.0
	void_motes.scale_amount_min = 0.3
	void_motes.scale_amount_max = 0.7
	void_motes.color = Color(0.5, 0.32, 0.72, 0.55)
	add_child(void_motes)

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
		var vein_count: int = maxi(1, int(p.y / 160.0))
		for v in vein_count:
			var vx2: float = -p.y + 80.0 + v * ((p.y * 2.0 - 160.0) / maxf(1.0, float(vein_count)))
			var e := _poly(body, PackedVector2Array([
				Vector2(vx2 - 2, 28), Vector2(vx2 + 3, 28),
				Vector2(vx2 + 6, 94), Vector2(vx2 - 1, 104), Vector2(vx2 - 5, 62),
			]), Color(0.62, 0.32, 0.88, 0.0))
			_pulses.append({"node": e, "phase": float((v * 61 + pi * 47) % 628) * 0.01})
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
		]), Color(0.2, 0.16, 0.26))
		var flag := _poly(cp, PackedVector2Array([
			Vector2(3, -60), Vector2(40, -50), Vector2(3, -38),
		]), Color(0.7, 0.4, 0.95))
		add_child(cp)
		cp.body_entered.connect(_on_checkpoint_body_entered.bind(cp, flag))

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
	PlatformPainter.build_sanctuary(self, 1850.0, GROUND_Y - 50.0)
	var leonie := LEONIE_SCENE.instantiate()
	leonie.position = Vector2(1850.0, SPAWN_Y)
	leonie.set_lines([
		{ "name": "Léonie", "text": "C'est ici que tout se joue, Eneko. Laisse ma lumière te soigner une dernière fois." },
		{ "name": "Léonie", "text": "Quoi qu'il arrive au-delà de cette arène... je suis fière du chemin parcouru avec toi." },
	])
	add_child(leonie)
	for o in ORBS:
		var orb := ORB_SCENE.instantiate()
		orb.position = o
		add_child(orb)

func _spawn_boss() -> void:
	boss = BOSS_SCENE.instantiate()
	boss.position = Vector2(BOSS_SPAWN_X, 168.0)
	boss.set_arena_bounds(ARENA_MIN_X, ARENA_MAX_X)
	boss.health_changed.connect(_on_boss_health_changed)
	boss.phase_changed.connect(_on_boss_phase_changed)
	boss.defeated.connect(_on_boss_defeated)
	add_child(boss)

func _setup_ambient() -> void:
	var amb := AmbientDialogue.new()
	add_child(amb)
	amb.add_line(self, 700.0, "Eneko", "Plus rien ne bat, ici, sinon l'Ombre elle-même. La source est proche.")
	amb.add_line(self, 1500.0, "Eneko", "Un œil, immense, tourné vers moi. Nous y sommes. C'est la fin du voyage.")

func _setup_audio() -> void:
	var rumble := AudioStreamPlayer.new()
	rumble.stream = load("res://assets/sfx/wind.wav")
	rumble.volume_db = -11.0
	rumble.pitch_scale = 0.55
	add_child(rumble)
	rumble.finished.connect(rumble.play)
	rumble.play()
	sfx_win = AudioStreamPlayer.new()
	sfx_win.stream = load("res://assets/sfx/win.wav")
	sfx_win.volume_db = -4.0
	add_child(sfx_win)

# --- Déroulement ----------------------------------------------------------

func _on_checkpoint_body_entered(body: Node2D, cp: Area2D, flag: Polygon2D) -> void:
	if body == player:
		if not cp.has_meta("lit"):
			cp.set_meta("lit", true)
			Atmosphere.spark_burst(self, cp.global_position, Color(0.7, 0.45, 1.0))
		player.set_checkpoint(Vector2(cp.global_position.x, SPAWN_Y))
		flag.color = Color(0.4, 0.9, 0.5, 0.95)

func _on_kill_zone_body_entered(body: Node2D) -> void:
	if body == player:
		player.fall_damage()

func _on_arena_trigger_body_entered(body: Node2D) -> void:
	if _arena_triggered or body != player:
		return
	_arena_triggered = true
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	dialogue.start(BOSS_INTRO_LINES)

func _on_dialogue_finished() -> void:
	player.set_physics_process(true)
	if _arena_triggered and not _boss_intro_done:
		_boss_intro_done = true
		boss_ui.visible = true
		Music.play_boss(true)
		_raise_barriers()
		if is_instance_valid(boss):
			boss.activate()

## Le Cœur entre en rage : deux Masques d'Oni surgissent en renfort, avec un
## bref éclat pourpre.
func _on_boss_phase_changed(_new_phase: int) -> void:
	_flash(Color(0.6, 0.2, 0.8, 0.5))
	for x in [ARENA_MIN_X + 110.0, ARENA_MAX_X - 110.0]:
		var m := MASK_SCENE.instantiate()
		m.position = Vector2(x, SPAWN_Y - 70.0)
		add_child(m)

func _raise_barriers() -> void:
	for bx in [ARENA_MIN_X - 10.0, ARENA_MAX_X + 10.0]:
		var b := StaticBody2D.new()
		b.position = Vector2(float(bx), GROUND_Y - 50.0)
		var sh := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(18, 420)
		sh.shape = rect
		sh.position = Vector2(0, -210)
		b.add_child(sh)
		var col := Polygon2D.new()
		col.polygon = PackedVector2Array([
			Vector2(-9, 0), Vector2(9, 0), Vector2(9, -420), Vector2(-9, -420),
		])
		col.color = Color(0.7, 0.35, 0.95, 0.3)
		b.add_child(col)
		var glow := Sprite2D.new()
		glow.texture = load("res://assets/mist.svg")
		glow.modulate = Color(0.7, 0.35, 0.95, 0.22)
		glow.scale = Vector2(1.6, 5.8)
		glow.position = Vector2(0, -210)
		b.add_child(glow)
		add_child(b)
		_barriers.append(b)

func _drop_barriers() -> void:
	for b in _barriers:
		if is_instance_valid(b):
			var t := create_tween()
			t.tween_property(b, "modulate:a", 0.0, 0.8)
			t.finished.connect(b.queue_free)
	_barriers.clear()

func _on_boss_health_changed(current: int, max_health: int) -> void:
	boss_bar_fill.scale.x = float(current) / float(max_health)

func _on_boss_defeated() -> void:
	player.set_physics_process(false)
	boss_ui.visible = false
	Music.play_world(2)
	_drop_barriers()
	_play_victory_cinematic()

## Bref voile de couleur plein écran (transition de phase, impact).
func _flash(col: Color) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(col.r, col.g, col.b, 0.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	var t := create_tween()
	t.tween_property(rect, "color:a", col.a, 0.08)
	t.tween_property(rect, "color:a", 0.0, 0.5)
	t.finished.connect(layer.queue_free)

## Ralenti dramatique + implosion pourpre, puis l'épilogue du Chapitre II.
func _play_victory_cinematic() -> void:
	Engine.time_scale = 0.3
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color(0.85, 0.6, 1.0, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)
	var t := create_tween()
	t.tween_property(flash, "color:a", 0.9, 0.4)
	await get_tree().create_timer(1.1, true, false, true).timeout
	Engine.time_scale = 1.0
	sfx_win.play()
	SaveManager.complete_level(LEVEL_ID, player.orbs)
	var results := Challenge.finish_level()
	_show_chapter_recap(results)
	var t2 := create_tween()
	t2.tween_property(flash, "color:a", 0.0, 0.8)
	t2.finished.connect(layer.queue_free)

## Épilogue du Chapitre II (ChapterRecap épuré) : l'épilogue apparaît en fondu
## comme un écran-titre, puis au tap le bilan du combat, puis l'amorce du
## Chapitre III avec les boutons.
func _show_chapter_recap(results: Dictionary) -> void:
	# On masque le HUD de jeu (cœurs, orbes, boutons) pendant l'épilogue.
	var hud := player.get_node_or_null("HUD")
	if hud != null:
		hud.visible = false
	var recap := ChapterRecap.new()
	add_child(recap)
	recap.show_recap({
		"title": "L'Ombre est vaincue à sa source !",
		"accent": Color(0.8, 0.6, 1.0),
		"epilogue": "Le Cœur se replie sur lui-même et implose dans un éclat de lumière. Par-delà la mer de brume, la source de l'Ombre est tarie : les Rivages de Cendre s'apaisent, le volcan mort se tait, et le Puits se referme lentement. Eneko ressort à l'air libre, la lame encore fumante. Léonie, à ses côtés, brille un peu plus fort — le mal qui la retenait s'est enfin dissipé.",
		"results": results,
		"next_title": "Chapitre III — L'Écho dans le Noir",
		"hook": "La source est tarie... et pourtant, très loin dans le noir, un dernier écho a répondu à l'implosion du Cœur. Léonie l'a entendu, elle aussi. L'Ombre n'était-elle qu'un reflet ? La Voie du Sabre continue.",
		"next_scene": SaveManager.LEVEL_SCENES.get("level_11", ""),
	})

func _on_menu_pressed() -> void:
	Transition.goto("res://scenes/main_menu.tscn")
