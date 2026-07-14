extends AnimatableBody2D
## Ascenseur spirituel : dalle de pierre pâle cerclée d'or qui flotte et
## oscille lentement le long de `travel` (départ au point bas, atteignable
## d'un saut depuis le bord du trou). Eneko peut monter dessus pour
## atteindre des orbes bonus placées en hauteur.
##
## La position est animée en _physics_process et `sync_to_physics` (réglé
## dans la scène) transmet le mouvement au personnage qui se tient dessus.

@export var half_w := 55.0
## Déplacement du point bas vers le point haut (vers le haut = y négatif).
@export var travel := Vector2(0, -175)
## Durée d'un aller-retour complet, en secondes.
@export var period := 6.0
## Décalage de départ (en secondes) pour désynchroniser plusieurs dalles.
@export var phase := 0.0

const STONE := Color(0.82, 0.79, 0.72)
const STONE_DARK := Color(0.6, 0.57, 0.51)
const GOLD := Color(0.9, 0.74, 0.34)

var _origin := Vector2.ZERO
var _t := 0.0

func _ready() -> void:
	_origin = position
	_t = phase
	_build_visuals()
	var sh := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(half_w * 2.0, 18.0)
	sh.shape = rect
	# Dessus de la dalle = y local 0 (les personnages marchent à y 0).
	sh.position = Vector2(0, 9.0)
	add_child(sh)

func _physics_process(delta: float) -> void:
	_t += delta
	# 0 → 1 → 0 en douceur (départ et arrivée sans à-coup).
	var k := 0.5 - 0.5 * cos(TAU * _t / period)
	position = _origin + travel * k

func _poly(points: PackedVector2Array, color: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	add_child(p)

func _build_visuals() -> void:
	# Liseré d'or sur le dessus, corps de pierre biseauté, dessous sombre.
	_poly(PackedVector2Array([
		Vector2(-half_w, 0), Vector2(half_w, 0),
		Vector2(half_w - 2, 4), Vector2(-half_w + 2, 4),
	]), GOLD)
	_poly(PackedVector2Array([
		Vector2(-half_w + 2, 4), Vector2(half_w - 2, 4),
		Vector2(half_w - 6, 16), Vector2(-half_w + 6, 16),
	]), STONE)
	_poly(PackedVector2Array([
		Vector2(-half_w + 6, 16), Vector2(half_w - 6, 16),
		Vector2(half_w - 14, 22), Vector2(-half_w + 14, 22),
	]), STONE_DARK)
	# Rune dorée au centre de la tranche.
	_poly(PackedVector2Array([
		Vector2(-5, 6), Vector2(0, 10), Vector2(5, 6), Vector2(0, 14),
	]), Color(1.0, 0.85, 0.45, 0.9))

	# Halo doré sous la dalle : c'est lui qui la porte.
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(1.0, 0.85, 0.5, 0.24)
	glow.scale = Vector2(1.5, 0.9)
	glow.position = Vector2(0, 30)
	add_child(glow)

	# Étincelles qui retombent doucement du dessous.
	var sparks := CPUParticles2D.new()
	sparks.amount = 6
	sparks.lifetime = 1.6
	sparks.preprocess = 1.6
	sparks.position = Vector2(0, 24)
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(half_w - 12.0, 2)
	sparks.direction = Vector2(0, 1)
	sparks.spread = 20.0
	sparks.gravity = Vector2(0, 18)
	sparks.initial_velocity_min = 8.0
	sparks.initial_velocity_max = 18.0
	sparks.scale_amount_min = 1.4
	sparks.scale_amount_max = 2.4
	sparks.color = Color(1.0, 0.85, 0.45, 0.6)
	add_child(sparks)
