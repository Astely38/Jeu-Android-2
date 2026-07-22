extends CharacterBody2D
## Karasu-tengu : corbeau-démon qui PATROUILLE en vol au-dessus d'Eneko. Quand
## le héros passe à sa portée, il se CABRE un instant (télégraphe) puis PLONGE
## en piqué vers la position visée, avant de REMONTER à son altitude de vol.
## Menace verticale, inédite : on l'esquive d'un pas de côté ou d'une ruée
## pendant le cabrage, et on le tranche à tout moment (un coup).
##
## Spectral comme les autres yokai : il traverse le décor (collision_mask = 0)
## et vit sur la couche 2 (tranchable au sabre) avec une hitbox qui blesse au
## contact — surtout redoutable pendant le piqué.

@export var speed := 92.0             # vitesse de patrouille en vol
@export var patrol_distance := 230.0
@export var detect_x := 250.0         # portée horizontale de déclenchement du piqué

const DIVE_SPEED := 430.0
const TELEGRAPH_TIME := 0.8
const DIVE_TIME := 0.7
const RECOVER_SPEED := 165.0
const COOLDOWN := 1.5
const DIVE_MAX_DROP := 320.0          # profondeur maximale du piqué avant remontée

const KARASU := "res://assets/enemies/karasu/"
## Halo spectral discret derrière le corbeau : le détache des fonds sombres
## des chapitres où il rôde, sans avoir à repeindre le sprite lui-même.
const AURA := Color(0.7, 0.42, 0.98)

enum { PATROL, TELEGRAPH, DIVE, RECOVER }

var player: Node2D = null
var _dying := false
var _t := 0.0
var _state := PATROL
var _dir := 1.0                       # sens de patrouille / regard horizontal
var _start_x := 0.0
var _fly_y := 0.0
var _state_t := 0.0
var _cd := 0.0
var _dive_vec := Vector2.ZERO
var _cur := ""

@onready var anim: AnimatedSprite2D = $Anim
@onready var hitbox: Area2D = $Hitbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_die: AudioStreamPlayer = $SfxDie

func _ready() -> void:
	collision_mask = 0  # vole et traverse le décor (spectral)
	_start_x = position.x
	_fly_y = position.y
	if Challenge.kensei:
		speed *= 1.2
	# Escalade de vitesse selon le chapitre (différée : le niveau fixe le
	# facteur après avoir posé ses ennemis, voir Challenge.start_level).
	_apply_chapter_speed.call_deferred()
	z_index = 6
	_build_glow()
	# Walk/Run sont ré-empaquetées en cellules 128px (comme Idle/Attack/Dead) :
	# des cellules plus étroites feraient « sauter » la largeur du sprite à
	# chaque changement d'animation (AnimatedSprite2D centre chaque frame sur
	# son origine).
	anim.sprite_frames = SpriteSheet.build([
		{"name": "idle", "path": KARASU + "Idle.png", "frames": 4, "fps": 6.0, "loop": true,
			"frame_w": 128, "frame_h": 128, "cols": 2},
		{"name": "walk", "path": KARASU + "Walk.png", "frames": 9, "fps": 10.0, "loop": true,
			"frame_w": 128, "frame_h": 128, "cols": 8},
		{"name": "run", "path": KARASU + "Run.png", "frames": 9, "fps": 15.0, "loop": true,
			"frame_w": 128, "frame_h": 128, "cols": 8},
		{"name": "attack", "path": KARASU + "Attack_1.png", "frames": 10, "fps": 15.0, "loop": true,
			"frame_w": 128, "frame_h": 128, "cols": 4},
		{"name": "dead", "path": KARASU + "Dead.png", "frames": 10, "fps": 13.0, "loop": false,
			"frame_w": 128, "frame_h": 128, "cols": 4},
	])
	anim.scale = Vector2(0.85, 0.85)
	_play("walk")
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_ignore_player_body()
	# Ombre au sol : trahit la position du corbeau et aide à anticiper le piqué.
	var sh := ContactShadow.new()
	sh.width = 36.0
	sh.max_drop = 700.0
	add_child(sh)
	move_child(sh, 0)

