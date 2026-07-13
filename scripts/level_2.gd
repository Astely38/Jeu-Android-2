extends Node2D
## Niveau 2 : « Le Temple Oublié ».
## Ruine sacrée dressée dans la nuit : ciel étoilé, lune au sommet,
## piliers de pierre, statues gardiennes, bannières, torches animées
## et braises flottantes. Ascension en zigzag jusqu'au sanctuaire.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const PATROL_SCENE := preload("res://scenes/enemy.tscn")
const SHADOW_SCENE := preload("res://scenes/shadow.tscn")
const LEONIE_SCENE := preload("res://scenes/leonie.tscn")

const LEVEL_ID := "level_2"

## Plateformes : zigzag gauche-droite, montée douce.
const PLATFORMS := [
	Vector2(300, 1900),
	Vector2(160, 1810), Vector2(420, 1730), Vector2(160, 1650), Vector2(420, 1570),
	Vector2(300, 1480),
	Vector2(420, 1390), Vector2(180, 1310), Vector2(420, 1230), Vector2(180, 1150),
	Vector2(300, 1060),
	Vector2(160, 970), Vector2(420, 890), Vector2(160, 810), Vector2(420, 730),
	Vector2(300, 640),
	Vector2(420, 550), Vector2(180, 470), Vector2(420, 390),
	Vector2(300, 290),
]
const HALF_WIDTHS := [
	240,
	120, 120, 120, 120,
	200,
	120, 120, 120, 120,
	200,
	120, 120, 120, 120,
	200,
	120, 120, 120,
	180,
]
const CHECKPOINT_IDX := [5, 10, 15]
const LEONIE_IDX := 10
const TOP_IDX := 19

const PATROL_IDX := [2, 4, 7, 9, 12, 14, 17]
const SHADOW_IDX := [6, 13, 18]
const TRAP_IDX := [3, 8, 11, 16]
const BANNER_IDX := [2, 7, 12, 17]

const LEONIE_LINES := [
	{ "name": "Léonie", "text": "Tu progresses bien, Eneko. Ce temple ancien respire d'une malveillance ancienne." },
	{ "name": "Léonie", "text": "Les Ombres y ont établi leur repaire depuis longtemps. Mais tu n'es pas seul." },
	{ "name": "Léonie", "text": "Je veille sur toi. Ma lumière te protégera un moment. Utilise ce temps pour avancer." },
	{ "name": "Léonie", "text": "Le sanctuaire au sommet attend ta purification. Les torches te guideront." },
	{ "name": "Eneko", "text": "Merci, Léonie. Je vais les chasser de ce lieu." },
]

const STONE := Color(0.45, 0.42, 0.38)
const STONE_TOP := Color(0.55, 0.52, 0.46)
const STONE_DARK := Color(0.32, 0.3, 0.26)
const MOSS := Color(0.32, 0.44, 0.28, 0.7)
const CLOTH := Color(0.52, 0.13, 0.11)
const CLOTH_TRIM := Color(0.85, 0.68, 0.3)

var sfx_win: AudioStreamPlayer
var embers: CPUParticles2D
var _flames: Array = []
var _halos: Array = []
var _t := 0.0

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var next_button: Button = $WinLabel/NextButton
@onready var dialogue: CanvasLayer = $Dialogue

func _ready() -> void:
	_build_decor()
	_build_platforms()
	_build_torches()
	_build_checkpoints()
	_build_traps()
	_build_goal()
	_build_kill_zone()
	_spawn_entities()
	_setup_audio()
	win_label.visible = false
	SaveManager.set_last_level(LEVEL_ID)
	var orb_count := _count_orbs()
	Challenge.start_level(LEVEL_ID, orb_count)
	menu_button.pressed.connect(_on_menu_pressed)
	dialogue.finished.connect(_on_dialogue_finished)
	var next_scene: String = SaveManager.LEVEL_SCENES.get("level_3", "")
	next_button.visible = next_scene != ""
	if next_scene != "":
		next_button.pressed.connect(func(): get_tree().change_scene_to_file(next_scene))

func _process(delta: float) -> void:
	_t += delta
	for i in _flames.size():
		var f: Polygon2D = _flames[i]
		f.scale.y = 1.0 + 0.16 * sin(_t * 8.0 + i * 1.7)
		f.scale.x = 1.0 + 0.1 * sin(_t * 6.3 + i * 2.3)
	for i in _halos.size():
		var h: Sprite2D = _halos[i]
		h.modulate.a = 0.17 + 0.06 * sin(_t * 5.0 + i * 1.3)

