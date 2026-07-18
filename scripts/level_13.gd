extends Node2D
## Chapitre III — Niveau 13 : « La Poursuite du Reflet ».
## Le Reflet d'Eneko s'est détaché du miroir : une marée de nuit qui déferle
## depuis la gauche et ne s'arrête jamais. Pas d'exploration ici, pas de
## dalles qui s'effondrent — une seule règle : COURIR vers la porte d'argent
## sans jamais se laisser rattraper. Le mur reste à une longueur d'écran tant
## qu'on avance ; hésiter (pièges, Masques, saut manqué) le laisse fondre sur
## Eneko. Le Double Saut aide à garder le rythme.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const MASK_SCENE := preload("res://scenes/split_shade.tscn")
const LEONIE_SCENE := preload("res://scenes/leonie.tscn")

const GROUND_Y := 550.0
const SPAWN_Y := 477.0
const LEVEL_END := 7300.0
const GOAL_X := 6950.0
const LEVEL_ID := "level_13"

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

## Plateformes à flux continu vers la droite (trous ≤ 150 px, franchissables
## sans jamais devoir reculer).
const PLATFORMS := [
	Vector2(230, 230), Vector2(850, 250), Vector2(1470, 230),
	Vector2(2080, 200), Vector2(2680, 240), Vector2(3300, 230),
	Vector2(3920, 210), Vector2(4540, 200), Vector2(5160, 250),
	Vector2(5780, 200), Vector2(6420, 240), Vector2(7040, 280),
]
const CHECKPOINT_XS := [1900.0, 3900.0, 5600.0]
## Obstacles à esquiver EN COURANT (jamais des passages obligés).
const TRAP_XS := [1500.0, 3350.0, 4600.0]
const MASK_XS := [2680.0, 5160.0]
const STELE_XS := [500.0, 3000.0, 5400.0, 6700.0]
## Traînée d'orbes à cueillir dans la fuite.
const ORBS := [
	Vector2(320, 420), Vector2(560, 385), Vector2(850, 420),
	Vector2(1150, 385), Vector2(1470, 420), Vector2(1780, 385),
	Vector2(2080, 420), Vector2(2380, 385), Vector2(2680, 420),
	Vector2(3000, 385), Vector2(3300, 420), Vector2(3610, 385),
	Vector2(3920, 420), Vector2(4230, 385), Vector2(4540, 420),
	Vector2(4850, 385), Vector2(5160, 420), Vector2(5470, 385),
	Vector2(5780, 420), Vector2(6100, 385), Vector2(6420, 420),
	Vector2(6730, 385),
]
## Orbes-reflet en hauteur (Double Saut), à saisir sans casser sa foulée.
const HIGH_ORBS := [
	Vector2(1470, 300), Vector2(3920, 300), Vector2(5780, 300),
]

## --- Réglages de la poursuite --------------------------------------------
const WALL_START_X := -520.0
## Le mur avance de lui-même quand Eneko ralentit…
const WALL_CREEP := 170.0
## …mais ne reste jamais à plus d'une longueur d'écran derrière lui.
const WALL_MAX_LEAD := 560.0
## Contact : le Reflet mord si Eneko passe cette limite.
const WALL_CONTACT := 44.0

const LEONIE_LINES := [
	{ "name": "Léonie", "text": "Eneko, prends garde — ton reflet s'est détaché du miroir. Il te suit, et il ne connaît pas la pitié." },
	{ "name": "Léonie", "text": "Ne te retourne pas, ne t'arrête jamais. Cours vers la porte d'argent, et ne laisse pas la nuit te rattraper !" },
	{ "name": "Eneko", "text": "Alors je courrai plus vite que ma propre ombre. Jusqu'à la porte." },
]

var sfx_win: AudioStreamPlayer
var glass_motes: CPUParticles2D
var _shimmers: Array = []
var _t := 0.0
## Le mur-Reflet.
var _wall: Node2D
var _wall_x := WALL_START_X
var _prev_px := 0.0
var _armed := false
var _reflet_fig: Node2D
var _ink: CPUParticles2D

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var next_button: Button = $WinLabel/NextButton
@onready var dialogue: CanvasLayer = $Dialogue

