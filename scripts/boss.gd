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
const MAX_HEALTH := 14
## Trois phases : la 2 s'active aux 2/3 de la vie, la 3 au dernier tiers.
## Chaque phase augmente la vitesse de marche et raccourcit le délai entre
## deux charges (la phase 1 ne charge jamais) et entre deux écrasements.
const PHASE2_HEALTH := 10
const PHASE3_HEALTH := 5
const PHASE_SPEED := [85.0, 130.0, 160.0]
const PHASE_DASH_CD := [0.0, 2.6, 1.6]
const PHASE_SLAM_CD := [4.5, 3.8, 3.0]

## Multiplicateur Kensei : accélère le Gardien et raccourcit ses répits.
var _kmult := 1.0
const DASH_SPEED := 380.0
const DASH_DURATION := 0.45
const ATTACK_RANGE := 60.0
const SLAM_JUMP_VY := -640.0
const WAVE_SPEED := 300.0
const VOLLEY_ORB := preload("res://scenes/spirit_orb.tscn")

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
## Saut-écrasement : première action ~1 s après l'activation, c'est le
## bond d'entrée en scène du Gardien vers Eneko.
var _slam_cd := 1.2
var _slam_air := false
var _waves: Array = []
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

var _sfx_slam: AudioStreamPlayer
var _aura_base_scale := Vector2.ONE

func _ready() -> void:
	if Challenge.kensei:
		_kmult = 1.2
	anim.sprite_frames = SpriteSheet.build([
		{"name": "idle", "path": SHINOBI + "Idle.png", "frames": 6, "fps": 7.0, "loop": true},
		{"name": "run", "path": SHINOBI + "Run.png", "frames": 8, "fps": 11.0, "loop": true},
		{"name": "attack", "path": SHINOBI + "Attack_1.png", "frames": 5, "fps": 13.0, "loop": false},
		{"name": "dead", "path": SHINOBI + "Dead.png", "frames": 4, "fps": 7.0, "loop": false},
	])
	_play("idle")
	_base_tint = anim.modulate
	if aura != null:
		_aura_base_scale = aura.scale
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_ignore_player_body()
	_sfx_slam = AudioStreamPlayer.new()
	_sfx_slam.stream = load("res://assets/sfx/slam.wav")
	_sfx_slam.volume_db = -3.0
	add_child(_sfx_slam)
	var sh := ContactShadow.new()
	sh.width = 52.0
	add_child(sh)
	move_child(sh, 0)

## Le corps d'Eneko n'est jamais un obstacle physique pour le Gardien :
## sans cette exception, la dépénétration du boss « collait » Eneko
## pendant la ruée et la traversée était impossible (constaté en jeu).
func _ignore_player_body() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl is PhysicsBody2D:
		add_collision_exception_with(pl)

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
	# Aura pulsante : elle vire du violet sombre au rouge de rage et enfle
	# à chaque phase — signal visuel clair de la fureur croissante du Gardien.
	_t += delta
	if aura != null:
		var rage := (float(phase) - 1.0) / 2.0  # 0 → 1 de la phase 1 à 3
		var a := 0.18 + 0.08 * float(phase) + 0.08 * sin(_t * 3.0)
		aura.modulate = Color(0.55 + 0.45 * rage, 0.25 + 0.08 * rage, 0.55 - 0.4 * rage, a)
		var sc := 1.0 + 0.05 * float(phase) + 0.06 * rage * sin(_t * (3.5 + float(phase)))
		aura.scale = _aura_base_scale * sc

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	if _dying or not active:
		velocity.x = 0.0
		move_and_slide()
		return

	_advance_waves(delta)

	if player == null:
		player = get_tree().get_first_node_in_group("player")

	# Saut-écrasement en cours : trajectoire balistique jusqu'à l'impact.
	if _slam_air:
		move_and_slide()
		_clamp_to_arena()
		if is_on_floor() and velocity.y >= 0.0:
			_slam_air = false
			_on_slam_impact()
		return

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
	_slam_cd -= delta

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

	if _slam_cd <= 0.0 and is_on_floor() and dist > 90.0:
		_start_slam(dx)
		return

	if dist <= ATTACK_RANGE:
		velocity.x = 0.0
		_attack()
	elif phase >= 2 and _dash_cd <= 0.0 and dist > 150.0 and dist < 450.0:
		_dash_cd = PHASE_DASH_CD[phase - 1] / _kmult
		_dash_timer = DASH_DURATION
		# Télégraphe : le Gardien s'embrase brièvement au départ de la charge.
		anim.modulate = Color(1.6, 0.5, 0.5)
		var t := create_tween()
		t.tween_property(anim, "modulate", _base_tint, 0.35)
		_play("run")
	else:
		var speed: float = PHASE_SPEED[phase - 1] * _kmult
		velocity.x = dir * speed
		_play("run")

	move_and_slide()
	_clamp_to_arena()

