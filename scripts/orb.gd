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
	# Rendu avant le sprite de l'orbe (passe dessous), mais au-dessus des
	# plateformes puisque l'orbe est instanciée après elles.
	move_child(_glow, 0)

func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * 3.0) * 4.0
	if _glow != null:
		var pulse := 0.5 + 0.5 * sin(_t * 2.4)
		_glow.modulate.a = _glow_base * (0.6 + 0.5 * pulse)
		var s := (2.1 if value > 1 else 1.5) * (0.92 + 0.12 * pulse)
		_glow.scale = Vector2(s, s)

func _on_body_entered(body: Node2D) -> void:
	if _taken:
		return
	if body.has_method("collect_orb"):
		_taken = true
		body.collect_orb(value)
		set_deferred("monitoring", false)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "scale", sprite.scale * 1.9, 0.25)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
		tween.finished.connect(queue_free)
