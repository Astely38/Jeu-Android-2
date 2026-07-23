extends LevelBase
## Chapitre IV — Niveau 19 : « L'Antichambre du Reflet ».
## Le puits s'arrête ; ce qui vient après n'est plus une chute mais une
## traversée erratique, montées et creux sans logique, comme si le terrain
## lui-même hésitait sur sa propre forme. Le chaos y est à son comble avant
## la porte du fond — et Léonie y avoue enfin ce qu'elle taisait depuis le
## début du chapitre.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const PATROL_SCENE := preload("res://scenes/enemy.tscn")
const SANS_VISAGE_SCENE := preload("res://scenes/sans_visage.tscn")
const LEONIE_SCENE := preload("res://scenes/leonie.tscn")

## Entre la surface du sol (déjà le bord praticable ici) et la position
## d'apparition d'un personnage.
const SPAWN_Y_OFFSET := 23.0
const LEVEL_END := 7000.0
const GOAL_X := 6850.0
const LEVEL_ID := "level_19"

## Même royaume sans écho que les niveaux 16 à 18.
const VOID := Color(0.055, 0.045, 0.07)
const VOID_DARK := Color(0.028, 0.022, 0.038)
const ASH := Color(0.19, 0.16, 0.21)
const GLITCH_A := Color(0.85, 0.25, 0.55)
const GLITCH_B := Color(0.3, 0.75, 0.85)

const PLATFORM_THEME := {
	"top": ASH,
	"top_light": Color(0.29, 0.25, 0.31),
	"body_a": VOID,
	"body_b": VOID_DARK,
	"dark": VOID_DARK,
	"speck": Color(0.37, 0.33, 0.41),
	# Pierre taillée plutôt que le style "naturel" (racines, touffes d'herbe) :
	# ce monde sans écho n'a rien de vivant ni d'organique.
	"cut": true,
}

## Profil du terrain : contrairement au Puits (une seule direction, vers le
## bas), l'Antichambre n'a plus de logique — montées et creux s'enchaînent
## sans jamais rendre au joueur un rythme stable.
const PROFILE := [
	Vector2(0, 900), Vector2(600, 900),          # départ, plat, au fond du puits
	Vector2(1200, 750),                           # remontée soudaine
	Vector2(1900, 750),                           # plat
	Vector2(2500, 850),                           # creux
	Vector2(3200, 850),                           # plat (refuge)
	Vector2(3800, 700),                           # remontée
	Vector2(4500, 700),                           # plat
	Vector2(5100, 820),                           # creux
	Vector2(5800, 820),                           # plat
	Vector2(6400, 650),                           # dernière remontée
	Vector2(7000, 650),                           # seuil, devant la porte
]

const CHECKPOINT_XS := [1200.0, 3200.0, 5800.0]
const PATROL_XS := [450.0, 3950.0, 5700.0, 6600.0]
const SANS_VISAGE_XS := [800.0, 1750.0, 2700.0, 4150.0, 5450.0, 6300.0, 6900.0]
## Failles glitchées, sur chaque tronçon plat sauf le refuge — le chaos du
## Chapitre IV atteint ici son comble, juste avant la porte.
const GLITCH_RIFT_XS := [250.0, 450.0, 1400.0, 1650.0, 4000.0, 4250.0, 5350.0, 5600.0, 6500.0, 6700.0]
## Cratères de l'Éboulis de miroir, intercalés entre les failles.
const ROCK_SLIDES := [
	Vector2(350.0, 900.0),
	Vector2(1525.0, 750.0),
	Vector2(4125.0, 700.0),
	Vector2(5475.0, 820.0),
	Vector2(6600.0, 650.0),
]
const REFUGE_X := 3200.0

const LEONIE_LINES := [
	{ "name": "Léonie", "text": "Nous voilà à l'antichambre, Eneko. Ce lieu n'a pas toujours été un puits — il fut un sanctuaire, avant que le tain ne se brise ici même." },
	{ "name": "Léonie", "text": "Je le reconnais, maintenant : je l'ai déjà vu porter ton visage. C'est pour cela que je t'ai suivi depuis le début — pour te prévenir, ou pour te retenir. Je ne sais plus lequel." },
	{ "name": "Léonie", "text": "Je ne peux pas franchir cette porte avec toi. Ce qui t'attend derrière me connaît trop bien." },
	{ "name": "Eneko", "text": "Alors j'irai seul lui rendre son visage, ou le mien. Attends-moi ici, Léonie — je reviendrai, quoi qu'il en coûte." },
]

