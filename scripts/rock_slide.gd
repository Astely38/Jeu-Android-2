class_name RockSlide
extends Node2D
## Cratère du Chapitre IV : pas un trou creusé dans le sol, un CÔNE QUI
## JAILLIT DU SOL — un petit volcan de miroir brisé, strates de roche
## sombre empilées qui se resserrent vers une bouche béante d'où couve
## l'énergie du glitch (magenta/cyan), comme une lave qui aurait remplacé
## le feu. Fissures qui courent sur ses flancs et dans la plateforme
## alentour (même langage que GlitchRift), éclats de verre dressés en
## couronne à la bouche, débris en suspension. L'énergie remonte le long
## des fissures à mesure que la salve se charge — le chaos du reflet
## visible avant même le tir. Par intermittence, il crache une salve de
## BOULES DE LUMIÈRE en CLOCHE, visée sur la position du joueur au moment
## du tir.
##
## Usage : RockSlide.new() ; `position` au sol, à la base du cône ;
## `phase` pour désynchroniser plusieurs cratères d'un même niveau ;
## `tint` pour la roche, `glow_a`/`glow_b` pour l'énergie du glitch (par
## défaut le magenta/cyan du chapitre).

const PERIOD := 3.4
const WARN := 0.65
const ORB_COUNT := 3
const FLIGHT_TIME := 0.85
const ARC_HEIGHT := 70.0
const SPREAD := 26.0
## Portée maximale : au-delà, le cratère reste actif (poussière, lueur) mais
## ne tire pas — sans ça, TOUS les cratères d'un niveau visent le joueur en
## permanence, même à l'autre bout du niveau.
const RANGE := 340.0

## Fissures qui courent sur les flancs du cône et jusque dans la plateforme
## alentour (direction, longueur) — la lave-glitch y affleure à la charge.
const CRACKS := [
	{"vec": Vector2(-0.95, -0.05), "len": 40.0}, {"vec": Vector2(-0.55, 0.55), "len": 26.0},
	{"vec": Vector2(-0.15, 0.75), "len": 22.0}, {"vec": Vector2(0.3, 0.7), "len": 24.0},
	{"vec": Vector2(0.85, 0.1), "len": 38.0}, {"vec": Vector2(0.5, -0.6), "len": 20.0},
	{"vec": Vector2(-0.35, -0.65), "len": 18.0},
]
## Éclats de verre dressés en couronne à la bouche (angle en degrés, hauteur).
const SHARDS := [-160.0, -115.0, -70.0, -25.0, 20.0, 65.0, 110.0, 155.0]

@export var phase := 0.0
@export var tint := Color(0.5, 0.46, 0.56)
@export var glow_a := Color(0.85, 0.25, 0.55)
@export var glow_b := Color(0.3, 0.75, 0.85)

var _t := 0.0
var _core: Polygon2D
var _cracks: Array = []

func _ready() -> void:
	_t = phase
	z_index = 4
	_build_crater()