func _ready() -> void:
	_build_decor()
	Atmosphere.add_foreground(self, Color(0.05, 0.06, 0.11, 0.34))
	_build_platforms()
	_build_steles()
	_build_checkpoints()
	_build_traps()
	_build_goal()
	_build_kill_zone()
	_build_wall()
	_spawn_entities()
	_setup_audio()
	_setup_ambient()
	player.set_land_dust_color(Color(0.7, 0.85, 0.95, 0.7))
	win_label.visible = false
	Music.play_world(2)
	SaveManager.set_last_level(LEVEL_ID)
	# Relique cachée, en hauteur sur le parcours (Double Saut, sans s'arrêter).
	var relic := Relic.new()
	relic.level_id = LEVEL_ID
	relic.position = Vector2(4540, 300)
	add_child(relic)
	Challenge.start_level(LEVEL_ID, ORBS.size() + HIGH_ORBS.size())
	dialogue.finished.connect(_on_dialogue_finished)
	menu_button.pressed.connect(_on_menu_pressed)
	var next_scene: String = SaveManager.LEVEL_SCENES.get("level_14", "")
	next_button.visible = next_scene != ""
	if next_scene != "":
		next_button.pressed.connect(func(): Transition.goto(next_scene))
	_prev_px = player.global_position.x
	# Pas de survol qui dévoile le niveau : Léonie avertit, puis la fuite
	# commence. Eneko reste figé le temps de la mise en garde.
	player.set_physics_process(false)
	dialogue.start(LEONIE_LINES)

func _process(delta: float) -> void:
	_t += delta
	for sh in _shimmers:
		var node: Polygon2D = sh["node"]
		node.modulate.a = 0.3 + 0.5 * (0.5 + 0.5 * sin(_t * 1.8 + float(sh["phase"])))
	if _reflet_fig != null:
		_reflet_fig.position.y = -70.0 + sin(_t * 3.0) * 6.0
		_reflet_fig.scale.x = 1.0 + 0.05 * sin(_t * 5.0)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	if glass_motes != null:
		glass_motes.position = Vector2(player.position.x, player.position.y - 300.0)
	# Sécurité : si la poursuite n'est pas encore armée mais qu'Eneko file déjà,
	# on l'arme (au cas où le dialogue aurait été passé autrement).
	if not _armed and player.global_position.x > 520.0:
		_armed = true
	# Le Reflet ne progresse que lorsqu'Eneko a la main (pas en cinématique).
	if _armed and player.is_physics_processing():
		_advance_wall(delta)
	# Retour à un checkpoint (téléportation en arrière) : on repousse le mur
	# pour ne pas rattraper Eneko à la seconde même où il réapparaît.
	if player.global_position.x < _prev_px - 300.0:
		_wall_x = player.global_position.x - 520.0
	_prev_px = player.global_position.x
	if _wall != null:
		_wall.position.x = _wall_x

func _advance_wall(delta: float) -> void:
	_wall_x += WALL_CREEP * delta
	_wall_x = maxf(_wall_x, player.global_position.x - WALL_MAX_LEAD)
	if player.global_position.x < _wall_x + WALL_CONTACT:
		if player.has_method("take_damage"):
			player.take_damage(1, Vector2(_wall_x - 120.0, player.global_position.y))

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
	var halo := Sprite2D.new()
	halo.texture = mist_tex
	halo.modulate = Color(0.7, 0.82, 0.95, 0.4)
	halo.scale = Vector2(9.0, 9.0)
	halo.position = Vector2(720.0, 120.0)
	sky.add_child(halo)
	var moon_pts := PackedVector2Array()
	for i in 22:
		var a := i * TAU / 22.0
		moon_pts.append(Vector2(cos(a) * 46.0, sin(a) * 46.0))
	_poly(sky, moon_pts, Color(0.88, 0.93, 1.0, 0.85), Vector2(720, 120))
	TextureLab.add_clouds(sky, 5, 70.0, 210.0, LEVEL_END, Color(0.6, 0.7, 0.85, 0.14))

	# Mer de verre lointaine.
	var sea := ParallaxLayer.new()
	sea.motion_scale = Vector2(0.25, 0.6)
	bg.add_child(sea)
	_poly(sea, PackedVector2Array([
		Vector2(-200, 470), Vector2(LEVEL_END + 400, 470),
		Vector2(LEVEL_END + 400, 640), Vector2(-200, 640),
	]), Color(0.12, 0.16, 0.22, 0.6))

	glass_motes = CPUParticles2D.new()
	glass_motes.texture = load("res://assets/leaf.svg")
	glass_motes.amount = 28
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
		var e := _poly(body, PackedVector2Array([
			Vector2(-6, 30), Vector2(-1, 30), Vector2(2, 96), Vector2(-4, 104), Vector2(-9, 66),
		]), Color(0.5, 0.85, 0.95, 0.0))
		_shimmers.append({"node": e, "phase": float(pi * 71 % 628) * 0.01})
		add_child(body)
		var refl := _poly(self, PackedVector2Array([
			Vector2(-p.y, 50), Vector2(p.y, 50), Vector2(p.y * 0.7, 150), Vector2(-p.y * 0.7, 150),
		]), Color(0.5, 0.62, 0.78, 0.12), Vector2(p.x, GROUND_Y))
		refl.z_index = -1

