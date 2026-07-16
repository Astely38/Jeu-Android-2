extends CharacterBody2D
## Ombre scindante : une ombre corrompue qui, tranchée, se DÉDOUBLE en deux
## ombrelettes plus petites et plus vives. Les ombrelettes, elles, meurent en
## un coup sans se rescinder. Un ennemi de « gestion de foule » : mieux vaut
## l'affronter avec de l'espace, ou enchaîner vite les deux moitiés.

@export var speed := 96.0
@export var detect_range := 380.0
@export var attack_range := 44.0
## Ombrelette issue d'un dédoublement : plus petite/rapide, ne se rescinde pas.
@export var small := false
## Élan horizontal initial (donné aux ombrelettes pour qu'elles s'écartent).
@export var spawn_vx := 0.0

const GRAVITY := 980.0
const SHINOBI := "res://assets/enemies/shinobi/"
const SELF_SCENE := preload("res://scenes/split_shade.tscn")

var player: Node2D = null
var lock_timer := 0.0
var _dying := false
var _cur := ""

@onready var anim: AnimatedSprite2D = $Anim
@onready var hitbox: Area2D = $Hitbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_die: AudioStreamPlayer = $SfxDie

func _ready() -> void:
	if Challenge.kensei:
		speed *= 1.25
	anim.sprite_frames = SpriteSheet.build([
		{"name": "idle", "path": SHINOBI + "Idle.png", "frames": 6, "fps": 8.0, "loop": true},
		{"name": "run", "path": SHINOBI + "Run.png", "frames": 8, "fps": 12.0, "loop": true},
		{"name": "attack", "path": SHINOBI + "Attack_1.png", "frames": 5, "fps": 11.0, "loop": false},
		{"name": "dead", "path": SHINOBI + "Dead.png", "frames": 4, "fps": 9.0, "loop": false},
	])
	_play("idle")
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_ignore_player_body()
	var shadow_w := 18.0 if small else 28.0
	var sh := ContactShadow.new()
	sh.width = shadow_w
	add_child(sh)
	move_child(sh, 0)
	if small:
		# Ombrelette : plus petite, plus rapide, teinte plus pâle.
		anim.scale *= 0.62
		anim.position.y += 8.0
		speed *= 1.45
		detect_range += 80.0
		anim.modulate = Color(0.5, 0.82, 0.72)
		velocity.x = spawn_vx
	else:
		anim.modulate = Color(0.36, 0.72, 0.6)

func _ignore_player_body() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl is PhysicsBody2D:
		add_collision_exception_with(pl)

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

## Tranchée au sabre : dissipation spirituelle. Si c'est une grande Ombre
## (pas une ombrelette), elle se DÉDOUBLE d'abord en deux moitiés qui
## s'écartent. Renvoie toujours true (un seul coup suffit à la trancher).
func die() -> bool:
	if _dying:
		return false
	_dying = true
	if not small:
		_split()
	Atmosphere.release_soul(get_parent(), global_position + Vector2(0, -22), Color(0.6, 0.95, 0.8))
	velocity = Vector2.ZERO
	hitbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	_play("dead")
	Sfx.varied(sfx_die, 1.0, 1.2)
	var tint := anim.modulate
	anim.modulate = Color(1.8, 1.8, 1.8, 1.0)
	var tween := create_tween()
	tween.tween_property(anim, "modulate", tint, 0.1)
	tween.tween_property(anim, "modulate:a", 0.0, 0.4)
	tween.finished.connect(queue_free)
	return true

## Fait naître deux ombrelettes qui jaillissent de part et d'autre.
func _split() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for s in [-1.0, 1.0]:
		var child := SELF_SCENE.instantiate()
		child.small = true
		child.spawn_vx = s * 110.0
		child.position = global_position + Vector2(s * 12.0, -6.0)
		parent.call_deferred("add_child", child)
