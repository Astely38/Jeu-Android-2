extends LevelBase
## Chapitre IV — Niveau 16 : « Le Versant Aveugle ».
## Au-delà du tain brisé, Eneko foule un monde qui ne renvoie plus rien : ni
## ombre, ni reflet, ni écho. Le sol n'est plus une suite de plateformes
## posées à plat mais un relief continu — pentes descendantes et montées
## franches, jamais de repos horizontal bien long. Deux nouveautés y rôdent :
## le Sans-Visage, esprit qui n'est solide que par intermittence, et deux
## dangers inédits — la Faille glitchée (immobile) et l'Éboulis de miroir
## (qui dévale les pentes en tournoyant).

const ORB_SCENE := preload("res://scenes/orb.tscn")
const PATROL_SCENE := preload("res://scenes/enemy.tscn")
const SANS_VISAGE_SCENE := preload("res://scenes/sans_visage.tscn")
const LEONIE_SCENE := preload("res://scenes/leonie.tscn")

## Entre la surface du sol (déjà le bord praticable ici, contrairement aux
## autres niveaux où GROUND_Y désigne le CENTRE de la plateforme) et la
## position d'apparition d'un personnage.
const SPAWN_Y_OFFSET := 23.0
const LEVEL_END := 7100.0
const GOAL_X := 6950.0
const LEVEL_ID := "level_16"

## Palette du royaume sans écho : matière mate, sans le moindre poli
## réfléchissant (à l'opposé du verre du Ch.3), et un glitch violet-magenta
## qui trahit l'image corrompue de ce monde.
const VOID := Color(0.07, 0.06, 0.09)
const VOID_DARK := Color(0.04, 0.03, 0.05)
const ASH := Color(0.22, 0.19, 0.24)
const GLITCH_A := Color(0.85, 0.25, 0.55)
const GLITCH_B := Color(0.3, 0.75, 0.85)

const PLATFORM_THEME := {
	"top": ASH,
	"top_light": Color(0.32, 0.28, 0.34),
	"body_a": VOID,
	"body_b": VOID_DARK,
	"dark": VOID_DARK,
	"speck": Color(0.4, 0.36, 0.44),
}

## Profil du terrain : suite de points (x, hauteur de sol). Entre deux points
## consécutifs de même hauteur → segment PLAT ; de hauteur différente →
## PENTE. Un seul relief continu, du départ jusqu'à la crête finale.
const PROFILE := [
	Vector2(0, 550), Vector2(900, 550),       # plat de départ
	Vector2(1500, 690),                        # descente
	Vector2(2400, 690),                        # plat (vallée)
	Vector2(3600, 400),                        # longue montée
	Vector2(4400, 400),                        # plat (plateau, refuge)
	Vector2(5000, 560),                        # descente
	Vector2(5900, 560),                        # plat
	Vector2(6700, 300),                        # montée finale
	Vector2(7100, 300),                        # plat (crête, porte)
]

const CHECKPOINT_XS := [1500.0, 3600.0, 5000.0]
const PATROL_XS := [1900.0, 5300.0]
const SANS_VISAGE_XS := [2000.0, 5500.0, 6850.0]
## Failles glitchées (immobiles) : sur le plat, jamais sur une pente.
const GLITCH_RIFT_XS := [1700.0, 5150.0]
## Éboulis de miroir : un par grande montée, en haut de la pente.
const ROCK_SLIDES := [
	{"x": 3420.0, "y": 430.0, "dir": Vector2(-1.0, 0.24)},
	{"x": 6520.0, "y": 330.0, "dir": Vector2(-1.0, 0.33)},
]
const REFUGE_X := 4000.0

const LEONIE_LINES := [
	{ "name": "Léonie", "text": "Nous y sommes, Eneko : au-delà du tain brisé. Ce monde ne renvoie plus rien — ni ombre, ni reflet, ni écho." },
	{ "name": "Léonie", "text": "Ces silhouettes robées qui rôdent... des Sans-Visage. Ils n'empruntent un corps que le temps d'un souffle, puis s'effacent en un rien intangible. Ne frappe que lorsqu'ils sont pleins." },
	{ "name": "Léonie", "text": "Prends garde aux pentes, aussi : ce sol n'a jamais connu de pas avant les tiens. Des pans entiers peuvent s'ébouler sous ta traversée." },
	{ "name": "Eneko", "text": "Alors je grimperai, je descendrai, aussi loin qu'il faudra. Ce qui m'a volé mon reflet me le rendra." },
]

var sfx_win: AudioStreamPlayer
var void_motes: CPUParticles2D
var _glitches: Array = []
var _t := 0.0

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var next_button: Button = $WinLabel/NextButton
@onready var dialogue: CanvasLayer = $Dialogue

func _ready() -> void:
	_build_decor()
	Atmosphere.add_foreground(self, Color(0.05, 0.04, 0.07, 0.35))
	_build_terrain()
	_build_bounds()
	_build_checkpoints()
	_build_glitch_rifts()
	_build_rock_slides()
	_build_goal()
	_build_kill_zone(LEVEL_END, 750.0, 400.0)
	_spawn_entities()
	_setup_audio()
	_setup_ambient()
	player.set_land_dust_color(Color(0.3, 0.26, 0.34, 0.75))
	win_label.visible = false
	Music.play_level(LEVEL_ID)
	SaveManager.set_last_level(LEVEL_ID)
	# Relique cachée, tapie au tout début.
	var relic := Relic.new()
	relic.level_id = LEVEL_ID
	relic.position = Vector2(60, _surface_y(60.0) - SPAWN_Y_OFFSET)
	add_child(relic)
	Challenge.start_level(LEVEL_ID, _orb_positions().size())
	dialogue.finished.connect(_on_dialogue_finished)
	menu_button.pressed.connect(_on_menu_pressed)
	var next_scene: String = SaveManager.LEVEL_SCENES.get("level_17", "")
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

