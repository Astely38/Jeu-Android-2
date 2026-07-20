class_name SpectralPendulum
extends Node2D
## Piège aérien : une faux spectrale suspendue à une poutre qui balance d'un
## côté à l'autre au-dessus du chemin. Contrairement au geyser (menace au
## sol), c'est une menace EN HAUTEUR — on passe dessous quand la lame est
## écartée sur un côté. Le mouvement est continu et parfaitement lisible (pas
## besoin de télégraphe) : le danger n'est jamais forcé, on lit le rythme.
##
## Usage : SpectralPendulum.new() ; `position` au sol sous le pivot ;
## `phase`, `max_angle`, `speed`, `arm_len`, `pivot_h` réglables.

## Amplitude du balancement (radians de part et d'autre de la verticale).
@export var max_angle := 0.8
## Vitesse du balancement.
@export var speed := 1.7
## Décalage de phase pour désynchroniser plusieurs faux.
@export var phase := 0.0
## Longueur du bras (pivot → lame).
@export var arm_len := 150.0
## Hauteur du pivot au-dessus du point de pose.
@export var pivot_h := 180.0
## Teinte spectrale de la lame et de sa lueur.
@export var tint := Color(0.6, 0.45, 1.0)

var _t := 0.0
var _arm: Node2D
var _hurt: Area2D
var _hit_cd := 0.0

func _ready() -> void:
	_t = phase
	var pivot := Vector2(0, -pivot_h)

	# Poutre d'ancrage fixe (ne balance pas).
	var beam := Polygon2D.new()
	beam.polygon = PackedVector2Array([
		Vector2(-34, -6), Vector2(34, -6), Vector2(34, 4), Vector2(-34, 4),
	])
	beam.color = Color(0.2, 0.17, 0.22)
	beam.position = pivot
	add_child(beam)

	# Bras pivotant : contient la chaîne, la lame et la zone de dégât.
	_arm = Node2D.new()
	_arm.position = pivot
	add_child(_arm)

	# Chaîne / hampe.
	var rod := Polygon2D.new()
	rod.polygon = PackedVector2Array([
		Vector2(-2, 0), Vector2(2, 0), Vector2(2, arm_len - 10), Vector2(-2, arm_len - 10),
	])
	rod.color = Color(0.3, 0.28, 0.34)
	_arm.add_child(rod)

	# Lame en croissant, spectrale et lumineuse.
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(tint.r, tint.g, tint.b, 0.4)
	glow.scale = Vector2(0.9, 0.9)
	glow.position = Vector2(0, arm_len)
	_arm.add_child(glow)
	var blade := Polygon2D.new()
	blade.polygon = PackedVector2Array([
		Vector2(-30, arm_len - 6), Vector2(0, arm_len - 20), Vector2(30, arm_len - 6),
		Vector2(24, arm_len + 6), Vector2(0, arm_len - 4), Vector2(-24, arm_len + 6),
	])
	blade.color = Color(tint.r, tint.g, tint.b, 0.92)
	_arm.add_child(blade)
	var edge := Polygon2D.new()
	edge.polygon = PackedVector2Array([
		Vector2(-30, arm_len - 6), Vector2(0, arm_len - 20), Vector2(30, arm_len - 6),
		Vector2(26, arm_len - 3), Vector2(0, arm_len - 15), Vector2(-26, arm_len - 3),
	])
	edge.color = Color(0.9, 0.95, 1.0, 0.9)
	_arm.add_child(edge)

	# Zone de dégât autour de la lame (monitoring permanent ; dégât régulé
	# par un petit temps de recharge).
	_hurt = Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	shape.position = Vector2(0, arm_len - 4)
	_hurt.add_child(shape)
	_arm.add_child(_hurt)

func _process(delta: float) -> void:
	_t += delta
	_hit_cd = maxf(0.0, _hit_cd - delta)
	_arm.rotation = max_angle * sin(_t * speed)
	if _hit_cd <= 0.0:
		for body in _hurt.get_overlapping_bodies():
			if body.is_in_group("player") and body.has_method("take_damage"):
				_hit_cd = 0.9
				body.take_damage(1, _hurt.global_position)
				return
