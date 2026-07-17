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

## Thème du peintre de plateformes (marbre taillé, filet d'or au sommet).
const PLATFORM_THEME := {
	"top": GOLD_TRIM,
	"top_light": Color(0.95, 0.85, 0.5),
	"body_a": MARBLE,
	"body_b": Color(0.75, 0.73, 0.67),
	"dark": MARBLE_DARK,
	"speck": Color(0.72, 0.7, 0.64),
	"cut": true,
}

## Approche en 6 plateformes — dont un grand vide de 400 px franchissable
## uniquement par deux dalles effondrables — puis la grande arène du boss.
const PLATFORMS := [
	Vector2(230, 230), Vector2(850, 210), Vector2(1470, 230),
	Vector2(2090, 210), Vector2(2900, 200), Vector2(3520, 190),
	Vector2(4700, 900),  # l'arène du combat final
]
const CHECKPOINT_XS := [1470.0, 3520.0]
const PATROL_XS := [1470.0, 2090.0, 3520.0]
const SHADOW_XS := [1300.0]
## Yūrei tireurs : toujours au-dessus d'une plateforme — le passage aux
## dalles effondrables reste un défi de plateforme pur, sans tirs.
const SPIRIT_XS := []
const TRAP_XS := [730.0, 1970.0, 2800.0, 3450.0]
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
	{ "name": "???", "text": "Qui ose troubler les cendres de ce sanctuaire ?" },
	{ "name": "Eneko", "text": "Je viens rallumer la Flamme d'Aube. Et te délivrer, Gardien — Léonie m'a tout dit." },
	{ "name": "Eneko", "text": "(Ses mots me reviennent : « Lis ses coups. Pare-les au bon moment... ou esquive d'une ruée et frappe juste après — ta lame tranchera deux fois plus fort. »)" },
	{ "name": "???", "text": "Léonie... ce nom n'éveille plus rien en moi. Il ne reste que l'Ombre. Viens la briser, si tu le peux." },
]
const VICTORY_LINE := "La Flamme d'Aube renaît !"

var sfx_win: AudioStreamPlayer
var motes: CPUParticles2D
var boss: CharacterBody2D = null
var _arena_triggered := false
var _boss_intro_done := false
var _barriers: Array = []
## Rais de lumière de l'arène : chacun balance et respire (voir _process).
var _shafts: Array = []
## Bannières de l'approche : elles ondulent doucement (voir _process).
var _banners: Array = []
## Taches de vitrail projetées au sol de l'arène (voir _process).
var _glass: Array = []
## Poussières dorées qui flottent dans les rais de lumière (voir _process).
var _dust: Array = []
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
	# Brume sacrée texturée qui rampe au sol du sanctuaire.
	TextureLab.add_ground_mist(self, 8, GROUND_Y - 44.0, LEVEL_END,
		Color(0.86, 0.82, 0.7, 0.1), 1)
	_build_platforms()
	_build_glass_floor()
	_build_pillars()
	_build_crumbles()
	_build_checkpoints()
	_build_traps()
	_build_hazards()
	_build_arena_trigger()
	_build_kill_zone()
	_spawn_entities()
	_spawn_boss()
	_setup_audio()
	_setup_ambient()
	win_label.visible = false
	boss_ui.visible = false
	# Si on vient de mourir pendant le combat, le niveau redémarre : on
	# revient au thème du monde jusqu'à la prochaine entrée dans l'arène.
	Music.play_world()
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

## Anime les rais de lumière de l'arène : léger balancement horizontal et
## respiration de l'intensité, chacun à son propre rythme.
func _process(delta: float) -> void:
	_t += delta
	for s in _shafts:
		var n: Polygon2D = s["node"]
		var ph: float = s["phase"]
		n.position.x = float(s["base_x"]) + sin(_t * 0.5 + ph) * 14.0
		n.color.a = 0.06 + 0.05 * (0.5 + 0.5 * sin(_t * 0.8 + ph))
	for bnr in _banners:
		var bn: Polygon2D = bnr["node"]
		bn.rotation = 0.12 * sin(_t * 1.6 + float(bnr["phase"]))
	for g in _glass:
		var gn: Polygon2D = g["node"]
		var ba: float = g["base_a"]
		gn.color.a = ba * (0.35 + 0.65 * (0.5 + 0.5 * sin(_t * 0.6 + float(g["phase"]))))
	for d in _dust:
		var dnode: Polygon2D = d["node"]
		var dph: float = float(d["phase"])
		# Montée lente avec enroulement en haut du rai.
		var yy: float = float(d["y"]) - float(d["spd"]) * delta
		if yy < -20.0:
			yy = 560.0
		d["y"] = yy
		var sway := 6.0 * sin(_t * 0.7 + dph)
		dnode.position = Vector2(float(d["x"]) + sway, yy)
		# Scintillement doux.
		dnode.color.a = 0.25 + 0.35 * (0.5 + 0.5 * sin(_t * 1.6 + dph))