func _clamp_to_arena() -> void:
	position.x = clampf(position.x, arena_min_x, arena_max_x)

## Saut-écrasement : le Gardien bondit en cloche vers Eneko et s'écrase
## au sol, libérant deux ondes de choc rasantes qu'il faut sauter.
func _start_slam(dx: float) -> void:
	_slam_cd = PHASE_SLAM_CD[phase - 1] / _kmult
	_slam_air = true
	var reach := clampf(dx, -420.0, 420.0)
	velocity = Vector2(reach / 1.3, SLAM_JUMP_VY)
	anim.modulate = Color(1.6, 0.5, 0.5)
	var t := create_tween()
	t.tween_property(anim, "modulate", _base_tint, 0.4)
	_play("run")

func _on_slam_impact() -> void:
	_attack_lock = 0.55 if phase < 3 else 0.4
	_play("idle")
	_sfx_slam.play()
	SaveManager.vibrate(60)
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null:
		pl.set("_shake", 9.0)
	_spawn_wave(-1.0)
	_spawn_wave(1.0)
	if phase >= 3:
		_fire_volley()

## Onde de choc rasante : une flamme sombre qui court sur le sol.
func _spawn_wave(dir: float) -> void:
	var w := Area2D.new()
	w.position = position + Vector2(dir * 54.0, 0)
	var sh := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 34)
	sh.shape = rect
	sh.position = Vector2(0, -17)
	w.add_child(sh)
	var flame := Polygon2D.new()
	flame.polygon = PackedVector2Array([
		Vector2(-14, 0), Vector2(14, 0), Vector2(9, -16), Vector2(0, -34), Vector2(-9, -16),
	])
	flame.color = Color(0.85, 0.25, 0.2, 0.9)
	w.add_child(flame)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(-6, 0), Vector2(6, 0), Vector2(0, -20),
	])
	core.color = Color(1.0, 0.6, 0.25, 0.95)
	w.add_child(core)
	w.set_meta("dir", dir)
	w.body_entered.connect(func(b: Node2D):
		if b.is_in_group("player") and b.has_method("take_damage"):
			b.take_damage(1, w.global_position)
	)
	get_parent().add_child(w)
	_waves.append(w)

## Fait courir les ondes de choc et les éteint aux bords de l'arène.
func _advance_waves(delta: float) -> void:
	var alive: Array = []
	for w in _waves:
		if not is_instance_valid(w):
			continue
		var d: float = w.get_meta("dir")
		w.position.x += d * WAVE_SPEED * delta
		if w.position.x < arena_min_x + 12.0 or w.position.x > arena_max_x - 12.0:
			w.queue_free()
		else:
			alive.append(w)
	_waves = alive

## Phase 3 : éventail de trois orbes corrompus après chaque écrasement
## (tranchables au sabre, esquivables d'une ruée).
func _fire_volley() -> void:
	if player == null or not is_instance_valid(player):
		return
	var dir := signf(player.global_position.x - global_position.x)
	if dir == 0.0:
		dir = -1.0
	for ang in [0.0, -0.22, -0.45]:
		var orb := VOLLEY_ORB.instantiate()
		orb.position = global_position + Vector2(dir * 34.0, -46.0)
		orb.direction = Vector2(dir, 0).rotated(float(ang) * dir)
		orb.speed = 215.0
		get_parent().add_child(orb)

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
	for w in _waves:
		if is_instance_valid(w):
			w.queue_free()
	_waves.clear()
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