func _physics_process(_delta: float) -> void:
	if embers != null and is_instance_valid(player):
		embers.position = player.position + Vector2(0, -80.0)

func _poly(parent: Node, points: PackedVector2Array, color: Color, pos := Vector2.ZERO) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.position = pos
	parent.add_child(p)
	return p

func _rect_points(hw: float, top: float, bot: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-hw, top), Vector2(hw, top),
		Vector2(hw, bot), Vector2(-hw, bot),
	])

func _stand_y(idx: int) -> Vector2:
	var p: Vector2 = PLATFORMS[idx]
	return Vector2(p.x, p.y - 73.0)

## Décor de fond : étoiles, lune, silhouette de la tour en ruine,
## colonnes fantômes et piliers latéraux qui portent les torches.
func _build_decor() -> void:
	# Étoiles scintillantes sur toute la hauteur du ciel.
	var i := 0
	while i < 70:
		var sx := -380.0 + float((i * 137) % 1360)
		var sy := 60.0 + float((i * 211) % 1840)
		var r := 1.4 + float(i % 3) * 0.7
		_poly(self, PackedVector2Array([
			Vector2(-r, 0), Vector2(0, -r), Vector2(r, 0), Vector2(0, r),
		]), Color(0.92, 0.93, 1.0, 0.4 + float(i % 4) * 0.12), Vector2(sx, sy))
		i += 1

	# Lune croissante près du sanctuaire (récompense visuelle du sommet).
	var moon_glow := Sprite2D.new()
	moon_glow.texture = load("res://assets/mist.svg")
	moon_glow.modulate = Color(0.8, 0.85, 1.0, 0.3)
	moon_glow.scale = Vector2(5.0, 5.0)
	moon_glow.position = Vector2(730.0, 240.0)
	add_child(moon_glow)
	var moon := PackedVector2Array()
	var k := 0
	while k <= 20:
		var a := -1.9 + k * 3.8 / 20.0
		moon.append(Vector2(cos(a) * 26.0, sin(a) * 26.0))
		k += 1
	k = 20
	while k >= 0:
		var a2 := -1.6 + k * 3.2 / 20.0
		moon.append(Vector2(cos(a2) * 20.0 + 9.0, sin(a2) * 20.0))
		k -= 1
	_poly(self, moon, Color(0.92, 0.94, 1.0, 0.9), Vector2(730, 240))

	# Silhouette de la tour en ruine derrière les plateformes.
	_poly(self, PackedVector2Array([
		Vector2(-30, 2050), Vector2(-30, 320), Vector2(-10, 300), Vector2(30, 330),
		Vector2(80, 260), Vector2(130, 310), Vector2(200, 280), Vector2(270, 320),
		Vector2(330, 250), Vector2(400, 300), Vector2(470, 270), Vector2(520, 320),
		Vector2(570, 290), Vector2(610, 330), Vector2(630, 2050),
	]), Color(0.12, 0.1, 0.13, 0.9))

	# Fenêtres en arche coiffées d'un petit toit de tuiles, éclairées
	# de l'intérieur.
	i = 0
	while i < 5:
		var wx := 150.0 if i % 2 == 0 else 450.0
		var wy := 1740.0 - i * 330.0
		_poly(self, PackedVector2Array([
			Vector2(wx - 14, wy), Vector2(wx + 14, wy), Vector2(wx + 14, wy - 34),
			Vector2(wx, wy - 48), Vector2(wx - 14, wy - 34),
		]), Color(0.95, 0.62, 0.25, 0.13))
		_poly(self, PackedVector2Array([
			Vector2(wx - 30, wy - 52), Vector2(wx + 30, wy - 52),
			Vector2(wx + 18, wy - 64), Vector2(wx - 18, wy - 64),
		]), Color(0.17, 0.15, 0.19, 0.9))
		_poly(self, PackedVector2Array([
			Vector2(wx - 38, wy - 58), Vector2(wx - 30, wy - 52), Vector2(wx - 22, wy - 54),
		]), Color(0.17, 0.15, 0.19, 0.9))
		_poly(self, PackedVector2Array([
			Vector2(wx + 38, wy - 58), Vector2(wx + 30, wy - 52), Vector2(wx + 22, wy - 54),
		]), Color(0.17, 0.15, 0.19, 0.9))
		_poly(self, PackedVector2Array([
			Vector2(wx - 30, wy - 50), Vector2(wx + 30, wy - 50),
			Vector2(wx + 28, wy - 54), Vector2(wx - 28, wy - 54),
		]), Color(0.45, 0.13, 0.1, 0.8))
		i += 1

	# Colonnes fantômes laquées à l'intérieur de la tour.
	for cx in [150.0, 300.0, 450.0]:
		var yy := 1990.0
		while yy > 420.0:
			_poly(self, _rect_points(16.0, -360.0, 0.0), Color(0.3, 0.14, 0.12, 0.3), Vector2(cx, yy))
			_poly(self, _rect_points(22.0, -378.0, -360.0), Color(0.5, 0.38, 0.2, 0.3), Vector2(cx, yy))
			yy -= 390.0

	# Piliers latéraux : colonnes de bois laqué rouge cerclées d'or,
	# elles portent les torches.
	for cx in [50.0, 550.0]:
		var inner := 1.0 if cx < 300.0 else -1.0
		# Fût continu.
		_poly(self, _rect_points(20.0, -1720.0, 0.0), Color(0.36, 0.14, 0.1), Vector2(cx, 2020.0))
		# Ombre côté extérieur, reflet côté intérieur.
		_poly(self, PackedVector2Array([
			Vector2(-20.0 * inner, -1720), Vector2(-10.0 * inner, -1720),
			Vector2(-10.0 * inner, 0), Vector2(-20.0 * inner, 0),
		]), Color(0.26, 0.1, 0.08), Vector2(cx, 2020.0))
		_poly(self, PackedVector2Array([
			Vector2(12.0 * inner, -1720), Vector2(20.0 * inner, -1720),
			Vector2(20.0 * inner, 0), Vector2(12.0 * inner, 0),
		]), Color(0.46, 0.2, 0.14), Vector2(cx, 2020.0))
		# Anneaux dorés.
		var yy := 1980.0
		while yy > 320.0:
			_poly(self, _rect_points(24.0, -10.0, 0.0), Color(0.8, 0.62, 0.28), Vector2(cx, yy))
			yy -= 235.0
		# Base de pierre et chapiteau.
		_poly(self, _rect_points(30.0, -22.0, 0.0), STONE_DARK, Vector2(cx, 2020.0))
		_poly(self, _rect_points(30.0, 0.0, 20.0), STONE_DARK, Vector2(cx, 300.0))

