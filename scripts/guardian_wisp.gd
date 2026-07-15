class_name GuardianWisp
extends Node2D
## Le feu follet de Léonie : un petit esprit de lumière chaud qui flotte et
## scintille autour d'Eneko, laissant une traînée d'étincelles. Symbole de
## la Flamme d'Aube qui veille sur lui — purement décoratif, présent dans
## tous les niveaux (ajouté comme enfant du joueur).

var _t := 0.0
var _glow: Sprite2D
var _core: Polygon2D

func _ready() -> void:
	z_index = 1  # devant le sprite d'Eneko, sous l'interface
	_t = randf() * 6.28

	# Halo chaud et doux.
	_glow = Sprite2D.new()
	_glow.texture = load("res://assets/mist.svg")
	_glow.modulate = Color(1.0, 0.85, 0.5, 0.5)
	_glow.scale = Vector2(0.7, 0.7)
	add_child(_glow)

	# Cœur lumineux vif.
	var pts := PackedVector2Array()
	for k in 10:
		var a := k * TAU / 10.0
		pts.append(Vector2(cos(a) * 3.2, sin(a) * 3.2))
	_core = Polygon2D.new()
	_core.polygon = pts
	_core.color = Color(1.0, 0.96, 0.72, 0.96)
	add_child(_core)

	# Fine traînée d'étincelles laissée dans le sillage (coords globales,
	# pour que les étincelles restent en place quand le follet se déplace).
	var trail := CPUParticles2D.new()
	trail.local_coords = false
	trail.amount = 14
	trail.lifetime = 0.6
	trail.explosiveness = 0.0
	trail.direction = Vector2(0, -1)
	trail.spread = 40.0
	trail.gravity = Vector2(0, -6)
	trail.initial_velocity_min = 3.0
	trail.initial_velocity_max = 10.0
	trail.scale_amount_min = 1.0
	trail.scale_amount_max = 2.0
	trail.color = Color(1.0, 0.82, 0.45, 0.7)
	add_child(trail)

func _process(delta: float) -> void:
	_t += delta
	# Orbite douce autour d'un point au-dessus et légèrement en retrait
	# de la tête d'Eneko ; le follet flotte, jamais tout à fait immobile.
	position = Vector2(cos(_t * 1.6) * 15.0 - 6.0, -34.0 + sin(_t * 2.3) * 6.0)
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	_glow.modulate.a = 0.32 + 0.26 * pulse
	var s := 0.58 + 0.16 * pulse
	_glow.scale = Vector2(s, s)
	_core.scale = Vector2(0.85 + 0.25 * pulse, 0.85 + 0.25 * pulse)
