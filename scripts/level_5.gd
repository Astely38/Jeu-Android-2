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
const CRUMBLE_SCENE := preload("res://scenes/crumble_platform.tscn")
const SPIRIT_SCENE := preload("res://scenes/spirit.tscn")

const GROUND_Y := 550.0
const SPAWN_Y := 477.0
const LEVEL_ID := "level_5"

const MARBLE := Color(0.82, 0.8, 0.74)
const MARBLE_DARK := Color(0.62, 0.6, 0.54)
const GOLD_TRIM := Color(0.82, 0.66, 0.28)

## Approche en 6 plateformes — dont un grand vide de 400 px franchissable
## uniquement par deux dalles effondrables — puis la grande arène du boss.
const PLATFORMS := [
	Vector2(230, 230), Vector2(850, 210), Vector2(1470, 230),
	Vector2(2090, 210), Vector2(2900, 200), Vector2(3520, 190),
	Vector2(4700, 900),  # l'arène du combat final
]
const CHECKPOINT_XS := [1470.0, 3520.0]
const PATROL_XS := [850.0, 1470.0, 2090.0, 2900.0, 3520.0]
const SHADOW_XS := [1300.0, 2150.0, 2950.0, 3600.0]
## Yūrei tireurs : l'un garde l'approche, l'autre surplombe le grand vide
## aux dalles effondrables.
const SPIRIT_XS := [1150.0, 2515.0]
const TRAP_XS := [700.0, 1950.0, 2800.0, 3450.0]
const PILLAR_XS := [3900.0, 4250.0, 5150.0, 5500.0]
## Dalles effondrables : x = centre, y = demi-largeur. Les deux premières
## sont le seul chemin au-dessus du grand vide — il faut enchaîner les
## sauts avant qu'elles ne s'écroulent.
const CRUMBLES := [Vector2(2430, 70), Vector2(2600, 70), Vector2(3215, 70)]
const ORBS := [
	Vector2(320, 420), Vector2(560, 385), Vector2(850, 420),
	Vector2(1150, 385), Vector2(1470, 420), Vector2(1800, 385),
	Vector2(2090, 420), Vector2(2430, 340), Vector2(2600, 340),
	Vector2(2900, 420), Vector2(3215, 340), Vector2(3520, 420),
]

const ARENA_TRIGGER_X := 3950.0
const ARENA_MIN_X := 3830.0
const ARENA_MAX_X := 5570.0
const BOSS_SPAWN_X := 5250.0
const LEVEL_END := 6000.0

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
	_build_crumbles()
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
	# Survol d'introduction : de l'arène du Gardien jusqu'à Eneko — le
	# joueur voit sa destination avant de faire le premier pas.
	player.intro_pan(Vector2(BOSS_SPAWN_X, 350.0), 2.2)

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

	# Rais de lumière dorée qui tombent en diagonale depuis le ciel,
	# comme au travers des verrières d'un sanctuaire.
	var shafts := ParallaxLayer.new()
	shafts.motion_scale = Vector2(0.2, 0.4)
	bg.add_child(shafts)
	var sx := 300.0
	var si := 0
	while sx < LEVEL_END:
		var sw := 55.0 + float(si * 31 % 45)
		_poly(shafts, PackedVector2Array([
			Vector2(-sw, 0), Vector2(sw * 0.4, 0),
			Vector2(sw * 1.7, 560), Vector2(sw * 0.3, 560),
		]), Color(1.0, 0.95, 0.75, 0.09), Vector2(sx, -10))
		sx += 520.0 + float(si * 43 % 240)
		si += 1

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

