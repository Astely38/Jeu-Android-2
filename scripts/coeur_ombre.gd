extends CharacterBody2D
## « Le Cœur de l'Ombre » — BOSS FINAL du Chapitre II. Une masse de nuit qui
## bat, hérissée de tentacules, avec un œil unique qui suit Eneko. Il flotte
## hors de portée et attaque à distance (salves d'orbes corrompus), protégé
## par un bouclier ; il ne s'expose qu'en PLONGEANT au sol : impact + ondes
## de choc à sauter, puis un bref étourdissement — la seule fenêtre pour le
## frapper. Trois phases de plus en plus féroces.

signal defeated
signal health_changed(current: int, max_health: int)
signal phase_changed(new_phase: int)

const MAX_HEALTH := 14
const P2_HEALTH := 9
const P3_HEALTH := 4

const ORB_SCENE := preload("res://scenes/spirit_orb.tscn")

const HOVER_Y := 168.0        # hauteur de vol (hors de portée du sabre)
const STUN_Y := 468.0         # hauteur au sol pendant l'étourdissement
const DIVE_SPEED := 560.0
const RISE_SPEED := 150.0
const CAST_WARN := 0.38
const SHOCKWAVE_SPEED := 300.0
const _R := 110.0

## Cadences par phase (1,2,3).
const VOLLEY_CD := [2.2, 1.6, 1.1]
const SLAM_CD := [4.8, 3.8, 3.0]
const STUN_TIME := [1.8, 1.5, 1.2]
const CHARGE_TIME := [0.75, 0.62, 0.5]

var health := MAX_HEALTH
var phase := 1
var player: Node2D = null
var active := false
var arena_min_x := -INF
var arena_max_x := INF

var _dying := false
var _state := "hover"   # hover / charge / dive / impact / stunned / rise
var _state_t := 0.0
var _volley_cd := 2.2
var _slam_cd := 3.0
var _casting := false
var _cast_t := 0.0
var _dive_x := 0.0
var _hurt_flash := 0.0
var _shield_flash := 0.0
var _t := 0.0
var _waves: Array = []

var _body: Node2D
var _aura: Sprite2D
var _shield: Sprite2D
var _eye_white: Polygon2D
var _pupil: Polygon2D
var _iris: Polygon2D
var _veins: Array[Polygon2D] = []
var _tendrils: Array = []

@onready var hitbox: Area2D = $Hitbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_die: AudioStreamPlayer = $SfxDie
@onready var sfx_hurt: AudioStreamPlayer = $SfxHurt

func _ready() -> void:
	collision_mask = 0  # flotte : position pilotée à la main
	z_index = 6
	_build_body()
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_ignore_player_body()
	position.y = HOVER_Y

func set_arena_bounds(min_x: float, max_x: float) -> void:
	arena_min_x = min_x
	arena_max_x = max_x

func activate() -> void:
	active = true
	_slam_cd = 2.4
	_volley_cd = 1.6

func _ignore_player_body() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl is PhysicsBody2D:
		add_collision_exception_with(pl)