## Faille glitchée : déchirure immobile, flush au sol, cerclée d'un liseré
## lumineux et de bandes qui clignotent entre les deux teintes de corruption
## du chapitre — pensée pour rester lisible même sur fond sombre.
func _build_glitch_rifts() -> void:
	for x in GLITCH_RIFT_XS:
		var y := _surface_y(x)
		var rift := Area2D.new()
		rift.position = Vector2(x, y - 14.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(60, 30)
		shape.shape = rect
		rift.add_child(shape)
		var pts := PackedVector2Array([
			Vector2(-30, 14), Vector2(30, 14), Vector2(24, -12), Vector2(-24, -12),
		])
		_poly(rift, pts, Color(0.03, 0.02, 0.05))
		# Liseré lumineux : détache la faille du fond, même immobile.
		var outline := Line2D.new()
		outline.points = pts
		outline.closed = true
		outline.width = 2.2
		outline.default_color = Color(GLITCH_A.r, GLITCH_A.g, GLITCH_A.b, 0.8)
		rift.add_child(outline)
		for k in 3:
			var ox := -18.0 + float(k) * 18.0
			var band := _poly(rift, PackedVector2Array([
				Vector2(ox - 5, 11), Vector2(ox + 5, 11), Vector2(ox + 7, -10), Vector2(ox - 7, -10),
			]), Color(GLITCH_A.r, GLITCH_A.g, GLITCH_A.b, 0.0))
			_glitches.append({"node": band, "phase": float(k) * 1.3 + x * 0.01})
		add_child(rift)
		rift.body_entered.connect(_on_trap_body_entered)

func _on_trap_body_entered(body: Node2D) -> void:
	if body == player and body.has_method("take_damage"):
		body.take_damage(1, body.global_position + Vector2(0, 20))

func _build_rock_slides() -> void:
	for r in ROCK_SLIDES:
		var rs := RockSlide.new()
		rs.position = Vector2(float(r["x"]), float(r["y"]))
		rs.fall_dir = r["dir"]
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
		]), Color(GLITCH_B.r, GLITCH_B.g, GLITCH_B.b, 0.0))
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
	amb.add_line(self, 1100.0, "Eneko", "Le sol se dérobe sous moi. Aucun écho ne me répond plus.")
	amb.add_line(self, 2900.0, "Eneko", "Cette montée n'en finit pas. Et pourtant, quelque chose m'y attend.")
	amb.add_line(self, 5600.0, "Eneko", "Je ne me vois plus nulle part. Ni dans l'eau, ni dans le verre, ni ici.")
	amb.add_line(self, 6800.0, "Eneko", "La faille, là-haut. C'est par elle que je reprendrai mon visage.")

func _setup_audio() -> void:
	var wind := AudioStreamPlayer.new()
	wind.stream = load("res://assets/sfx/wind.wav")
	wind.volume_db = -12.0
	wind.pitch_scale = 0.92
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

	# Ciel sans astre : une lueur pâle et froide, sans source précise —
	# ce monde n'a pas de soleil qui vaille la peine d'être reflété.
	var sky := ParallaxLayer.new()
	sky.motion_scale = Vector2(0.05, 0.05)
	bg.add_child(sky)
	var haze := Sprite2D.new()
	haze.texture = mist_tex
	haze.modulate = Color(0.4, 0.36, 0.46, 0.35)
	haze.scale = Vector2(14.0, 6.0)
	haze.position = Vector2(600.0, 80.0)
	sky.add_child(haze)
	TextureLab.add_clouds(sky, 4, 30.0, 160.0, LEVEL_END, Color(0.18, 0.15, 0.22, 0.16))

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
		]), Color(0.1, 0.08, 0.13, 0.75), Vector2(mx, 600.0))
		mx += 340.0 + float(mi * 41 % 130)
		mi += 1

	# Failles de glitch dans le ciel lui-même : bandes qui se décalent, comme
	# une image mal reconstruite.
	var gx := 100.0
	var gi := 0
	while gx < LEVEL_END:
		var gy := 60.0 + float(gi * 37 % 300)
		var gw := 30.0 + float(gi * 23 % 60)
		var col := GLITCH_A if gi % 2 == 0 else GLITCH_B
		var band := _poly(sky, PackedVector2Array([
			Vector2(-gw, -2), Vector2(gw, -2), Vector2(gw, 2), Vector2(-gw, 2),
		]), Color(col.r, col.g, col.b, 0.0), Vector2(gx, gy))
		_glitches.append({"node": band, "phase": float(gi) * 1.7})
		gx += 260.0 + float(gi * 47 % 220)
		gi += 1

	void_motes = CPUParticles2D.new()
	void_motes.texture = load("res://assets/leaf.svg")
	void_motes.amount = 24
	void_motes.lifetime = 7.0
	void_motes.preprocess = 7.0
	void_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	void_motes.emission_rect_extents = Vector2(560, 220)
	void_motes.direction = Vector2(0, 1)
	void_motes.spread = 180.0
	void_motes.gravity = Vector2(2, 6)
	void_motes.initial_velocity_min = 4.0
	void_motes.initial_velocity_max = 14.0
	void_motes.scale_amount_min = 0.3
	void_motes.scale_amount_max = 0.6
	void_motes.color = Color(0.4, 0.36, 0.46, 0.5)
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