## Plateformes : balcons de bois laqué (petites) et terrasses de pierre
## sculptée (grands paliers). La collision reste identique (24px centrés).
func _build_platforms() -> void:
	for i in PLATFORMS.size():
		var p: Vector2 = PLATFORMS[i]
		var hw: float = HALF_WIDTHS[i]
		var body := StaticBody2D.new()
		body.position = p
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(hw * 2.0, 24.0)
		shape.shape = rect
		body.add_child(shape)
		if hw >= 180.0:
			_deco_terrace(body, hw)
		else:
			_deco_balcony(body, hw, i)
		add_child(body)

## Terrasse de pierre : corniche débordante, frise gravée, mousse.
func _deco_terrace(body: Node, hw: float) -> void:
	_poly(body, _rect_points(hw + 10.0, -12.0, -4.0), Color(0.6, 0.56, 0.48))
	_poly(body, _rect_points(hw, -4.0, 48.0), STONE)
	_poly(body, _rect_points(hw - 6.0, 8.0, 28.0), Color(0.38, 0.35, 0.3))
	var mx := -hw + 18.0
	while mx < hw - 18.0:
		_poly(body, PackedVector2Array([
			Vector2(mx, 13), Vector2(mx + 12, 13), Vector2(mx + 12, 23), Vector2(mx, 23),
		]), Color(0.5, 0.46, 0.4))
		mx += 30.0
	_poly(body, _rect_points(hw, 40.0, 48.0), STONE_DARK)
	_poly(body, PackedVector2Array([
		Vector2(-hw - 10, -12), Vector2(-hw + 20, -12),
		Vector2(-hw + 14, -18), Vector2(-hw - 2, -14),
	]), MOSS)
	_poly(body, PackedVector2Array([
		Vector2(hw - 20, -12), Vector2(hw + 10, -12),
		Vector2(hw + 2, -14), Vector2(hw - 14, -18),
	]), MOSS)