## Construit le Cœur : masse de nuit battante, veines lumineuses, tentacules,
## œil central, halo et bouclier.
func _build_body() -> void:
	_body = Node2D.new()
	add_child(_body)

	_aura = Sprite2D.new()
	_aura.texture = load("res://assets/mist.svg")
	_aura.modulate = Color(0.6, 0.15, 0.5, 0.35)
	_aura.scale = Vector2(11.0, 11.0)
	_body.add_child(_aura)

	# Tentacules de nuit qui ondulent derrière la masse.
	for ti in 7:
		var ang := -PI * 0.9 + ti * (PI * 1.8 / 6.0)
		var bx := cos(ang) * _R * 0.8
		var by := sin(ang) * _R * 0.7
		var tent := _poly(PackedVector2Array([
			Vector2(-10, 0), Vector2(-5, -40), Vector2(-9, -84),
			Vector2(0, -96), Vector2(9, -84), Vector2(5, -40), Vector2(10, 0),
		]), Color(0.08, 0.06, 0.12, 0.9), Vector2(bx, by))
		tent.rotation = ang + PI * 0.5
		tent.scale = Vector2(0.8, 0.8)
		_tendrils.append({"node": tent, "base_rot": ang + PI * 0.5, "phase": float(ti) * 0.8})

	# Masse principale (contour de « cœur » anguleux).
	var heart := PackedVector2Array()
	var hi := 0
	while hi < 24:
		var a := hi * TAU / 24.0
		var rr := _R + 18.0 * sin(a * 3.0) + 10.0 * cos(a * 2.0)
		heart.append(Vector2(cos(a) * rr, sin(a) * rr * 0.9))
		hi += 1
	_poly(heart, Color(0.12, 0.07, 0.18, 0.98), Vector2.ZERO)
	_poly(heart, Color(0.18, 0.09, 0.26, 0.6), Vector2(0, -8)).scale = Vector2(0.7, 0.7)

	# Veines lumineuses qui rampent depuis le centre.
	for vi in 7:
		var va := vi * TAU / 7.0
		var vein := _poly(PackedVector2Array([
			Vector2(0, 0), Vector2(cos(va) * 34 - 6, sin(va) * 30),
			Vector2(cos(va) * (_R - 6), sin(va) * (_R - 10)),
			Vector2(cos(va) * 34 + 6, sin(va) * 30),
		]), Color(0.75, 0.3, 0.9, 0.0), Vector2.ZERO)
		_veins.append(vein)

	# Œil central : blanc violacé, iris, pupille qui suit Eneko.
	_eye_white = _poly(_ellipse(40.0, 28.0), Color(0.9, 0.85, 0.95, 0.95), Vector2(0, -4))
	_iris = _poly(_ellipse(20.0, 20.0), Color(0.55, 0.2, 0.75, 1.0), Vector2(0, -4))
	_pupil = _poly(_ellipse(9.0, 12.0), Color(0.05, 0.02, 0.08, 1.0), Vector2(0, -4))

	# Bouclier : anneau qui n'apparaît que lorsqu'il est protégé (en vol).
	_shield = Sprite2D.new()
	_shield.texture = load("res://assets/mist.svg")
	_shield.modulate = Color(0.5, 0.7, 1.0, 0.0)
	_shield.scale = Vector2(9.0, 9.0)
	_body.add_child(_shield)

func _poly(pts: PackedVector2Array, c: Color, pos: Vector2) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = c
	p.position = pos
	_body.add_child(p)
	return p

