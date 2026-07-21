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
const TELEGRAPH_TIME := 0.5
const DIVE_TIME := 0.7
const RECOVER_SPEED := 165.0
const COOLDOWN := 1.5
const DIVE_MAX_DROP := 320.0          # profondeur maximale du piqué avant remontée

const FEATHER := Color(0.12, 0.1, 0.16)
const FEATHER_HI := Color(0.26, 0.22, 0.33)
const BEAK := Color(0.95, 0.78, 0.25)
const EYE := Color(1.0, 0.28, 0.22)

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
var _flap := 1.0                      # amplitude du battement d'ailes selon l'état

var _gfx: Node2D
var _wing_l: Polygon2D
var _wing_r: Polygon2D

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
	_build_visual()
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_ignore_player_body()
	# Ombre au sol : trahit la position du corbeau et aide à anticiper le piqué.
	var sh := ContactShadow.new()
	sh.width = 30.0
	sh.max_drop = 700.0
	add_child(sh)
	move_child(sh, 0)

func _apply_chapter_speed() -> void:
	speed *= Challenge.speed_scale

func _ignore_player_body() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl is PhysicsBody2D:
		add_collision_exception_with(pl)

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
			_flap = 1.0
			velocity.x = _dir * speed
			if absf(position.x - _start_x) >= patrol_distance:
				_dir = -signf(position.x - _start_x)
			# Retour souple à l'altitude de vol + léger flottement.
			var target_y := _fly_y + sin(_t * 2.4) * 5.0
			velocity.y = (target_y - position.y) * 3.0
			move_and_slide()
			_try_trigger()
		TELEGRAPH:
			_flap = 0.25
			velocity = velocity.lerp(Vector2.ZERO, 0.25)
			move_and_slide()
			if _state_t >= TELEGRAPH_TIME:
				_begin_dive()
		DIVE:
			_flap = 0.0
			velocity = _dive_vec
			move_and_slide()
			var reached: bool = player != null and is_instance_valid(player) \
				and global_position.distance_to(player.global_position) < 24.0
			if _state_t >= DIVE_TIME or reached or position.y > _fly_y + DIVE_MAX_DROP:
				_enter(RECOVER)
		RECOVER:
			_flap = 0.7
			if player != null and is_instance_valid(player):
				_dir = signf(player.global_position.x - position.x)
				if _dir == 0.0:
					_dir = 1.0
			velocity = Vector2(_dir * speed * 0.4, -RECOVER_SPEED)
			move_and_slide()
			if position.y <= _fly_y + 6.0:
				position.y = _fly_y
				_cd = COOLDOWN
				_enter(PATROL)

	_animate()

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
	if _gfx != null:
		var tw := _gfx.create_tween()
		tw.set_parallel(true)
		tw.tween_property(_gfx, "modulate:a", 0.0, 0.35)
		tw.tween_property(_gfx, "position:y", 44.0, 0.35)
		tw.tween_property(_gfx, "rotation", _dir * 2.0, 0.35)
		tw.chain().tween_callback(queue_free)
	else:
		queue_free()
	return true

# --- Visuel ---------------------------------------------------------------

func _build_visual() -> void:
	_gfx = Node2D.new()
	add_child(_gfx)

	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(0.5, 0.22, 0.5, 0.26)
	glow.scale = Vector2(1.7, 1.1)
	_gfx.add_child(glow)

	# Ailes (derrière le corps) : elles battent en tournant autour de l'épaule.
	_wing_l = Polygon2D.new()
	_wing_l.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(-28, -10), Vector2(-32, 4), Vector2(-6, 8),
	])
	_wing_l.color = FEATHER
	_wing_l.position = Vector2(-3, -2)
	_gfx.add_child(_wing_l)

	_wing_r = Polygon2D.new()
	_wing_r.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(28, -10), Vector2(32, 4), Vector2(6, 8),
	])
	_wing_r.color = FEATHER
	_wing_r.position = Vector2(3, -2)
	_gfx.add_child(_wing_r)

	# Corps profilé (pointe vers la droite au repos ; flip par scale.x).
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-9, -6), Vector2(5, -8), Vector2(16, -2), Vector2(5, 8), Vector2(-9, 6),
	])
	body.color = FEATHER_HI
	_gfx.add_child(body)

	# Queue en éventail.
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([
		Vector2(-9, -5), Vector2(-20, -9), Vector2(-18, 0), Vector2(-20, 9), Vector2(-9, 5),
	])
	tail.color = FEATHER
	_gfx.add_child(tail)

	# Bec.
	var beak := Polygon2D.new()
	beak.polygon = PackedVector2Array([Vector2(14, -3), Vector2(25, 0), Vector2(14, 3)])
	beak.color = BEAK
	_gfx.add_child(beak)

	# Œil luisant.
	var eye := Polygon2D.new()
	var ep := PackedVector2Array()
	for i in 8:
		var a := i * TAU / 8.0
		ep.append(Vector2(cos(a) * 2.4, sin(a) * 2.4))
	eye.polygon = ep
	eye.position = Vector2(8, -3)
	eye.color = EYE
	_gfx.add_child(eye)

func _animate() -> void:
	if _gfx == null:
		return
	_gfx.scale.x = _dir if _dir != 0.0 else 1.0
	# Battement d'ailes (rapide en vol, figé en piqué).
	var beat := sin(_t * 22.0) * _flap
	if _wing_l != null:
		_wing_l.rotation = -0.45 - beat * 0.8
	if _wing_r != null:
		_wing_r.rotation = 0.45 + beat * 0.8
	# Tangage du corps : se cabre au télégraphe, pique en plongée.
	var want_rot := 0.0
	if _state == TELEGRAPH:
		want_rot = -0.35
	elif _state == DIVE:
		want_rot = 0.55
	_gfx.rotation = lerpf(_gfx.rotation, want_rot, 0.25)
