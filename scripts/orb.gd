extends Area2D
## Orbe spirituel à collecter. Flotte doucement ; ramassé au contact
## d'Eneko (incrémente son compteur), puis disparaît dans un petit éclat.

## Nombre d'orbes que vaut ce ramassage (3 pour l'orbe dorée des élites).
@export var value := 1

var _base_y := 0.0
var _t := 0.0
var _taken := false

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)
	if value > 1:
		# Orbe dorée : plus grosse, chaude et lumineuse.
		sprite.modulate = Color(1.0, 0.82, 0.35)
		sprite.scale *= 1.35

func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * 3.0) * 4.0

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
