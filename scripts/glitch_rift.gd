class_name GlitchRift
extends Node2D
## Faille glitchée du Chapitre IV : bloc de roche fracturé, EMBOÎTÉ dans le
## sol (son centre vertical calé sur la ligne de marche, pas posé dessus),
## d'où jaillissent des pics de lumière magenta/cyan. Danger fixe, jamais
## télégraphié — se repère à sa lueur et à son scintillement, pas à une
## alerte.
##
## Usage : GlitchRift.new() ; `position` au sol, là où la faille doit trouer
## le décor ; `phase` pour désynchroniser le clignotement de plusieurs
## failles d'un même niveau.

const TEX := preload("res://assets/traps/glitch_rift/rift_open.png")
const SHARD_TEX := preload("res://assets/traps/glitch_rift/shard.png")
const ART_SCALE := 0.5
const GLITCH_A := Color(0.85, 0.25, 0.55)
const GLITCH_B := Color(0.3, 0.75, 0.85)

@export var phase := 0.0
## Conservées pour compatibilité des appelants existants (level_16/17) —
## sans effet sur l'image peinte, dont les teintes sont fixes.
@export var color_a := GLITCH_A
@export var color_b := GLITCH_B

var _sprite: Sprite2D
var _t := 0.0

func _ready() -> void:
	_t = phase
	# Le point le plus large de l'image (l'équateur du bloc) tombe pile à sa
	# moitié verticale : centrer le sprite sur `position` suffit à caler le
	# sol du décor sur la ligne de marche — la moitié basse s'enfonce dans la
	# plateforme, seuls les pics dépassent au-dessus.
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.scale = Vector2(ART_SCALE, ART_SCALE)
	add_child(_sprite)
	Atmosphere.breathe(_sprite, 0.05, 2.0)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(52, 60)
	shape.shape = rect
	var area := Area2D.new()
	area.position = Vector2(0, -16.0)
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)

	for col in [GLITCH_A, GLITCH_B]:
		var debris := CPUParticles2D.new()
		debris.texture = SHARD_TEX
		debris.amount = 5
		debris.lifetime = 2.6
		debris.preprocess = 2.6
		debris.position = Vector2(0, -22)
		debris.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		debris.emission_rect_extents = Vector2(30, 8)
		debris.direction = Vector2(0, -1)
		debris.spread = 30.0
		debris.gravity = Vector2.ZERO
		debris.initial_velocity_min = 6.0
		debris.initial_velocity_max = 16.0
		debris.angular_velocity_min = -90.0
		debris.angular_velocity_max = 90.0
		debris.scale_amount_min = 0.5
		debris.scale_amount_max = 0.85
		debris.color = col
		add_child(debris)

func _process(delta: float) -> void:
	_t += delta
	if _sprite != null:
		# Scintillement doux : le sprite est fixe, seule sa luminosité vit.
		_sprite.modulate = Color(1, 1, 1) * (0.85 + 0.15 * absf(sin(_t * 6.0 + phase)))

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1, body.global_position + Vector2(0, 20))
