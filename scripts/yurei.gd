extends CharacterBody2D
## Yurei : esprit errant qui détecte Eneko, le poursuit et l'attaque au
## contact. Plus mobile que l'esprit patrouilleur. Vaincu au sabre, il
## disparaît dans un fondu spirituel.

@export var speed := 92.0
@export var detect_range := 340.0
@export var attack_range := 46.0

const GRAVITY := 980.0
const YUREI := "res://assets/enemies/yurei/"

var player: Node2D = null
var lock_timer := 0.0
var _dying := false
var _cur := ""

@onready var anim: AnimatedSprite2D = $Anim
@onready var hitbox: Area2D = $Hitbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	anim.sprite_frames = SpriteSheet.build([
		{"name": "idle", "path": YUREI + "Idle.png", "frames": 5, "fps": 7.0, "loop": true},
		{"name": "walk", "path": YUREI + "Walk.png", "frames": 5, "fps": 9.0, "loop": true},
		{"name": "attack", "path": YUREI + "Attack_1.png", "frames": 4, "fps": 10.0, "loop": false},
		{"name": "dead", "path": YUREI + "Dead.png", "frames": 4, "fps": 9.0, "loop": false},
	])
	_play("idle")
	hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta: float) -> void:
	if _dying:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	if lock_timer > 0.0:
		lock_timer -= delta

	var moving := false
	if player != null and lock_timer <= 0.0:
		var dx: float = player.global_position.x - global_position.x
		var dist := absf(dx)
		if dist < detect_range:
			var dir := signf(dx)
			if dir != 0.0:
				anim.flip_h = dir < 0.0
			if dist > attack_range:
				velocity.x = dir * speed
				moving = true
			else:
				velocity.x = 0.0
				_attack()
		else:
			velocity.x = move_toward(velocity.x, 0.0, speed)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)

	move_and_slide()

	if lock_timer <= 0.0:
		_play("walk" if moving else "idle")

func _attack() -> void:
	# Petite pause + animation d'attaque ; les dégâts passent par le hitbox.
	lock_timer = 0.5
	_play("attack")

func _play(n: String) -> void:
	if _cur != n:
		_cur = n
		anim.play(n)

func _on_hitbox_body_entered(body: Node2D) -> void:
	if _dying:
		return
	if body.has_method("take_damage"):
		body.take_damage(1, global_position)

## Vaincu au sabre : fondu spirituel puis disparition.
func die() -> void:
	if _dying:
		return
	_dying = true
	velocity = Vector2.ZERO
	hitbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	_play("dead")
	var tween := create_tween()
	tween.tween_property(anim, "modulate:a", 0.0, 0.6)
	tween.finished.connect(queue_free)
