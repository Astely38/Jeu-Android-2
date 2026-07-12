extends CharacterBody2D

@export var patrol_distance := 100.0
@export var speed := 60.0

const GRAVITY := 980.0

var start_x := 0.0
var direction := 1.0

func _ready() -> void:
	start_x = position.x

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	velocity.x = direction * speed
	move_and_slide()

	if absf(position.x - start_x) >= patrol_distance:
		direction *= -1.0

func die() -> void:
	queue_free()
