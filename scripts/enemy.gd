extends CharacterBody2D
## Esprit Onre : démon corrompu qui patrouille sa plateforme de gauche à
## droite. Inflige des dégâts au contact ; n'est vaincu qu'au sabre et se
## dissipe alors dans un fondu spirituel.

@export var patrol_distance := 100.0
@export var speed := 74.0

const GRAVITY := 980.0
const ONRE := "res://assets/enemies/onre/"

var start_x := 0.0
var direction := 1.0
var _dying := false
var _cur := ""

@onready var anim: AnimatedSprite2D = $Anim
@onready var hitbox: Area2D = $Hitbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_die: AudioStreamPlayer = $SfxDie

func _ready() -> void:
	start_x = position.x
	anim.sprite_frames = SpriteSheet.build([
		{"name": "walk", "path": ONRE + "Walk.png", "frames": 7, "fps": 9.0, "loop": true},
		{"name": "dead", "path": ONRE + "Dead.png", "frames": 6, "fps": 10.0, "loop": false},
	])
	_play("walk")
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

	anim.flip_h = direction < 0.0

func _play(n: String) -> void:
	if _cur != n:
		_cur = n
		anim.play(n)

func _on_hitbox_body_entered(body: Node2D) -> void:
	if _dying:
		return
	if body.has_method("take_damage"):
		body.take_damage(1, global_position)

## Vaincu par le sabre : animation de mort + fondu, puis disparition.
func die() -> void:
	if _dying:
		return
	_dying = true
	velocity = Vector2.ZERO
	hitbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	_play("dead")
	sfx_die.play()
	# Flash blanc à l'impact, puis fondu spirituel.
	anim.modulate = Color(1.8, 1.8, 1.8, 1.0)
	var tween := create_tween()
	tween.tween_property(anim, "modulate", Color(1, 1, 1, 1), 0.1)
	tween.tween_property(anim, "modulate:a", 0.0, 0.55)
	tween.finished.connect(queue_free)
