extends Area2D
## Orbe spirituel à collecter. Flotte doucement ; ramassé au contact
## d'Eneko (incrémente son compteur), puis disparaît dans un petit éclat.

var _base_y := 0.0
var _t := 0.0
var _taken := false

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * 3.0) * 4.0

func _on_body_entered(body: Node2D) -> void:
	if _taken:
		return
	if body.has_method("collect_orb"):
		_taken = true
		body.collect_orb()
		set_deferred("monitoring", false)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "scale", sprite.scale * 1.9, 0.25)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
		tween.finished.connect(queue_free)
