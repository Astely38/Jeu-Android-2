extends LevelBase
## Niveau 20 : « Le Reflet Corrompu ».
## Une dernière approche à travers l'antichambre, puis l'arène où Eneko
## affronte seul ce que le tain brisé a fait de lui — son propre reflet,
## corrompu, qui connaît chacun de ses gestes avant même qu'il ne les
## fasse. Léonie n'apparaît pas ici : elle est restée à la porte.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const SANS_VISAGE_SCENE := preload("res://scenes/sans_visage.tscn")

const GROUND_Y := 550.0
const SPAWN_Y := 477.0
const LEVEL_ID := "level_20"

## Même royaume sans écho que les niveaux 16 à 19.
const VOID := Color(0.05, 0.04, 0.07)
const VOID_DARK := Color(0.025, 0.02, 0.035)
const ASH := Color(0.18, 0.15, 0.2)
const GLITCH_A := Color(0.85, 0.25, 0.55)
const GLITCH_B := Color(0.3, 0.75, 0.85)

const PLATFORM_THEME := {
	"top": ASH,
	"top_light": Color(0.28, 0.24, 0.3),
	"body_a": VOID,
	"body_b": VOID_DARK,
	"dark": VOID_DARK,
	"speck": Color(0.36, 0.32, 0.4),
	# Pierre taillée plutôt que le style "naturel" (racines, touffes d'herbe) :
	# ce monde sans écho n'a rien de vivant ni d'organique.
	"cut": true,
}

## Approche en 4 plateformes, puis la grande arène du combat.
const PLATFORMS := [
	Vector2(230, 230), Vector2(830, 210), Vector2(1450, 230), Vector2(2050, 210),
	Vector2(3050, 900),  # l'arène
]
const CHECKPOINT_XS := [1450.0]
const SANS_VISAGE_XS := [830.0, 2050.0]
## Dernières failles et dernier cratère du chapitre : le chaos accompagne
## Eneko jusqu'à la porte de l'arène, puis s'efface — le combat qui suit
## n'appartient qu'à lui et à son reflet.
const GLITCH_RIFT_XS := [500.0, 1750.0]
const ROCK_SLIDE_X := 1150.0
const ORBS := [
	Vector2(320, 420), Vector2(600, 420), Vector2(830, 385),
	Vector2(1120, 420), Vector2(1450, 385), Vector2(1750, 420),
	Vector2(2050, 385), Vector2(2350, 420),
]

const ARENA_TRIGGER_X := 2350.0
const ARENA_MIN_X := 2230.0
const ARENA_MAX_X := 3870.0
const BOSS_SPAWN_X := 3550.0
const LEVEL_END := 4000.0

const BOSS_INTRO_LINES := [
	{ "name": "???", "text": "Tu es venu. Je le savais — je me souviens de tout ce dont tu te souviens." },
	{ "name": "Eneko", "text": "Alors tu sais aussi pourquoi je suis là. Rends-moi ce que le tain a brisé." },
	{ "name": "Eneko", "text": "(Léonie me revient : « Lis ses coups, pare au bon moment — ou esquive d'une ruée et frappe juste après. Et prends garde : il a compté chacun de tes pas. »)" },
	{ "name": "???", "text": "Il n'y a rien à rendre, Eneko. Il n'y a qu'à choisir lequel de nous deux reste." },
]

var sfx_win: AudioStreamPlayer
var void_motes: CPUParticles2D
var boss: ReflectionBoss = null
var _arena_triggered := false
var _boss_intro_done := false
var _barriers: Array = []
var _glitches: Array = []
var _t := 0.0

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var next_button: Button = $WinLabel/NextButton
@onready var dialogue: CanvasLayer = $Dialogue
@onready var boss_ui: CanvasLayer = $BossUI
@onready var boss_bar_fill: Polygon2D = $BossUI/BarFill

func _ready() -> void:
	_build_decor()
	Atmosphere.add_foreground(self, Color(0.04, 0.03, 0.055, 0.42))
	_build_platforms()
	_build_checkpoints()
	_build_glitch_rifts()
	_build_rock_slide()
	_build_arena_trigger()
	_build_kill_zone(LEVEL_END, 900.0, 200.0)
	_spawn_entities()
	_spawn_boss()
	_setup_audio()
	_setup_ambient()
	player.set_land_dust_color(Color(0.26, 0.22, 0.3, 0.75))
	win_label.visible = false
	boss_ui.visible = false
	Music.play_level(LEVEL_ID)
	SaveManager.set_last_level(LEVEL_ID)
	# Relique cachée, tapie au tout début.
	var relic := Relic.new()
	relic.level_id = LEVEL_ID
	relic.position = Vector2(60, SPAWN_Y)
	add_child(relic)
	Challenge.start_level(LEVEL_ID, ORBS.size())
	dialogue.finished.connect(_on_dialogue_finished)
	menu_button.pressed.connect(_on_menu_pressed)
	next_button.visible = false
	player.intro_pan(Vector2(BOSS_SPAWN_X, 350.0), 2.2)