# --- Construction du niveau ---------------------------------------------

## Taches de lumière colorée projetées au sol de l'arène, comme la clarté
## qui tombe des verrières d'un sanctuaire ; leur intensité respire.
func _build_glass_floor() -> void:
	var cols := [Color(0.4, 0.6, 1.0), Color(1.0, 0.82, 0.4),
		Color(0.9, 0.32, 0.36), Color(0.95, 0.95, 1.0)]
	var x := ARENA_MIN_X + 90.0
	var i := 0
	while x < ARENA_MAX_X - 60.0:
		var c: Color = cols[i % cols.size()]
		var base_a := 0.1 + 0.04 * float(i % 3)
		var pane := _poly(self, PackedVector2Array([
			Vector2(-48, 0), Vector2(22, 0), Vector2(50, 42), Vector2(-20, 42),
		]), Color(c.r, c.g, c.b, base_a), Vector2(x, GROUND_Y - 50.0))
		_glass.append({"node": pane, "base_a": base_a, "phase": float(i) * 0.9})
		x += 128.0
		i += 1

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
		var beam := _poly(shafts, PackedVector2Array([
			Vector2(-sw, 0), Vector2(sw * 0.4, 0),
			Vector2(sw * 1.7, 560), Vector2(sw * 0.3, 560),
		]), Color(1.0, 0.95, 0.75, 0.09), Vector2(sx, -10))
		# Chaque rai balance doucement et respire à son propre rythme.
		_shafts.append({"node": beam, "base_x": sx, "phase": float(si) * 1.4})
		# Poussières en suspension qui flottent lentement dans le rai.
		var dn := 0
		while dn < 5:
			var offx := -sw * 0.4 + float((dn * 53 + si * 37) % int(sw * 1.6))
			var yy := float((dn * 97 + si * 61) % 540)
			var dot := _poly(shafts, PackedVector2Array([
				Vector2(-1.5, 0), Vector2(0, -1.5), Vector2(1.5, 0), Vector2(0, 1.5),
			]), Color(1.0, 0.95, 0.72, 0.0), Vector2(sx + offx, yy))
			_dust.append({
				"node": dot, "x": sx + offx, "y": yy,
				"spd": 8.0 + float(dn % 3) * 5.0, "phase": float(dn * 90 + si * 40) * 0.01,
			})
			dn += 1
		sx += 520.0 + float(si * 43 % 240)
		si += 1

	# Grand portique doré en fond, derrière l'arène : dernière image que
	# le joueur voit avant le combat.
	var gate := ParallaxLayer.new()
	gate.motion_scale = Vector2(0.3, 0.6)
	bg.add_child(gate)
	var col_pts := PackedVector2Array([
		Vector2(-14, 0), Vector2(14, 0), Vector2(14, -260), Vector2(-14, -260),
	])
	_poly(gate, col_pts, GOLD_TRIM, Vector2(BOSS_SPAWN_X + 180.0, 540))
	_poly(gate, col_pts, GOLD_TRIM, Vector2(BOSS_SPAWN_X - 180.0, 540))
	# Or patiné : grain sur les montants et le linteau du grand portique.
	TextureLab.grain_poly(gate, col_pts, 0.12, Vector2(0, 0), Vector2(BOSS_SPAWN_X + 180.0, 540))
	TextureLab.grain_poly(gate, col_pts, 0.12, Vector2(40, 0), Vector2(BOSS_SPAWN_X - 180.0, 540))
	var lintel_pts := PackedVector2Array([
		Vector2(-210, -250), Vector2(210, -250), Vector2(190, -280), Vector2(-190, -280),
	])
	_poly(gate, lintel_pts, GOLD_TRIM, Vector2(BOSS_SPAWN_X, 540))
	TextureLab.grain_poly(gate, lintel_pts, 0.12, Vector2(0, 0), Vector2(BOSS_SPAWN_X, 540))
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
		var cloth := _poly(banners, PackedVector2Array([
			Vector2(-14, 0), Vector2(14, 0), Vector2(14, 90), Vector2(0, 78), Vector2(-14, 90),
		]), Color(0.95, 0.9, 0.8, 0.85), Vector2(bx, 250.0))
		# La bannière ondule doucement, comme sous une brise sacrée.
		_banners.append({"node": cloth, "phase": bx * 0.013})
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
		PlatformPainter.paint(body, p.y, PLATFORM_THEME)
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
		# Veinage du marbre : fin grain tuilé sur le fût.
		TextureLab.grain_poly(pillar, _rect_points(16.0, -220.0, 0.0), 0.1, Vector2(float(x), 0.0))
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

