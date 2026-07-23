extends LevelBase
## Chapitre IV — Niveau 17 : « L'Écho Muet ».
## Le tain reste brisé, et cette fois c'est le reflet d'Eneko lui-même qui
## s'en détache : un jumeau glitché (EchoTwin) qui rejoue son tracé avec un
## souffle de retard, intangible et sans malice. Mais certains passages —
## les Portes Muettes — n'obéissent qu'à lui : il faut s'immobiliser devant
## elles et attendre que l'écho, différé, vienne enfin les toucher.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const PATROL_SCENE := preload("res://scenes/enemy.tscn")
const SANS_VISAGE_SCENE := preload("res://scenes/sans_visage.tscn")
const LEONIE_SCENE := preload("res://scenes/leonie.tscn")

const GROUND_Y := 550.0
const SPAWN_Y := 477.0
const LEVEL_END := 7100.0
const GOAL_X := 6650.0
const LEVEL_ID := "level_17"

## Même royaume sans écho que le niveau 16 : matière mate, aucun poli
## réfléchissant, glitch violet-magenta / cyan qui trahit l'image corrompue.
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
	# Pierre taillée plutôt que le style "naturel" (racines, touffes d'herbe) :
	# ce monde sans écho n'a rien de vivant ni d'organique.
	"cut": true,
}

## Plateformes (x = centre, y = demi-largeur) : sol plat, contrairement au
## relief continu du niveau 16 — le nouveau défi est l'Écho, pas la pente.
const PLATFORMS := [
	Vector2(230, 260), Vector2(860, 210), Vector2(1440, 230),
	Vector2(2020, 200), Vector2(2580, 220), Vector2(3150, 260),
	Vector2(3760, 220), Vector2(4340, 200), Vector2(4900, 230),
	Vector2(5480, 210), Vector2(6050, 230), Vector2(6650, 300),
]
const CHECKPOINT_XS := [2020.0, 4340.0, 6050.0]
const PATROL_XS := [860.0, 3150.0, 6500.0]
const SANS_VISAGE_XS := [1440.0, 4900.0]
## Failles glitchées, bien plus nombreuses que la première traversée du
## Chapitre IV — le chaos gagne aussi les paliers entre les Portes Muettes.
const GLITCH_RIFT_XS := [900.0, 1500.0, 2580.0, 3150.0, 4900.0, 5480.0, 6350.0]
## Cratères de l'Éboulis de miroir, intercalés entre les failles.
const ROCK_SLIDES := [550.0, 1150.0, 2850.0, 5150.0, 5750.0, 6200.0]
## Portes Muettes : n'admettent que l'écho, jamais Eneko lui-même — il faut
## rester immobile devant et attendre que le jumeau, différé, les rejoigne.
const GATE_XS := [1950.0, 4300.0, 6000.0]
const GATE_TRIGGER_RADIUS := 46.0
const REFUGE_X := 3760.0

const LEONIE_LINES := [
	{ "name": "Léonie", "text": "Regarde derrière toi, Eneko : ton reflet lui-même s'est détaché. Il te suit, muet, avec un souffle de retard." },
	{ "name": "Léonie", "text": "Il ne te blessera jamais — la lame le traverse comme une brume. Mais certaines portes n'obéissent qu'à lui : reste immobile devant elles, et laisse-le te rejoindre." },
	{ "name": "Eneko", "text": "Alors j'attendrai mon propre pas, aussi loin qu'il traîne derrière moi. Le silence, cette fois, ouvrira la voie." },
]

var sfx_win: AudioStreamPlayer
var sfx_gate: AudioStreamPlayer
var void_motes: CPUParticles2D
var echo: EchoTwin
var _gates: Array = []
var _glitches: Array = []
var _t := 0.0
## Secousses périodiques, plus marquées qu'au niveau 16 — le chaos du
## Chapitre IV s'installe.
var _shake_t := 1.8

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var next_button: Button = $WinLabel/NextButton
@onready var dialogue: CanvasLayer = $Dialogue

