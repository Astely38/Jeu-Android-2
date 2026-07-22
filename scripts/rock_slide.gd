class_name RockSlide
extends Node2D
## Piège du Chapitre IV, propre aux pentes : un surplomb instable qui, par
## intermittence, libère une volée d'éclats qui DÉVALENT la pente en
## tournoyant. Télégraphié par un tremblement bref (le surplomb se fissure)
## avant l'éboulis — un joueur attentif a le temps de s'écarter ou de
## franchir la pente avant la chute.
##
## Usage : RockSlide.new() ; `position` en haut de la pente ; `fall_dir` =
## vecteur de chute normalisé (suit la pente, ex. Vector2(1, 0.4).normalized()
## pour une descente vers la droite) ; `phase` pour désynchroniser plusieurs
## éboulis d'un même niveau.

const PERIOD := 3.6
const WARN := 0.7
const FALL_SPEED := 260.0
const RANGE := 420.0
const SHARD_COUNT := 3

@export var fall_dir := Vector2(1, 0.4)
@export var phase := 0.0
@export var tint := Color(0.5, 0.55, 0.65)

var _t := 0.0
var _warn_poly: Polygon2D

func _ready() -> void:
	_t = phase
	fall_dir = fall_dir.normalized()
	z_index = 4
	# Surplomb fissuré : silhouette de roche instable, au-dessus de la pente.
	# Un peu plus claire que le fond et cerclée d'un liseré, pour ne jamais se
	# fondre dans le décor sombre du chapitre — reste lisible même au repos.
	var rock := Color(0.34, 0.31, 0.4)
	var rock_pts := PackedVector2Array([
		Vector2(-22, 8), Vector2(-10, -14), Vector2(6, -10), Vector2(20, 6), Vector2(10, 10),
	])
	_poly(rock_pts, rock)
	var outline := Line2D.new()
	outline.points = rock_pts
	outline.closed = true
	outline.width = 1.8
	outline.default_color = Color(tint.r, tint.g, tint.b, 0.7)
	add_child(outline)
	_warn_poly = _poly(PackedVector2Array([
		Vector2(-6, -2), Vector2(-1, -10), Vector2(3, -3), Vector2(8, -8), Vector2(4, 4), Vector2(-2, 6),
	]), Color(tint.r, tint.g, tint.b, 0.0))

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
		_release()
	# Télégraphe : la fissure s'illumine dans le dernier tiers du cycle.
	var warn := clampf((_t - (PERIOD - WARN)) / WARN, 0.0, 1.0)
	if _warn_poly != null:
		_warn_poly.color.a = warn * 0.9
		_warn_poly.scale = Vector2.ONE * (1.0 + 0.15 * warn)

## Libère une volée d'éclats qui dévalent la pente en tournoyant, chacun
## infligeant un dégât au contact avant de disparaître à distance.
func _release() -> void:
	var host := get_parent()
	if host == null:
		return
	for i in SHARD_COUNT:
		var shard := Area2D.new()
		var poly := PackedVector2Array()
		var r := randf_range(5.0, 9.0)
		for k in 6:
			var a := k * TAU / 6.0
			poly.append(Vector2(cos(a) * r, sin(a) * r * 0.8))
		var body := Polygon2D.new()
		body.polygon = poly
		body.color = Color(tint.r, tint.g, tint.b, 0.95)
		shard.add_child(body)
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = r
		shape.shape = circle
		shard.add_child(shape)
		shard.z_index = 3
		host.add_child(shard)
		var offset := Vector2(-fall_dir.y, fall_dir.x) * float(i - 1) * 16.0
		shard.global_position = global_position + offset
		shard.body_entered.connect(_on_shard_hit.bind(shard))
		var t := shard.create_tween()
		t.set_parallel(true)
		t.tween_property(shard, "position", shard.position + fall_dir * RANGE, RANGE / FALL_SPEED)
		t.tween_property(shard, "rotation", (8.0 + float(i)) * (1.0 if fall_dir.x >= 0.0 else -1.0), RANGE / FALL_SPEED)
		t.chain().tween_callback(shard.queue_free)

func _on_shard_hit(body: Node2D, shard: Area2D) -> void:
	if not is_instance_valid(shard):
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1, shard.global_position)
		shard.queue_free()