## Lanceurs de dards spectraux gardant l'approche du sanctuaire : posés au
## bord droit de deux plateformes, ils tirent vers la gauche — les dards
## viennent à la rencontre d'Eneko qui avance, et s'esquivent d'un saut.
func _build_hazards() -> void:
	# Lanceurs de dards sur les plateformes 2 et 4 (tir vers la gauche).
	for entry in [{"x": 1680.0, "ph": 0.0}, {"x": 3080.0, "ph": 1.2}]:
		var d := DartLauncher.new()
		d.position = Vector2(entry["x"], GROUND_Y - 50.0)
		d.dir = -1.0
		d.phase = entry["ph"]
		d.tint = Color(0.7, 0.5, 1.0)
		add_child(d)
	# Presse spectrale sur la plateforme 1 (la moins chargée) : alterne avec
	# les dards pour un gantelet varié, sans jamais empiler les dangers.
	var c := SpectralCrusher.new()
	c.position = Vector2(980.0, GROUND_Y - 50.0)
	c.phase = 0.0
	add_child(c)

func _build_traps() -> void:
	for x in TRAP_XS:
		var trap := Area2D.new()
		trap.position = Vector2(x, GROUND_Y - 54.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(66, 34)
		shape.shape = rect
		trap.add_child(shape)
		_poly(trap, PackedVector2Array([
			Vector2(-33, 22), Vector2(33, 22), Vector2(33, 6), Vector2(-33, 6),
		]), MARBLE_DARK)
		for k in 4:
			var ox := -24.0 + k * 16.0
			_poly(trap, PackedVector2Array([
				Vector2(ox - 7, 6), Vector2(ox + 7, 6), Vector2(ox, -22),
			]), Color(0.55, 0.15, 0.15))
			_poly(trap, PackedVector2Array([
				Vector2(ox - 3, 2), Vector2(ox + 3, 2), Vector2(ox, -18),
			]), Color(0.7, 0.24, 0.22))
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
## Répliques d'ambiance au fil du niveau (non bloquantes).
func _setup_ambient() -> void:
	var amb := AmbientDialogue.new()
	add_child(amb)
	amb.add_line(self, 850.0, "Eneko", "Le marbre résonne encore des prières d'autrefois. Ici brûlait la Flamme.")
	amb.add_line(self, 2900.0, "Eneko", "L'autel est froid. Il ne tient qu'à moi de le rallumer.")
	amb.add_line(self, 3600.0, "Voix", "Approche, porteur de lumière. Voyons si ta flamme vaut mieux que la mienne.")

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
		Music.play_boss()
		_raise_barriers()
		if is_instance_valid(boss):
			boss.activate()

## Barrières spirituelles qui scellent l'arène pendant le combat.
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
		col.color = Color(1.0, 0.85, 0.45, 0.3)
		b.add_child(col)
		var glow := Sprite2D.new()
		glow.texture = load("res://assets/mist.svg")
		glow.modulate = Color(1.0, 0.85, 0.5, 0.22)
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
	# Le Gardien entre en rage : deux Ombres viennent renforcer l'arène.
	for x in [ARENA_MIN_X + 90.0, ARENA_MAX_X - 90.0]:
		var s := SHADOW_SCENE.instantiate()
		s.position = Vector2(x, SPAWN_Y)
		add_child(s)

func _on_boss_defeated() -> void:
	player.set_physics_process(false)
	boss_ui.visible = false
	Music.play_world()
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

	# Récap dans un conteneur défilant : l'histoire finale et le teaser
	# peuvent s'étendre sans jamais être tronqués.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 60.0
	scroll.offset_right = -60.0
	scroll.offset_top = 22.0
	scroll.offset_bottom = -22.0
	layer.add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	UiScroll.make_touch_friendly(scroll)

	var title := Label.new()
	title.text = "La Flamme d'Aube renaît !"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	box.add_child(title)

	var epilogue := Label.new()
	epilogue.text = "Libéré de l'Ombre, le Gardien s'incline une dernière fois, puis s'éteint en paix. La Flamme d'Aube s'élève à nouveau au cœur du Sanctuaire ; sa clarté redescend sur la montagne, le village, le temple, la clairière. Les âmes en peine trouvent enfin le repos, et Léonie, dernier éclat, peut rejoindre la lumière. La contrée est sauvée — par la Voie du Sabre d'Eneko."
	epilogue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	epilogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	epilogue.custom_minimum_size = Vector2(640, 0)
	epilogue.add_theme_font_size_override("font_size", 16)
	epilogue.add_theme_color_override("font_color", Color(0.94, 0.9, 0.82))
	box.add_child(epilogue)

	var farewell := Label.new()
	farewell.text = "Léonie : « Merci, Eneko. Ma lumière peut enfin se reposer... mais garde ta lame près de toi. »"
	farewell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	farewell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	farewell.custom_minimum_size = Vector2(640, 0)
	farewell.add_theme_font_size_override("font_size", 16)
	farewell.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	box.add_child(farewell)

	box.add_child(_spacer(6.0))

	var run := Label.new()
	run.text = "Gardien vaincu — Grade : %s — %s — Orbes : %d/%d — Esprits vaincus : %d" % [
		Challenge.grade_name(results["grade"]), _format_time(results["time"]),
		results["orbs"], results["total_orbs"], results["kills"],
	]
	if int(results["combo"]) >= 2:
		run.text += " — Meilleur combo : ×%d" % int(results["combo"])
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

	# Si le Chapitre II existe, on propose d'y plonger directement.
	var chap2_scene: String = SaveManager.LEVEL_SCENES.get("level_6", "")
	if chap2_scene != "":
		var chap2 := _recap_button("Chapitre II →", Color(1.0, 0.5, 0.2))
		chap2.pressed.connect(func(): get_tree().change_scene_to_file(chap2_scene))
		buttons.add_child(chap2)
	var replay := _recap_button("Rejouer le niveau", Color(0.92, 0.65, 0.3))
	replay.pressed.connect(func(): get_tree().reload_current_scene())
	buttons.add_child(replay)
	var menu_b := _recap_button("Retour au menu", Color(0.6, 0.5, 0.45))
	menu_b.pressed.connect(_on_menu_pressed)
	buttons.add_child(menu_b)

	# --- Amorce du chapitre suivant : la vraie source de l'Ombre s'éveille.
	box.add_child(_spacer(18.0))
	var suite := Label.new()
	suite.text = "À suivre…"
	suite.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	suite.add_theme_font_size_override("font_size", 22)
	suite.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
	box.add_child(suite)

	var chap := Label.new()
	chap.text = "Chapitre II — Les Rivages de Cendre"
	chap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chap.add_theme_font_size_override("font_size", 18)
	chap.add_theme_color_override("font_color", Color(0.85, 0.8, 0.9))
	box.add_child(chap)

	var hook := Label.new()
	hook.text = "Dans son dernier souffle, le Gardien a murmuré : « Je n'étais que le premier à tomber... L'Ombre a une source, par-delà la mer de brume. Et elle s'éveille. » La Voie du Sabre ne fait que commencer."
	hook.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hook.custom_minimum_size = Vector2(640, 0)
	hook.add_theme_font_size_override("font_size", 15)
	hook.add_theme_color_override("font_color", Color(0.82, 0.8, 0.86))
	box.add_child(hook)
	box.add_child(_spacer(10.0))

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
