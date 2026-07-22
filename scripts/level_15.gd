extends LevelBase
## Chapitre III — Niveau 15 : « Le Reflet » (BOSS FINAL du chapitre).
## Au cœur du royaume-miroir, Eneko affronte son propre reflet détaché du verre.
## Mécanique évoluée : le Reflet miroite Eneko derrière un bouclier qui fait
## ricocher le sabre ; on ne l'expose qu'en RENVOYANT ses lames-miroir d'un coup
## de sabre. Le vaincre clôt le Chapitre III et ouvre sur le Chapitre IV.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const LEONIE_SCENE := preload("res://scenes/leonie.tscn")
const BOSS_SCENE := preload("res://scenes/reflet.tscn")

const GROUND_Y := 550.0
const SPAWN_Y := 477.0
const LEVEL_END := 4500.0
const LEVEL_ID := "level_15"

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
## Ancrages du Fil Spirituel dans l'arène : pour se repositionner en plein combat.
const ANCHOR_POS := [Vector2(2420, 300), Vector2(3780, 300)]

const ARENA_TRIGGER_X := 2280.0
const ARENA_MIN_X := 2240.0
const ARENA_MAX_X := 3960.0
const BOSS_SPAWN_X := 3100.0

const BOSS_INTRO_LINES := [
	{ "name": "Léonie", "text": "Le voici, Eneko : ton Reflet, né du miroir. Il te copie, il t'attend de l'autre côté. Son bouclier fera ricocher ta lame — l'attaquer de front ne sert à rien." },
	{ "name": "Le Reflet", "text": "Je suis toi. Chacun de tes gestes, je le connais déjà. On ne se vainc pas soi-même, petite flamme." },
	{ "name": "Léonie", "text": "Écoute : quand il lance ses lames-miroir, FRAPPE-les au sabre pour les lui renvoyer. Touché par son propre reflet, son bouclier se brise — alors il s'effondre à ta portée. C'est là, et là seulement, que tu peux le trancher !" },
	{ "name": "Eneko", "text": "Un reflet n'a pas de volonté. Moi, si. Voyons lequel de nous deux est réel." },
]

var sfx_win: AudioStreamPlayer
var glass_motes: CPUParticles2D
var boss: CharacterBody2D = null
var _shimmers: Array = []
var _arena_triggered := false
var _boss_intro_done := false
var _barriers: Array = []
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
	Atmosphere.add_foreground(self, Color(0.06, 0.08, 0.12, 0.3))
	_build_platforms()
	_build_anchors()
	_build_checkpoints()
	_build_arena_trigger()
	_build_kill_zone(LEVEL_END, 720.0)
	_spawn_entities()
	_spawn_boss()
	_setup_audio()
	_setup_ambient()
	player.set_land_dust_color(Color(0.7, 0.85, 0.95, 0.7))
	win_label.visible = false
	boss_ui.visible = false
	Music.play_level(LEVEL_ID)
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
	player.intro_pan(Vector2(BOSS_SPAWN_X, 330.0), 2.2)

func _process(delta: float) -> void:
	_t += delta
	for sh in _shimmers:
		var node: Polygon2D = sh["node"]
		node.modulate.a = 0.3 + 0.5 * (0.5 + 0.5 * sin(_t * 1.8 + float(sh["phase"])))