var sfx_win: AudioStreamPlayer
var void_motes: CPUParticles2D
var _glitches: Array = []
var _t := 0.0
## Secousses périodiques, les plus fortes du chapitre — le chaos culmine ici.
var _shake_t := 1.2

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var next_button: Button = $WinLabel/NextButton
@onready var dialogue: CanvasLayer = $Dialogue

func _ready() -> void:
	_build_decor()
	Atmosphere.add_foreground(self, Color(0.04, 0.03, 0.055, 0.42))
	_build_terrain()
	_build_bounds()
	_build_checkpoints()
	_build_glitch_rifts()
	_build_rock_slides()
	_build_goal()
	# Filet de sécurité PURE défense : le relief est continu (aucun trou) et
	# borné par des murs aux deux bouts, donc une chute est en principe
	# impossible. On place quand même la zone bien SOUS le point le plus bas
	# du sol (y=900) pour ne jamais frapper un joueur au sol.
	_build_kill_zone(LEVEL_END, 1160.0, 200.0)
	_spawn_entities()
	_setup_audio()
	_setup_ambient()
	player.set_land_dust_color(Color(0.27, 0.23, 0.31, 0.75))
	win_label.visible = false
	Music.play_level(LEVEL_ID)
	SaveManager.set_last_level(LEVEL_ID)
	# Relique cachée, au-dessus du refuge.
	var relic := Relic.new()
	relic.level_id = LEVEL_ID
	relic.position = Vector2(REFUGE_X, _surface_y(REFUGE_X) - 220.0)
	add_child(relic)
	Challenge.start_level(LEVEL_ID, _orb_positions().size())
	dialogue.finished.connect(_on_dialogue_finished)
	menu_button.pressed.connect(_on_menu_pressed)
	var next_scene: String = SaveManager.LEVEL_SCENES.get("level_20", "")
	next_button.visible = next_scene != ""
	if next_scene != "":
		next_button.pressed.connect(func(): Transition.goto(next_scene))
	player.intro_pan(Vector2(GOAL_X, _surface_y(GOAL_X) - 220.0))

func _process(delta: float) -> void:
	_t += delta
	for g in _glitches:
		var node: Polygon2D = g["node"]
		node.modulate = GLITCH_A if sin(_t * 9.0 + float(g["phase"])) > 0.3 else GLITCH_B
		node.modulate.a = 0.35 + 0.35 * absf(sin(_t * 5.0 + float(g["phase"])))
	_shake_t -= delta
	if _shake_t <= 0.0 and is_instance_valid(player) and player.has_method("add_shake"):
		var depth := clampf(player.global_position.x / LEVEL_END, 0.0, 1.0)
		player.add_shake(3.0 + depth * 9.0)
		_shake_t = randf_range(1.8, 3.0) * (1.0 - depth * 0.4)

func _physics_process(_delta: float) -> void:
	if void_motes != null and is_instance_valid(player):
		void_motes.position = Vector2(player.position.x, player.position.y - 260.0)

# --- Profil du terrain ------------------------------------------------------

## Hauteur du sol (interpolation linéaire du profil) à la position `x`.
func _surface_y(x: float) -> float:
	for i in PROFILE.size() - 1:
		var a: Vector2 = PROFILE[i]
		var b: Vector2 = PROFILE[i + 1]
		if x >= a.x and x <= b.x:
			if b.x == a.x:
				return a.y
			var f := (x - a.x) / (b.x - a.x)
			return lerpf(a.y, b.y, f)
	return PROFILE[PROFILE.size() - 1].y

## Position d'apparition (personnages/objets) à la position `x`, un peu
## au-dessus du sol.
func _stand_y(x: float) -> float:
	return _surface_y(x) - SPAWN_Y_OFFSET

## Positions des orbes, calculées une seule fois : garantit que le total
## annoncé (Challenge.start_level) corresponde exactement au nombre réel
## d'orbes semées par _spawn_entities.
func _orb_positions() -> Array:
	var out := []
	var x := 260.0
	var i := 0
	while x < LEVEL_END - 200.0:
		out.append(Vector2(x, _surface_y(x) - 80.0 - float(i % 2) * 35.0))
		x += 260.0
		i += 1
	return out