func _apply_chapter_speed() -> void:
	speed *= Challenge.speed_scale

func _ignore_player_body() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl is PhysicsBody2D:
		add_collision_exception_with(pl)

func _build_glow() -> void:
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(AURA.r, AURA.g, AURA.b, 0.6)
	glow.scale = Vector2(2.4, 1.7)
	glow.z_index = -1
	add_child(glow)
	Atmosphere.breathe(glow, 0.25, 2.0)

func _physics_process(delta: float) -> void:
	if _dying:
		return
	_t += delta
	_state_t += delta
	_cd = maxf(0.0, _cd - delta)
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	match _state:
		PATROL:
			velocity.x = _dir * speed
			if absf(position.x - _start_x) >= patrol_distance:
				_dir = -signf(position.x - _start_x)
			# Retour souple à l'altitude de vol + léger flottement.
			var target_y := _fly_y + sin(_t * 2.4) * 5.0
			velocity.y = (target_y - position.y) * 3.0
			move_and_slide()
			_play("walk")
			_try_trigger()
		TELEGRAPH:
			velocity = velocity.lerp(Vector2.ZERO, 0.25)
			move_and_slide()
			_play("idle")
			if _state_t >= TELEGRAPH_TIME:
				_begin_dive()
		DIVE:
			velocity = _dive_vec
			move_and_slide()
			_play("attack")
			var reached: bool = player != null and is_instance_valid(player) \
				and global_position.distance_to(player.global_position) < 24.0
			if _state_t >= DIVE_TIME or reached or position.y > _fly_y + DIVE_MAX_DROP:
				_enter(RECOVER)
		RECOVER:
			if player != null and is_instance_valid(player):
				_dir = signf(player.global_position.x - position.x)
				if _dir == 0.0:
					_dir = 1.0
			velocity = Vector2(_dir * speed * 0.4, -RECOVER_SPEED)
			move_and_slide()
			_play("run")
			if position.y <= _fly_y + 6.0:
				position.y = _fly_y
				_cd = COOLDOWN
				_enter(PATROL)

	anim.flip_h = _dir < 0.0

## Déclenche l'attaque si Eneko est à portée horizontale ET plus bas (on plonge
## toujours vers le sol), hors temps de recharge.
func _try_trigger() -> void:
	if _cd > 0.0 or player == null or not is_instance_valid(player):
		return
	var dx: float = player.global_position.x - global_position.x
	var dy: float = player.global_position.y - global_position.y
	if absf(dx) < detect_x and dy > 30.0:
		if dx != 0.0:
			_dir = signf(dx)
		_enter(TELEGRAPH)

func _begin_dive() -> void:
	var target := global_position + Vector2(_dir * 130.0, 210.0)
	if player != null and is_instance_valid(player):
		target = player.global_position
	_dive_vec = (target - global_position).normalized() * DIVE_SPEED
	if _dive_vec.x != 0.0:
		_dir = signf(_dive_vec.x)
	_enter(DIVE)

func _enter(s: int) -> void:
	_state = s
	_state_t = 0.0

func _play(n: String) -> void:
	if _cur != n:
		_cur = n
		anim.play(n)

func _on_hitbox_body_entered(body: Node2D) -> void:
	if _dying:
		return
	if body.has_method("take_damage"):
		body.take_damage(1, global_position)

## Tranché : le corbeau se disloque dans une bouffée de plumes et se dissout.
## Renvoie toujours true (meurt en un coup).
func die() -> bool:
	if _dying:
		return false
	_dying = true
	hitbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	Sfx.varied(sfx_die, 0.95, 1.15)
	var parent := get_parent()
	if parent != null:
		Atmosphere.spark_burst(parent, global_position, Color(0.35, 0.28, 0.42))
		Atmosphere.death_burst(parent, global_position, Color(0.85, 0.76, 1.0))
	velocity = Vector2.ZERO
	_play("dead")
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.set_parallel(true)
	tw.tween_property(anim, "modulate:a", 0.0, 0.35)
	tw.tween_property(anim, "position:y", anim.position.y + 44.0, 0.35)
	tw.chain().tween_callback(queue_free)
	return true
