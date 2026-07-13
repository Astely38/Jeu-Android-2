extends CharacterBody2D
## Le Gardien Corrompu, boss final du Sanctuaire. Version massive et
## assombrie du guerrier spectral (Ombre) : plusieurs points de vie, une
## seconde phase plus agressive à mi-vie (charge + invocation d'Ombres),
## et une attaque de contact classique.

signal defeated
signal health_changed(current: int, max_health: int)
signal phase_changed(new_phase: int)

const GRAVITY := 980.0
const SHINOBI := "res://assets/enemies/shinobi/"
const MAX_HEALTH := 8
const SPEED_PHASE1 := 70.0
const SPEED_PHASE2 := 108.0
const DASH_SPEED := 340.0
const DASH_DURATION := 0.45
const DASH_COOLDOWN := 3.2
const ATTACK_RANGE := 60.0

var health := MAX_HEALTH
var phase := 1
var player: Node2D = null
var active := false  # devient vrai quand le combat démarre (activate())
var arena_min_x := -INF
var arena_max_x := INF

var _dying := false
var _hurt_timer := 0.0
var _attack_lock := 0.0
var _dash_timer := 0.0
var _dash_cd := 2.0
var _cur := ""

@onready var anim: AnimatedSprite2D = $Anim
@onready var hitbox: Area2D = $Hitbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_die: AudioStreamPlayer = $SfxDie
@onready var sfx_hurt: AudioStreamPlayer = $SfxHurt

func _ready() -> void:
	anim.sprite_frames = SpriteSheet.build([
		{"name": "idle", "path": SHINOBI + "Idle.png", "frames": 6, "fps": 7.0, "loop": true},
		{"name": "run", "path": SHINOBI + "Run.png", "frames": 8, "fps": 11.0, "loop": true},
		{"name": "attack", "path": SHINOBI + "Attack_1.png", "frames": 5, "fps": 13.0, "loop": false},
		{"name": "dead", "path": SHINOBI + "Dead.png", "frames": 4, "fps": 7.0, "loop": false},
	])
	_play("idle")
	hitbox.body_entered.connect(_on_hitbox_body_entered)

## Limite les déplacements du boss à l'arène (évite qu'une charge ne le
## fasse sortir du décor construit par le niveau).
func set_arena_bounds(min_x: float, max_x: float) -> void:
	arena_min_x = min_x
	arena_max_x = max_x

## Réveille le boss : c'est le niveau qui appelle ça une fois le dialogue
## d'introduction terminé.
func activate() -> void:
	active = true

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	if _dying or not active:
		velocity.x = 0.0
		move_and_slide()
		return

	if player == null:
		player = get_tree().get_first_node_in_group("player")

	if _hurt_timer > 0.0:
		_hurt_timer -= delta
		velocity.x = 0.0
		move_and_slide()
		return

	if _attack_lock > 0.0:
		_attack_lock -= delta
		velocity.x = 0.0
		move_and_slide()
		if _attack_lock <= 0.0:
			_play("idle")
		return

	_dash_cd -= delta

	if player == null or not is_instance_valid(player):
		velocity.x = move_toward(velocity.x, 0.0, SPEED_PHASE1)
		move_and_slide()
		return

	var dx: float = player.global_position.x - global_position.x
	var dist := absf(dx)
	var dir := signf(dx) if dx != 0.0 else 1.0
	anim.flip_h = dir < 0.0

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity.x = dir * DASH_SPEED
		move_and_slide()
		_clamp_to_arena()
		if _dash_timer <= 0.0:
			_play("idle")
		return

	if dist <= ATTACK_RANGE:
		velocity.x = 0.0
		_attack()
	elif phase == 2 and _dash_cd <= 0.0 and dist > 160.0 and dist < 420.0:
		_dash_cd = DASH_COOLDOWN
		_dash_timer = DASH_DURATION
		_play("run")
	else:
		var speed := SPEED_PHASE2 if phase == 2 else SPEED_PHASE1
		velocity.x = dir * speed
		_play("run")

	move_and_slide()
	_clamp_to_arena()

func _clamp_to_arena() -> void:
	position.x = clampf(position.x, arena_min_x, arena_max_x)

func _attack() -> void:
	_attack_lock = 0.6
	_play("attack")

func _play(n: String) -> void:
	if _cur != n:
		_cur = n
		anim.play(n)

func _on_hitbox_body_entered(body: Node2D) -> void:
	if _dying or not active:
		return
	if body.has_method("take_damage"):
		body.take_damage(1, global_position)

## Appelé par l'attaque au sabre du joueur : contrairement aux ennemis
## normaux, le boss encaisse un coup plutôt que de mourir instantanément.
func die() -> void:
	if _dying or not active:
		return
	health -= 1
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0:
		_die_for_real()
		return
	if phase == 1 and health <= MAX_HEALTH / 2:
		phase = 2
		phase_changed.emit(phase)
	_hurt_timer = 0.3
	sfx_hurt.play()
	anim.modulate = Color(1.5, 0.6, 0.6)
	var tween := create_tween()
	tween.tween_property(anim, "modulate", Color(1, 1, 1), 0.25)

func _die_for_real() -> void:
	_dying = true
	velocity = Vector2.ZERO
	hitbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	_play("dead")
	sfx_die.play()
	var tween := create_tween()
	tween.tween_property(anim, "modulate:a", 0.0, 1.0)
	tween.finished.connect(func():
		defeated.emit()
		queue_free()
	)