## Balcon de bois : plancher, poutre laquée rouge aux embouts dorés,
## étais croisés, lanterne de papier ou bannière suspendue.
func _deco_balcony(body: Node, hw: float, i: int) -> void:
	# Plancher de bois avec rainures.
	_poly(body, _rect_points(hw, -12.0, 2.0), Color(0.5, 0.34, 0.2))
	var px := -hw + 34.0
	while px < hw - 10.0:
		_poly(body, PackedVector2Array([
			Vector2(px, -12), Vector2(px + 2, -12), Vector2(px + 2, 2), Vector2(px, 2),
		]), Color(0.38, 0.25, 0.14))
		px += 42.0
	# Poutre laquée rouge.
	_poly(body, _rect_points(hw, 2.0, 18.0), Color(0.58, 0.16, 0.12))
	_poly(body, _rect_points(hw, 14.0, 18.0), Color(0.42, 0.11, 0.08))
	# Embouts dorés.
	for side in [-1.0, 1.0]:
		_poly(body, PackedVector2Array([
			Vector2(side * (hw - 10.0), 0.0), Vector2(side * hw, 0.0),
			Vector2(side * hw, 20.0), Vector2(side * (hw - 10.0), 20.0),
		]), CLOTH_TRIM)
	# Jambes de force sous le balcon.
	for side in [-1.0, 1.0]:
		_poly(body, PackedVector2Array([
			Vector2(side * (hw - 18.0), 18.0), Vector2(side * (hw - 32.0), 18.0),
			Vector2(side * 6.0, 82.0), Vector2(side * 20.0, 82.0),
		]), Color(0.34, 0.21, 0.12))
	_poly(body, PackedVector2Array([
		Vector2(-24, 76), Vector2(24, 76), Vector2(18, 92), Vector2(-18, 92),
	]), Color(0.28, 0.17, 0.1))
	# Bannière ou lanterne suspendue.
	var banner_side := -1.0 if i % 2 == 0 else 1.0
	if i in BANNER_IDX:
		var bx := banner_side * (hw - 34.0)
		_poly(body, PackedVector2Array([
			Vector2(bx - 12, 20), Vector2(bx + 12, 20),
			Vector2(bx + 12, 122), Vector2(bx, 108), Vector2(bx - 12, 122),
		]), CLOTH)
		_poly(body, PackedVector2Array([
			Vector2(bx - 12, 28), Vector2(bx + 12, 28),
			Vector2(bx + 12, 34), Vector2(bx - 12, 34),
		]), CLOTH_TRIM)
		var em := PackedVector2Array()
		var k := 0
		while k < 8:
			var a := k * TAU / 8.0
			em.append(Vector2(bx + cos(a) * 6.0, 68.0 + sin(a) * 6.0))
			k += 1
		_poly(body, em, CLOTH_TRIM)
	if i % 2 == 1:
		var lantern_side := 1.0 if i % 4 == 1 else -1.0
		if i in BANNER_IDX:
			lantern_side = -banner_side
		_build_lantern(body, Vector2(lantern_side * (hw - 26.0), 46.0))

## Lanterne de papier ronde suspendue, au halo pulsant.
func _build_lantern(parent: Node, pos: Vector2) -> void:
	_poly(parent, PackedVector2Array([
		Vector2(pos.x - 1, 18), Vector2(pos.x + 1, 18),
		Vector2(pos.x + 1, pos.y - 12), Vector2(pos.x - 1, pos.y - 12),
	]), Color(0.2, 0.15, 0.1))
	var lg := Sprite2D.new()
	lg.texture = load("res://assets/mist.svg")
	lg.modulate = Color(1.0, 0.72, 0.35, 0.22)
	lg.scale = Vector2(2.2, 2.2)
	lg.position = pos
	parent.add_child(lg)
	_halos.append(lg)
	var lpts := PackedVector2Array()
	var k := 0
	while k < 12:
		var a := k * TAU / 12.0
		lpts.append(Vector2(pos.x + cos(a) * 9.0, pos.y + sin(a) * 11.0))
		k += 1
	_poly(parent, lpts, Color(1.0, 0.62, 0.28, 0.95))
	_poly(parent, PackedVector2Array([
		Vector2(pos.x - 8, pos.y - 5), Vector2(pos.x + 8, pos.y - 5),
		Vector2(pos.x + 8, pos.y - 3), Vector2(pos.x - 8, pos.y - 3),
	]), Color(0.75, 0.4, 0.18))
	_poly(parent, PackedVector2Array([
		Vector2(pos.x - 8, pos.y + 3), Vector2(pos.x + 8, pos.y + 3),
		Vector2(pos.x + 8, pos.y + 5), Vector2(pos.x - 8, pos.y + 5),
	]), Color(0.75, 0.4, 0.18))