func _ready() -> void:
	_build_decor()
	Atmosphere.add_foreground(self, Color(0.05, 0.04, 0.07, 0.35))
	_build_platforms()
	_build_checkpoints()
	_build_gates()
	_build_glitch_rifts()
	_build_rock_slides()
	_build_goal()
	_build_kill_zone(LEVEL_END, 720.0)
	_spawn_entities()
	_build_echo()
	_setup_audio()
	_setup_ambient()
	player.set_land_dust_color(Color(0.3, 0.26, 0.34, 0.75))
	win_label.visible = false
	Music.play_level(LEVEL_ID)
	SaveManager.set_last_level(LEVEL_ID)
	# Relique cachée, au-dessus du refuge (Double Saut).
	var relic := Relic.new()
	relic.level_id = LEVEL_ID
	relic.position = Vector2(REFUGE_X, GROUND_Y - 220.0)
	add_child(relic)
	Challenge.start_level(LEVEL_ID, _orb_positions().size())
	dialogue.finished.connect(_on_dialogue_finished)
	menu_button.pressed.connect(_on_menu_pressed)
	var next_scene: String = SaveManager.LEVEL_SCENES.get("level_18", "")
	next_button.visible = next_scene != ""
	if next_scene != "":
		next_button.pressed.connect(func(): Transition.goto(next_scene))
	player.intro_pan(Vector2(GOAL_X, GROUND_Y - 220.0))

func _process(delta: float) -> void:
	_t += delta
	for g in _glitches:
		var node: Polygon2D = g["node"]
		node.modulate = GLITCH_A if sin(_t * 9.0 + float(g["phase"])) > 0.3 else GLITCH_B
		node.modulate.a = 0.35 + 0.35 * absf(sin(_t * 5.0 + float(g["phase"])))
	_shake_t -= delta
	if _shake_t <= 0.0 and is_instance_valid(player) and player.has_method("add_shake"):
		var depth := clampf(player.global_position.x / LEVEL_END, 0.0, 1.0)
		player.add_shake(1.5 + depth * 5.5)
		_shake_t = randf_range(2.8, 4.2) * (1.0 - depth * 0.35)
	if echo != null and echo.is_active():
		for g in _gates:
			if not g["open"]:
				var gx: float = (g["node"] as Node2D).global_position.x
				if absf(echo.global_position.x - gx) < GATE_TRIGGER_RADIUS:
					_open_gate(g)

func _physics_process(_delta: float) -> void:
	if void_motes != null and is_instance_valid(player):
		void_motes.position = Vector2(player.position.x, player.position.y - 260.0)

# --- Orbes ------------------------------------------------------------------

func _orb_positions() -> Array:
	var out := []
	var x := 260.0
	var i := 0
	while x < LEVEL_END - 200.0:
		out.append(Vector2(x, GROUND_Y - 130.0 - float(i % 2) * 35.0))
		x += 260.0
		i += 1
	return out

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

## Faille glitchée : hasard fixe, repris tel quel du niveau 16 (classe
## partagée GlitchRift) — même langage visuel pour tout le Chapitre IV.
func _build_glitch_rifts() -> void:
	for x in GLITCH_RIFT_XS:
		var rift := GlitchRift.new()
		rift.position = Vector2(x, GROUND_Y - 50.0)
		rift.phase = x * 0.01
		rift.color_a = GLITCH_A
		rift.color_b = GLITCH_B
		add_child(rift)

## Cratères de l'Éboulis de miroir : classe partagée RockSlide, reprise du
## niveau 16 — le chaos du Chapitre IV gagne aussi la traversée de l'Écho.
func _build_rock_slides() -> void:
	for x in ROCK_SLIDES:
		var rs := RockSlide.new()
		rs.position = Vector2(x, GROUND_Y - 50.0)
		rs.phase = x * 0.017
		rs.tint = Color(0.5, 0.46, 0.56)
		add_child(rs)

