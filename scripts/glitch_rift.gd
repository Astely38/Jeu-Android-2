class_name GlitchRift
extends Node2D
## Faille glitchée du Chapitre IV : déchirure immobile, flush au sol, cerclée
## d'un liseré lumineux, fendue d'une fêlure centrale vive et cernée d'éclats
## corrompus en suspension. Danger fixe, jamais télégraphié — se repère à sa
## lueur et à son scintillement, pas à une alerte.
##
## Usage : GlitchRift.new() ; `position` au sol, là où la faille doit trouer
## le décor ; `phase` pour désynchroniser plusieurs failles d'un même niveau ;
## `color_a` / `color_b` pour transposer sa palette au thème du niveau hôte.

@export var phase := 0.0
@export var color_a := Color(0.85, 0.25, 0.55)
@export var color_b := Color(0.3, 0.75, 0.85)

var _t := 0.0
var _bands: Array = []

func _ready() -> void:
	_t = phase
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(70, 34)
	shape.shape = rect
	var rift := Area2D.new()
	rift.position = Vector2(0, -16.0)
	rift.add_child(shape)
	# Lueur qui sourd de la faille : signale le danger de loin, sur le sol.
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(color_a.r, color_a.g, color_a.b, 0.4)
	glow.scale = Vector2(1.8, 1.2)
	glow.position = Vector2(0, -4)
	glow.z_index = -1
	rift.add_child(glow)
	Atmosphere.breathe(glow, 0.25, 1.6)
	var pts := PackedVector2Array([
		Vector2(-35, 16), Vector2(35, 16), Vector2(28, -14), Vector2(-28, -14),
	])
	_poly(rift, pts, Color(0.03, 0.02, 0.05))
	# Liseré lumineux : détache la faille du fond, même immobile.
	var outline := Line2D.new()
	outline.points = pts
	outline.closed = true
	outline.width = 2.4
	outline.default_color = Color(color_a.r, color_a.g, color_a.b, 0.85)
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
	for k in 3:
		var ox := -20.0 + float(k) * 20.0
		# Alpha de base 1.0 : _process pilote entièrement modulate (teinte +
		# alpha pulsée). Avec un alpha de base à 0, la bande resterait
		# invisible (0 × modulate.a = 0).
		var band := _poly(rift, PackedVector2Array([
			Vector2(ox - 5, 13), Vector2(ox + 5, 13), Vector2(ox + 7, -12), Vector2(ox - 7, -12),
		]), color_a)
		_bands.append({"node": band, "phase": float(k) * 1.3})
	# Éclats corrompus en suspension au-dessus de la faille : dérivent
	# lentement, clignotent, renforcent l'idée d'image brisée.
	var debris := CPUParticles2D.new()
	debris.texture = load("res://assets/leaf.svg")
	debris.amount = 6
	debris.lifetime = 2.6
	debris.preprocess = 2.6
	debris.position = Vector2(0, -18)
	debris.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	debris.emission_rect_extents = Vector2(28, 6)
	debris.direction = Vector2(0, -1)
	debris.spread = 25.0
	debris.gravity = Vector2.ZERO
	debris.initial_velocity_min = 6.0
	debris.initial_velocity_max = 14.0
	debris.angular_velocity_min = -90.0
	debris.angular_velocity_max = 90.0
	debris.scale_amount_min = 0.35
	debris.scale_amount_max = 0.6
	debris.color = color_a
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
		node.modulate.a = 0.35 + 0.35 * absf(sin(_t * 5.0 + float(b["phase"])))

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1, body.global_position + Vector2(0, 20))
