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
	# Surplomb fissuré : silhouette de roche instable, au-dessus de la pente,
	# bâtie en plusieurs facettes (volume + relief) pour bien se détacher du
	# fond sombre du chapitre même au repos.
	var rock_dark := Color(0.22, 0.2, 0.27)
	var rock := Color(0.36, 0.33, 0.42)
	var rock_hi := Color(0.48, 0.44, 0.56)
	var rock_pts := PackedVector2Array([
		Vector2(-28, 10), Vector2(-14, -18), Vector2(8, -13), Vector2(26, 8), Vector2(13, 13),
	])
	_poly(rock_pts, rock_dark)
	var main := _poly(PackedVector2Array([
		Vector2(-24, 8), Vector2(-12, -15), Vector2(6, -11), Vector2(22, 7), Vector2(10, 11),
	]), rock)
	# Facette éclairée du dessus : suggère une source de lumière et du volume.
	_poly(PackedVector2Array([
		Vector2(-12, -15), Vector2(6, -11), Vector2(14, -4), Vector2(-4, -6),
	]), rock_hi)
	var outline := Line2D.new()
	outline.points = main.polygon
	outline.closed = true
	outline.width = 2.0
	outline.default_color = Color(tint.r, tint.g, tint.b, 0.75)
	add_child(outline)
	# Lézardes statiques, toujours visibles : le surplomb a déjà commencé à
	# se fendre, bien avant l'éboulis proprement dit.
	for crack_pts in [
		PackedVector2Array([Vector2(-8, -8), Vector2(-2, 0), Vector2(-6, 6)]),
		PackedVector2Array([Vector2(4, -9), Vector2(9, -2), Vector2(6, 4)]),
	]:
		var crack := Line2D.new()
		crack.points = crack_pts
		crack.width = 1.0
		crack.default_color = Color(0.1, 0.09, 0.13, 0.8)
		add_child(crack)
	# Poussière qui tombe en continu, discrète : le surplomb s'effrite déjà.
	var dust := CPUParticles2D.new()
	dust.amount = 4
	dust.lifetime = 1.4
	dust.preprocess = 1.4
	dust.position = Vector2(0, 4)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(16, 2)
	dust.direction = Vector2(0, 1)
	dust.spread = 10.0
	dust.gravity = Vector2(0, 60)
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 10.0
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 0.9
	dust.color = Color(tint.r, tint.g, tint.b, 0.5)
	add_child(dust)
	_warn_poly = _poly(PackedVector2Array([
		Vector2(-8, -2), Vector2(-1, -13), Vector2(4, -4), Vector2(10, -10), Vector2(5, 5), Vector2(-3, 8),
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
		# Halo : détache l'éclat du fond sombre du chapitre pendant sa chute.
		var glow := Sprite2D.new()
		glow.texture = load("res://assets/mist.svg")
		glow.modulate = Color(0.8, 0.7, 0.95, 0.4)
		glow.scale = Vector2.ONE * (r / 14.0)
		shard.add_child(glow)
		var body := Polygon2D.new()
		body.polygon = poly
		body.color = Color(tint.r + 0.12, tint.g + 0.1, tint.b + 0.14, 0.98)
		shard.add_child(body)
		var edge := Line2D.new()
		edge.points = poly
		edge.closed = true
		edge.width = 1.4
		edge.default_color = Color(0.85, 0.78, 1.0, 0.85)
		shard.add_child(edge)
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
