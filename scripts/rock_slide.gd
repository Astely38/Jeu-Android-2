class_name RockSlide
extends Node2D
## Piège du Chapitre IV : un cratère qui déchire le sol — pas une simple
## tache posée dessus, un vrai puits aux parois dégradées, cerné de
## fissures qui courent dans la plateforme (même langage que GlitchRift).
## Par intermittence, il crache une salve de BOULES DE LUMIÈRE en CLOCHE,
## visée sur la position du joueur au moment du tir — plus imprévisible
## qu'un éboulis qui suivrait toujours la même trajectoire. Télégraphié
## par une lueur qui gonfle au fond du cratère juste avant chaque salve.
##
## Usage : RockSlide.new() ; `position` au sol, au centre du cratère ;
## `phase` pour désynchroniser plusieurs cratères d'un même niveau ;
## `tint` pour la pierre du pourtour, `glow_a`/`glow_b` pour la couleur
## des boules de lumière (par défaut le glitch magenta/cyan du chapitre).

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

@export var phase := 0.0
@export var tint := Color(0.5, 0.46, 0.56)
@export var glow_a := Color(0.85, 0.25, 0.55)
@export var glow_b := Color(0.3, 0.75, 0.85)

var _t := 0.0
var _core: Polygon2D

func _ready() -> void:
	_t = phase
	z_index = 4
	_build_crater()

## Cratère qui déchire le sol : assise sombre pour l'ancrer, fissures qui
## courent dans la plateforme depuis son bord, puis un vrai puits en
## dégradé (rebord clair, fond presque noir) — pas une tache plate.
func _build_crater() -> void:
	# Assise : ombre large et diffuse sous le pourtour, pour que le cratère
	# ne semble jamais simplement "collé" sur la plateforme.
	var ao := Sprite2D.new()
	ao.texture = load("res://assets/mist.svg")
	ao.modulate = Color(0, 0, 0, 0.4)
	ao.scale = Vector2(1.0, 0.5)
	ao.position = Vector2(0, 4)
	ao.z_index = -1
	add_child(ao)

	# Fissures qui déchirent la plateforme depuis le bord du trou — le sol
	# lui-même cède, pas juste un rond creusé proprement.
	for side: float in [-1.0, 1.0]:
		for k in 2:
			var base_x := side * (28.0 + float(k) * 16.0)
			var crack := Line2D.new()
			crack.points = PackedVector2Array([
				Vector2(side * 20.0, 2.0), Vector2(base_x * 0.6, -3.0),
				Vector2(base_x, 1.0), Vector2(base_x + side * 10.0, -4.0),
			])
			crack.width = 1.1
			crack.default_color = Color(0.04, 0.03, 0.05, 0.75)
			add_child(crack)
			var glint := Line2D.new()
			glint.points = crack.points
			glint.width = 0.5
			glint.default_color = Color(glow_a.r, glow_a.g, glow_a.b, 0.3)
			add_child(glint)

	# Puits en dégradé : trois strates emboîtées, du rebord clair (encore
	# éclairé) au fond presque noir — la profondeur se lit d'un coup d'œil,
	# plus besoin d'attendre la lueur d'alerte pour reconnaître un trou.
	var rim_lit := Color(tint.r * 0.85, tint.g * 0.8, tint.b * 0.9, 0.9)
	var wall := Color(0.1, 0.09, 0.12, 0.95)
	var pit_dark := Color(0.03, 0.025, 0.04, 0.98)
	_poly(PackedVector2Array([
		Vector2(-30, 4), Vector2(-20, 18), Vector2(0, 24), Vector2(20, 17), Vector2(30, 3),
		Vector2(24, -6), Vector2(0, -10), Vector2(-24, -5),
	]), rim_lit)
	_poly(PackedVector2Array([
		Vector2(-25, 5), Vector2(-16, 16), Vector2(0, 21), Vector2(16, 15), Vector2(25, 4),
		Vector2(19, -3), Vector2(0, -6), Vector2(-19, -2),
	]), wall)
	_poly(PackedVector2Array([
		Vector2(-16, 6), Vector2(-9, 13), Vector2(0, 16), Vector2(9, 12), Vector2(16, 5),
		Vector2(11, -1), Vector2(0, -3), Vector2(-11, 0),
	]), pit_dark)
	# Rebord fissuré, irrégulier — instable, prêt à s'ébouler encore.
	var rim_edge := Line2D.new()
	rim_edge.points = PackedVector2Array([
		Vector2(-32, -2), Vector2(-24, -9), Vector2(-14, -5), Vector2(-4, -10),
		Vector2(6, -4), Vector2(16, -9), Vector2(26, -3), Vector2(32, -6),
	])
	rim_edge.width = 2.2
	rim_edge.default_color = Color(tint.r + 0.15, tint.g + 0.12, tint.b + 0.18)
	add_child(rim_edge)
	# Lueur qui gonfle au fond du cratère : seul vrai télégraphe de la salve.
	_core = _poly(PackedVector2Array([
		Vector2(-8, 5), Vector2(-3, 10), Vector2(4, 9), Vector2(8, 2), Vector2(1, -3), Vector2(-4, -1),
	]), Color(glow_b.r, glow_b.g, glow_b.b, 0.0))
	_core.position = Vector2(0, 4)
	_core.z_index = 1
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

## Boule de lumière : halo doux + cœur radieux + fin anneau scintillant,
## pas un caillou anguleux — le cratère crache l'énergie du miroir brisé,
## pas des gravats.
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
	var ring := Line2D.new()
	ring.points = poly
	ring.closed = true
	ring.width = 1.2
	ring.default_color = Color(col.r, col.g, col.b, 0.95)
	orb.add_child(ring)

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
	tw.parallel().tween_property(ring, "rotation", randf_range(4.0, 7.0) * (1.0 if randf() > 0.5 else -1.0), FLIGHT_TIME)
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

## À l'impact, la boule de lumière s'éteint dans un petit éclat au lieu de
## simplement disparaître.
func _on_orb_spent(orb: Area2D) -> void:
	if not is_instance_valid(orb):
		return
	var host := get_parent()
	if host != null:
		var puff := CPUParticles2D.new()
		puff.amount = 8
		puff.lifetime = 0.4
		puff.one_shot = true
		puff.emitting = true
		puff.global_position = orb.global_position
		puff.direction = Vector2(0, -1)
		puff.spread = 180.0
		puff.gravity = Vector2.ZERO
		puff.initial_velocity_min = 30.0
		puff.initial_velocity_max = 70.0
		puff.scale_amount_min = 0.4
		puff.scale_amount_max = 0.8
		puff.color = Color(glow_a.r, glow_a.g, glow_a.b, 0.7)
		host.add_child(puff)
		var pt := puff.create_tween()
		pt.tween_interval(0.45)
		pt.tween_callback(puff.queue_free)
	orb.queue_free()
