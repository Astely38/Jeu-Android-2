extends CharacterBody2D
## Le Gardien Corrompu, boss final du Sanctuaire. Version massive et
## assombrie du guerrier spectral (Ombre) : 12 points de vie et trois
## phases de plus en plus agressives — marche, puis charges, puis charges
## rapprochées et coups enchaînés. Chaque changement de phase invoque des
## Ombres en renfort (géré par le niveau via le signal phase_changed).

signal defeated
signal health_changed(current: int, max_health: int)
signal phase_changed(new_phase: int)

const GRAVITY := 980.0
const SHINOBI := "res://assets/enemies/shinobi/"
const MAX_HEALTH := 12
## Trois phases : la 2 s'active aux 2/3 de la vie, la 3 au dernier tiers.
## Chaque phase augmente la vitesse de marche et raccourcit le délai entre
## deux charges (la phase 1 ne charge jamais).
const PHASE2_HEALTH := 8
const PHASE3_HEALTH := 4
const PHASE_SPEED := [80.0, 125.0, 155.0]
const PHASE_DASH_CD := [0.0, 2.6, 1.6]
const DASH_SPEED := 380.0
const DASH_DURATION := 0.45
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
var _t := 0.0
## Teinte sombre du sprite (définie dans le .tscn) : les flashs de dégâts
## et de charge doivent revenir vers elle, pas vers le blanc.
var _base_tint := Color(1, 1, 1)

@onready var anim: AnimatedSprite2D = $Anim
@onready var hitbox: Area2D = $Hitbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_die: AudioStreamPlayer = $SfxDie
@onready var sfx_hurt: AudioStreamPlayer = $SfxHurt
@onready var aura: Sprite2D = get_node_or_null("Aura")

func _ready() -> void:
	anim.sprite_frames = SpriteSheet.build([
		{"name": "idle", "path": SHINOBI + "Idle.png", "frames": 6, "fps": 7.0, "loop": true},
		{"name": "run", "path": SHINOBI + "Run.png", "frames": 8, "fps": 11.0, "loop": true},
		{"name": "attack", "path": SHINOBI + "Attack_1.png", "frames": 5, "fps": 13.0, "loop": false},
		{"name": "dead", "path": SHINOBI + "Dead.png", "frames": 4, "fps": 7.0, "loop": false},
	])
	_play("idle")
	_base_tint = anim.modulate
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
	# Aura sombre pulsante, plus intense à chaque phase.
	_t += delta
	if aura != null:
		aura.modulate.a = 0.18 + 0.07 * float(phase) + 0.08 * sin(_t * 3.0)

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
		velocity.x = move_toward(velocity.x, 0.0, PHASE_SPEED[0])
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
	elif phase >= 2 and _dash_cd <= 0.0 and dist > 150.0 and dist < 450.0:
		_dash_cd = PHASE_DASH_CD[phase - 1]
		_dash_timer = DASH_DURATION
		# Télégraphe : le Gardien s'embrase brièvement au départ de la charge.
		anim.modulate = Color(1.6, 0.5, 0.5)
		var t := create_tween()
		t.tween_property(anim, "modulate", _base_tint, 0.35)
		_play("run")
	else:
		var speed: float = PHASE_SPEED[phase - 1]
		velocity.x = dir * speed
		_play("run")

	move_and_slide()
	_clamp_to_arena()

func _clamp_to_arena() -> void:
	position.x = clampf(position.x, arena_min_x, arena_max_x)

func _attack() -> void:
	# En phase 3 le Gardien enchaîne ses coups plus vite.
	_attack_lock = 0.6 if phase < 3 else 0.4
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
	var new_phase := 1
	if health <= PHASE3_HEALTH:
		new_phase = 3
	elif health <= PHASE2_HEALTH:
		new_phase = 2
	if new_phase > phase:
		phase = new_phase
		phase_changed.emit(phase)
	_hurt_timer = 0.3
	sfx_hurt.play()
	anim.modulate = Color(1.8, 1.8, 1.8)
	var tween := create_tween()
	tween.tween_property(anim, "modulate", _base_tint, 0.25)

func _die_for_real() -> void:
	_dying = true
	velocity = Vector2.ZERO
	hitbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	_play("dead")
	sfx_die.play()
	set_physics_process(false)  # fige l'aura et le corps pendant le fondu
	var tween := create_tween()
	tween.tween_property(anim, "modulate:a", 0.0, 1.0)
	if aura != null:
		tween.parallel().tween_property(aura, "modulate:a", 0.0, 1.0)
	tween.finished.connect(func():
		defeated.emit()
		queue_free()
	)
