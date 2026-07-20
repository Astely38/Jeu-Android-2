class_name DartLauncher
extends Node2D
## Piège à projectiles : un masque de pierre corrompu qui crache par
## intermittence un DARD spectral filant à l'horizontale en travers du chemin.
## Troisième famille de danger, après le geyser (sol) et la faux (plafond) :
## ici la menace VIENT VERS SOI et s'esquive en sautant par-dessus le dard.
##
## Le tir est télégraphié : les yeux du masque s'illuminent ~0,6 s avant. Les
## dards volent bas (au-dessus du sol) : un saut bien placé les évite.
##
## Usage : DartLauncher.new() ; `position` au sol ; `dir` = sens de tir
## (-1 vers la gauche, +1 vers la droite) ; `phase` pour désynchroniser.

const PERIOD := 2.4
const WARN := 0.6
const BOLT_SPEED := 320.0
const RANGE := 480.0
const BOLT_Y := -20.0

@export var dir := -1.0
@export var phase := 0.0
@export var tint := Color(0.62, 0.45, 1.0)

var _t := 0.0
var _eyes: Array[Polygon2D] = []

func _ready() -> void:
	_t = phase
	# Socle et masque de pierre corrompu, tourné dans le sens de tir.
	var face := Color(0.2, 0.18, 0.24)
	var stone := Color(0.32, 0.3, 0.36)
	_poly(PackedVector2Array([
		Vector2(-16, 0), Vector2(16, 0), Vector2(12, -10), Vector2(-12, -10),
	]), stone)
	_poly(PackedVector2Array([
		Vector2(-14, -10), Vector2(14, -10), Vector2(16, -40), Vector2(-16, -40),
	]), face)
	# Bouche (par où sort le dard), côté du tir.
	_poly(PackedVector2Array([
		Vector2(dir * 10.0, -22), Vector2(dir * 20.0, -20), Vector2(dir * 10.0, -18),
	]), Color(0.05, 0.04, 0.07))
	# Deux yeux qui s'allument avant le tir (télégraphe).
	for sx in [-7.0, 7.0]:
		var eye := _poly(PackedVector2Array([
			Vector2(sx - 3, -32), Vector2(sx + 3, -32), Vector2(sx + 3, -27), Vector2(sx - 3, -27),
		]), Color(tint.r, tint.g, tint.b, 0.3))
		_eyes.append(eye)

func _poly(pts: PackedVector2Array, c: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = c
	add_child(p)
	return p

func _process(delta: float) -> void:
	_t += delta
	if _t >= PERIOD:
		_t -= PERIOD
		_fire()
	# Télégraphe : les yeux brillent pendant la dernière fraction du cycle.
	var warn := clampf((_t - (PERIOD - WARN)) / WARN, 0.0, 1.0)
	var a := 0.25 + 0.75 * warn
	for eye in _eyes:
		eye.color = Color(tint.r, tint.g, tint.b, a)

## Crache un dard spectral, posé sur le niveau (survit au lanceur), animé en
## translation ; il inflige un dégât au contact puis disparaît.
func _fire() -> void:
	var host := get_parent()
	if host == null:
		return
	var bolt := Area2D.new()
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(dir * 14.0, 0), Vector2(-dir * 6.0, -5),
		Vector2(-dir * 10.0, 0), Vector2(-dir * 6.0, 5),
	])
	body.color = Color(tint.r, tint.g, tint.b, 0.95)
	bolt.add_child(body)
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(tint.r, tint.g, tint.b, 0.4)
	glow.scale = Vector2(0.5, 0.5)
	bolt.add_child(glow)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	bolt.add_child(shape)
	bolt.z_index = 3
	host.add_child(bolt)
	bolt.global_position = global_position + Vector2(dir * 18.0, BOLT_Y)
	bolt.body_entered.connect(_on_bolt_hit.bind(bolt))
	var tw := bolt.create_tween()
	tw.tween_property(bolt, "position:x", bolt.position.x + dir * RANGE, RANGE / BOLT_SPEED)
	tw.tween_callback(bolt.queue_free)

func _on_bolt_hit(body: Node2D, bolt: Area2D) -> void:
	if not is_instance_valid(bolt):
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1, bolt.global_position)
		bolt.queue_free()