func _physics_process(_delta: float) -> void:
	if glass_motes != null and is_instance_valid(player):
		glass_motes.position = Vector2(player.position.x, player.position.y - 260.0)

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
	halo.scale = Vector2(10.0, 10.0)
	halo.position = Vector2(600.0, 150.0)
	sky.add_child(halo)
	var moon_pts := PackedVector2Array()
	for i in 22:
		var a := i * TAU / 22.0
		moon_pts.append(Vector2(cos(a) * 52.0, sin(a) * 52.0))
	_poly(sky, moon_pts, Color(0.88, 0.93, 1.0, 0.85), Vector2(600, 150))
	TextureLab.add_clouds(sky, 4, 70.0, 210.0, LEVEL_END, Color(0.6, 0.7, 0.85, 0.14))
	# Rayons de lune dramatiques, balayant l'arène du duel final.
	var rays := GodRays.new()
	rays.ray_count = 9
	rays.half_spread = 1.0
	rays.length = 1450.0
	rays.color = Color(0.75, 0.85, 1.0, 0.05)
	rays.position = Vector2(600, 150)
	sky.add_child(rays)

	# Éclats de miroir dressés, en silhouette : ancrent le "royaume-miroir"
	# en profondeur de champ, de l'approche jusqu'à l'arène du Reflet.
	var shards := ParallaxLayer.new()
	shards.motion_scale = Vector2(0.32, 0.6)
	bg.add_child(shards)
	var sx := 120.0
	var si := 0
	while sx < LEVEL_END + 300.0:
		var sh_h := 260.0 + float(si * 53 % 190)
		var sh_w := 42.0 + float(si * 29 % 32)
		var tip := Vector2(0, -sh_h)
		var pts := PackedVector2Array([
			Vector2(-sh_w * 0.4, 0), tip, Vector2(sh_w * 0.4, 0),
			Vector2(sh_w * 0.15, -sh_h * 0.32),
		])
		var col := Color(0.16, 0.2, 0.28, 0.5) if si % 2 == 0 else Color(0.1, 0.13, 0.19, 0.55)
		_poly(shards, pts, col, Vector2(sx, 560))
		# Liseré clair qui capte la lueur lunaire sur l'arête du tesson.
		var edge := _poly(shards, PackedVector2Array([
			Vector2(-2, 0), tip + Vector2(-1, 5), tip + Vector2(2, 3), Vector2(2, 0),
		]), Color(0.75, 0.88, 1.0, 0.0), Vector2(sx, 560))
		_shimmers.append({"node": edge, "phase": float(si) * 0.7})
		sx += 340.0 + float(si * 41 % 230)
		si += 1

	# Mer de verre.
	var sea := ParallaxLayer.new()
	sea.motion_scale = Vector2(0.25, 0.6)
	bg.add_child(sea)
	_poly(sea, PackedVector2Array([
		Vector2(-200, 470), Vector2(LEVEL_END + 400, 470),
		Vector2(LEVEL_END + 400, 640), Vector2(-200, 640),
	]), Color(0.12, 0.16, 0.22, 0.6))
	# Craquelures figées à la surface de la mer de verre, qui scintillent.
	var cx := 60.0
	var ci := 0
	while cx < LEVEL_END:
		var crack := PackedVector2Array([Vector2(0, 0)])
		var ang := -0.3 + float(ci % 5) * 0.15
		var seglen := 26.0
		for seg in 4:
			var last: Vector2 = crack[crack.size() - 1]
			ang += randf_range(-0.5, 0.5)
			crack.append(last + Vector2(cos(ang), sin(ang) * 0.4) * seglen)
		var cracks_line := Line2D.new()
		cracks_line.points = crack
		cracks_line.width = 1.6
		cracks_line.default_color = Color(0.8, 0.92, 1.0, 0.35)
		cracks_line.position = Vector2(cx, 500.0 + float(ci % 3) * 20.0)
		sea.add_child(cracks_line)
		# Scintillement indépendant (Line2D n'est pas un Polygon2D : ne rejoint
		# pas le tableau _shimmers, typé Polygon2D).
		var ctw := cracks_line.create_tween().set_loops()
		ctw.tween_property(cracks_line, "modulate:a", 0.75, 1.4 + float(ci % 3) * 0.3) \
			.set_trans(Tween.TRANS_SINE)
		ctw.tween_property(cracks_line, "modulate:a", 0.2, 1.4 + float(ci % 3) * 0.3) \
			.set_trans(Tween.TRANS_SINE)
		cx += 260.0 + float(ci * 37 % 200)
		ci += 1
	# Brume rasante au ras de la mer de verre.
	TextureLab.add_ground_mist(self, 7, 500.0, LEVEL_END, Color(0.62, 0.76, 0.92, 0.12))

	glass_motes = CPUParticles2D.new()
	glass_motes.texture = load("res://assets/leaf.svg")
	glass_motes.amount = 26
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
		add_child(body)
		var refl := _poly(self, PackedVector2Array([
			Vector2(-p.y, 50), Vector2(p.y, 50), Vector2(p.y * 0.7, 150), Vector2(-p.y * 0.7, 150),
		]), Color(0.5, 0.62, 0.78, 0.1), Vector2(p.x, GROUND_Y))
		refl.z_index = -1

