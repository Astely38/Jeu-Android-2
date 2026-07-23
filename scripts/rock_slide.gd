class_name RockSlide
extends Node2D
## Piège du Chapitre IV : un cratère instable qui, par intermittence, crache
## une salve d'éclats en CLOCHE, visée sur la position du joueur au moment
## du tir — plus imprévisible qu'un éboulis qui suivrait toujours la même
## trajectoire. Télégraphié par une lueur qui gonfle au fond du cratère
## juste avant chaque salve.
##
## Usage : RockSlide.new() ; `position` au sol, au centre du cratère ;
## `phase` pour désynchroniser plusieurs cratères d'un même niveau.

const PERIOD := 3.4
const WARN := 0.65
const SHARD_COUNT := 3
const FLIGHT_TIME := 0.85
const ARC_HEIGHT := 70.0
const SPREAD := 26.0
## Cible de repli si aucun joueur n'est trouvé dans la scène.
const DEFAULT_TARGET_OFFSET := Vector2(140.0, -20.0)

@export var phase := 0.0
@export var tint := Color(0.5, 0.46, 0.56)

var _t := 0.0
var _core: Polygon2D

func _ready() -> void:
	_t = phase
	z_index = 4
	_build_crater()

## Cratère enfoncé dans le sol, rebord fissuré, lueur d'alerte au fond.
func _build_crater() -> void:
	var pit_dark := Color(0.08, 0.07, 0.09)
	var pit := Color(0.18, 0.16, 0.21)
	var rim := Color(0.34, 0.31, 0.4)
	_poly(PackedVector2Array([
		Vector2(-30, 6), Vector2(-20, 20), Vector2(0, 26), Vector2(20, 19), Vector2(30, 5),
		Vector2(24, -4), Vector2(0, -8), Vector2(-24, -3),
	]), pit_dark)
	_poly(PackedVector2Array([
		Vector2(-24, 4), Vector2(-15, 15), Vector2(0, 19), Vector2(15, 14), Vector2(24, 3),
		Vector2(18, -3), Vector2(0, -6), Vector2(-18, -2),
	]), pit)
	# Rebord fissuré, irrégulier — instable, prêt à s'ébouler encore.
	var rim_edge := Line2D.new()
	rim_edge.points = PackedVector2Array([
		Vector2(-32, -2), Vector2(-24, -9), Vector2(-14, -5), Vector2(-4, -10),
		Vector2(6, -4), Vector2(16, -9), Vector2(26, -3), Vector2(32, -6),
	])
	rim_edge.width = 2.2
	rim_edge.default_color = rim
	add_child(rim_edge)
	# Lueur qui gonfle au fond du cratère : seul vrai télégraphe de la salve.
	_core = _poly(PackedVector2Array([
		Vector2(-9, 6), Vector2(-4, 12), Vector2(5, 11), Vector2(9, 3), Vector2(2, -4), Vector2(-5, -2),
	]), Color(tint.r + 0.3, tint.g + 0.15, tint.b + 0.05, 0.0))
	_core.position = Vector2(0, 6)
	# Poussière qui s'échappe en continu : le cratère reste instable au repos.
	var dust := CPUParticles2D.new()
	dust.amount = 5
	dust.lifetime = 1.2
	dust.preprocess = 1.2
	dust.position = Vector2(0, 4)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(20, 3)
	dust.direction = Vector2(0, -1)
	dust.spread = 20.0
	dust.gravity = Vector2(0, -10)
	dust.initial_velocity_min = 5.0
	dust.initial_velocity_max = 14.0
	dust.scale_amount_min = 0.4
	dust.scale_amount_max = 0.8
	dust.color = Color(tint.r, tint.g, tint.b, 0.45)
	add_child(dust)

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
		_spit()
	# Télégraphe : la lueur du cratère gonfle dans le dernier tiers du cycle.
	var warn := clampf((_t - (PERIOD - WARN)) / WARN, 0.0, 1.0)
	if _core != null:
		_core.color.a = warn * 0.95
		_core.scale = Vector2.ONE * (1.0 + 0.4 * warn)

