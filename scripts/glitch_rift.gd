class_name GlitchRift
extends Node2D
## Faille glitchée du Chapitre IV : plus une simple déchirure au sol, mais
## une FRACTURE QUI TRAVERSE TOUT L'ÉCRAN de haut en bas, comme si le monde
## lui-même se fendait à cet endroit — le miroir qui s'effondre. Un tracé
## principal en éclair, hérissé de fractures secondaires qui partent en
## éventail et de tics numériques scintillants sur toute sa hauteur, cerclé
## d'un double liseré (aberration chromatique). Danger fixe, jamais
## télégraphié — se repère à sa lueur et à son scintillement, pas à une
## alerte. Seul le tronçon au ras du sol est réellement dangereux au
## contact.
##
## Usage : GlitchRift.new() ; `position` au sol, là où la faille doit trouer
## le décor ; `phase` pour désynchroniser plusieurs failles d'un même niveau ;
## `color_a` / `color_b` pour transposer sa palette au thème du niveau hôte.

@export var phase := 0.0
@export var color_a := Color(0.85, 0.25, 0.55)
@export var color_b := Color(0.3, 0.75, 0.85)

## Tracé principal, du haut de l'écran à son bas (y=0 = sol, positif = sous
## terre) — jagged, jamais une ligne droite.
const MAIN_PTS := [
	Vector2(0, -320), Vector2(-10, -260), Vector2(14, -210), Vector2(-16, -160),
	Vector2(9, -120), Vector2(-14, -80), Vector2(16, -40), Vector2(-8, -5),
	Vector2(10, 20), Vector2(-15, 55), Vector2(8, 95), Vector2(-12, 140),
	Vector2(15, 190), Vector2(-9, 240), Vector2(12, 290), Vector2(0, 320),
]
## Fractures secondaires : le monde qui éclate en éventail depuis le tracé
## principal (index dans MAIN_PTS, direction, longueur).
const BRANCHES := [
	{"i": 2, "vec": Vector2(0.85, -0.5), "len": 120.0},
	{"i": 2, "vec": Vector2(-0.75, -0.55), "len": 100.0},
	{"i": 3, "vec": Vector2(0.5, -0.85), "len": 70.0},
	{"i": 4, "vec": Vector2(0.9, -0.15), "len": 85.0},
	{"i": 5, "vec": Vector2(-0.85, -0.25), "len": 110.0},
	{"i": 5, "vec": Vector2(-0.4, -0.9), "len": 60.0},
	{"i": 6, "vec": Vector2(0.6, 0.2), "len": 60.0},
	{"i": 7, "vec": Vector2(0.55, 0.35), "len": 75.0},
	{"i": 7, "vec": Vector2(-0.5, 0.4), "len": 70.0},
	{"i": 8, "vec": Vector2(-0.9, 0.05), "len": 115.0},
	{"i": 9, "vec": Vector2(0.85, 0.4), "len": 90.0},
	{"i": 9, "vec": Vector2(0.3, 0.92), "len": 55.0},
	{"i": 10, "vec": Vector2(-0.6, 0.5), "len": 95.0},
	{"i": 11, "vec": Vector2(0.7, 0.4), "len": 110.0},
	{"i": 12, "vec": Vector2(-0.55, 0.55), "len": 85.0},
	{"i": 12, "vec": Vector2(-0.2, 0.95), "len": 60.0},
	{"i": 13, "vec": Vector2(0.85, 0.3), "len": 100.0},
	{"i": 14, "vec": Vector2(-0.85, 0.35), "len": 80.0},
]
## Indices de MAIN_PTS où planter un petit éclat/tic numérique scintillant.
const TICKS := [0, 1, 3, 4, 6, 8, 9, 11, 12, 14, 15]
## Indices de MAIN_PTS où faire baver un halo lumineux, pour que la lueur de
## la faille se lise sur toute sa hauteur, pas seulement au sol.
const GLOW_STOPS := [1, 4, 7, 10, 13]

var _t := 0.0
var _bands: Array = []

