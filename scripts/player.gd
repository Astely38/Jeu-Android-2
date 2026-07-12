extends CharacterBody2D
## Eneko, l'apprenti sabreur. Déplacement gauche/droite, saut, attaque au
## sabre (Area2D), barre de vie (cœurs) avec invincibilité temporaire et
## recul. Petites animations procédurales (balancement, éclat de sabre).

const SPEED := 220.0
const JUMP_VELOCITY := -420.0
const GRAVITY := 980.0
const ATTACK_DURATION := 0.2
const MAX_HEALTH := 3
const INVULN_TIME := 1.0
const KNOCKBACK_SPEED := 240.0
const KNOCKBACK_TIME := 0.18
const SPRITE_BASE_Y := -6.0
const MAX_ENERGY := 100.0
const ENERGY_REGEN := 26.0
const ATTACK_COST := 22.0
const HEART_BASE_SCALE := Vector2(1.1, 1.1)

var moving_left := false
var moving_right := false
var attacking := false
var facing := 1.0
var health := MAX_HEALTH
var invuln := 0.0
var knockback := 0.0
var anim_time := 0.0
var energy := MAX_ENERGY
var start_position := Vector2.ZERO

@onready var attack_area: Area2D = $AttackArea
@onready var sprite: Sprite2D = $Sprite
@onready var slash: Polygon2D = $Slash
@onready var energy_fill: Polygon2D = $HUD/EnergyFill
@onready var hearts: Array = [$HUD/Heart1, $HUD/Heart2, $HUD/Heart3]

func _ready() -> void:
	start_position = position
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	slash.visible = false
	_update_hearts()

func _physics_process(delta: float) -> void:
	# Clignotement pendant l'invincibilité.
	if invuln > 0.0:
		invuln -= delta
		sprite.modulate.a = 0.35 if int(invuln * 12.0) % 2 == 0 else 1.0
	else:
		sprite.modulate.a = 1.0

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Déplacement horizontal (ou recul si on vient d'être touché).
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

	_animate(delta)

## Balancement léger + régénération/affichage de l'énergie + pulsation des cœurs.
func _animate(delta: float) -> void:
	anim_time += delta

	# Balancement (idle lent, marche plus vif ; immobile en l'air).
	if is_on_floor():
		var moving := absf(velocity.x) > 10.0
		var freq := 9.0 if moving else 3.0
		var amp := 2.0 if moving else 1.0
		sprite.position.y = SPRITE_BASE_Y + sin(anim_time * freq) * amp
	else:
		sprite.position.y = SPRITE_BASE_Y

	# Énergie du sabre : se régénère avec le temps (purement visuelle pour l'instant).
	energy = minf(MAX_ENERGY, energy + ENERGY_REGEN * delta)
	energy_fill.scale.x = energy / MAX_ENERGY

	# Léger battement des cœurs.
	var pulse := 1.0 + sin(anim_time * 3.0) * 0.04
	for h in hearts:
		h.scale = HEART_BASE_SCALE * pulse

func _set_facing(dir: float) -> void:
	facing = dir
	sprite.flip_h = dir < 0.0
	attack_area.position.x = 26.0 * dir
	slash.scale.x = dir

func jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_VELOCITY

## Attaque au sabre : active la zone de dégâts et l'éclat visuel un court instant.
func attack() -> void:
	if attacking:
		return
	attacking = true
	energy = maxf(0.0, energy - ATTACK_COST)
	attack_area.monitoring = true
	slash.visible = true
	await get_tree().create_timer(ATTACK_DURATION).timeout
	attack_area.monitoring = false
	slash.visible = false
	attacking = false

## Reçoit des dégâts (contact d'un esprit). Ignoré pendant l'invincibilité.
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

## Retour au point de départ avec vie pleine (chute ou 0 cœur).
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
