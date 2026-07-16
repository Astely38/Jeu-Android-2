extends Area2D
## Orbe spirituel à collecter. Flotte doucement ; ramassé au contact
## d'Eneko (incrémente son compteur), puis disparaît dans un petit éclat.

## Nombre d'orbes que vaut ce ramassage (3 pour l'orbe dorée des élites).
@export var value := 1

var _base_y := 0.0
var _t := 0.0
var _taken := false
var _glow: Sprite2D
var _glow_base := 0.34
## Aura texturée qui tourne lentement derrière l'orbe (scintillement).
var _aura: Sprite2D

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)
	# Halo lumineux qui pulse doucement derrière l'orbe (rendu avant le
	# sprite pour passer dessous). Bleu spirituel, doré pour l'orbe d'élite.
	_glow = Sprite2D.new()
	_glow.texture = load("res://assets/mist.svg")
	if value > 1:
		# Orbe dorée : plus grosse, chaude et lumineuse.
		sprite.modulate = Color(1.0, 0.82, 0.35)
		sprite.scale *= 1.35
		_glow.modulate = Color(1.0, 0.82, 0.4, _glow_base)
		_glow.scale = Vector2(2.1, 2.1)
	else:
		_glow.modulate = Color(0.55, 0.9, 1.0, _glow_base)
		_glow.scale = Vector2(1.5, 1.5)
	add_child(_glow)
	# Aura texturée (voile de bruit) qui tourne derrière le halo : donne un
	# scintillement de matière à la lueur, teintée comme l'orbe.
	_aura = Sprite2D.new()
	_aura.texture = TextureLab.cloud_veil()
	var au := _glow.modulate
	_aura.modulate = Color(au.r, au.g, au.b, 0.22)
	var asc := 0.42 if value > 1 else 0.3
	_aura.scale = Vector2(asc, asc)
	add_child(_aura)
	# Rendu avant le sprite de l'orbe (passe dessous), mais au-dessus des
	# plateformes puisque l'orbe est instanciée après elles.
	move_child(_aura, 0)
	move_child(_glow, 1)

func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * 3.0) * 4.0
	if _glow != null:
		var pulse := 0.5 + 0.5 * sin(_t * 2.4)
		_glow.modulate.a = _glow_base * (0.6 + 0.5 * pulse)
		var s := (2.1 if value > 1 else 1.5) * (0.92 + 0.12 * pulse)
		_glow.scale = Vector2(s, s)
	if _aura != null:
		_aura.rotation += delta * 0.6
		var abase := 0.42 if value > 1 else 0.3
		var apulse := abase * (0.85 + 0.18 * sin(_t * 1.7))
		_aura.scale = Vector2(apulse, apulse)

func _on_body_entered(body: Node2D) -> void:
	if _taken:
		return
	if body.has_method("collect_orb"):
		_taken = true
		body.collect_orb(value)
		_spawn_pickup_burst()
		set_deferred("monitoring", false)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "scale", sprite.scale * 1.9, 0.25)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
		tween.finished.connect(queue_free)

## Petit éclat d'étincelles à la collecte (posé sur le parent : il survit
## à la disparition de l'orbe).
func _spawn_pickup_burst() -> void:
	var burst := CPUParticles2D.new()
	burst.global_position = global_position
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.amount = 12
	burst.lifetime = 0.5
	burst.direction = Vector2(0, -1)
	burst.spread = 180.0
	burst.initial_velocity_min = 45.0
	burst.initial_velocity_max = 120.0
	burst.gravity = Vector2(0, 140)
	burst.scale_amount_min = 1.2
	burst.scale_amount_max = 2.6
	burst.color = Color(1.0, 0.85, 0.4) if value > 1 else Color(0.6, 0.95, 1.0)
	get_parent().add_child(burst)
	burst.finished.connect(burst.queue_free)