## Portes Muettes : un rideau d'énergie déchiqueté qui barre la plateforme,
## cerné d'un double liseré et marqué au sol d'une rune à diamants
## concentriques — le signe que ce point attend une seconde présence pour
## s'ouvrir. Même famille visuelle que la Faille (silhouette irrégulière,
## bandes qui clignotent), pour rester dans le langage du Chapitre IV.
func _build_gates() -> void:
	for x in GATE_XS:
		var gate := StaticBody2D.new()
		gate.position = Vector2(x, GROUND_Y - 120.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(30, 200)
		shape.shape = rect
		gate.add_child(shape)
		# Silhouette abîmée plutôt qu'un rectangle plein : deux longues arêtes
		# droites, entaillées d'un seul éclat qui dépasse et d'une seule morsure
		# par côté — pas un zigzag continu (qui finit par onduler comme un tube
		# à l'échelle du jeu), juste quelques dégâts nets et lisibles.
		var pts := PackedVector2Array([
			Vector2(-15, -100), Vector2(15, -100), Vector2(21, -52), Vector2(15, -22),
			Vector2(15, 8), Vector2(7, 24), Vector2(15, 40), Vector2(15, 100),
			Vector2(-15, 100), Vector2(-15, 58), Vector2(-22, 42), Vector2(-15, 26),
			Vector2(-15, -8), Vector2(-6, -24), Vector2(-15, -42),
		])
		var body_poly := _poly(gate, pts, Color(GLITCH_A.r, GLITCH_A.g, GLITCH_A.b, 0.35))
		var outlines: Array = []
		for off in [Vector2(-2.5, 0.0), Vector2(2.5, 0.0)]:
			var outline := Line2D.new()
			outline.points = pts
			outline.closed = true
			outline.width = 1.8
			outline.position = off
			outline.default_color = Color(GLITCH_A.r, GLITCH_A.g, GLITCH_A.b, 0.75) if off.x < 0.0 else Color(GLITCH_B.r, GLITCH_B.g, GLITCH_B.b, 0.75)
			gate.add_child(outline)
			outlines.append(outline)
		var glow := Sprite2D.new()
		glow.texture = load("res://assets/mist.svg")
		glow.modulate = Color(GLITCH_A.r, GLITCH_A.g, GLITCH_A.b, 0.3)
		glow.scale = Vector2(1.4, 3.2)
		gate.add_child(glow)
		# Bandes de scintillement internes, plus étroites que la silhouette
		# (jamais en saillie) pour ne pas fragmenter le contour en tranches.
		var gate_bands: Array = []
		for k in 4:
			var oy := -70.0 + float(k) * 45.0
			var band := _poly(gate, PackedVector2Array([
				Vector2(-13, oy), Vector2(13, oy), Vector2(13, oy + 6), Vector2(-13, oy + 6),
			]), GLITCH_A)
			var entry := {"node": band, "phase": float(k) * 1.2 + x * 0.01}
			_glitches.append(entry)
			gate_bands.append(entry)
		# Rune de résonance, au pied de la porte : diamants concentriques,
		# le point que l'écho doit atteindre pour que la porte cède.
		var rune := Node2D.new()
		rune.position = Vector2(0, 70)
		for r: float in [11.0, 6.0]:
			var dp := PackedVector2Array([
				Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0),
			])
			var d_line := Line2D.new()
			d_line.points = dp
			d_line.closed = true
			d_line.width = 1.4
			d_line.default_color = Color(GLITCH_B.r, GLITCH_B.g, GLITCH_B.b, 0.85)
			rune.add_child(d_line)
		gate.add_child(rune)
		add_child(gate)
		_gates.append({
			"node": gate, "shape": shape, "poly": body_poly, "outlines": outlines,
			"rune": rune, "glow": glow, "bands": gate_bands, "open": false,
		})

