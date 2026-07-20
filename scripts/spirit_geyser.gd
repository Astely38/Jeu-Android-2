class_name SpiritGeyser
extends Node2D
## Piège dynamique : un évent au sol d'où jaillit par intermittence une
## colonne de flamme spectrale. Le cycle est TÉLÉGRAPHIÉ — une lueur et des
## braises montent pendant ~0,7 s avant l'éruption — et il existe une longue
## fenêtre dormante et sûre : le piège est toujours franchissable en attendant
## le bon moment (jamais un dégât forcé).
##
## Usage : SpiritGeyser.new() ; définir `position` sur le dessus d'une
## plateforme, éventuellement `phase` pour désynchroniser plusieurs geysers.

## Durée totale d'un cycle (dormant + télégraphe + éruption).
const PERIOD := 3.2
## Durée du télégraphe (avertissement) juste avant l'éruption.
const WARN := 0.7
## Durée de l'éruption active (dégât).
const ERUPT := 0.9
## Hauteur de la colonne de flamme à pleine éruption.
const FLAME_H := 84.0

## Décalage temporel : permet d'alterner les geysers d'un même niveau.
@export var phase := 0.0

var _t := 0.0
var _hurt: Area2D
var _flame: Polygon2D
var _flame_core: Polygon2D
var _glow: Sprite2D
var _embers: CPUParticles2D
var _active := false
var _hit_this_cycle := false

func _ready() -> void:
	_t = phase
	# Évent de pierre noircie posé au ras du sol.
	_vent(Color(0.16, 0.14, 0.18), -18.0, 18.0, 0.0, -6.0)
	_vent(Color(0.28, 0.24, 0.3), -13.0, 13.0, -4.0, -9.0)

	# Lueur de télégraphe (s'allume avant l'éruption).
	_glow = Sprite2D.new()
	_glow.texture = load("res://assets/mist.svg")
	_glow.modulate = Color(0.7, 0.5, 1.0, 0.0)
	_glow.scale = Vector2(1.4, 1.4)
	_glow.position = Vector2(0, -14)
	_glow.z_index = 1
	add_child(_glow)

	# Braises spectrales qui montent pendant le télégraphe.
	_embers = CPUParticles2D.new()
	_embers.emitting = false
	_embers.amount = 12
	_embers.lifetime = 0.8
	_embers.position = Vector2(0, -6)
	_embers.direction = Vector2(0, -1)
	_embers.spread = 24.0
	_embers.gravity = Vector2(0, -40)
	_embers.initial_velocity_min = 30.0
	_embers.initial_velocity_max = 70.0
	_embers.scale_amount_min = 1.0
	_embers.scale_amount_max = 2.2
	_embers.color = Color(0.7, 0.55, 1.0, 0.8)
	add_child(_embers)

	# Colonne de flamme (cachée au repos : échelle verticale nulle).
	_flame = Polygon2D.new()
	_flame.polygon = PackedVector2Array([
		Vector2(-15, 0), Vector2(-9, -FLAME_H * 0.55), Vector2(-4, -FLAME_H * 0.85),
		Vector2(0, -FLAME_H), Vector2(4, -FLAME_H * 0.85), Vector2(9, -FLAME_H * 0.55),
		Vector2(15, 0),
	])
	_flame.color = Color(0.55, 0.4, 1.0, 0.9)
	_flame.scale = Vector2(1.0, 0.0)
	_flame.z_index = 2
	add_child(_flame)
	_flame_core = Polygon2D.new()
	_flame_core.polygon = PackedVector2Array([
		Vector2(-7, 0), Vector2(-4, -FLAME_H * 0.5), Vector2(0, -FLAME_H * 0.78),
		Vector2(4, -FLAME_H * 0.5), Vector2(7, 0),
	])
	_flame_core.color = Color(0.85, 0.9, 1.0, 0.95)
	_flame.add_child(_flame_core)

	# Zone de dégât : monitoring toujours actif (les chevauchements restent à
	# jour) ; le dégât n'est appliqué QUE pendant l'éruption, dans _process.
	_hurt = Area2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, FLAME_H)
	shape.shape = rect
	shape.position = Vector2(0, -FLAME_H * 0.5)
	_hurt.add_child(shape)
	add_child(_hurt)

func _vent(c: Color, x0: float, x1: float, top: float, bottom: float) -> void:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([
		Vector2(x0, bottom), Vector2(x1, bottom), Vector2(x1 - 3, top), Vector2(x0 + 3, top),
	])
	p.color = c
	add_child(p)

func _process(delta: float) -> void:
	_t += delta
	if _t >= PERIOD:
		_t -= PERIOD
	var warn_start := PERIOD - ERUPT - WARN
	var erupt_start := PERIOD - ERUPT

	if _t < warn_start:
		# Dormant : tout est éteint.
		_active = false
		_glow.modulate.a = 0.0
		_embers.emitting = false
		_flame.scale.y = 0.0
	elif _t < erupt_start:
		# Télégraphe : la lueur enfle et les braises montent.
		var w := (_t - warn_start) / WARN
		_active = false
		_glow.modulate.a = 0.5 * w
		_glow.scale = Vector2(1.4 + 0.6 * w, 1.4 + 0.6 * w)
		_embers.emitting = true
		_flame.scale.y = 0.12 * w
	else:
		# Éruption : la flamme jaillit et le dégât est actif.
		var e := (_t - erupt_start) / ERUPT
		if not _active:
			_active = true
			_hit_this_cycle = false  # un seul dégât par éruption
		_embers.emitting = false
		_glow.modulate.a = 0.55 * (1.0 - e)
		# Montée rapide puis retombée, avec vacillement.
		var rise := clampf(e * 4.0, 0.0, 1.0) * (1.0 - clampf((e - 0.7) / 0.3, 0.0, 1.0))
		_flame.scale.y = maxf(0.12, rise) * (0.94 + 0.06 * sin(_t * 40.0))
		_flame.scale.x = 1.0 + 0.08 * sin(_t * 33.0)
		_check_hit()

## Applique le dégât si Eneko est dans la colonne (une fois par éruption).
func _check_hit() -> void:
	if _hit_this_cycle:
		return
	for body in _hurt.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			_hit_this_cycle = true
			body.take_damage(1, global_position + Vector2(0, -20))
			return
