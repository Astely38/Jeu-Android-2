extends LevelBase
## Chapitre IV — Niveau 18 : « Le Puits sans Fond ».
## Le relief ne remonte plus : il s'enfonce, palier après palier, dans un
## puits qui n'a pas de fond connu. Failles et cratères s'y multiplient à
## mesure qu'on descend — plus la corruption est profonde, plus le monde se
## fend et crache. Léonie, elle, se fait plus rare à mesure qu'on approche
## du fond : quelque chose ici la reconnaît, et elle ne dit pas quoi.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const PATROL_SCENE := preload("res://scenes/enemy.tscn")
const SANS_VISAGE_SCENE := preload("res://scenes/sans_visage.tscn")
const LEONIE_SCENE := preload("res://scenes/leonie.tscn")

## Entre la surface du sol (déjà le bord praticable ici, contrairement aux
## autres niveaux où GROUND_Y désigne le CENTRE de la plateforme) et la
## position d'apparition d'un personnage.
const SPAWN_Y_OFFSET := 23.0
const LEVEL_END := 7300.0
const GOAL_X := 7150.0
const LEVEL_ID := "level_18"

## Même royaume sans écho que les niveaux 16 et 17.
const VOID := Color(0.06, 0.05, 0.08)
const VOID_DARK := Color(0.03, 0.025, 0.04)
const ASH := Color(0.2, 0.17, 0.22)
const GLITCH_A := Color(0.85, 0.25, 0.55)
const GLITCH_B := Color(0.3, 0.75, 0.85)

const PLATFORM_THEME := {
	"top": ASH,
	"top_light": Color(0.3, 0.26, 0.32),
	"body_a": VOID,
	"body_b": VOID_DARK,
	"dark": VOID_DARK,
	"speck": Color(0.38, 0.34, 0.42),
}

## Profil du terrain : contrairement au Versant Aveugle (qui alternait
## montées et descentes), ce puits ne remonte JAMAIS — chaque palier est
## plus bas que le précédent, jusqu'au fond.
const PROFILE := [
	Vector2(0, 300), Vector2(700, 300),         # départ, plat
	Vector2(1300, 480),                          # première chute
	Vector2(2100, 480),                          # plat
	Vector2(2900, 650),                          # nouvelle chute
	Vector2(3600, 650),                          # plat (refuge)
	Vector2(4300, 780),                          # chute
	Vector2(5100, 780),                          # plat
	Vector2(5900, 920),                          # chute finale
	Vector2(7300, 920),                          # fond du puits, jusqu'à la porte
]

const CHECKPOINT_XS := [1300.0, 3600.0, 5900.0]
const PATROL_XS := [1700.0, 4700.0, 6500.0]
const SANS_VISAGE_XS := [900.0, 1600.0, 2600.0, 4400.0, 5300.0, 6300.0, 6900.0]
## Failles glitchées : de plus en plus nombreuses et de plus en plus serrées
## à mesure qu'on descend — le chaos s'aggrave avec la profondeur, jusqu'à
## l'enchaînement quasi continu du fond du puits. Toujours sur le plat.
const GLITCH_RIFT_XS := [
	350.0, 600.0,
	1450.0, 1700.0, 1950.0,
	4450.0, 4700.0, 4950.0,
	6050.0, 6300.0, 6550.0, 6800.0, 7050.0,
]
## Cratères de l'Éboulis de miroir, intercalés entre les failles — le
## plateau-refuge (2900-3600) reste seul épargné. Densité maximale sur le
## dernier tronçon : le fond du puits ne laisse presque plus de répit.
const ROCK_SLIDES := [
	Vector2(475.0, 300.0),
	Vector2(1575.0, 480.0), Vector2(1825.0, 480.0),
	Vector2(4575.0, 780.0), Vector2(4825.0, 780.0),
	Vector2(6175.0, 920.0), Vector2(6425.0, 920.0), Vector2(6675.0, 920.0), Vector2(6925.0, 920.0),
]
const REFUGE_X := 3600.0

const LEONIE_LINES := [
	{ "name": "Léonie", "text": "Le sol se dérobe encore, Eneko — nous descendons. Ce monde n'a pas de fond, seulement des profondeurs plus sombres que les précédentes." },
	{ "name": "Léonie", "text": "Je... je sens ici quelque chose que je ne sentais pas plus haut. Une présence qui me reconnaît. Ne m'attends pas si je me tais." },
	{ "name": "Léonie", "text": "Là-bas, dans la faille — as-tu vu ? Une silhouette. La tienne. Elle ne bouge pas comme toi." },
	{ "name": "Eneko", "text": "Alors je descendrai jusqu'au bout de ce puits. Si mon reflet m'attend en bas, qu'il m'attende encore un peu — j'irai moi-même le chercher." },
]

var sfx_win: AudioStreamPlayer
var void_motes: CPUParticles2D
var _glitches: Array = []
var _t := 0.0
## Secousses périodiques, de plus en plus fréquentes et fortes à mesure que
## le joueur descend — le puits lui-même tremble davantage vers le fond.
var _shake_t := 1.5

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var next_button: Button = $WinLabel/NextButton
@onready var dialogue: CanvasLayer = $Dialogue

