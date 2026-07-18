extends Node2D
class_name SpiritAnchor
## Ancrage du Fil Spirituel : un anneau de lumière suspendu vers lequel Eneko
## peut lancer son fil pour s'y hisser. Purement décoratif + un point de
## visée (le joueur cherche les nœuds du groupe « spirit_anchor »).

const CYAN := Color(0.55, 0.9, 1.0)

var _t := 0.0
var _ring: Line2D
var _core: Polygon2D
var _glow: Sprite2D

func _ready() -> void:
	add_to_group("spirit_anchor")
	z_index = 4
	# Halo diffus.
	_glow = Sprite2D.new()
	_glow.texture = load("res://assets/mist.svg")
	_glow.modulate = Color(0.6, 0.9, 1.0, 0.35)
	_glow.scale = Vector2(1.3, 1.3)
	add_child(_glow)
	# Anneau lumineux.
	_ring = Line2D.new()
	_ring.width = 3.0
	_ring.default_color = CYAN
	_ring.closed = true
	var pts := PackedVector2Array()
	for i in 20:
		var a := i * TAU / 20.0
		pts.append(Vector2(cos(a) * 15.0, sin(a) * 15.0))
	_ring.points = pts
	add_child(_ring)
	# Cœur.
	var cpts := PackedVector2Array()
	for i in 8:
		var a := i * TAU / 8.0
		cpts.append(Vector2(cos(a) * 4.5, sin(a) * 4.5))
	_core = Polygon2D.new()
	_core.polygon = cpts
	_core.color = Color(0.9, 0.98, 1.0)
	add_child(_core)

func _process(delta: float) -> void:
	_t += delta
	var pulse := 0.5 + 0.5 * sin(_t * 2.2)
	_ring.modulate.a = 0.6 + 0.4 * pulse
	_ring.scale = Vector2.ONE * (0.92 + 0.12 * pulse)
	if _glow != null:
		_glow.modulate.a = 0.25 + 0.16 * pulse
	if _core != null:
		_core.rotation += delta * 1.5

## Éclat bref quand le fil s'y accroche.
func ping() -> void:
	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(0.85, 0.97, 1.0)
	ring.closed = true
	var pts := PackedVector2Array()
	for i in 20:
		var a := i * TAU / 20.0
		pts.append(Vector2(cos(a) * 15.0, sin(a) * 15.0))
	ring.points = pts
	add_child(ring)
	var t := ring.create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector2(2.6, 2.6), 0.4)
	t.tween_property(ring, "modulate:a", 0.0, 0.4)
	t.chain().tween_callback(ring.queue_free)