func _ellipse(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a := i * TAU / 16.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _physics_process(delta: float) -> void:
	if _dying:
		_advance_waves(delta)
		return
	_t += delta
	if _hurt_flash > 0.0: _hurt_flash -= delta
	if _shield_flash > 0.0: _shield_flash -= delta
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	if active and player != null and is_instance_valid(player):
		_run_state(delta)
	_advance_waves(delta)
	_animate(delta)

func _run_state(delta: float) -> void:
	_state_t += delta
	var pi := phase - 1
	match _state:
		"hover":
			position.x = lerpf(position.x, clampf(player.global_position.x, arena_min_x + _R * 0.5, arena_max_x - _R * 0.5), 0.02)
			position.y = lerpf(position.y, HOVER_Y + sin(_t * 1.6) * 10.0, 0.06)
			if _casting:
				_cast_t -= delta
				if _cast_t <= 0.0:
					_release_orbs()
					_casting = false
					_volley_cd = VOLLEY_CD[pi]
			else:
				_volley_cd -= delta
				_slam_cd -= delta
				if _slam_cd <= 0.0:
					_state = "charge"; _state_t = 0.0
				elif _volley_cd <= 0.0:
					_casting = true
					_cast_t = CAST_WARN
		"charge":
			# Télégraphe du plongeon : il se gonfle, l'œil s'embrase de rouge.
			position.y = lerpf(position.y, HOVER_Y - 14.0, 0.15)
			_dive_x = player.global_position.x
			if _state_t >= CHARGE_TIME[pi]:
				_state = "dive"; _state_t = 0.0
				Sfx.varied(sfx_hurt, 1.2, 1.35)
		"dive":
			# Plongeon dévastateur : contact = dégât.
			var target := Vector2(clampf(_dive_x, arena_min_x + _R * 0.5, arena_max_x - _R * 0.5), STUN_Y)
			position = position.move_toward(target, DIVE_SPEED * delta)
			for b in hitbox.get_overlapping_bodies():
				if b == player and b.has_method("take_damage"):
					b.take_damage(1, global_position)
			if position.distance_to(target) < 6.0:
				_state = "impact"; _state_t = 0.0
		"impact":
			_spawn_shockwave(-1.0)
			_spawn_shockwave(1.0)
			Atmosphere.spark_burst(get_parent(), global_position + Vector2(0, 90), Color(0.7, 0.3, 0.95))
			Sfx.varied(sfx_die, 0.7, 0.85)
			_state = "stunned"; _state_t = 0.0
		"stunned":
			# EXPOSÉ : bouclier baissé, l'œil pend, vulnérable au sabre.
			position.y = lerpf(position.y, STUN_Y, 0.2)
			if _state_t >= STUN_TIME[pi]:
				_state = "rise"; _state_t = 0.0
		"rise":
			position.y = move_toward(position.y, HOVER_Y, RISE_SPEED * delta)
			if absf(position.y - HOVER_Y) < 4.0:
				_state = "hover"; _state_t = 0.0
				_slam_cd = SLAM_CD[pi]
				_volley_cd = VOLLEY_CD[pi] * 0.6

## Salve d'orbes corrompus : un éventail vers Eneko ; en phase 3, un anneau
## complet en plus. Tranchables au sabre, esquivables d'une ruée.
func _release_orbs() -> void:
	if player == null or not is_instance_valid(player):
		return
	var origin := global_position + Vector2(0, 6)
	var to_player := (player.global_position - origin).normalized()
	var base := to_player.angle()
	var counts := [5, 7, 9]
	var n: int = counts[phase - 1]
	var spread := 0.6
	for i in n:
		var frac := (float(i) / float(n - 1)) - 0.5
		var ang := base + frac * spread
		_shoot(origin, Vector2.RIGHT.rotated(ang), 210.0)
	if phase >= 3:
		for i in 12:
			_shoot(origin, Vector2.RIGHT.rotated(i * TAU / 12.0), 165.0)

func _shoot(origin: Vector2, dir: Vector2, spd: float) -> void:
	var orb := ORB_SCENE.instantiate()
	orb.position = origin
	orb.direction = dir
	orb.speed = spd
	get_parent().add_child(orb)

## Onde de choc rasante qui court au sol depuis le point d'impact : à SAUTER.
func _spawn_shockwave(dir: float) -> void:
	var w := Area2D.new()
	w.position = Vector2(global_position.x + dir * 70.0, STUN_Y + 70.0)
	var sh := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 40)
	sh.shape = rect
	sh.position = Vector2(0, -20)
	w.add_child(sh)
	var flame := Polygon2D.new()
	flame.polygon = PackedVector2Array([
		Vector2(-16, 0), Vector2(16, 0), Vector2(10, -18), Vector2(0, -38), Vector2(-10, -18),
	])
	flame.color = Color(0.6, 0.25, 0.9, 0.9)
	w.add_child(flame)
	w.set_meta("dir", dir)
	w.body_entered.connect(func(b: Node2D):
		if b.is_in_group("player") and b.has_method("take_damage"):
			b.take_damage(1, w.global_position))
	get_parent().add_child(w)
	_waves.append(w)

func _advance_waves(delta: float) -> void:
	var alive: Array = []
	for w in _waves:
		if not is_instance_valid(w):
			continue
		var d: float = w.get_meta("dir")
		w.position.x += d * SHOCKWAVE_SPEED * delta
		if w.position.x < arena_min_x + 12.0 or w.position.x > arena_max_x - 12.0:
			w.queue_free()
		else:
			alive.append(w)
	_waves = alive

