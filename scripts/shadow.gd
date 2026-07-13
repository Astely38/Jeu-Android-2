extends CharacterBody2D
## Ombre corrompue : un guerrier spectral qui détecte Eneko, le poursuit
## et frappe au contact. Silhouette sombre (sprite shinobi teinté).
## Vaincue au sabre, elle se dissipe dans un fondu spirituel.

@export var speed := 104.0
@export var detect_range := 380.0
@export var attack_range := 46.0

const GRAVITY := 980.0
const SHINOBI := "res://assets/enemies/shinobi/"

var player: Node2D = null
var lock_timer := 0.0
var _dying := false
var _cur := ""

@onready var anim: AnimatedSprite2D = $Anim
@onready var hitbox: Area2D = $Hitbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_die: AudioStreamPlayer = $SfxDie

func _ready() -> void:
	anim.sprite_frames = SpriteSheet.build([
		{"name": "idle", "path": SHINOBI + "Idle.png", "frames": 6, "fps": 8.0, "loop": true},
		{"name": "run", "path": SHINOBI + "Run.png", "frames": 8, "fps": 12.0, "loop": true},
		{"name": "attack", "path": SHINOBI + "Attack_1.png", "frames": 5, "fps": 11.0, "loop": false},
		{"name": "dead", "path": SHINOBI + "Dead.png", "frames": 4, "fps": 9.0, "loop": false},
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
		var dy: float = player.global_position.y - global_position.y
		var dist := absf(dx)
		# Ignore le joueur s'il est sur une plateforme trop différente en
		# hauteur (sinon l'Ombre "sent" Eneko à travers plusieurs étages
		# et tombe dans le vide en essayant de le rejoindre).
		if dist < detect_range and absf(dy) < 90.0:
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
		_play("run" if moving else "idle")

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

## Vaincue au sabre : animation de mort + fondu spirituel puis disparition.
func die() -> void:
	if _dying:
		return
	_dying = true
	velocity = Vector2.ZERO
	hitbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	_play("dead")
	sfx_die.play()
	# Flash blanc à l'impact, puis fondu spirituel (la teinte violette de
	# l'Ombre revient pendant le fondu).
	var tint := anim.modulate
	anim.modulate = Color(1.8, 1.8, 1.8, 1.0)
	var tween := create_tween()
	tween.tween_property(anim, "modulate", tint, 0.1)
	tween.tween_property(anim, "modulate:a", 0.0, 0.5)
	tween.finished.connect(queue_free)