func _build_steles() -> void:
	for sx in STELE_XS:
		var st := Node2D.new()
		st.position = Vector2(sx, GROUND_Y - 50.0)
		_poly(st, PackedVector2Array([
			Vector2(-16, 0), Vector2(-12, -110), Vector2(0, -126), Vector2(12, -110), Vector2(16, 0),
		]), Color(0.1, 0.13, 0.18))
		var glint := _poly(st, PackedVector2Array([
			Vector2(-2, -20), Vector2(2, -20), Vector2(4, -96), Vector2(-1, -104), Vector2(-4, -60),
		]), Color(0.8, 0.95, 1.0, 0.0))
		_shimmers.append({"node": glint, "phase": float(int(sx) % 628) * 0.012})
		add_child(st)

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

func _build_traps() -> void:
	for i in TRAP_XS.size():
		var x: float = TRAP_XS[i]
		var trap := Area2D.new()
		trap.position = Vector2(x, GROUND_Y - 54.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(66, 34)
		shape.shape = rect
		trap.add_child(shape)
		_poly(trap, PackedVector2Array([
			Vector2(-33, 22), Vector2(33, 22), Vector2(33, 6), Vector2(-33, 6),
		]), Color(0.12, 0.15, 0.2))
		for k in 4:
			var ox := -24.0 + k * 16.0
			_poly(trap, PackedVector2Array([
				Vector2(ox - 7, 6), Vector2(ox + 7, 6), Vector2(ox, -22),
			]), Color(0.2, 0.3, 0.4, 0.9))
			_poly(trap, PackedVector2Array([
				Vector2(ox - 3, 2), Vector2(ox + 3, 2), Vector2(ox, -16),
			]), Color(0.75, 0.92, 1.0, 0.9))
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
	glow.modulate = Color(0.6, 0.85, 1.0, 0.5)
	glow.scale = Vector2(4.5, 4.5)
	goal.add_child(glow)
	_poly(goal, PackedVector2Array([Vector2(-40, -60), Vector2(40, -60), Vector2(40, 66), Vector2(-40, 66)]), Color(0.6, 0.8, 1.0, 0.22))
	_poly(goal, PackedVector2Array([Vector2(-28, -55), Vector2(-20, -55), Vector2(-20, 70), Vector2(-28, 70)]), Color(0.14, 0.17, 0.23))
	_poly(goal, PackedVector2Array([Vector2(20, -55), Vector2(28, -55), Vector2(28, 70), Vector2(20, 70)]), Color(0.14, 0.17, 0.23))
	_poly(goal, PackedVector2Array([Vector2(-42, -70), Vector2(42, -70), Vector2(38, -58), Vector2(-38, -58)]), Color(0.5, 0.7, 0.9))
	add_child(goal)
	Atmosphere.breathe(glow)
	goal.body_entered.connect(_on_goal_body_entered)

func _build_kill_zone() -> void:
	var kz := Area2D.new()
	kz.position = Vector2(LEVEL_END / 2.0, 720.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(LEVEL_END + 800.0, 100.0)
	shape.shape = rect
	kz.add_child(shape)
	add_child(kz)
	kz.body_entered.connect(_on_kill_zone_body_entered)

## Le mur-Reflet : un pan de nuit qui déferle, hérissé d'éclats de verre, avec
## la silhouette d'Eneko à sa crête. Rendu par-dessus le décor.
func _build_wall() -> void:
	_wall = Node2D.new()
	_wall.z_index = 30
	_wall.position = Vector2(_wall_x, GROUND_Y)
	add_child(_wall)
	# Masse de nuit (bord droit à x = 0 local).
	_poly(_wall, PackedVector2Array([
		Vector2(-3200, -900), Vector2(0, -900), Vector2(0, 420), Vector2(-3200, 420),
	]), Color(0.04, 0.03, 0.07, 0.97))
	# Bandes de lueur violette près de la crête.
	_poly(_wall, PackedVector2Array([
		Vector2(-150, -900), Vector2(0, -900), Vector2(0, 420), Vector2(-150, 420),
	]), Color(0.35, 0.12, 0.5, 0.5))
	_poly(_wall, PackedVector2Array([
		Vector2(-60, -900), Vector2(0, -900), Vector2(0, 420), Vector2(-60, 420),
	]), Color(0.6, 0.25, 0.85, 0.4))
	# Dents de verre le long de la crête.
	for j in 16:
		var yy := -820.0 + j * 78.0
		_poly(_wall, PackedVector2Array([
			Vector2(0, yy), Vector2(44, yy + 30), Vector2(0, yy + 60),
		]), Color(0.5, 0.25, 0.75, 0.85))
	# Silhouette d'Eneko, à la crête, qui frémit (voir _process).
	_reflet_fig = Node2D.new()
	_reflet_fig.position = Vector2(-8, -70)
	_wall.add_child(_reflet_fig)
	_poly(_reflet_fig, PackedVector2Array([
		Vector2(-12, 46), Vector2(12, 46), Vector2(9, -22), Vector2(0, -40), Vector2(-9, -22),
	]), Color(0.32, 0.12, 0.45))
	_poly(_reflet_fig, PackedVector2Array([
		Vector2(9, -20), Vector2(14, -20), Vector2(34, -82), Vector2(29, -84),
	]), Color(0.7, 0.4, 0.95))
	for s in [-1.0, 1.0]:
		var eye := _poly(_reflet_fig, PackedVector2Array([
			Vector2(s * 3 - 2, -14), Vector2(s * 3 + 2, -14), Vector2(s * 3 + 2, -8), Vector2(s * 3 - 2, -8),
		]), Color(0.95, 0.5, 1.0))
		_shimmers.append({"node": eye, "phase": float(s) + 2.0})
	# Volutes d'encre qui montent le long de la crête.
	_ink = CPUParticles2D.new()
	_ink.amount = 30
	_ink.lifetime = 2.2
	_ink.preprocess = 2.0
	_ink.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_ink.emission_rect_extents = Vector2(20, 460)
	_ink.position = Vector2(-10, -240)
	_ink.direction = Vector2(0.3, -1.0)
	_ink.spread = 25.0
	_ink.gravity = Vector2(6, -30)
	_ink.initial_velocity_min = 20.0
	_ink.initial_velocity_max = 55.0
	_ink.scale_amount_min = 2.0
	_ink.scale_amount_max = 5.0
	_ink.color = Color(0.5, 0.25, 0.7, 0.5)
	_wall.add_child(_ink)

func _spawn_entities() -> void:
	for x in MASK_XS:
		var m := MASK_SCENE.instantiate()
		m.position = Vector2(x, SPAWN_Y - 70.0)
		add_child(m)
	for o in ORBS:
		var orb := ORB_SCENE.instantiate()
		orb.position = o
		add_child(orb)
	for o in HIGH_ORBS:
		var orb := ORB_SCENE.instantiate()
		orb.position = o
		add_child(orb)

func _setup_ambient() -> void:
	var amb := AmbientDialogue.new()
	add_child(amb)
	amb.add_line(self, 2200.0, "Eneko", "Il gagne du terrain dès que je ralentis. Ne pas m'arrêter. Jamais.")
	amb.add_line(self, 4600.0, "Eneko", "Mon propre visage, dans cette nuit... et il veut ma peau.")
	amb.add_line(self, 6400.0, "Eneko", "La porte ! Encore un souffle et je suis passé.")

func _setup_audio() -> void:
	var wind := AudioStreamPlayer.new()
	wind.stream = load("res://assets/sfx/wind.wav")
	wind.volume_db = -14.0
	wind.pitch_scale = 1.12
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

func _on_kill_zone_body_entered(body: Node2D) -> void:
	if body == player:
		player.fall_damage()

func _on_goal_body_entered(body: Node2D) -> void:
	if body == player:
		_armed = false
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
		damage_label.text = "Dégâts : %d   •   Esprits vaincus : %d" % [results["damage"], results["kills"]]
		if int(results["combo"]) >= 2:
			damage_label.text += "   •   Combo ×%d" % int(results["combo"])
	if time_label:
		time_label.text = "Temps : %s" % _format_time(results["time"])
	var stats_half := 150.0
	for child in challenge_stats.get_children():
		if child is Label:
			stats_half = maxf(stats_half, (child as Label).get_minimum_size().x * 0.5 + 10.0)
	challenge_stats.offset_left = -stats_half
	challenge_stats.offset_right = stats_half
	var stats_bg = win_label.find_child("StatsBG", true, false)
	if stats_bg != null:
		stats_bg.offset_left = -stats_half - 30.0
		stats_bg.offset_right = stats_half + 30.0

func _format_time(seconds: float) -> String:
	var mins: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	return "%d:%02d" % [mins, secs]

func _on_dialogue_finished() -> void:
	player.set_physics_process(true)
	_armed = true

func _on_menu_pressed() -> void:
	Transition.goto("res://scenes/main_menu.tscn")