func _animate(delta: float) -> void:
	if _body == null:
		return
	var beat := 0.5 + 0.5 * sin(_t * 2.2)
	var exposed := _state == "stunned" or _state == "dive"
	# Pulsation de la masse.
	var s := 1.0 + 0.05 * beat + (0.12 if _state == "charge" else 0.0)
	_body.scale = Vector2(s, s)
	# Veines qui palpitent (plus vives à mesure que la vie baisse).
	var vein_a := (0.3 + 0.4 * beat) * (1.0 + 0.4 * float(phase - 1))
	for v in _veins:
		v.modulate.a = vein_a
	# Aura : rougit et s'intensifie avec la phase.
	_aura.modulate = Color(0.6 + 0.12 * float(phase - 1), 0.15, 0.5 - 0.1 * float(phase - 1), 0.32 + 0.1 * beat)
	# Bouclier : visible seulement quand il est protégé (pas exposé).
	var target_shield := 0.0 if exposed else 0.16 + (0.5 if _shield_flash > 0.0 else 0.0)
	_shield.modulate.a = lerpf(_shield.modulate.a, target_shield, 0.2)
	# Œil : la pupille suit Eneko ; l'iris s'embrase à l'armement/plongeon,
	# et s'éteint quand il est étourdi.
	if player != null and is_instance_valid(player):
		var d := (player.global_position - global_position).normalized()
		_pupil.position = Vector2(0, -4) + d * 9.0
		_iris.position = Vector2(0, -4) + d * 4.0
	if _state == "stunned":
		_iris.color = Color(0.3, 0.12, 0.4, 1.0)
		_eye_white.color = Color(0.5, 0.42, 0.55, 0.9)
	elif _state == "charge" or _state == "dive":
		_iris.color = Color(1.0, 0.3, 0.25, 1.0)
		_eye_white.color = Color(1.0, 0.8, 0.75, 0.95)
	else:
		_iris.color = Color(0.55, 0.2, 0.75, 1.0)
		_eye_white.color = Color(0.9, 0.85, 0.95, 0.95)
	# Flash blanc quand touché.
	_body.modulate = _body.modulate.lerp(Color(2.0, 2.0, 2.0) if _hurt_flash > 0.0 else Color(1, 1, 1), 0.4)
	# Tentacules qui ondulent.
	for td in _tendrils:
		var tn: Polygon2D = td["node"]
		tn.rotation = float(td["base_rot"]) + 0.18 * sin(_t * 1.4 + float(td["phase"]))

func _on_hitbox_body_entered(body: Node2D) -> void:
	if _dying or _state != "dive":
		return
	if body.has_method("take_damage"):
		body.take_damage(1, global_position)

## Frappé au sabre. Un BOUCLIER protège le Cœur tant qu'il n'est pas exposé
## (plongeon/étourdissement) : les coups ricochent alors sans l'entamer.
func die() -> bool:
	if _dying:
		return false
	if _state != "stunned" and _state != "dive":
		_shield_flash = 0.2
		Sfx.varied(sfx_hurt, 1.3, 1.5)
		return false
	health -= 1
	health_changed.emit(health, MAX_HEALTH)
	_hurt_flash = 0.18
	Sfx.varied(sfx_hurt, 0.85, 1.05)
	if health <= 0:
		_die_for_real()
		return true
	if phase < 3 and health <= P3_HEALTH:
		phase = 3
		phase_changed.emit(3)
	elif phase < 2 and health <= P2_HEALTH:
		phase = 2
		phase_changed.emit(2)
	return false

func _die_for_real() -> void:
	_dying = true
	active = false
	velocity = Vector2.ZERO
	hitbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	Sfx.varied(sfx_die, 0.7, 0.9)
	Atmosphere.spark_burst(get_parent(), global_position, Color(0.9, 0.4, 1.0))
	defeated.emit()
	# Effondrement : la masse s'affaisse, l'œil se ferme, tout s'efface dans
	# une implosion de lumière.
	if _body != null:
		var tw := _body.create_tween()
		tw.set_parallel(true)
		tw.tween_property(_body, "scale", Vector2(0.05, 0.05), 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(_body, "rotation", 1.2, 1.1)
		tw.tween_property(_body, "modulate:a", 0.0, 1.1)
		tw.chain().tween_callback(queue_free)
	else:
		queue_free()