func _build_anchors() -> void:
	for p in ANCHOR_POS:
		var a := SpiritAnchor.new()
		a.position = p
		add_child(a)

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

func _spawn_entities() -> void:
	PlatformPainter.build_sanctuary(self, 1850.0, GROUND_Y - 50.0)
	var leonie := LEONIE_SCENE.instantiate()
	leonie.position = Vector2(1850.0, SPAWN_Y)
	leonie.set_lines([
		{ "name": "Léonie", "text": "Le seuil du miroir, Eneko. Laisse ma lumière te soigner avant l'ultime épreuve." },
		{ "name": "Léonie", "text": "Ce qui t'attend porte ton visage. Ne te laisse pas prendre au piège de ta propre image." },
	])
	add_child(leonie)
	for o in ORBS:
		var orb := ORB_SCENE.instantiate()
		orb.position = o
		add_child(orb)

func _spawn_boss() -> void:
	boss = BOSS_SCENE.instantiate()
	boss.position = Vector2(BOSS_SPAWN_X, 430.0)
	boss.set_arena_bounds(ARENA_MIN_X, ARENA_MAX_X)
	boss.health_changed.connect(_on_boss_health_changed)
	boss.phase_changed.connect(_on_boss_phase_changed)
	boss.defeated.connect(_on_boss_defeated)
	add_child(boss)

func _setup_ambient() -> void:
	var amb := AmbientDialogue.new()
	add_child(amb)
	amb.add_line(self, 700.0, "Eneko", "Le verre me suit du regard. Quelque chose, au bout, attend que j'approche.")
	amb.add_line(self, 1500.0, "Eneko", "Mon reflet ne s'efface plus quand je détourne les yeux. Il m'attend.")

func _setup_audio() -> void:
	var wind := AudioStreamPlayer.new()
	wind.stream = load("res://assets/sfx/wind.wav")
	wind.volume_db = -13.0
	wind.pitch_scale = 1.0
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
		Music.play_combat()
		_raise_barriers()
		if is_instance_valid(boss):
			boss.activate()

func _on_boss_phase_changed(_new_phase: int) -> void:
	_flash(Color(0.5, 0.8, 1.0, 0.45))

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
		col.color = Color(0.55, 0.8, 1.0, 0.3)
		b.add_child(col)
		var glow := Sprite2D.new()
		glow.texture = load("res://assets/mist.svg")
		glow.modulate = Color(0.55, 0.8, 1.0, 0.22)
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
	Music.play_level(LEVEL_ID)
	_drop_barriers()
	_play_victory_cinematic()

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

func _play_victory_cinematic() -> void:
	Engine.time_scale = 0.3
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color(0.8, 0.92, 1.0, 0.0)
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

## Épilogue du Chapitre III (ChapterRecap épuré) : l'épilogue apparaît en fondu
## comme un écran-titre, puis au tap le bilan du combat, puis l'amorce du
## Chapitre IV. Fin de la progression actuelle (pas de « Chapitre suivant »).
func _show_chapter_recap(results: Dictionary) -> void:
	var hud := player.get_node_or_null("HUD")
	if hud != null:
		hud.visible = false
	var recap := ChapterRecap.new()
	add_child(recap)
	recap.show_recap({
		"title": "Le Reflet est brisé !",
		"accent": Color(0.6, 0.85, 1.0),
		"epilogue": "Le Reflet chancelle, son bouclier vole en mille éclats de verre — et dans chacun, un instant, Eneko voit son propre visage apaisé. La silhouette se dissout en une pluie d'argent. Le royaume-miroir se fissure, révélant, derrière le tain, une autre lumière, plus ancienne. Léonie s'approche, grave : « Ce n'était pas toi qu'il fallait vaincre, Eneko... mais ce qui, de l'autre côté, se servait de ton image. »",
		"results": results,
		"next_title": "Chapitre IV — Au-delà du Miroir",
		"hook": "Derrière le tain brisé s'ouvre un lieu que nul reflet ne renvoie : la source de toutes les images. Ce qui se cachait derrière le miroir n'a plus de visage à emprunter — et il a vu Eneko. La Voie du Sabre mène désormais au-delà du verre.",
		"next_scene": SaveManager.LEVEL_SCENES.get("level_16", ""),
	})