## Torches accrochées aux piliers : flammes animées et halos pulsants.
func _build_torches() -> void:
	var mist_tex: Texture2D = load("res://assets/mist.svg")
	var torch_xs := [50.0, 550.0]
	var y := 1850.0
	while y > 300.0:
		for tx in torch_xs:
			var t := Node2D.new()
			t.position = Vector2(tx, y)
			var dir := 1.0 if tx < 300.0 else -1.0
			var fx := 20.0 * dir
			# Bras de fer forgé
			_poly(t, PackedVector2Array([
				Vector2(0, -2), Vector2(fx, -4), Vector2(fx, 2), Vector2(0, 4),
			]), Color(0.16, 0.14, 0.13))
			# Coupelle
			_poly(t, PackedVector2Array([
				Vector2(fx - 8, -4), Vector2(fx + 8, -4), Vector2(fx + 5, 4), Vector2(fx - 5, 4),
			]), Color(0.24, 0.2, 0.17))
			# Halo doux (sprite radial)
			var halo := Sprite2D.new()
			halo.texture = mist_tex
			halo.modulate = Color(1.0, 0.65, 0.25, 0.2)
			halo.scale = Vector2(3.4, 3.4)
			halo.position = Vector2(fx, -14.0)
			t.add_child(halo)
			_halos.append(halo)
			# Flamme animée (base ancrée dans la coupelle)
			var flame := Polygon2D.new()
			flame.position = Vector2(fx, -3.0)
			flame.polygon = PackedVector2Array([
				Vector2(-6, 0), Vector2(6, 0), Vector2(4, -12), Vector2(0, -22), Vector2(-4, -12),
			])
			flame.color = Color(1.0, 0.6, 0.15)
			var inner := Polygon2D.new()
			inner.polygon = PackedVector2Array([
				Vector2(-3, 0), Vector2(3, 0), Vector2(0, -14),
			])
			inner.color = Color(1.0, 0.9, 0.45)
			flame.add_child(inner)
			t.add_child(flame)
			_flames.append(flame)
			add_child(t)
		y -= 160.0

	# Braises flottantes qui suivent le joueur dans l'ascension.
	embers = CPUParticles2D.new()
	embers.amount = 26
	embers.lifetime = 5.0
	embers.preprocess = 5.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(340, 260)
	embers.direction = Vector2(0, -1)
	embers.spread = 30.0
	embers.gravity = Vector2(0, -16)
	embers.initial_velocity_min = 6.0
	embers.initial_velocity_max = 20.0
	embers.scale_amount_min = 1.4
	embers.scale_amount_max = 2.8
	embers.color = Color(1.0, 0.62, 0.2, 0.5)
	add_child(embers)

