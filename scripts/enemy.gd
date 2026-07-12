extends CharacterBody2D
## Esprit corrompu : patrouille de gauche à droite sur sa plateforme.
## Inflige des dégâts au joueur au contact, et n'est vaincu qu'au sabre.

@export var patrol_distance := 100.0
@export var speed := 60.0

const GRAVITY := 980.0

var start_x := 0.0
var direction := 1.0
var _dying := false

@onready var sprite: Sprite2D = $Sprite
@onready var hitbox: Area2D = $Hitbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	start_x = position.x
	hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta: float) -> void:
	if _dying:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	velocity.x = direction * speed
	move_and_slide()

	if absf(position.x - start_x) >= patrol_distance:
		direction *= -1.0

	sprite.flip_h = direction < 0.0

func _on_hitbox_body_entered(body: Node2D) -> void:
	if _dying:
		return
	if body.has_method("take_damage"):
		body.take_damage(1, global_position)

## Vaincu par le sabre : effet spirituel (dilatation + fondu) puis disparition.
func die() -> void:
	if _dying:
		return
	_dying = true
	velocity = Vector2.ZERO
	hitbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", sprite.scale * 1.8, 0.3)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_property(sprite, "position:y", sprite.position.y - 20.0, 0.3)
	tween.finished.connect(queue_free)
