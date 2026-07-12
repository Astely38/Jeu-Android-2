extends CharacterBody2D

@export var patrol_distance := 100.0
@export var speed := 60.0

const GRAVITY := 980.0

var start_x := 0.0
var direction := 1.0

@onready var sprite: Sprite2D = $Sprite
@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
	start_x = position.x
	hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta: float) -> void:
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
	if body.has_method("take_damage"):
		body.take_damage(1, global_position)

func die() -> void:
	queue_free()