func _process(delta: float) -> void:
	_t += delta
	for g in _glitches:
		var node: Polygon2D = g["node"]
		node.modulate = GLITCH_A if sin(_t * 9.0 + float(g["phase"])) > 0.3 else GLITCH_B
		node.modulate.a = 0.35 + 0.35 * absf(sin(_t * 5.0 + float(g["phase"])))

func _physics_process(_delta: float) -> void:
	if void_motes != null and is_instance_valid(player):
		void_motes.position = Vector2(player.position.x, player.position.y - 260.0)

# --- Construction ------------------------------------------------------------

func _build_platforms() -> void:
	for p in PLATFORMS:
		var body := StaticBody2D.new()
		body.position = Vector2(p.x, GROUND_Y)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(p.y * 2.0, 100.0)
		shape.shape = rect
		body.add_child(shape)
		PlatformPainter.paint(body, p.y, PLATFORM_THEME)
		add_child(body)

func _build_checkpoints() -> void:
	for x in CHECKPOINT_XS:
		var cp := Area2D.new()
		cp.position = Vector2(x, GROUND_Y - 120.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(60, 120)
		shape.shape = rect
		cp.add_child(shape)
		_poly(cp, PackedVector2Array([
			Vector2(-3, -60), Vector2(3, -60), Vector2(3, 70), Vector2(-3, 70),
		]), Color(0.2, 0.18, 0.24))
		var flag := _poly(cp, PackedVector2Array([
			Vector2(3, -60), Vector2(40, -50), Vector2(3, -38),
		]), GLITCH_B)
		add_child(cp)
		cp.body_entered.connect(_on_checkpoint_body_entered.bind(cp, flag))

## Dernières failles glitchées du chapitre : voir GlitchRift (classe
## partagée avec les niveaux 16 à 19).
func _build_glitch_rifts() -> void:
	for x in GLITCH_RIFT_XS:
		var rift := GlitchRift.new()
		rift.position = Vector2(x, GROUND_Y - 50.0)
		rift.phase = x * 0.01
		rift.color_a = GLITCH_A
		rift.color_b = GLITCH_B
		add_child(rift)

func _build_rock_slide() -> void:
	var rs := RockSlide.new()
	rs.position = Vector2(ROCK_SLIDE_X, GROUND_Y - 50.0)
	rs.phase = ROCK_SLIDE_X * 0.017
	rs.tint = Color(0.5, 0.46, 0.56)
	add_child(rs)

## Zone d'entrée dans l'arène : déclenche le dialogue d'intro puis réveille
## le Reflet une fois la dernière réplique lue.
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

func _spawn_entities() -> void:
	for x in SANS_VISAGE_XS:
		var sv := SANS_VISAGE_SCENE.instantiate()
		sv.position = Vector2(x, SPAWN_Y)
		add_child(sv)
	for o in ORBS:
		var orb := ORB_SCENE.instantiate()
		orb.position = o
		add_child(orb)

func _spawn_boss() -> void:
	boss = ReflectionBoss.new()
	boss.position = Vector2(BOSS_SPAWN_X, SPAWN_Y)
	boss.set_arena_bounds(ARENA_MIN_X, ARENA_MAX_X)
	boss.health_changed.connect(_on_boss_health_changed)
	boss.phase_changed.connect(_on_boss_phase_changed)
	boss.defeated.connect(_on_boss_defeated)
	add_child(boss)

func _setup_ambient() -> void:
	var amb := AmbientDialogue.new()
	add_child(amb)
	amb.add_line(self, 900.0, "Eneko", "L'air lui-même semble retenir son souffle, ici.")
	amb.add_line(self, 1900.0, "Eneko", "Léonie n'a pas menti. Quelque chose m'attend, et ce n'est pas un ennemi ordinaire.")

func _setup_audio() -> void:
	var wind := AudioStreamPlayer.new()
	wind.stream = load("res://assets/sfx/wind.wav")
	wind.volume_db = -13.0
	wind.pitch_scale = 0.8
	add_child(wind)
	wind.finished.connect(wind.play)
	wind.play()
	sfx_win = AudioStreamPlayer.new()
	sfx_win.stream = load("res://assets/sfx/win.wav")
	sfx_win.volume_db = -4.0
	add_child(sfx_win)

# --- Décor --------------------------------------------------------------

func _build_decor() -> void:
	var bg: ParallaxBackground = $ParallaxBackground
	var mist_tex: Texture2D = load("res://assets/mist.svg")

	var sky := ParallaxLayer.new()
	sky.motion_scale = Vector2(0.05, 0.05)
	bg.add_child(sky)
	var haze := Sprite2D.new()
	haze.texture = mist_tex
	haze.modulate = Color(0.3, 0.26, 0.38, 0.4)
	haze.scale = Vector2(14.0, 6.0)
	haze.position = Vector2(600.0, 80.0)
	sky.add_child(haze)
	TextureLab.add_clouds(sky, 4, 30.0, 160.0, LEVEL_END, Color(0.13, 0.1, 0.17, 0.2))

	var far := ParallaxLayer.new()
	far.motion_scale = Vector2(0.14, 0.35)
	bg.add_child(far)
	var mx := -200.0
	var mi := 0
	while mx < LEVEL_END + 700.0:
		var mh := 180.0 + float(mi * 53 % 140)
		_poly(far, PackedVector2Array([
			Vector2(-260, 0), Vector2(-40, -mh + 30), Vector2(0, -mh), Vector2(70, -mh + 50), Vector2(260, 0),
		]), Color(0.07, 0.055, 0.1, 0.8), Vector2(mx, 600.0))
		mx += 340.0 + float(mi * 41 % 130)
		mi += 1

	# Un grand portique brisé se dresse derrière l'arène, dernier repère
	# avant le combat — sa silhouette rappelle un torii, mais le verre en
	# a remplacé le bois.
	var gate := ParallaxLayer.new()
	gate.motion_scale = Vector2(0.3, 0.6)
	bg.add_child(gate)
	var col_pts := PackedVector2Array([
		Vector2(-12, 0), Vector2(12, 0), Vector2(12, -240), Vector2(-12, -240),
	])
	_poly(gate, col_pts, Color(0.14, 0.11, 0.17), Vector2(BOSS_SPAWN_X + 170.0, 540))
	_poly(gate, col_pts, Color(0.14, 0.11, 0.17), Vector2(BOSS_SPAWN_X - 170.0, 540))
	var lintel_pts := PackedVector2Array([
		Vector2(-200, -232), Vector2(200, -232), Vector2(182, -260), Vector2(-182, -260),
	])
	_poly(gate, lintel_pts, Color(0.14, 0.11, 0.17), Vector2(BOSS_SPAWN_X, 540))
	for off in [Vector2(-2.0, 0), Vector2(2.0, 0)]:
		var edge_a := Line2D.new()
		edge_a.points = col_pts
		edge_a.closed = true
		edge_a.width = 1.6
		edge_a.position = off + Vector2(BOSS_SPAWN_X + 170.0, 540)
		edge_a.default_color = Color(GLITCH_A.r, GLITCH_A.g, GLITCH_A.b, 0.7) if off.x < 0.0 else Color(GLITCH_B.r, GLITCH_B.g, GLITCH_B.b, 0.7)
		gate.add_child(edge_a)
		var edge_b := Line2D.new()
		edge_b.points = col_pts
		edge_b.closed = true
		edge_b.width = 1.6
		edge_b.position = off + Vector2(BOSS_SPAWN_X - 170.0, 540)
		edge_b.default_color = edge_a.default_color
		gate.add_child(edge_b)
	var gate_glow := Sprite2D.new()
	gate_glow.texture = mist_tex
	gate_glow.modulate = Color(GLITCH_A.r, GLITCH_A.g, GLITCH_A.b, 0.3)
	gate_glow.scale = Vector2(9.0, 6.0)
	gate_glow.position = Vector2(BOSS_SPAWN_X, 400.0)
	gate.add_child(gate_glow)

	var gx := 90.0
	var gi := 0
	while gx < LEVEL_END:
		var gy := 55.0 + float(gi * 37 % 310)
		var gw := 28.0 + float(gi * 23 % 64)
		var col := GLITCH_A if gi % 2 == 0 else GLITCH_B
		var band := _poly(sky, PackedVector2Array([
			Vector2(-gw, -2), Vector2(gw, -2), Vector2(gw, 2), Vector2(-gw, 2),
		]), col, Vector2(gx, gy))
		_glitches.append({"node": band, "phase": float(gi) * 1.7})
		gx += 165.0 + float(gi * 47 % 150)
		gi += 1

	void_motes = CPUParticles2D.new()
	void_motes.texture = load("res://assets/leaf.svg")
	void_motes.amount = 34
	void_motes.lifetime = 7.0
	void_motes.preprocess = 7.0
	void_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	void_motes.emission_rect_extents = Vector2(560, 240)
	void_motes.direction = Vector2(0, 1)
	void_motes.spread = 180.0
	void_motes.gravity = Vector2(2, 6)
	void_motes.initial_velocity_min = 4.0
	void_motes.initial_velocity_max = 14.0
	void_motes.scale_amount_min = 0.3
	void_motes.scale_amount_max = 0.6
	void_motes.color = Color(0.34, 0.3, 0.4, 0.5)
	add_child(void_motes)

# --- Déroulement ----------------------------------------------------------

func _on_checkpoint_body_entered(body: Node2D, cp: Area2D, flag: Polygon2D) -> void:
	if body == player:
		if not cp.has_meta("lit"):
			cp.set_meta("lit", true)
			Atmosphere.spark_burst(self, cp.global_position, GLITCH_B)
		player.set_checkpoint(Vector2(cp.global_position.x, cp.global_position.y + 47.0))
		flag.color = Color(0.4, 0.85, 0.5, 0.95)

func _on_dialogue_finished() -> void:
	player.set_physics_process(true)
	if _arena_triggered and not _boss_intro_done:
		_boss_intro_done = true
		boss_ui.visible = true
		Music.play_combat()
		_raise_barriers()
		if is_instance_valid(boss):
			boss.activate()

## Barrières glitchées qui scellent l'arène pendant le combat.
func _raise_barriers() -> void:
	for bx in [ARENA_MIN_X - 10.0, ARENA_MAX_X + 10.0]:
		var b := StaticBody2D.new()
		b.position = Vector2(float(bx), GROUND_Y - 50.0)
		var sh := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(18, 380)
		sh.shape = rect
		sh.position = Vector2(0, -190)
		b.add_child(sh)
		var col := Polygon2D.new()
		col.polygon = PackedVector2Array([
			Vector2(-9, 0), Vector2(9, 0), Vector2(9, -380), Vector2(-9, -380),
		])
		col.color = Color(GLITCH_A.r, GLITCH_A.g, GLITCH_A.b, 0.3)
		b.add_child(col)
		var glow := Sprite2D.new()
		glow.texture = load("res://assets/mist.svg")
		glow.modulate = Color(GLITCH_B.r, GLITCH_B.g, GLITCH_B.b, 0.22)
		glow.scale = Vector2(1.6, 5.2)
		glow.position = Vector2(0, -190)
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

func _on_boss_phase_changed(_new_phase: int) -> void:
	pass

func _on_boss_defeated() -> void:
	player.set_physics_process(false)
	boss_ui.visible = false
	Music.play_level(LEVEL_ID)
	_drop_barriers()
	_play_victory_cinematic()

## Ralenti dramatique + fondu blanc, puis l'écran de victoire.
func _play_victory_cinematic() -> void:
	Engine.time_scale = 0.3
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)
	var t := create_tween()
	t.tween_property(flash, "color:a", 0.85, 0.3)
	await get_tree().create_timer(1.0, true, false, true).timeout
	Engine.time_scale = 1.0
	sfx_win.play()
	SaveManager.complete_level(LEVEL_ID, player.orbs)
	var results := Challenge.finish_level()
	_show_endgame_recap(results)
	var t2 := create_tween()
	t2.tween_property(flash, "color:a", 0.0, 0.7)
	t2.finished.connect(layer.queue_free)