# --- Construction ------------------------------------------------------------

func _build_terrain() -> void:
	for i in PROFILE.size() - 1:
		var a: Vector2 = PROFILE[i]
		var b: Vector2 = PROFILE[i + 1]
		if a.y == b.y:
			var mid := (a.x + b.x) * 0.5
			var half_w := (b.x - a.x) * 0.5
			var body := StaticBody2D.new()
			body.position = Vector2(mid, a.y + 50.0)
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(half_w * 2.0, 100.0)
			shape.shape = rect
			body.add_child(shape)
			PlatformPainter.paint(body, half_w, PLATFORM_THEME)
			add_child(body)
		else:
			SlopePainter.build(self, a.x, a.y, b.x, b.y, PLATFORM_THEME)

## Murs invisibles aux deux extrémités du relief : le profil ne définit rien
## au-delà, un joueur qui déborderait (recul, poussée d'un piège) tomberait
## sinon dans le vide sans que le filet de la zone de mort n'intervienne à
## temps. Bien plus hauts que le relief pour ne jamais être sautés.
func _build_bounds() -> void:
	for edge_x in [PROFILE[0].x - 40.0, PROFILE[PROFILE.size() - 1].x + 40.0]:
		var wall := StaticBody2D.new()
		wall.position = Vector2(edge_x, 0.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(80.0, 4000.0)
		shape.shape = rect
		wall.add_child(shape)
		add_child(wall)

func _build_checkpoints() -> void:
	for x in CHECKPOINT_XS:
		var y := _surface_y(x) - 70.0
		var cp := Area2D.new()
		cp.position = Vector2(x, y)
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

## Faille glitchée : voir GlitchRift (classe partagée avec les niveaux 16 à
## 18) — même langage visuel pour tout le Chapitre IV.
func _build_glitch_rifts() -> void:
	for x in GLITCH_RIFT_XS:
		var rift := GlitchRift.new()
		rift.position = Vector2(x, _surface_y(x))
		rift.phase = x * 0.01
		rift.color_a = GLITCH_A
		rift.color_b = GLITCH_B
		add_child(rift)

func _build_rock_slides() -> void:
	for p in ROCK_SLIDES:
		var rs := RockSlide.new()
		rs.position = p
		rs.phase = p.x * 0.017
		rs.tint = Color(0.5, 0.46, 0.56)
		add_child(rs)

func _build_goal() -> void:
	var y := _surface_y(GOAL_X)
	var goal := Area2D.new()
	goal.position = Vector2(GOAL_X, y - 70.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 140)
	shape.shape = rect
	goal.add_child(shape)
	# Déchirure verticale dans le vide : la porte de ce monde n'est plus un
	# torii mais une faille béante, cerclée de glitch — la dernière avant le
	# Gardien du reflet.
	_poly(goal, PackedVector2Array([
		Vector2(-36, -70), Vector2(36, -70), Vector2(30, 70), Vector2(-30, 70),
	]), Color(0.1, 0.08, 0.14, 0.9))
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(0.7, 0.4, 0.75, 0.4)
	glow.scale = Vector2(4.2, 4.2)
	goal.add_child(glow)
	for k in 4:
		var oy := -60.0 + float(k) * 40.0
		var band := _poly(goal, PackedVector2Array([
			Vector2(-30, oy), Vector2(30, oy), Vector2(28, oy + 14), Vector2(-28, oy + 14),
		]), GLITCH_B)
		_glitches.append({"node": band, "phase": float(k) * 0.9})
	add_child(goal)
	Atmosphere.breathe(glow)
	goal.body_entered.connect(_on_goal_body_entered)

func _spawn_entities() -> void:
	for x in PATROL_XS:
		var e := PATROL_SCENE.instantiate()
		e.position = Vector2(x, _stand_y(x))
		add_child(e)
	for x in SANS_VISAGE_XS:
		var sv := SANS_VISAGE_SCENE.instantiate()
		sv.position = Vector2(x, _stand_y(x))
		add_child(sv)
	PlatformPainter.build_sanctuary(self, REFUGE_X, _surface_y(REFUGE_X))
	var leonie := LEONIE_SCENE.instantiate()
	leonie.position = Vector2(REFUGE_X, _stand_y(REFUGE_X))
	leonie.set_lines(LEONIE_LINES)
	add_child(leonie)
	for o in _orb_positions():
		var orb := ORB_SCENE.instantiate()
		orb.position = o
		add_child(orb)

func _setup_ambient() -> void:
	var amb := AmbientDialogue.new()
	add_child(amb)
	amb.add_line(self, 900.0, "Eneko", "Ce sol ne sait plus s'il doit monter ou s'effondrer. Rien ici n'obéit plus à rien.")
	amb.add_line(self, 2600.0, "Eneko", "Léonie se tait plus qu'elle ne parle, depuis l'entrée de ce lieu.")
	amb.add_line(self, 4600.0, "Eneko", "Je sens un regard sur moi, où que je me tourne. Le mien, peut-être.")
	amb.add_line(self, 6300.0, "Eneko", "La porte. Enfin. Et derrière... ce que je redoutais de reconnaître.")

func _setup_audio() -> void:
	var wind := AudioStreamPlayer.new()
	wind.stream = load("res://assets/sfx/wind.wav")
	wind.volume_db = -10.0
	wind.pitch_scale = 0.82
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

	# Ciel sans astre, à son plus sombre — le chaos visuel culmine ici.
	var sky := ParallaxLayer.new()
	sky.motion_scale = Vector2(0.05, 0.05)
	bg.add_child(sky)
	var haze := Sprite2D.new()
	haze.texture = mist_tex
	haze.modulate = Color(0.3, 0.26, 0.38, 0.42)
	haze.scale = Vector2(14.0, 6.0)
	haze.position = Vector2(600.0, 80.0)
	sky.add_child(haze)
	TextureLab.add_clouds(sky, 5, 30.0, 160.0, LEVEL_END, Color(0.13, 0.1, 0.17, 0.22))

	# Crêtes lointaines, dentelées, qui suivent grossièrement le relief.
	var far := ParallaxLayer.new()
	far.motion_scale = Vector2(0.14, 0.35)
	bg.add_child(far)
	var mx := -200.0
	var mi := 0
	while mx < LEVEL_END + 700.0:
		var mh := 180.0 + float(mi * 53 % 140)
		_poly(far, PackedVector2Array([
			Vector2(-260, 0), Vector2(-40, -mh + 30), Vector2(0, -mh), Vector2(70, -mh + 50), Vector2(260, 0),
		]), Color(0.07, 0.055, 0.1, 0.82), Vector2(mx, 600.0))
		mx += 340.0 + float(mi * 41 % 130)
		mi += 1

	# Deux silhouettes, immobiles, qui encadrent désormais l'approche de la
	# porte finale — la première trace claire de ce qui attend derrière.
	for sx in [5900.0, 6700.0]:
		var silhouette := _poly(far, PackedVector2Array([
			Vector2(-15, 64), Vector2(-17, 12), Vector2(-10, -32), Vector2(0, -50),
			Vector2(10, -32), Vector2(17, 12), Vector2(15, 64),
		]), Color(0.06, 0.045, 0.08, 0.6), Vector2(sx, _surface_y(sx) - 60.0))
		silhouette.z_index = -1

	# Failles de glitch dans le ciel lui-même : au maximum de densité pour
	# tout le chapitre — le chaos visuel pur avant la porte.
	var gx := 70.0
	var gi := 0
	while gx < LEVEL_END:
		var gy := 45.0 + float(gi * 37 % 330)
		var gw := 24.0 + float(gi * 23 % 74)
		var col := GLITCH_A if gi % 2 == 0 else GLITCH_B
		var band := _poly(sky, PackedVector2Array([
			Vector2(-gw, -2), Vector2(gw, -2), Vector2(gw, 2), Vector2(-gw, 2),
		]), col, Vector2(gx, gy))
		_glitches.append({"node": band, "phase": float(gi) * 1.7})
		gx += 105.0 + float(gi * 47 % 95)
		gi += 1

	void_motes = CPUParticles2D.new()
	void_motes.texture = load("res://assets/leaf.svg")
	void_motes.amount = 52
	void_motes.lifetime = 6.0
	void_motes.preprocess = 6.0
	void_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	void_motes.emission_rect_extents = Vector2(560, 260)
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

func _on_goal_body_entered(body: Node2D) -> void:
	_reach_goal(body, LEVEL_ID, sfx_win)