func _build_checkpoints() -> void:
	for idx in CHECKPOINT_IDX:
		var p: Vector2 = PLATFORMS[idx]
		var hw: float = HALF_WIDTHS[idx]
		# Statues gardiennes aux deux bords du palier.
		_build_statue(Vector2(p.x - hw + 36.0, p.y - 12.0), 1.0)
		_build_statue(Vector2(p.x + hw - 36.0, p.y - 12.0), -1.0)
		var cp := Area2D.new()
		cp.position = Vector2(p.x, p.y - 80.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(60, 120)
		shape.shape = rect
		cp.add_child(shape)
		_poly(cp, PackedVector2Array([
			Vector2(-3, -60), Vector2(3, -60), Vector2(3, 60), Vector2(-3, 60),
		]), Color(0.35, 0.28, 0.2))
		var flag := _poly(cp, PackedVector2Array([
			Vector2(3, -60), Vector2(40, -50), Vector2(3, -38),
		]), Color(0.85, 0.75, 0.35))
		add_child(cp)
		cp.body_entered.connect(_on_checkpoint.bind(cp, flag))

## Statue gardienne (komainu stylisé) : socle, corps assis, tête dressée
## et œil qui luit dans la pénombre.
func _build_statue(pos: Vector2, side: float) -> void:
	var st := Node2D.new()
	st.position = pos
	st.scale = Vector2(side, 1.0)
	add_child(st)
	var stone := Color(0.4, 0.38, 0.34)
	var dark := Color(0.29, 0.27, 0.24)
	_poly(st, PackedVector2Array([
		Vector2(-18, 0), Vector2(18, 0), Vector2(15, -8), Vector2(-15, -8),
	]), dark)
	_poly(st, PackedVector2Array([
		Vector2(-12, -8), Vector2(12, -8), Vector2(10, -26), Vector2(-2, -30), Vector2(-12, -20),
	]), stone)
	_poly(st, PackedVector2Array([
		Vector2(-4, -18), Vector2(4, -18), Vector2(2, -26), Vector2(-4, -24),
	]), dark)
	_poly(st, PackedVector2Array([
		Vector2(0, -30), Vector2(14, -30), Vector2(14, -44), Vector2(0, -44),
	]), stone)
	_poly(st, PackedVector2Array([
		Vector2(1, -44), Vector2(5, -50), Vector2(7, -44),
	]), stone)
	_poly(st, PackedVector2Array([
		Vector2(8, -44), Vector2(12, -50), Vector2(14, -44),
	]), stone)
	_poly(st, PackedVector2Array([
		Vector2(8, -40), Vector2(12, -40), Vector2(12, -37), Vector2(8, -37),
	]), Color(0.95, 0.62, 0.2, 0.9))

func _build_traps() -> void:
	for idx in TRAP_IDX:
		var p: Vector2 = PLATFORMS[idx]
		var hw: float = HALF_WIDTHS[idx]
		var side := 1.0 if idx % 2 == 0 else -1.0
		var trap := Area2D.new()
		trap.position = Vector2(p.x + side * (hw - 28.0), p.y - 18.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(44, 24)
		shape.shape = rect
		trap.add_child(shape)
		_poly(trap, PackedVector2Array([
			Vector2(-22, 12), Vector2(22, 12), Vector2(22, 4), Vector2(-22, 4),
		]), Color(0.38, 0.24, 0.13))
		var j := 0
		while j < 3:
			var ox := -16.0 + j * 16.0
			_poly(trap, PackedVector2Array([
				Vector2(ox - 5, 4), Vector2(ox + 5, 4), Vector2(ox, -10),
			]), Color(0.52, 0.34, 0.18))
			_poly(trap, PackedVector2Array([
				Vector2(ox - 2, 2), Vector2(ox + 2, 2), Vector2(ox, -8),
			]), Color(0.62, 0.44, 0.24))
			j += 1
		add_child(trap)
		trap.body_entered.connect(_on_trap)

func _build_goal() -> void:
	var top: Vector2 = PLATFORMS[TOP_IDX]
	var goal := Area2D.new()
	goal.position = Vector2(top.x, top.y - 90.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 120)
	shape.shape = rect
	goal.add_child(shape)
	# Colonne de lumière sacrée qui monte vers la lune.
	_poly(goal, PackedVector2Array([
		Vector2(-26, -58), Vector2(26, -58), Vector2(44, -320), Vector2(-44, -320),
	]), Color(0.85, 0.9, 1.0, 0.07))
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(0.85, 0.88, 1.0, 0.4)
	glow.scale = Vector2(4.2, 4.2)
	goal.add_child(glow)
	_poly(goal, PackedVector2Array([
		Vector2(-28, -50), Vector2(-20, -50), Vector2(-20, 60), Vector2(-28, 60),
	]), Color(0.85, 0.2, 0.15))
	_poly(goal, PackedVector2Array([
		Vector2(20, -50), Vector2(28, -50), Vector2(28, 60), Vector2(20, 60),
	]), Color(0.85, 0.2, 0.15))
	_poly(goal, PackedVector2Array([
		Vector2(-24, -30), Vector2(24, -30), Vector2(24, -22), Vector2(-24, -22),
	]), Color(0.85, 0.2, 0.15))
	_poly(goal, PackedVector2Array([
		Vector2(-34, -58), Vector2(34, -58), Vector2(30, -48), Vector2(-30, -48),
	]), Color(0.78, 0.16, 0.12))
	add_child(goal)
	goal.body_entered.connect(_on_goal)

func _build_kill_zone() -> void:
	var kz := Area2D.new()
	kz.position = Vector2(300.0, 2100.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(1600, 100)
	shape.shape = rect
	kz.add_child(shape)
	add_child(kz)
	kz.body_entered.connect(_on_kill)

func _spawn_entities() -> void:
	for idx in PATROL_IDX:
		var e := PATROL_SCENE.instantiate()
		e.patrol_distance = maxf(30.0, HALF_WIDTHS[idx] - 45.0)
		e.position = _stand_y(idx)
		add_child(e)
	for idx in SHADOW_IDX:
		var s := SHADOW_SCENE.instantiate()
		s.position = _stand_y(idx)
		add_child(s)
	var leonie := LEONIE_SCENE.instantiate()
	leonie.position = _stand_y(LEONIE_IDX) + Vector2(60, 0)
	leonie.set_lines(LEONIE_LINES)
	leonie.talk.connect(_on_leonie_talk)
	add_child(leonie)
	var i := 1
	while i < PLATFORMS.size() - 1:
		if not (i in CHECKPOINT_IDX) and i != TOP_IDX:
			var orb := ORB_SCENE.instantiate()
			orb.position = Vector2(PLATFORMS[i].x, PLATFORMS[i].y - 80.0)
			add_child(orb)
		i += 1

func _setup_audio() -> void:
	var wind := AudioStreamPlayer.new()
	wind.stream = load("res://assets/sfx/wind.wav")
	wind.volume_db = -22.0
	wind.pitch_scale = 0.7
	add_child(wind)
	wind.finished.connect(wind.play)
	wind.play()
	sfx_win = AudioStreamPlayer.new()
	sfx_win.stream = load("res://assets/sfx/win.wav")
	sfx_win.volume_db = -4.0
	add_child(sfx_win)

func _on_checkpoint(body: Node2D, cp: Area2D, flag: Polygon2D) -> void:
	if body == player:
		player.set_checkpoint(Vector2(cp.global_position.x, cp.global_position.y + 30.0))
		flag.color = Color(0.35, 0.8, 0.4)

func _on_trap(body: Node2D) -> void:
	if body == player and body.has_method("take_damage"):
		body.take_damage(1, body.global_position + Vector2(0, 40))

func _on_kill(body: Node2D) -> void:
	if body == player:
		player.fall_damage()

func _on_goal(body: Node2D) -> void:
	if body == player:
		player.set_physics_process(false)
		sfx_win.play()
		SaveManager.complete_level(LEVEL_ID, player.orbs)
		_display_challenge_results()
		win_label.visible = true

func _count_orbs() -> int:
	var count := 0
	for i in range(1, PLATFORMS.size() - 1):
		if i not in CHECKPOINT_IDX and i != TOP_IDX:
			count += 1
	return count

func _display_challenge_results() -> void:
	var results := Challenge.get_results()

	var challenge_stats = win_label.find_child("ChallengeStats", true, false)
	if challenge_stats == null:
		return

	var grade_label = challenge_stats.find_child("Grade", true, false)
	var orbs_label = challenge_stats.find_child("Orbs", true, false)
	var damage_label = challenge_stats.find_child("Damage", true, false)
	var time_label = challenge_stats.find_child("Time", true, false)

	if grade_label:
		grade_label.text = "Grade: %s" % results["grade"]
	if orbs_label:
		orbs_label.text = "Orbes: %d/%d" % [results["orbs"], results["total_orbs"]]
	if damage_label:
		damage_label.text = "Dégâts: %d" % results["damage"]
	if time_label:
		time_label.text = "Temps: %s" % _format_time(results["time"])

	Challenge.reset()

func _format_time(seconds: float) -> String:
	var mins: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	return "%d:%02d" % [mins, secs]

func _on_leonie_talk(lines: Array) -> void:
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	dialogue.start(lines)

func _on_dialogue_finished() -> void:
	player.set_physics_process(true)

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