func _ready() -> void:
	_build_decor()
	Atmosphere.add_foreground(self, Color(0.04, 0.03, 0.06, 0.4))
	_build_terrain()
	_build_bounds()
	_build_checkpoints()
	_build_glitch_rifts()
	_build_rock_slides()
	_build_goal()
	# Filet de sécurité PURE défense : le relief est continu (aucun trou) et
	# borné par des murs aux deux bouts, donc une chute est en principe
	# impossible. On place quand même la zone bien SOUS le point le plus bas
	# du sol (le fond du puits, y=920) pour ne jamais frapper un joueur au sol.
	_build_kill_zone(LEVEL_END, 1180.0, 200.0)
	_spawn_entities()
	_setup_audio()
	_setup_ambient()
	player.set_land_dust_color(Color(0.28, 0.24, 0.32, 0.75))
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
	var next_scene: String = SaveManager.LEVEL_SCENES.get("level_19", "")
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
		player.add_shake(2.0 + depth * 8.0)
		_shake_t = randf_range(2.4, 3.8) * (1.0 - depth * 0.5)

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

## Faille glitchée : voir GlitchRift (classe partagée avec les niveaux 16
## et 17) — même langage visuel pour tout le Chapitre IV.
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
	# torii mais une faille béante, cerclée de glitch.
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
	amb.add_line(self, 1000.0, "Eneko", "Chaque pas m'enfonce un peu plus. L'air lui-même semble se souvenir de moins en moins de moi.")
	amb.add_line(self, 2700.0, "Eneko", "Cette faille... elle n'a pas la même voix que les autres. Plus profonde. Plus proche.")
	amb.add_line(self, 4900.0, "Eneko", "Je ne devrais pas reconnaître ce silence. Et pourtant.")
	amb.add_line(self, 6600.0, "Eneko", "Le fond du puits. Enfin. Ou peut-être seulement le début de quelque chose d'autre.")

func _setup_audio() -> void:
	var wind := AudioStreamPlayer.new()
	wind.stream = load("res://assets/sfx/wind.wav")
	wind.volume_db = -11.0
	wind.pitch_scale = 0.86
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

	# Ciel sans astre, plus sombre encore que les niveaux précédents — la
	# lumière elle-même se raréfie à mesure qu'on descend.
	var sky := ParallaxLayer.new()
	sky.motion_scale = Vector2(0.05, 0.05)
	bg.add_child(sky)
	var haze := Sprite2D.new()
	haze.texture = mist_tex
	haze.modulate = Color(0.32, 0.28, 0.4, 0.4)
	haze.scale = Vector2(14.0, 6.0)
	haze.position = Vector2(600.0, 80.0)
	sky.add_child(haze)
	TextureLab.add_clouds(sky, 4, 30.0, 160.0, LEVEL_END, Color(0.14, 0.11, 0.18, 0.2))

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
		]), Color(0.08, 0.06, 0.11, 0.8), Vector2(mx, 600.0))
		mx += 340.0 + float(mi * 41 % 130)
		mi += 1

	# Silhouette lointaine, immobile : la première trace visible de ce qui
	# attend au fond — jamais nommée, jamais approchée, juste entr'aperçue.
	var silhouette := _poly(far, PackedVector2Array([
		Vector2(-14, 60), Vector2(-16, 10), Vector2(-9, -30), Vector2(0, -46),
		Vector2(9, -30), Vector2(16, 10), Vector2(14, 60),
	]), Color(0.05, 0.04, 0.07, 0.55), Vector2(5300.0, 760.0))
	silhouette.z_index = -1

	# Failles de glitch dans le ciel lui-même : bandes qui se décalent, comme
	# une image mal reconstruite — bien plus denses que dans les niveaux
	# précédents, jusqu'au chaos visuel pur sur le dernier tronçon.
	var gx := 80.0
	var gi := 0
	while gx < LEVEL_END:
		var gy := 50.0 + float(gi * 37 % 320)
		var gw := 26.0 + float(gi * 23 % 70)
		var col := GLITCH_A if gi % 2 == 0 else GLITCH_B
		var band := _poly(sky, PackedVector2Array([
			Vector2(-gw, -2), Vector2(gw, -2), Vector2(gw, 2), Vector2(-gw, 2),
		]), col, Vector2(gx, gy))
		_glitches.append({"node": band, "phase": float(gi) * 1.7})
		gx += 130.0 + float(gi * 47 % 110)
		gi += 1

	void_motes = CPUParticles2D.new()
	void_motes.texture = load("res://assets/leaf.svg")
	void_motes.amount = 42
	void_motes.lifetime = 6.5
	void_motes.preprocess = 6.5
	void_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	void_motes.emission_rect_extents = Vector2(560, 240)
	void_motes.direction = Vector2(0, 1)
	void_motes.spread = 180.0
	void_motes.gravity = Vector2(2, 6)
	void_motes.initial_velocity_min = 4.0
	void_motes.initial_velocity_max = 14.0
	void_motes.scale_amount_min = 0.3
	void_motes.scale_amount_max = 0.6
	void_motes.color = Color(0.36, 0.32, 0.42, 0.5)
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