func _ready() -> void:
	_t = phase
	# Lézardes au sol : le terrain se fend bien au-delà du bord de la faille,
	# comme si l'instabilité gagnait la plateforme elle-même.
	for side: float in [-1.0, 1.0]:
		for k in 2:
			var base_x := side * (42.0 + float(k) * 22.0)
			var crack := Line2D.new()
			crack.points = PackedVector2Array([
				Vector2(side * 26.0, 4.0), Vector2(base_x * 0.6, -1.0),
				Vector2(base_x, 3.0), Vector2(base_x + side * 14.0, -2.0),
			])
			crack.width = 1.2
			crack.default_color = Color(0.05, 0.04, 0.07, 0.7)
			add_child(crack)
			var glint := Line2D.new()
			glint.points = crack.points
			glint.width = 0.6
			glint.default_color = Color(color_a.r, color_a.g, color_a.b, 0.35)
			add_child(glint)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(76, 36)
	shape.shape = rect
	var rift := Area2D.new()
	# Le tracé encadre déjà lui-même la ligne de marche (des points de part
	# et d'autre de y=0) : pas besoin de décaler la zone de danger.
	rift.add_child(shape)
	# Lueur qui sourd de la faille : un halo par tronçon, pour que la lumière
	# bave sur toute la hauteur de la fracture, pas seulement au sol.
	for gi in GLOW_STOPS:
		var glow := Sprite2D.new()
		glow.texture = load("res://assets/mist.svg")
		glow.modulate = Color(color_a.r, color_a.g, color_a.b, 0.32)
		glow.scale = Vector2(1.8, 2.6)
		glow.position = MAIN_PTS[gi]
		glow.z_index = -1
		rift.add_child(glow)
		Atmosphere.breathe(glow, 0.25, 1.6)
	# Corps sombre de la fracture : un ruban plein, plus large au centre, qui
	# traverse tout l'écran — le vide qui s'ouvre sous la réalité.
	_ribbon(rift, MAIN_PTS, 5.0, 14.0, Color(0.03, 0.02, 0.05))
	# Double liseré, légèrement désaxé : aberration chromatique qui vend le
	# glitch même sur une image figée.
	for off in [Vector2(-2.5, 0), Vector2(2.5, 0)]:
		var outline := Line2D.new()
		outline.points = PackedVector2Array(MAIN_PTS)
		outline.width = 3.0
		outline.position = off
		outline.default_color = Color(color_a.r, color_a.g, color_a.b, 0.8) if off.x < 0.0 else Color(color_b.r, color_b.g, color_b.b, 0.8)
		rift.add_child(outline)
	# Cœur clair : la vive lumière qui bat au fond de la fracture.
	var core := Line2D.new()
	core.points = PackedVector2Array(MAIN_PTS)
	core.width = 2.0
	core.default_color = Color(1, 1, 1, 0.9)
	rift.add_child(core)
	# Fractures secondaires : le monde qui éclate en éventail, chacune
	# prolongée d'une sous-fracture plus fine — l'effet toile d'araignée
	# d'un miroir qui a volé en éclats.
	for b in BRANCHES:
		var idx: int = b["i"]
		var origin: Vector2 = MAIN_PTS[idx]
		var vec: Vector2 = b["vec"]
		var length: float = b["len"]
		var col := Color(color_a.r, color_a.g, color_a.b, 0.5) if idx % 2 == 0 else Color(color_b.r, color_b.g, color_b.b, 0.5)
		var mid := _branch(rift, origin, vec, length, col, 1.5)
		var sub_vec := Vector2(vec.y, -vec.x) * 0.8
		_branch(rift, mid, sub_vec, length * 0.4, Color(col.r, col.g, col.b, 0.35), 1.0)
	# Tics numériques : petits éclats qui scintillent sur toute la hauteur de
	# la fracture, pas seulement à sa base — la corruption gagne tout l'écran.
	for idx in TICKS:
		var p: Vector2 = MAIN_PTS[idx]
		var side := 1.0 if idx % 2 == 0 else -1.0
		var h := 14.0 + float(idx % 3) * 4.0
		var tick := _poly(rift, PackedVector2Array([
			p + Vector2(side * 4.0, 6.0), p + Vector2(side * 8.0, 6.0), p + Vector2(side * 6.0, 6.0 - h),
		]), color_b if side > 0.0 else color_a)
		_bands.append({"node": tick, "phase": float(idx) * 0.7})
	# Éclats corrompus en suspension près du sol : dérivent lentement,
	# clignotent, mêlant les deux teintes du glitch pour un nuage bicolore.
	for col in [color_a, color_b]:
		var debris := CPUParticles2D.new()
		debris.texture = load("res://assets/leaf.svg")
		debris.amount = 5
		debris.lifetime = 2.6
		debris.preprocess = 2.6
		debris.position = Vector2(0, -20)
		debris.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		debris.emission_rect_extents = Vector2(32, 8)
		debris.direction = Vector2(0, -1)
		debris.spread = 30.0
		debris.gravity = Vector2.ZERO
		debris.initial_velocity_min = 6.0
		debris.initial_velocity_max = 16.0
		debris.angular_velocity_min = -90.0
		debris.angular_velocity_max = 90.0
		debris.scale_amount_min = 0.3
		debris.scale_amount_max = 0.55
		debris.color = col
		rift.add_child(debris)
	add_child(rift)
	rift.body_entered.connect(_on_body_entered)

## Ruban plein généré à partir d'une ligne centrale — plus large en son
## centre, effilé à ses deux bouts.
func _ribbon(parent: Node, pts: Array, w0: float, w1: float, c: Color) -> Polygon2D:
	var n := pts.size()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n:
		var t := float(i) / float(n - 1)
		var w := w0 + (w1 - w0) * sin(t * PI)
		var tangent: Vector2
		if i == 0:
			tangent = pts[1] - pts[0]
		elif i == n - 1:
			tangent = pts[i] - pts[i - 1]
		else:
			tangent = pts[i + 1] - pts[i - 1]
		var normal := tangent.normalized().orthogonal()
		left.append(pts[i] + normal * w)
		right.append(pts[i] - normal * w)
	right.reverse()
	var poly := PackedVector2Array()
	for p in left:
		poly.append(p)
	for p in right:
		poly.append(p)
	return _poly(parent, poly, c)

## Trace une fracture secondaire depuis `origin` dans la direction `vec` sur
## `length` unités (légèrement cintrée) et renvoie son point milieu, pour
## pouvoir y greffer une sous-fracture.
func _branch(parent: Node, origin: Vector2, vec: Vector2, length: float, c: Color, width: float) -> Vector2:
	var mid := origin + vec * length * 0.5 + vec.orthogonal() * 6.0
	var end := origin + vec * length
	var line := Line2D.new()
	line.points = PackedVector2Array([origin, mid, end])
	line.width = width
	line.default_color = c
	parent.add_child(line)
	return mid

func _poly(parent: Node, pts: PackedVector2Array, c: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = c
	parent.add_child(p)
	return p

func _process(delta: float) -> void:
	_t += delta
	for b in _bands:
		var node: Polygon2D = b["node"]
		node.modulate = color_a if sin(_t * 9.0 + float(b["phase"])) > 0.3 else color_b
		node.modulate.a = 0.4 + 0.35 * absf(sin(_t * 5.0 + float(b["phase"])))
		node.scale.y = 0.9 + 0.15 * absf(sin(_t * 6.0 + float(b["phase"]) * 1.4))

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1, body.global_position + Vector2(0, 20))
