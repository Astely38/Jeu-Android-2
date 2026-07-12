extends CharacterBody2D

const SPEED := 220.0
const JUMP_VELOCITY := -420.0
const GRAVITY := 980.0
const ATTACK_DURATION := 0.2

var moving_left := false
var moving_right := false
var attacking := false
var start_position := Vector2.ZERO

@onready var attack_area: Area2D = $AttackArea

func _ready() -> void:
	start_position = position
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var direction := 0.0
	if moving_left or Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		direction -= 1.0
	if moving_right or Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		direction += 1.0

	velocity.x = direction * SPEED
	move_and_slide()

	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_SPACE):
		jump()
	if Input.is_physical_key_pressed(KEY_X):
		attack()

func jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_VELOCITY

func attack() -> void:
	if attacking:
		return
	attacking = true
	attack_area.monitoring = true
	await get_tree().create_timer(ATTACK_DURATION).timeout
	attack_area.monitoring = false
	attacking = false

func respawn() -> void:
	position = start_position
	velocity = Vector2.ZERO

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.has_method("die"):
		body.die()

func _on_left_pressed() -> void:
	moving_left = true

func _on_left_released() -> void:
	moving_left = false

func _on_right_pressed() -> void:
	moving_right = true

func _on_right_released() -> void:
	moving_right = false

func _on_jump_pressed() -> void:
	jump()

func _on_attack_pressed() -> void:
	attack()
