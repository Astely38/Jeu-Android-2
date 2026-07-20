class_name GodRays
extends Node2D
## Rayons de lumière (god-rays) : faisceaux doux qui s'évasent depuis une
## source lumineuse (soleil, lune) et scintillent lentement. Purement
## décoratif — à placer dans une couche de parallaxe, à la position de la
## source. Régler les propriétés AVANT add_child.

@export var ray_count := 7
@export var length := 1200.0
## Demi-ouverture angulaire de l'éventail (radians).
@export var half_spread := 0.8
## Direction centrale des rayons (défaut : vers le bas, PI/2).
@export var base_angle := 1.5708
@export var base_width := 46.0
@export var color := Color(1.0, 0.86, 0.5, 0.07)

var _beams: Array = []
var _t := 0.0

func _ready() -> void:
	for i in ray_count:
		var f := float(i) / maxf(1.0, float(ray_count - 1))
		var ang := base_angle - half_spread + 2.0 * half_spread * f
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x)
		var w0 := base_width * 0.12
		var w1 := base_width * (0.6 + 0.7 * absf(sin(f * 9.0)))
		var beam := Polygon2D.new()
		beam.polygon = PackedVector2Array([
			-perp * w0, perp * w0,
			dir * length + perp * w1, dir * length - perp * w1,
		])
		beam.color = color
		add_child(beam)
		_beams.append(beam)

func _process(delta: float) -> void:
	_t += delta
	for i in _beams.size():
		var b: Polygon2D = _beams[i]
		b.color.a = color.a * (0.4 + 0.6 * (0.5 + 0.5 * sin(_t * 0.5 + float(i) * 1.3)))
