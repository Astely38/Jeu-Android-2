class_name SpectralCrusher
extends Node2D
## Piège d'écrasement : une lourde dalle de pierre suspendue entre deux
## glissières qui s'ABAT brutalement au sol par intervalles, puis remonte
## lentement. Quatrième famille de danger : l'écrasement vertical.
##
## Le coup est franchement TÉLÉGRAPHIÉ — la dalle tremble et une marque
## spectrale palpite au sol ~0,6 s avant la chute — et il existe une longue
## fenêtre haute et sûre : on traverse dessous quand la dalle est levée.
##
## Usage : SpectralCrusher.new() ; `position` au sol ; `phase` pour
## désynchroniser plusieurs presses.

const PERIOD := 3.0
const WARN_START := 1.8
const SLAM_START := 2.4
const SLAM_END := 2.55
const HOLD_END := 2.8
const UP_Y := -150.0
const DOWN_Y := -20.0

@export var phase := 0.0
@export var tint := Color(0.62, 0.45, 1.0)

var _t := 0.0
var _slab: Node2D
var _marker: Polygon2D
var _hurt: Area2D
var _hit := false

func _ready() -> void:
	_t = phase
	# Glissières verticales fixes.
	for sx in [-26.0, 26.0]:
		_poly(self, PackedVector2Array([
			Vector2(sx - 3, 0), Vector2(sx + 3, 0), Vector2(sx + 3, -170), Vector2(sx - 3, -170),
		]), Color(0.24, 0.22, 0.28))

	# Marque au sol : zone d'impact, qui palpite pendant le télégraphe.
	_marker = _poly(self, PackedVector2Array([
		Vector2(-24, -3), Vector2(24, -3), Vector2(24, 2), Vector2(-24, 2),
	]), Color(tint.r, tint.g, tint.b, 0.15))

	# Dalle mobile (+ zone de dégât solidaire).
	_slab = Node2D.new()
	_slab.position = Vector2(0, UP_Y)
	add_child(_slab)
	_poly(_slab, PackedVector2Array([
		Vector2(-24, -16), Vector2(24, -16), Vector2(24, 14), Vector2(-24, 14),
	]), Color(0.28, 0.26, 0.32))
	_poly(_slab, PackedVector2Array([
		Vector2(-24, 10), Vector2(24, 10), Vector2(24, 14), Vector2(-24, 14),
	]), Color(tint.r, tint.g, tint.b, 0.7))
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(tint.r, tint.g, tint.b, 0.22)
	glow.scale = Vector2(0.7, 0.5)
	glow.position = Vector2(0, 8)
	_slab.add_child(glow)

	_hurt = Area2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(46, 44)
	shape.shape = rect
	shape.position = Vector2(0, 12)
	_hurt.add_child(shape)
	_slab.add_child(_hurt)

func _poly(parent: Node, pts: PackedVector2Array, c: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = c
	parent.add_child(p)
	return p

func _process(delta: float) -> void:
	_t += delta
	if _t >= PERIOD:
		_t -= PERIOD
		_hit = false

	var y := UP_Y
	var shake := 0.0
	var mk := 0.15
	var active := false

	if _t < WARN_START:
		y = UP_Y
	elif _t < SLAM_START:
		# Télégraphe : la dalle tremble, la marque au sol s'intensifie.
		var w := (_t - WARN_START) / (SLAM_START - WARN_START)
		shake = 2.2 * sin(_t * 65.0)
		mk = 0.15 + 0.55 * w
	elif _t < SLAM_END:
		# Chute brutale (accélérée).
		var s := (_t - SLAM_START) / (SLAM_END - SLAM_START)
		y = lerpf(UP_Y, DOWN_Y, s * s)
		mk = 0.65
		active = true
	elif _t < HOLD_END:
		# Impact maintenu au sol.
		y = DOWN_Y
		mk = 0.5
		active = true
	else:
		# Remontée lente.
		var r := (_t - HOLD_END) / (PERIOD - HOLD_END)
		y = lerpf(DOWN_Y, UP_Y, r)
		mk = 0.3 * (1.0 - r)

	_slab.position = Vector2(shake, y)
	_marker.color.a = mk
	if active and not _hit:
		_check_hit()

func _check_hit() -> void:
	for body in _hurt.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			_hit = true
			body.take_damage(1, global_position + Vector2(0, -20))
			return