## Cône-volcan : assise sombre, trois strates de roche jagged qui montent
## et se resserrent (base large et sombre -> rebord étroit et éclairé),
## bouche béante d'où couve l'énergie du glitch, fissures qui courent sur
## les flancs, éclats de verre dressés en couronne, débris en suspension.
func _build_crater() -> void:
	# Assise : ombre large et diffuse à la base, pour que le cône se fonde
	# dans la plateforme au lieu de sembler simplement "posé dessus".
	var ao := Sprite2D.new()
	ao.texture = load("res://assets/mist.svg")
	ao.modulate = Color(0, 0, 0, 0.45)
	ao.scale = Vector2(1.5, 0.6)
	ao.position = Vector2(0, 5)
	ao.z_index = -1
	add_child(ao)

	# Trois strates de roche empilées, jagged (pas de courbes lisses — de la
	# pierre brisée), qui rétrécissent en montant vers la bouche.
	var base_c := Color(0.06, 0.05, 0.07, 0.98)
	var mid_c := Color(tint.r * 0.5, tint.g * 0.46, tint.b * 0.56, 0.97)
	var rim_c := Color(tint.r * 0.9, tint.g * 0.85, tint.b * 0.95, 0.95)
	_poly(_rock_ring(4.0, 30.0, 9.0, 0.22, 10, 0.0), base_c)
	_poly(_rock_ring(-8.0, 21.0, 9.0, 0.26, 10, 1.7), mid_c)
	_poly(_rock_ring(-18.0, 12.0, 7.0, 0.3, 9, 3.1), rim_c)

	# Bouche béante au sommet : anneau sombre autour de la lueur.
	_poly(_rock_ring(-20.0, 7.0, 4.0, 0.18, 8, 4.4), Color(0.02, 0.015, 0.03, 0.95))

	# Fissures qui courent sur les flancs du cône (et un peu dans la
	# plateforme alentour) : l'énergie du glitch y affleure à la charge.
	for c in CRACKS:
		var vec: Vector2 = c["vec"]
		var length: float = c["len"]
		var start := Vector2(vec.x * 8.0, -10.0 + vec.y * 4.0)
		var mid := start + vec * length * 0.55 + vec.orthogonal() * 3.0
		var end := start + vec * length
		var crack := Line2D.new()
		crack.points = PackedVector2Array([start, mid, end])
		crack.width = 1.2
		crack.default_color = Color(0.02, 0.015, 0.03, 0.8)
		add_child(crack)
		var col := glow_a if randf() > 0.5 else glow_b
		var glint := Line2D.new()
		glint.points = crack.points
		glint.width = 0.55
		glint.default_color = Color(col.r, col.g, col.b, 0.0)
		add_child(glint)
		_cracks.append({"node": glint, "base": col, "phase": randf() * TAU})

	# Éclats de verre dressés en couronne à la bouche : le miroir brisé qui
	# hérisse le cône, pas un simple tas de gravats.
	for i in SHARDS.size():
		var ang: float = deg_to_rad(SHARDS[i])
		var dir := Vector2(cos(ang), sin(ang) * 0.6)
		var anchor := Vector2(dir.x * 9.0, -20.0 + dir.y * 5.0)
		var h := 7.0 + float(i % 3) * 4.0
		var side := dir.orthogonal() * 2.2
		var tip := anchor + dir * h - Vector2(0, h * 0.3)
		var col := glow_a if i % 2 == 0 else glow_b
		_poly(PackedVector2Array([anchor - side, anchor + side, tip]), Color(col.r, col.g, col.b, 0.6))

	# Lueur qui gonfle dans la bouche : seul vrai télégraphe de la salve.
	_core = _poly(PackedVector2Array([
		Vector2(-6, 2), Vector2(-2, 5), Vector2(3, 4), Vector2(6, -1), Vector2(1, -4), Vector2(-3, -3),
	]), Color(glow_b.r, glow_b.g, glow_b.b, 0.0))
	_core.position = Vector2(0, -19)
	_core.z_index = 1

	# Motes de débris en suspension autour de la bouche : des éclats du
	# miroir qui n'ont jamais fini de retomber, comme autour d'une GlitchRift.
	for col in [glow_a, glow_b]:
		var debris := CPUParticles2D.new()
		debris.texture = load("res://assets/leaf.svg")
		debris.amount = 4
		debris.lifetime = 2.2
		debris.preprocess = 2.2
		debris.position = Vector2(0, -22)
		debris.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		debris.emission_rect_extents = Vector2(14, 5)
		debris.direction = Vector2(0, -1)
		debris.spread = 40.0
		debris.gravity = Vector2.ZERO
		debris.initial_velocity_min = 4.0
		debris.initial_velocity_max = 12.0
		debris.angular_velocity_min = -80.0
		debris.angular_velocity_max = 80.0
		debris.scale_amount_min = 0.25
		debris.scale_amount_max = 0.45
		debris.color = col
		add_child(debris)

	# Poussière qui s'échappe en continu de la bouche : le cône reste
	# instable au repos.
	var dust := CPUParticles2D.new()
	dust.amount = 5
	dust.lifetime = 1.2
	dust.preprocess = 1.2
	dust.position = Vector2(0, -20)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(6, 2)
	dust.direction = Vector2(0, -1)
	dust.spread = 20.0
	dust.gravity = Vector2(0, -10)
	dust.initial_velocity_min = 6.0
	dust.initial_velocity_max = 16.0
	dust.scale_amount_min = 0.4
	dust.scale_amount_max = 0.8
	dust.color = Color(tint.r, tint.g, tint.b, 0.45)
	add_child(dust)