## Crache une salve d'éclats visant la position du joueur au moment du tir
## (trajectoire en cloche), décalés latéralement pour former un éventail.
func _spit() -> void:
	var host := get_parent()
	if host == null:
		return
	var player := get_tree().get_first_node_in_group("player")
	var target := global_position + DEFAULT_TARGET_OFFSET
	if player != null:
		target = (player as Node2D).global_position
	for i in SHARD_COUNT:
		var lateral := float(i - 1) * SPREAD
		_launch_shard(host, target + Vector2(lateral, 0))

func _launch_shard(host: Node, target: Vector2) -> void:
	var shard := Area2D.new()
	var r := randf_range(6.0, 10.0)
	var poly := PackedVector2Array()
	for k in 6:
		var a := k * TAU / 6.0
		poly.append(Vector2(cos(a) * r, sin(a) * r * 0.85))
	var body := Polygon2D.new()
	body.polygon = poly
	body.color = Color(tint.r + 0.1, tint.g + 0.08, tint.b + 0.12, 0.98)
	shard.add_child(body)
	# Facette claire au sommet : vend le volume du caillou en plein vol.
	var hi := Polygon2D.new()
	hi.polygon = PackedVector2Array([poly[0] * 0.7, poly[1] * 0.65, Vector2.ZERO])
	hi.color = Color(0.9, 0.86, 0.95, 0.75)
	shard.add_child(hi)
	var edge := Line2D.new()
	edge.points = poly
	edge.closed = true
	edge.width = 1.2
	edge.default_color = Color(0.15, 0.13, 0.17, 0.9)
	shard.add_child(edge)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = r
	shape.shape = circle
	shard.add_child(shape)
	shard.z_index = 3
	shard.global_position = global_position + Vector2(0, -6)
	host.add_child(shard)
	shard.body_entered.connect(_on_shard_hit.bind(shard))

	var start := shard.global_position
	var tw := shard.create_tween()
	tw.tween_method(_update_arc.bind(shard, start, target), 0.0, 1.0, FLIGHT_TIME)
	tw.parallel().tween_property(shard, "rotation", randf_range(6.0, 10.0) * (1.0 if randf() > 0.5 else -1.0), FLIGHT_TIME)
	tw.tween_callback(_on_shard_spent.bind(shard))

## Trajectoire en cloche : interpolation linéaire vers la cible, moins un
## arc de sinus qui la soulève au-dessus de la ligne droite.
func _update_arc(f: float, shard: Area2D, start: Vector2, target: Vector2) -> void:
	if not is_instance_valid(shard):
		return
	var pos := start.lerp(target, f)
	pos.y -= sin(f * PI) * ARC_HEIGHT
	shard.global_position = pos

func _on_shard_hit(body: Node2D, shard: Area2D) -> void:
	if not is_instance_valid(shard):
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1, shard.global_position)
		shard.queue_free()

## À l'impact, l'éclat s'efface dans un petit nuage de poussière au lieu de
## simplement disparaître.
func _on_shard_spent(shard: Area2D) -> void:
	if not is_instance_valid(shard):
		return
	var host := get_parent()
	if host != null:
		var puff := CPUParticles2D.new()
		puff.amount = 7
		puff.lifetime = 0.45
		puff.one_shot = true
		puff.emitting = true
		puff.global_position = shard.global_position
		puff.direction = Vector2(0, -1)
		puff.spread = 60.0
		puff.gravity = Vector2(0, 50)
		puff.initial_velocity_min = 25.0
		puff.initial_velocity_max = 55.0
		puff.scale_amount_min = 0.4
		puff.scale_amount_max = 0.8
		puff.color = Color(tint.r, tint.g, tint.b, 0.6)
		host.add_child(puff)
		var pt := puff.create_tween()
		pt.tween_interval(0.5)
		pt.tween_callback(puff.queue_free)
	shard.queue_free()
