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

## Palette pensée pour RESSORTIR sur les fonds sombres du Chapitre II :
## plumes violet-ardoise (pas noires), liseré spectral lumineux et halo.
const FEATHER := Color(0.26, 0.2, 0.36)       # plumes violet-ardoise
const FEATHER_HI := Color(0.48, 0.36, 0.64)   # reflet violet clair (dos, tête)
const BELLY := Color(0.66, 0.56, 0.82)        # poitrail clair (contraste)
const EDGE := Color(0.85, 0.76, 1.0)          # liseré spectral qui détache la silhouette
const BEAK := Color(1.0, 0.62, 0.2)           # bec orange vif
const EYE := Color(1.0, 0.34, 0.26)           # œil rouge braise
const AURA := Color(0.7, 0.42, 0.98)          # halo violet

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
var _wing_l: Node2D
var _wing_r: Node2D

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

	# Halo spectral marqué : signale le corbeau même dans les zones sombres.
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(AURA.r, AURA.g, AURA.b, 0.42)
	glow.scale = Vector2(2.2, 1.5)
	_gfx.add_child(glow)

	# Queue en éventail (tout au fond).
	_shape(_gfx, PackedVector2Array([
		Vector2(-8, -5), Vector2(-22, -11), Vector2(-19, 0), Vector2(-22, 11), Vector2(-8, 5),
	]), FEATHER)

	# Aile arrière (plus haute, plus sombre) : bat autour de l'épaule.
	_wing_l = _make_wing(Vector2(-2, -4), FEATHER)
	_gfx.add_child(_wing_l)

	# Corps profilé (pointe vers la droite au repos ; flip par scale.x).
	_shape(_gfx, PackedVector2Array([
		Vector2(-9, -7), Vector2(4, -9), Vector2(17, -2), Vector2(4, 9), Vector2(-9, 7),
	]), FEATHER_HI)
	# Poitrail clair pour contraster.
	var belly := Polygon2D.new()
	belly.polygon = PackedVector2Array([
		Vector2(-2, 0), Vector2(13, -1), Vector2(15, -2), Vector2(6, 9), Vector2(-6, 7),
	])
	belly.color = BELLY
	_gfx.add_child(belly)

	# Crête de plumes sur la tête (silhouette de tengu).
	for cp in [Vector2(2, -9), Vector2(-2, -11), Vector2(-5, -10)]:
		_shape(_gfx, PackedVector2Array([
			Vector2(cp.x, cp.y), Vector2(cp.x - 5, cp.y - 6), Vector2(cp.x + 2, cp.y - 1),
		]), FEATHER_HI)

	# Bec orange vif, proéminent.
	_shape(_gfx, PackedVector2Array([
		Vector2(13, -4), Vector2(27, 0), Vector2(13, 3),
	]), BEAK)

	# Œil rouge braise + halo.
	var eye_halo := Polygon2D.new()
	var hp := PackedVector2Array()
	for i in 10:
		var a := i * TAU / 10.0
		hp.append(Vector2(cos(a) * 4.4, sin(a) * 4.4))
	eye_halo.polygon = hp
	eye_halo.position = Vector2(8, -3)
	eye_halo.color = Color(EYE.r, EYE.g, EYE.b, 0.35)
	_gfx.add_child(eye_halo)
	var eye := Polygon2D.new()
	var ep := PackedVector2Array()
	for i in 8:
		var a := i * TAU / 8.0
		ep.append(Vector2(cos(a) * 2.5, sin(a) * 2.5))
	eye.polygon = ep
	eye.position = Vector2(8, -3)
	eye.color = EYE
	_gfx.add_child(eye)

	# Aile avant (plus claire, devant le corps) : bat en opposition.
	_wing_r = _make_wing(Vector2(2, -1), FEATHER_HI)
	_gfx.add_child(_wing_r)

## Construit une aile sur un pivot d'épaule : membrane dentelée cernée du
## liseré lumineux, avec quelques plumes primaires en bout.
func _make_wing(pivot: Vector2, fill: Color) -> Node2D:
	var w := Node2D.new()
	w.position = pivot
	_shape(w, PackedVector2Array([
		Vector2(0, 0), Vector2(-10, -12), Vector2(-26, -14), Vector2(-34, -4),
		Vector2(-24, 2), Vector2(-6, 6),
	]), fill)
	for tx in [-33.0, -26.0, -19.0]:
		_shape(w, PackedVector2Array([
			Vector2(tx, -4), Vector2(tx - 5, 3), Vector2(tx + 3, 3),
		]), fill)
	return w

## Polygone plein cerné d'un liseré spectral (Line2D). C'est ce contour clair
## qui détache le corbeau des décors sombres du Chapitre II.
func _shape(parent: Node, pts: PackedVector2Array, fill: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = fill
	parent.add_child(p)
	var l := Line2D.new()
	l.points = pts
	l.closed = true
	l.width = 1.8
	l.default_color = EDGE
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	parent.add_child(l)

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