## Dalles effondrables (voir CRUMBLES) : posées au niveau du sol.
func _build_crumbles() -> void:
	for c in CRUMBLES:
		var pad := CRUMBLE_SCENE.instantiate()
		pad.half_width = c.y
		pad.position = Vector2(c.x, GROUND_Y - 44.0)
		add_child(pad)

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
	for x in SPIRIT_XS:
		var sp := SPIRIT_SCENE.instantiate()
		sp.position = Vector2(x, SPAWN_Y - 85.0)
		add_child(sp)
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
	boss_ui.visible = false
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
	# Attente en temps réel (insensible au ralenti) avant de reprendre.
	await get_tree().create_timer(1.0, true, false, true).timeout
	Engine.time_scale = 1.0
	sfx_win.play()
	SaveManager.complete_level(LEVEL_ID, player.orbs)
	var results := Challenge.finish_level()
	_show_endgame_recap(results)
	var t2 := create_tween()
	t2.tween_property(flash, "color:a", 0.0, 0.7)
	t2.finished.connect(layer.queue_free)

## Écran de fin de jeu : à la place du simple écran de victoire, le
## récapitulatif complet du périple — grade et meilleur temps de chacun
## des cinq niveaux — avec la performance du combat final en tête.
func _show_endgame_recap(results: Dictionary) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.11, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -330.0
	box.offset_right = 330.0
	box.offset_top = -235.0
	box.offset_bottom = 235.0
	box.add_theme_constant_override("separation", 6)
	layer.add_child(box)

	var title := Label.new()
	title.text = "La Voie du Sabre est accomplie !"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	box.add_child(title)

	var run := Label.new()
	run.text = "Gardien vaincu — Grade : %s — %s — Orbes : %d/%d" % [
		Challenge.grade_name(results["grade"]), _format_time(results["time"]),
		results["orbs"], results["total_orbs"],
	]
	run.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	run.add_theme_font_size_override("font_size", 18)
	box.add_child(run)

	box.add_child(_spacer(10.0))

	var header := Label.new()
	header.text = "Ton périple :"
	header.add_theme_font_size_override("font_size", 20)
	box.add_child(header)

	for id in SaveManager.LEVEL_ORDER:
		var lid: String = id
		box.add_child(_recap_row(lid))

	box.add_child(_spacer(12.0))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	box.add_child(buttons)

	var replay := _recap_button("Rejouer le niveau", Color(0.92, 0.65, 0.3))
	replay.pressed.connect(func(): get_tree().reload_current_scene())
	buttons.add_child(replay)
	var menu_b := _recap_button("Retour au menu", Color(0.6, 0.5, 0.45))
	menu_b.pressed.connect(_on_menu_pressed)
	buttons.add_child(menu_b)

## Une ligne du récapitulatif : nom du niveau, meilleur grade (coloré) et
## meilleur temps.
func _recap_row(row_level_id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_l := Label.new()
	name_l.text = str(SaveManager.LEVEL_NAMES.get(row_level_id, row_level_id))
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.add_theme_font_size_override("font_size", 18)
	row.add_child(name_l)
	var grade := SaveManager.best_grade(row_level_id)
	var grade_l := Label.new()
	grade_l.text = Challenge.grade_name(grade) if grade != "" else "—"
	if grade != "":
		grade_l.add_theme_color_override("font_color", Challenge.grade_color(grade))
	grade_l.add_theme_font_size_override("font_size", 18)
	row.add_child(grade_l)
	var bt := SaveManager.best_time(row_level_id)
	var time_l := Label.new()
	time_l.text = _format_time(bt) if bt > 0.0 else "—"
	time_l.custom_minimum_size = Vector2(70, 0)
	time_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_l.add_theme_font_size_override("font_size", 18)
	row.add_child(time_l)
	return row

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _recap_button(label_text: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = label_text
	b.custom_minimum_size = Vector2(220, 52)
	b.add_theme_font_size_override("font_size", 22)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.09, 0.17, 0.92)
	sb.border_color = accent
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8.0)
	var hov: StyleBoxFlat = sb.duplicate()
	hov.bg_color = Color(0.2, 0.15, 0.22, 0.95)
	var prs: StyleBoxFlat = sb.duplicate()
	prs.bg_color = Color(0.34, 0.2, 0.18, 0.95)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", prs)
	return b

func _format_time(seconds: float) -> String:
	var mins: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	return "%d:%02d" % [mins, secs]

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