func _open_gate(g: Dictionary) -> void:
	g["open"] = true
	(g["shape"] as CollisionShape2D).set_deferred("disabled", true)
	var at: Vector2 = (g["node"] as Node2D).global_position
	Atmosphere.spark_burst(self, at, GLITCH_B)
	if sfx_gate != null:
		Sfx.varied(sfx_gate, 0.92, 1.08)
	# Les bandes internes sont pilotées par _process via _glitches : il faut
	# les en retirer avant de les faire disparaître, sinon la boucle continue
	# de réécrire leur modulate par-dessus le fondu.
	for entry in (g["bands"] as Array):
		_glitches.erase(entry)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(g["poly"], "modulate:a", 0.0, 0.7)
	for outline in (g["outlines"] as Array):
		tw.tween_property(outline, "modulate:a", 0.0, 0.7)
	for entry in (g["bands"] as Array):
		tw.tween_property(entry["node"], "modulate:a", 0.0, 0.7)
	tw.tween_property(g["rune"], "modulate:a", 0.0, 0.7)
	tw.tween_property(g["glow"], "modulate:a", 0.0, 0.7)

func _build_goal() -> void:
	var goal := Area2D.new()
	goal.position = Vector2(GOAL_X, GROUND_Y - 120.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 140)
	shape.shape = rect
	goal.add_child(shape)
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
		e.position = Vector2(x, SPAWN_Y)
		add_child(e)
	for x in SANS_VISAGE_XS:
		var sv := SANS_VISAGE_SCENE.instantiate()
		sv.position = Vector2(x, SPAWN_Y)
		add_child(sv)
	PlatformPainter.build_sanctuary(self, REFUGE_X, GROUND_Y - 50.0)
	var leonie := LEONIE_SCENE.instantiate()
	leonie.position = Vector2(REFUGE_X, SPAWN_Y)
	leonie.set_lines(LEONIE_LINES)
	add_child(leonie)
	for o in _orb_positions():
		var orb := ORB_SCENE.instantiate()
		orb.position = o
		add_child(orb)

## Le jumeau glitché : réplique visuelle et retardée du joueur, seule clé des
## Portes Muettes. Sans effet ni collision — jamais un danger.
func _build_echo() -> void:
	echo = EchoTwin.new()
	echo.color_a = GLITCH_A
	echo.color_b = GLITCH_B
	echo.delay = 1.4
	add_child(echo)
	echo.target = player

func _setup_ambient() -> void:
	var amb := AmbientDialogue.new()
	add_child(amb)
	amb.add_line(self, 1000.0, "Eneko", "Il marche dans mes pas, un souffle après moi. Étrange, de se voir suivre ainsi.")
	amb.add_line(self, 2650.0, "Eneko", "Cette porte ne cède à rien que je fasse. Il faut... attendre.")
	amb.add_line(self, 4600.0, "Eneko", "Mon écho s'attarde à mesure que j'avance. Rejoindra-t-il un jour mon ombre ?")
	amb.add_line(self, 6200.0, "Eneko", "La dernière porte. Encore un instant, et mon reflet me rejoint enfin.")

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
	sfx_gate = AudioStreamPlayer.new()
	sfx_gate.stream = load("res://assets/sfx/checkpoint.wav")
	sfx_gate.volume_db = -3.0
	add_child(sfx_gate)

# --- Décor --------------------------------------------------------------

func _build_decor() -> void:
	var bg: ParallaxBackground = $ParallaxBackground
	var mist_tex: Texture2D = load("res://assets/mist.svg")

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

	# Crêtes lointaines, dentelées.
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

	# Écho des crêtes : la même silhouette, légèrement décalée et translucide,
	# comme un second tracé qui traîne derrière le premier — le motif visuel
	# du niveau, jusque dans le décor.
	var echo_layer := ParallaxLayer.new()
	echo_layer.motion_scale = Vector2(0.1, 0.3)
	bg.add_child(echo_layer)
	var ex := -170.0
	var ei := 0
	while ex < LEVEL_END + 700.0:
		var eh := 170.0 + float(ei * 53 % 140)
		_poly(echo_layer, PackedVector2Array([
			Vector2(-260, 0), Vector2(-40, -eh + 30), Vector2(0, -eh), Vector2(70, -eh + 50), Vector2(260, 0),
		]), Color(GLITCH_A.r, GLITCH_A.g, GLITCH_A.b, 0.08), Vector2(ex, 604.0))
		ex += 340.0 + float(ei * 41 % 130)
		ei += 1

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
