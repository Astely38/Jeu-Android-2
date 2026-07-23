class_name GlitchRift
extends Node2D
## Faille glitchée du Chapitre IV : déchirure immobile, flush au sol, cerclée
## d'un double liseré (aberration chromatique), hérissée d'une crête de pics
## numériques d'hauteur irrégulière, et prolongée au sol par des lézardes qui
## trahissent l'instabilité du terrain bien au-delà de son bord. Danger fixe,
## jamais télégraphié — se repère à sa lueur et à son scintillement, pas à
## une alerte.
##
## Usage : GlitchRift.new() ; `position` au sol, là où la faille doit trouer
## le décor ; `phase` pour désynchroniser plusieurs failles d'un même niveau ;
## `color_a` / `color_b` pour transposer sa palette au thème du niveau hôte.

@export var phase := 0.0
@export var color_a := Color(0.85, 0.25, 0.55)
@export var color_b := Color(0.3, 0.75, 0.85)

const SPIKE_HEIGHTS := [14.0, 26.0, 18.0, 34.0, 20.0, 28.0, 15.0]

var _t := 0.0
var _bands: Array = []

func _ready() -> void:
	_t = phase
	# Lézardes au sol : le terrain se fend bien au-delà du bord de la faille,
	# comme si l'instabilité gagnait la plateforme elle-même.
	for side: float in [-1.0, 1.0]:
		for k in 2:
			var base_x: float = side * (42.0 + float(k) * 22.0)
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
	rift.position = Vector2(0, -17.0)
	rift.add_child(shape)
	# Lueur qui sourd de la faille : signale le danger de loin, sur le sol.
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(color_a.r, color_a.g, color_a.b, 0.42)
	glow.scale = Vector2(2.0, 1.4)
	glow.position = Vector2(0, -4)
	glow.z_index = -1
	rift.add_child(glow)
	Atmosphere.breathe(glow, 0.25, 1.6)
	var pts := PackedVector2Array([
		Vector2(-38, 17), Vector2(38, 17), Vector2(30, -15), Vector2(-30, -15),
	])
	_poly(rift, pts, Color(0.03, 0.02, 0.05))
	# Double liseré, légèrement désaxé : aberration chromatique qui vend le
	# glitch même sur une image figée.
	for off in [Vector2(-1.2, 0), Vector2(1.2, 0)]:
		var outline := Line2D.new()
		outline.points = pts
		outline.closed = true
		outline.width = 1.6
		outline.position = off
		outline.default_color = Color(color_a.r, color_a.g, color_a.b, 0.7) if off.x < 0.0 else Color(color_b.r, color_b.g, color_b.b, 0.7)
		rift.add_child(outline)
	# Fêlure centrale, fine et vive : le cœur de la déchirure, cerné d'un
	# fin liseré clair pour bien la détacher du fond noir.
	var crack := PackedVector2Array([
		Vector2(-22, 14), Vector2(-8, -2), Vector2(-14, -10),
		Vector2(2, 4), Vector2(10, -12), Vector2(22, 12),
		Vector2(6, 6), Vector2(0, 14),
	])
	var crack_fill := _poly(rift, crack, Color(0.95, 0.95, 1.0, 0.9))
	crack_fill.z_index = 1
	var crack_edge := Line2D.new()
	crack_edge.points = crack
	crack_edge.closed = true
	crack_edge.width = 1.0
	crack_edge.default_color = Color(1, 1, 1, 0.7)
	crack_edge.z_index = 1
	rift.add_child(crack_edge)
	# Crête de pics numériques : hauteurs irrégulières, certains dépassant
	# largement le bord de la faille — silhouette « onde corrompue ».
	var span := 60.0
	var n := SPIKE_HEIGHTS.size()
	for k in n:
		var ox := -span * 0.5 + span * float(k) / float(n - 1)
		var h: float = SPIKE_HEIGHTS[k]
		var w := 3.0 + fmod(h, 5.0) * 0.3
		var band := _poly(rift, PackedVector2Array([
			Vector2(ox - w, 13), Vector2(ox + w, 13), Vector2(ox + w * 0.6, -h), Vector2(ox - w * 0.6, -h),
		]), color_a)
		_bands.append({"node": band, "phase": float(k) * 0.9 + h * 0.05})
	# Éclats corrompus en suspension au-dessus de la faille : dérivent
	# lentement, clignotent, renforcent l'idée d'image brisée — mêlant les
	# deux teintes du glitch pour un nuage bicolore.
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
