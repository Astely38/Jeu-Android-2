extends CharacterBody2D
## Eneko, l'apprenti sabreur. Déplacement/saut/attaque au sabre avec un
## AnimatedSprite2D piloté par une machine à états (idle / run / jump /
## attack / hurt). Barre de vie (cœurs), énergie du sabre, invincibilité,
## recul et point de contrôle.

const SPEED := 220.0
const JUMP_VELOCITY := -480.0
const GRAVITY := 980.0
const ATTACK_DURATION := 0.42
const HURT_LOCK := 0.28
const MAX_HEALTH := 3
const INVULN_TIME := 1.0
const KNOCKBACK_SPEED := 240.0
const KNOCKBACK_TIME := 0.18
const MAX_ENERGY := 100.0
const ENERGY_REGEN := 26.0
const ATTACK_COST := 22.0
const HEART_BASE_SCALE := Vector2(1.1, 1.1)
const SAMURAI := "res://assets/character/samurai/"

var moving_left := false
var moving_right := false
var attacking := false
var facing := 1.0
var health := MAX_HEALTH
var invuln := 0.0
var knockback := 0.0
var lock_timer := 0.0
var anim_time := 0.0
var energy := MAX_ENERGY
var orbs := 0
var start_position := Vector2.ZERO
var _cur := ""

@onready var attack_area: Area2D = $AttackArea
@onready var anim: AnimatedSprite2D = $Anim
@onready var energy_fill: Polygon2D = $HUD/EnergyFill
@onready var orb_label: Label = $HUD/OrbCount
@onready var hearts: Array = [$HUD/Heart1, $HUD/Heart2, $HUD/Heart3]
@onready var sfx_jump: AudioStreamPlayer = $SfxJump
@onready var sfx_slash: AudioStreamPlayer = $SfxSlash
@onready var sfx_hurt: AudioStreamPlayer = $SfxHurt
@onready var sfx_orb: AudioStreamPlayer = $SfxOrb
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	add_to_group("player")
	start_position = position
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	anim.sprite_frames = SpriteSheet.build([
		{"name": "idle", "path": SAMURAI + "Idle.png", "frames": 6, "fps": 8.0, "loop": true},
		{"name": "run", "path": SAMURAI + "Run.png", "frames": 8, "fps": 13.0, "loop": true},
		{"name": "jump", "path": SAMURAI + "Jump.png", "frames": 12, "fps": 14.0, "loop": false},
		{"name": "attack", "path": SAMURAI + "Attack_1.png", "frames": 6, "fps": 14.0, "loop": false},
		{"name": "hurt", "path": SAMURAI + "Hurt.png", "frames": 2, "fps": 9.0, "loop": false},
	])
	_play("idle")
	orb_label.text = "x0"
	_update_hearts()

func _physics_process(delta: float) -> void:
	# Invincibilité : clignotement.
	if invuln > 0.0:
		invuln -= delta
		anim.modulate.a = 0.35 if int(invuln * 12.0) % 2 == 0 else 1.0
	else:
		anim.modulate.a = 1.0

	# Verrou d'animation (attaque / touché).
	if lock_timer > 0.0:
		lock_timer -= delta
		if lock_timer <= 0.0 and attacking:
			attacking = false
			attack_area.monitoring = false

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

	_update_animation()
	_animate(delta)

## Choisit l'animation selon l'état (sauf pendant un verrou attaque/touché).
func _update_animation() -> void:
	if lock_timer > 0.0:
		return
	if not is_on_floor():
		_play("jump")
	elif absf(velocity.x) > 12.0:
		_play("run")
	else:
		_play("idle")

func _play(n: String) -> void:
	if _cur != n:
		_cur = n
		anim.play(n)

func _animate(delta: float) -> void:
	anim_time += delta
	energy = minf(MAX_ENERGY, energy + ENERGY_REGEN * delta)
	energy_fill.scale.x = energy / MAX_ENERGY
	var pulse := 1.0 + sin(anim_time * 3.0) * 0.04
	for h in hearts:
		h.scale = HEART_BASE_SCALE * pulse

func _set_facing(dir: float) -> void:
	facing = dir
	anim.flip_h = dir < 0.0
	attack_area.position.x = 26.0 * dir

func jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_VELOCITY
		sfx_jump.play()

func attack() -> void:
	if attacking or lock_timer > 0.0:
		return
	attacking = true
	lock_timer = ATTACK_DURATION
	energy = maxf(0.0, energy - ATTACK_COST)
	attack_area.monitoring = true
	sfx_slash.play()
	_play("attack")

func take_damage(amount: int, from_position: Vector2) -> void:
	if invuln > 0.0:
		return
	health -= amount
	_update_hearts()
	sfx_hurt.play()
	if health <= 0:
		respawn()
		return
	invuln = INVULN_TIME
	knockback = KNOCKBACK_TIME
	lock_timer = HURT_LOCK
	_play("hurt")
	var push := signf(global_position.x - from_position.x)
	if push == 0.0:
		push = -facing
	velocity.x = push * KNOCKBACK_SPEED
	velocity.y = -220.0

## Chute dans un trou : coûte un cœur et renvoie au dernier checkpoint
## (les cœurs restants sont conservés ; à zéro, la vie est restaurée).
func fall_damage() -> void:
	health -= 1
	sfx_hurt.play()
	if health <= 0:
		health = MAX_HEALTH
	_update_hearts()
	_return_to_checkpoint()

## Mort (0 cœur suite aux dégâts) : vie pleine et retour au checkpoint.
func respawn() -> void:
	health = MAX_HEALTH
	_update_hearts()
	_return_to_checkpoint()

func _return_to_checkpoint() -> void:
	position = start_position
	velocity = Vector2.ZERO
	invuln = 0.8
	knockback = 0.0
	lock_timer = 0.0
	attacking = false
	attack_area.monitoring = false
	anim.modulate.a = 1.0
	# La téléportation peut être très grande (chute verticale) : sans ça,
	# la caméra met plusieurs secondes à rattraper son lissage et Eneko
	# reste hors-écran pendant ce temps.
	camera.reset_smoothing()

## Déplace le point de réapparition (checkpoint atteint).
func set_checkpoint(pos: Vector2) -> void:
	start_position = pos

## Ramasse un orbe spirituel : recharge l'énergie, et tous les 5 orbes
## Eneko récupère un cœur.
func collect_orb() -> void:
	orbs += 1
	orb_label.text = "x%d" % orbs
	energy = minf(MAX_ENERGY, energy + 15.0)
	sfx_orb.play()
	if orbs % 5 == 0 and health < MAX_HEALTH:
		health += 1
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