## Anneau de roche jagged (pas une ellipse lisse) : `n` sommets répartis
## autour d'une ellipse (cy, rx, ry), chacun décalé par un motif
## déterministe (`seed_off` différencie les strates entre elles).
func _rock_ring(cy: float, rx: float, ry: float, jitter: float, n: int, seed_off: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := float(i) / float(n) * TAU
		var j := 1.0 + jitter * sin(a * 3.7 + seed_off) * 0.5 + jitter * cos(a * 2.3 + seed_off * 1.3) * 0.5
		pts.append(Vector2(cos(a) * rx * j, cy + sin(a) * ry * j))
	return pts

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
	# Télégraphe : la lueur du cratère gonfle dans le dernier tiers du cycle,
	# et l'énergie remonte le long des fissures — le chaos se lit avant le tir.
	var warn := clampf((_t - (PERIOD - WARN)) / WARN, 0.0, 1.0)
	if _core != null:
		_core.color.a = warn * 0.95
		_core.scale = Vector2.ONE * (1.0 + 0.4 * warn)
	for c in _cracks:
		var node: Line2D = c["node"]
		var base: Color = c["base"]
		var shimmer := 0.12 + 0.1 * absf(sin(_t * 6.0 + float(c["phase"])))
		node.default_color = Color(base.r, base.g, base.b, shimmer + warn * 0.6)

## Crache une salve de boules de lumière visant la position du joueur au
## moment du tir (trajectoire en cloche), décalées latéralement pour former
## un éventail — seulement si le joueur est à portée : un cratère loin
## derrière ou devant reste actif visuellement mais ne tire pas dans le vide.
func _spit() -> void:
	var host := get_parent()
	if host == null:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not (player as Node2D).global_position.distance_to(global_position) <= RANGE:
		return
	var target: Vector2 = (player as Node2D).global_position
	for i in ORB_COUNT:
		var lateral := float(i - 1) * SPREAD
		_launch_orb(host, target + Vector2(lateral, 0))

## Boule de lumière : halo doux + cœur radieux + éclats orbitaux (fragments
## du miroir brisé qui tournent autour) — pas un caillou anguleux, le
## cratère crache l'énergie du reflet, pas des gravats.
func _launch_orb(host: Node, target: Vector2) -> void:
	var orb := Area2D.new()
	var r := randf_range(6.0, 9.0)
	var col := glow_a if randf() > 0.5 else glow_b

	var halo := Sprite2D.new()
	halo.texture = load("res://assets/mist.svg")
	halo.modulate = Color(col.r, col.g, col.b, 0.55)
	halo.scale = Vector2(0.55, 0.55) * (r / 7.0)
	halo.z_index = -1
	orb.add_child(halo)

	var poly := PackedVector2Array()
	for k in 10:
		var a := k * TAU / 10.0
		poly.append(Vector2(cos(a), sin(a)) * r)
	var core := Polygon2D.new()
	core.polygon = poly
	core.color = Color(1.0, 0.98, 1.0, 0.95)
	orb.add_child(core)
	var tinted := Polygon2D.new()
	tinted.polygon = poly
	tinted.scale = Vector2(0.7, 0.7)
	tinted.color = Color(col.r, col.g, col.b, 0.8)
	orb.add_child(tinted)

	# Éclats orbitaux : trois fragments du miroir qui tournent autour du
	# cœur lumineux, tantôt magenta tantôt cyan — le chaos du reflet en vol.
	var shards := Node2D.new()
	orb.add_child(shards)
	for i in 3:
		var sa := float(i) * TAU / 3.0
		var sc := glow_b if i % 2 == 0 else glow_a
		var pos := Vector2(cos(sa), sin(sa)) * (r + 4.0)
		var tri := Polygon2D.new()
		tri.polygon = PackedVector2Array([Vector2(-2, -3), Vector2(2, -3), Vector2(0, 4)])
		tri.color = Color(sc.r, sc.g, sc.b, 0.9)
		tri.position = pos
		tri.rotation = sa + PI / 2.0
		shards.add_child(tri)
	var st := shards.create_tween().set_loops()
	st.tween_property(shards, "rotation", TAU, 0.7).set_trans(Tween.TRANS_LINEAR)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = r
	shape.shape = circle
	orb.add_child(shape)
	orb.z_index = 3
	orb.global_position = global_position + Vector2(0, -6)
	host.add_child(orb)
	orb.body_entered.connect(_on_orb_hit.bind(orb))

	var start := orb.global_position
	var tw := orb.create_tween()
	tw.tween_method(_update_arc.bind(orb, start, target), 0.0, 1.0, FLIGHT_TIME)
	tw.tween_callback(_on_orb_spent.bind(orb))

## Trajectoire en cloche : interpolation linéaire vers la cible, moins un
## arc de sinus qui la soulève au-dessus de la ligne droite.
func _update_arc(f: float, orb: Area2D, start: Vector2, target: Vector2) -> void:
	if not is_instance_valid(orb):
		return
	var pos := start.lerp(target, f)
	pos.y -= sin(f * PI) * ARC_HEIGHT
	orb.global_position = pos

func _on_orb_hit(body: Node2D, orb: Area2D) -> void:
	if not is_instance_valid(orb):
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1, orb.global_position)
		orb.queue_free()

## À l'impact, la boule de lumière éclate en fragments au lieu de
## simplement disparaître.
func _on_orb_spent(orb: Area2D) -> void:
	if not is_instance_valid(orb):
		return
	var host := get_parent()
	if host != null:
		var puff := CPUParticles2D.new()
		puff.amount = 10
		puff.lifetime = 0.45
		puff.one_shot = true
		puff.emitting = true
		puff.global_position = orb.global_position
		puff.direction = Vector2(0, -1)
		puff.spread = 180.0
		puff.gravity = Vector2.ZERO
		puff.initial_velocity_min = 35.0
		puff.initial_velocity_max = 80.0
		puff.scale_amount_min = 0.4
		puff.scale_amount_max = 0.85
		puff.color = Color(glow_a.r, glow_a.g, glow_a.b, 0.75)
		host.add_child(puff)
		var pt := puff.create_tween()
		pt.tween_interval(0.5)
		pt.tween_callback(puff.queue_free)
	orb.queue_free()
