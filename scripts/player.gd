extends CharacterBody2D

const SPEED := 220.0
const JUMP_VELOCITY := -420.0
const GRAVITY := 980.0
const ATTACK_DURATION := 0.2
const MAX_HEALTH := 3
const INVULN_TIME := 1.0
const KNOCKBACK_SPEED := 240.0
const KNOCKBACK_TIME := 0.18

var moving_left := false
var moving_right := false
var attacking := false
var facing := 1.0
var health := MAX_HEALTH
var invuln := 0.0
var knockback := 0.0
var start_position := Vector2.ZERO

@onready var attack_area: Area2D = $AttackArea
@onready var sprite: Sprite2D = $Sprite
@onready var hearts: Array = [$HUD/Heart1, $HUD/Heart2, $HUD/Heart3]

func _ready() -> void:
	start_position = position
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	_update_hearts()

func _physics_process(delta: float) -> void:
	if invuln > 0.0:
		invuln -= delta
		sprite.modulate.a = 0.35 if int(invuln * 12.0) % 2 == 0 else 1.0
	else:
		sprite.modulate.a = 1.0

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if knockback > 0.0:
		knockback -= delta
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 3.0 * delta)
	else:
		var direction := 0.0
		if moving_left or Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
			direction -= 1.0
		if moving_right or Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
			direction += 1.0
		velocity.x = direction * SPEED
		if direction != 0.0:
			_set_facing(direction)

	move_and_slide()

	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_SPACE):
		jump()
	if Input.is_physical_key_pressed(KEY_X):
		attack()

func _set_facing(dir: float) -> void:
	facing = dir
	sprite.flip_h = dir < 0.0
	attack_area.position.x = 26.0 * dir

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

func take_damage(amount: int, from_position: Vector2) -> void:
	if invuln > 0.0:
		return
	health -= amount
	_update_hearts()
	if health <= 0:
		respawn()
		return
	invuln = INVULN_TIME
	knockback = KNOCKBACK_TIME
	var push := signf(global_position.x - from_position.x)
	if push == 0.0:
		push = -facing
	velocity.x = push * KNOCKBACK_SPEED
	velocity.y = -220.0

func respawn() -> void:
	position = start_position
	velocity = Vector2.ZERO
	health = MAX_HEALTH
	invuln = 0.0
	knockback = 0.0
	sprite.modulate.a = 1.0
	_update_hearts()

func _update_hearts() -> void:
	for i in hearts.size():
		hearts[i].visible = i < health

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