## Écran de fin, épuré et paginé (ChapterRecap) : l'épilogue de la quête
## d'Eneko pour rallumer la Flamme d'Aube.
func _show_endgame_recap(results: Dictionary) -> void:
	var hud := player.get_node_or_null("HUD")
	if hud != null:
		hud.visible = false
	var recap := ChapterRecap.new()
	add_child(recap)
	recap.show_recap({
		"title": "Le reflet s'apaise enfin.",
		"accent": Color(0.85, 0.6, 0.85),
		"epilogue": "Le Reflet ne se brise pas : il se tait, enfin, et son visage — le visage d'Eneko — se referme sur lui-même comme une eau qui retrouve son calme. Le tain se ressoude, imparfait mais entier. Derrière la porte, Léonie attend ; elle ne dit rien, mais pour la première fois depuis le Versant Aveugle, son reflet à elle aussi se laisse voir, net, à ses côtés. Ce monde qui ne renvoyait plus rien recommence, doucement, à répondre.",
		"special": "Léonie : « Tu n'as pas vaincu ton reflet, Eneko. Tu l'as simplement laissé se reposer. C'est peut-être tout ce que la Flamme d'Aube a jamais demandé. »",
		"results": results,
		"hook": "Eneko referme les yeux, et pour la première fois depuis longtemps, il ne voit rien qui lui fasse peur.",
	})
