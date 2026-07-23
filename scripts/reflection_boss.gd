class_name ReflectionBoss
extends CharacterBody2D
## Le Reflet Corrompu, boss du Chapitre IV : ce que le tain brisé a fait
## d'Eneko lui-même. Porte son visage, son sabre, sa ruée — mais chaque
## geste en est une version glitchée, en retard ou en avance sur lui-même.
## Son attaque propre, la Copie Différée, rejoue contre le joueur le tracé
## qu'IL vient de parcourir : le Reflet ne frappe jamais au hasard, il
## frappe avec le passé du joueur.
##
## Quatre attaques, aucune héritée d'un autre boss : Frappe-miroir (sabre,
## parable), Ruée fantôme (dash + leurre statique), Copie Différée (rejoue
## le tracé récent du joueur) et, à partir de la phase 3, Fracture (saut-
## écrasement + éclats de miroir en volée).

signal defeated
signal health_changed(current: int, max_health: int)
signal phase_changed(new_phase: int)

const GRAVITY := 980.0
const SAMURAI := "res://assets/character/samurai/"
const MAX_HEALTH := 10
const PHASE2_HEALTH := 7
const PHASE3_HEALTH := 3
const PHASE_SPEED := [80.0, 125.0, 158.0]

const GLITCH_A := Color(0.85, 0.25, 0.55)
const GLITCH_B := Color(0.3, 0.75, 0.85)

## Multiplicateur Kensei : accélère le Reflet et raccourcit ses répits.
var _kmult := 1.0

const ATTACK_RANGE := 68.0
const SWING_WINDUP := 0.42
const SWING_ACTIVE := 0.2
const SWING_RECOVER := 0.5
const SWING_RECOVER_PARRIED := 0.95
const SWING_CD := 0.4
## Fenêtre de parade : seulement la toute fin de l'armement (+ la frappe).
const PARRY_LEAD := 0.15

const DASH_SPEED := 360.0
const DASH_DURATION := 0.38
const DASH_CD := [3.0, 2.2, 1.5]
## Le leurre laissé par la Ruée fantôme reste dangereux un court instant.
const DECOY_LIFE := 1.1

## Copie Différée : combien de secondes du tracé du joueur sont mémorisées
## et rejouées, et à quelle cadence l'attaque revient.
const ECHO_RECORD_TIME := 2.4
const ECHO_CD := [6.0, 4.6, 3.4]

const SLAM_JUMP_VY := -600.0
const SLAM_CD := [0.0, 0.0, 3.4]
const WAVE_SPEED := 280.0
const SHARD_CD := [0.0, 3.6, 2.6]

var health := MAX_HEALTH
var phase := 1
var player: Node2D = null
var active := false
var arena_min_x := -INF
var arena_max_x := INF

var _dying := false
var _hurt_timer := 0.0
var _t := 0.0

var _swing := ""  # "" / "windup" / "active" / "recover"
var _swing_t := 0.0
var _swing_cd := 0.0
var _swing_dir := 1.0
var _swing_did_damage := false
var _swing_hit: Area2D
var _swing_warn: Polygon2D

var _dash_timer := 0.0
var _dash_cd := 1.6
var _decoys: Array = []

var _echo_cd := 3.0
var _history: Array = []
var _echoes: Array = []

var _slam_cd := 2.0
var _slam_air := false
var _waves: Array = []
var _shard_cd := 2.0

var _cur := ""
var _base_tint := Color(1, 1, 1)

var anim: AnimatedSprite2D
var hitbox: Area2D
var body_shape: CollisionShape2D
var sfx_die: AudioStreamPlayer
var sfx_hurt: AudioStreamPlayer
var _aura: Sprite2D
var _aura_base_scale := Vector2.ONE
var _cracks: Array = []

func _ready() -> void:
	if Challenge.kensei:
		_kmult = 1.2
	z_index = 6
	anim = AnimatedSprite2D.new()
	anim.sprite_frames = SpriteSheet.build([
		{"name": "idle", "path": SAMURAI + "Idle.png", "frames": 6, "fps": 8.0, "loop": true},
		{"name": "run", "path": SAMURAI + "Run.png", "frames": 8, "fps": 13.0, "loop": true},
		{"name": "attack", "path": SAMURAI + "Attack_1.png", "frames": 6, "fps": 15.0, "loop": false},
		{"name": "hurt", "path": SAMURAI + "Hurt.png", "frames": 2, "fps": 9.0, "loop": false},
		{"name": "dead", "path": SAMURAI + "Dead.png", "frames": 3, "fps": 6.0, "loop": false},
	])
	# Le même visage que le joueur, mais lavé de ses couleurs et cerné de
	# glitch : c'est bien Eneko, mais un Eneko que rien n'anime plus de
	# l'intérieur.
	_base_tint = Color(0.55, 0.5, 0.62)
	anim.modulate = _base_tint
	anim.scale = Vector2(1.15, 1.15)
	add_child(anim)
	_play("idle")

	body_shape = CollisionShape2D.new()
	var body_capsule := CapsuleShape2D.new()
	body_capsule.radius = 14.0
	body_capsule.height = 46.0
	body_shape.shape = body_capsule
	body_shape.position = Vector2(0, -23)
	add_child(body_shape)

	_aura = Sprite2D.new()
	_aura.texture = load("res://assets/mist.svg")
	_aura.modulate = Color(GLITCH_A.r, GLITCH_A.g, GLITCH_A.b, 0.22)
	_aura.scale = Vector2(2.0, 2.4)
	_aura.position = Vector2(0, -24)
	_aura.z_index = -1
	add_child(_aura)
	_aura_base_scale = _aura.scale

	hitbox = Area2D.new()
	var hshape := CollisionShape2D.new()
	var hcapsule := CapsuleShape2D.new()
	hcapsule.radius = 15.0
	hcapsule.height = 48.0
	hshape.shape = hcapsule
	hshape.position = Vector2(0, -23)
	hitbox.add_child(hshape)
	add_child(hitbox)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_ignore_player_body()

	sfx_die = AudioStreamPlayer.new()
	sfx_die.stream = load("res://assets/sfx/win.wav")
	sfx_die.volume_db = -3.0
	sfx_die.pitch_scale = 0.6
	add_child(sfx_die)
	sfx_hurt = AudioStreamPlayer.new()
	sfx_hurt.stream = load("res://assets/sfx/checkpoint.wav")
	sfx_hurt.volume_db = -4.0
	sfx_hurt.pitch_scale = 0.75
	add_child(sfx_hurt)

	var sh := ContactShadow.new()
	sh.width = 46.0
	add_child(sh)
	move_child(sh, 0)

	# Zone de dégât de la Frappe-miroir (active seulement pendant la frappe).
	_swing_hit = Area2D.new()
	_swing_hit.monitoring = false
	var swing_shape := CollisionShape2D.new()
	var swing_rect := RectangleShape2D.new()
	swing_rect.size = Vector2(72, 62)
	swing_shape.shape = swing_rect
	_swing_hit.add_child(swing_shape)
	add_child(_swing_hit)
	_swing_hit.body_entered.connect(_on_swing_hit)

	# Télégraphe : un arc glitché qui grandit devant le Reflet à l'armement.
	_swing_warn = Polygon2D.new()
	_swing_warn.polygon = PackedVector2Array([
		Vector2(6, -50), Vector2(46, -38), Vector2(56, -8), Vector2(46, 18),
		Vector2(28, 6), Vector2(36, -16), Vector2(16, -32),
	])
	_swing_warn.color = Color(GLITCH_B.r, GLITCH_B.g, GLITCH_B.b, 0.0)
	_swing_warn.z_index = 2
	_swing_warn.visible = false
	add_child(_swing_warn)

func _ignore_player_body() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl is PhysicsBody2D:
		add_collision_exception_with(pl)

func set_arena_bounds(min_x: float, max_x: float) -> void:
	arena_min_x = min_x
	arena_max_x = max_x

func activate() -> void:
	active = true

func _physics_process(delta: float) -> void:
	_t += delta
	_update_aura(delta)
	_advance_waves(delta)
	_advance_decoys(delta)
	_advance_echoes(delta)
	_record_player(delta)

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

	if _swing != "":
		_process_swing(delta)
		return

	if _dash_timer > 0.0:
		_dash_timer -= delta
		move_and_slide()
		_clamp_to_arena()
		if _dash_timer <= 0.0:
			_play("idle")
		return

	if player == null or not is_instance_valid(player):
		velocity.x = move_toward(velocity.x, 0.0, PHASE_SPEED[0])
		move_and_slide()
		return

	_dash_cd -= delta
	_echo_cd -= delta
	_slam_cd -= delta
	_shard_cd -= delta
	_swing_cd = maxf(0.0, _swing_cd - delta)

	var dx: float = player.global_position.x - global_position.x
	var dist := absf(dx)
	var dir := signf(dx) if dx != 0.0 else 1.0
	anim.flip_h = dir < 0.0

	if phase >= 3 and _slam_cd <= 0.0 and is_on_floor() and dist > 80.0:
		_start_slam(dx)
		return
	if phase >= 2 and _shard_cd <= 0.0 and dist > 120.0:
		_fire_shards()
		_shard_cd = SHARD_CD[phase - 1] / _kmult
	if _echo_cd <= 0.0 and _history.size() > 4:
		_trigger_echo()
		_echo_cd = ECHO_CD[phase - 1] / _kmult
	elif dist <= ATTACK_RANGE:
		velocity.x = 0.0
		_attack()
	elif _dash_cd <= 0.0 and dist > 140.0 and dist < 460.0:
		_dash_cd = DASH_CD[phase - 1] / _kmult
		_start_dash(dir)
	else:
		var speed: float = PHASE_SPEED[phase - 1] * _kmult
		velocity.x = dir * speed
		_play("run")

	move_and_slide()
	_clamp_to_arena()

func _clamp_to_arena() -> void:
	position.x = clampf(position.x, arena_min_x, arena_max_x)

func _update_aura(delta: float) -> void:
	if _aura == null:
		return
	var rage := (float(phase) - 1.0) / 2.0
	var a := 0.16 + 0.07 * float(phase) + 0.06 * sin(_t * 3.2)
	_aura.modulate = Color(GLITCH_A.r, GLITCH_A.g, GLITCH_A.b, a) if sin(_t * 6.0) > 0.0 else Color(GLITCH_B.r, GLITCH_B.g, GLITCH_B.b, a)
	var sc := 1.0 + 0.05 * float(phase) + 0.06 * rage * sin(_t * (3.2 + float(phase)))
	_aura.scale = _aura_base_scale * sc
	for cr in _cracks:
		cr.modulate.a = 0.4 + 0.35 * sin(_t * 5.5)

# --- Frappe-miroir (sabre, parable) -----------------------------------------

func _attack() -> void:
	if _swing != "" or _swing_cd > 0.0:
		return
	_swing = "windup"
	_swing_t = SWING_WINDUP / _kmult
	_swing_did_damage = false
	_swing_dir = signf(player.global_position.x - global_position.x) if player != null else 1.0
	if _swing_dir == 0.0:
		_swing_dir = 1.0
	anim.flip_h = _swing_dir < 0.0
	_play("attack")
	_swing_warn.position = Vector2.ZERO
	_swing_warn.visible = true
	_swing_warn.color = Color(GLITCH_B.r, GLITCH_B.g, GLITCH_B.b, 0.15)
	anim.modulate = Color(_base_tint.r * 1.8, _base_tint.g * 1.5, _base_tint.b * 1.8)

func _process_swing(delta: float) -> void:
	_swing_t -= delta
	velocity.x = 0.0
	move_and_slide()
	if _swing == "windup":
		var w := 1.0 - clampf(_swing_t / (SWING_WINDUP / _kmult), 0.0, 1.0)
		_swing_warn.color.a = 0.15 + 0.55 * w
		_swing_warn.scale = Vector2(_swing_dir * (0.7 + 0.3 * w), 0.7 + 0.3 * w)
		if _swing_t <= 0.0:
			_begin_swing()
	elif _swing == "active":
		if not _swing_did_damage:
			for b in _swing_hit.get_overlapping_bodies():
				_on_swing_hit(b)
		if _swing_t <= 0.0:
			_swing = "recover"
			_swing_t = SWING_RECOVER / _kmult
			_swing_hit.monitoring = false
	else:
		if _swing_t <= 0.0:
			_swing = ""
			_swing_cd = SWING_CD / _kmult
			_play("idle")

func _begin_swing() -> void:
	_swing = "active"
	_swing_t = SWING_ACTIVE
	_swing_warn.visible = false
	anim.modulate = _base_tint
	_swing_hit.position = Vector2(_swing_dir * 44.0, -18.0)
	_swing_hit.monitoring = true
	var slash := Polygon2D.new()
	slash.polygon = PackedVector2Array([
		Vector2(8, -48), Vector2(52, -32), Vector2(60, -4), Vector2(48, 20),
		Vector2(38, 6), Vector2(44, -14), Vector2(20, -32),
	])
	slash.color = Color(GLITCH_B.r, GLITCH_B.g, GLITCH_B.b, 0.9)
	slash.scale = Vector2(_swing_dir, 1.0)
	slash.z_index = 2
	add_child(slash)
	var st := slash.create_tween()
	st.tween_property(slash, "modulate:a", 0.0, 0.22)
	st.tween_callback(slash.queue_free)
	Sfx.varied(sfx_hurt, 1.1, 1.25)

func _on_swing_hit(body: Node2D) -> void:
	if _swing != "active" or _swing_did_damage:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		_swing_did_damage = true
		body.take_damage(1, global_position)

## PARADE : identique dans l'esprit à celle du joueur — frapper le Reflet
## pendant l'armement de son coup dévie la lame et ouvre une fenêtre de
## riposte, sans dégât pour Eneko.
func _parry() -> void:
	_swing_did_damage = true
	_swing = "recover"
	_swing_t = SWING_RECOVER_PARRIED / _kmult
	_swing_hit.monitoring = false
	_swing_warn.visible = false
	_swing_cd = SWING_CD / _kmult
	Atmosphere.spark_burst(get_parent(), global_position + Vector2(_swing_dir * 32.0, -30.0), GLITCH_B)
	SaveManager.vibrate(45)
	anim.modulate = Color(1.9, 1.9, 2.0)
	var tw := create_tween()
	tw.tween_property(anim, "modulate", _base_tint, 0.4)
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and pl.has_method("add_shake"):
		pl.add_shake(5.0)

# --- Ruée fantôme (dash + leurre) -------------------------------------------

## Fonce sur le joueur, puis laisse derrière lui un leurre statique et
## dangereux : le vrai Reflet a déjà bougé, mais son reflet-du-reflet
## traîne encore un instant à l'endroit du départ.
func _start_dash(dir: float) -> void:
	_spawn_decoy()
	_dash_timer = DASH_DURATION
	velocity.x = dir * DASH_SPEED
	anim.modulate = Color(_base_tint.r * 1.6, _base_tint.g * 1.3, _base_tint.b * 1.8)
	var t := create_tween()
	t.tween_property(anim, "modulate", _base_tint, 0.3)
	_play("run")

func _spawn_decoy() -> void:
	var host := get_parent()
	if host == null:
		return
	var decoy := Area2D.new()
	decoy.global_position = global_position
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 14.0
	capsule.height = 46.0
	shape.shape = capsule
	shape.position = Vector2(0, -23)
	decoy.add_child(shape)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-11, 0), Vector2(11, 0), Vector2(9, -40), Vector2(-9, -40),
	])
	body.color = Color(GLITCH_A.r, GLITCH_A.g, GLITCH_A.b, 0.55)
	decoy.add_child(body)
	var edge := Line2D.new()
	edge.points = body.polygon
	edge.closed = true
	edge.width = 1.6
	edge.default_color = Color(GLITCH_B.r, GLITCH_B.g, GLITCH_B.b, 0.85)
	decoy.add_child(edge)
	decoy.body_entered.connect(func(b: Node2D):
		if b.is_in_group("player") and b.has_method("take_damage"):
			b.take_damage(1, decoy.global_position)
	)
	host.add_child(decoy)
	_decoys.append({"node": decoy, "life": DECOY_LIFE, "poly": body})

func _advance_decoys(delta: float) -> void:
	var alive: Array = []
	for d in _decoys:
		if not is_instance_valid(d["node"]):
			continue
		d["life"] = float(d["life"]) - delta
		var node: Area2D = d["node"]
		var poly: Polygon2D = d["poly"]
		poly.modulate.a = 0.4 + 0.5 * absf(sin(_t * 12.0))
		if float(d["life"]) <= 0.0:
			var tw := node.create_tween()
			tw.tween_property(poly, "modulate:a", 0.0, 0.25)
			tw.tween_callback(node.queue_free)
		else:
			alive.append(d)
	_decoys = alive

# --- Copie Différée (attaque signature) -------------------------------------

## Mémorise en continu la position du joueur (comme un EchoTwin, mais
## hostile) : la Copie Différée s'en sert pour rejouer contre lui son
## propre tracé récent.
func _record_player(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_history.append({"t": _t, "pos": player.global_position})
	while _history.size() > 1 and float(_history[0]["t"]) < _t - ECHO_RECORD_TIME - 0.2:
		_history.pop_front()

## Fait naître, à l'endroit où se trouvait le joueur il y a ECHO_RECORD_TIME
## secondes, une silhouette glitchée qui rejoue son tracé exact vers le
## présent — le joueur doit fuir SON PROPRE chemin.
func _trigger_echo() -> void:
	var host := get_parent()
	if host == null or _history.is_empty():
		return
	var path: Array = _history.duplicate(true)
	var start_t: float = path[0]["t"]

	var echo_node := Node2D.new()
	echo_node.global_position = path[0]["pos"]
	echo_node.z_index = 5
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(GLITCH_A.r, GLITCH_A.g, GLITCH_A.b, 0.3)
	glow.scale = Vector2(1.3, 1.6)
	glow.position = Vector2(0, -20)
	glow.z_index = -1
	echo_node.add_child(glow)
	var pts := PackedVector2Array([
		Vector2(-9, 0), Vector2(9, 0), Vector2(7, -20), Vector2(4, -34),
		Vector2(-4, -34), Vector2(-7, -20),
	])
	var body := Polygon2D.new()
	body.polygon = pts
	body.color = Color(GLITCH_B.r, GLITCH_B.g, GLITCH_B.b, 0.65)
	echo_node.add_child(body)
	var edge := Line2D.new()
	edge.points = pts
	edge.closed = true
	edge.width = 1.4
	edge.default_color = Color(GLITCH_A.r, GLITCH_A.g, GLITCH_A.b, 0.9)
	echo_node.add_child(edge)

	var hit := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	shape.position = Vector2(0, -18)
	hit.add_child(shape)
	echo_node.add_child(hit)
	hit.body_entered.connect(func(b: Node2D):
		if b.is_in_group("player") and b.has_method("take_damage"):
			b.take_damage(1, echo_node.global_position)
	)
	host.add_child(echo_node)
	Atmosphere.spark_burst(host, echo_node.global_position, GLITCH_A)
	_echoes.append({"node": echo_node, "poly": body, "path": path, "start_t": start_t, "elapsed": 0.0})

func _advance_echoes(delta: float) -> void:
	var alive: Array = []
	for e in _echoes:
		if not is_instance_valid(e["node"]):
			continue
		e["elapsed"] = float(e["elapsed"]) + delta
		var node: Node2D = e["node"]
		var poly: Polygon2D = e["poly"]
		poly.modulate.a = 0.5 + 0.4 * absf(sin(_t * 10.0))
		var path: Array = e["path"]
		var target_t: float = float(e["start_t"]) + float(e["elapsed"])
		var pos: Vector2 = path[path.size() - 1]["pos"]
		var prev: Dictionary = path[0]
		var found := false
		for entry in path:
			if float(entry["t"]) >= target_t:
				var span: float = float(entry["t"]) - float(prev["t"])
				var f: float = 0.0 if span <= 0.0 else clampf((target_t - float(prev["t"])) / span, 0.0, 1.0)
				pos = (prev["pos"] as Vector2).lerp(entry["pos"] as Vector2, f)
				found = true
				break
			prev = entry
		node.global_position = pos
		if found:
			alive.append(e)
		else:
			var tw := node.create_tween()
			tw.tween_property(poly, "modulate:a", 0.0, 0.3)
			tw.tween_callback(node.queue_free)
	_echoes = alive

# --- Éclats de miroir (phase 2+) --------------------------------------------

func _fire_shards() -> void:
	if player == null or not is_instance_valid(player):
		return
	var host := get_parent()
	if host == null:
		return
	var dir := signf(player.global_position.x - global_position.x)
	if dir == 0.0:
		dir = -1.0
	for ang in [0.0, -0.25, 0.25]:
		var shard := Area2D.new()
		shard.global_position = global_position + Vector2(dir * 30.0, -40.0)
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 7.0
		shape.shape = circle
		shard.add_child(shape)
		var poly := PackedVector2Array([
			Vector2(0, -9), Vector2(6, 0), Vector2(0, 9), Vector2(-6, 0),
		])
		var body := Polygon2D.new()
		body.polygon = poly
		body.color = GLITCH_A if ang <= 0.0 else GLITCH_B
		shard.add_child(body)
		var edge := Line2D.new()
		edge.points = poly
		edge.closed = true
		edge.width = 1.0
		edge.default_color = Color(1, 1, 1, 0.8)
		shard.add_child(edge)
		host.add_child(shard)
		var v: Vector2 = Vector2(dir, 0).rotated(ang) * 230.0
		shard.body_entered.connect(func(b: Node2D):
			if b.is_in_group("player") and b.has_method("take_damage"):
				b.take_damage(1, shard.global_position)
				shard.queue_free()
		)
		var st := shard.create_tween()
		st.tween_property(shard, "position", shard.position + v * 1.8, 1.8)
		st.tween_callback(shard.queue_free)
		st.parallel().tween_property(shard, "rotation", 8.0 * dir, 1.8)

# --- Fracture (saut-écrasement, phase 3) ------------------------------------

func _start_slam(dx: float) -> void:
	_slam_cd = SLAM_CD[phase - 1] / _kmult
	_slam_air = true
	var reach := clampf(dx, -420.0, 420.0)
	velocity = Vector2(reach / 1.3, SLAM_JUMP_VY)
	anim.modulate = Color(_base_tint.r * 1.8, _base_tint.g * 1.4, _base_tint.b * 1.9)
	var t := create_tween()
	t.tween_property(anim, "modulate", _base_tint, 0.4)
	_play("run")

func _on_slam_impact() -> void:
	_play("idle")
	Sfx.varied(sfx_hurt, 0.85, 0.98)
	SaveManager.vibrate(60)
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and pl.has_method("add_shake"):
		pl.add_shake(9.0)
	_spawn_wave(-1.0)
	_spawn_wave(1.0)

func _spawn_wave(dir: float) -> void:
	var host := get_parent()
	if host == null:
		return
	var w := Area2D.new()
	w.position = position + Vector2(dir * 50.0, 0)
	var sh := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 32)
	sh.shape = rect
	sh.position = Vector2(0, -16)
	w.add_child(sh)
	var flame := Polygon2D.new()
	flame.polygon = PackedVector2Array([
		Vector2(-13, 0), Vector2(13, 0), Vector2(8, -15), Vector2(0, -32), Vector2(-8, -15),
	])
	flame.color = Color(GLITCH_A.r, GLITCH_A.g, GLITCH_A.b, 0.9)
	w.add_child(flame)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(-5, 0), Vector2(5, 0), Vector2(0, -18),
	])
	core.color = Color(GLITCH_B.r, GLITCH_B.g, GLITCH_B.b, 0.95)
	w.add_child(core)
	w.set_meta("dir", dir)
	w.body_entered.connect(func(b: Node2D):
		if b.is_in_group("player") and b.has_method("take_damage"):
			b.take_damage(1, w.global_position)
	)
	host.add_child(w)
	_waves.append(w)

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

# --- Dégâts / mort -----------------------------------------------------------

func _on_hitbox_body_entered(body: Node2D) -> void:
	if _dying or not active:
		return
	if _dash_timer <= 0.0 and not _slam_air:
		return
	if body.has_method("take_damage"):
		body.take_damage(1, global_position)

func die() -> void:
	if _dying or not active:
		return
	var parryable := (_swing == "active" and not _swing_did_damage) \
		or (_swing == "windup" and _swing_t <= PARRY_LEAD)
	if parryable:
		_parry()
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
		_spawn_cracks()
	_hurt_timer = 0.3
	Sfx.varied(sfx_hurt, 0.9, 1.1)
	anim.modulate = Color(1.8, 1.8, 1.8) if SaveManager.setting_on("flash") else Color(1.3, 1.3, 1.3)
	var tween := create_tween()
	tween.tween_property(anim, "modulate", _base_tint, 0.25)

func _spawn_cracks() -> void:
	for c in 2:
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = Color(GLITCH_B.r, GLITCH_B.g, GLITCH_B.b, 1.0)
		var ox := -13.0 + randf() * 26.0
		var oy := -34.0 + randf() * 22.0
		var pts := PackedVector2Array([Vector2(ox, oy)])
		var seg := 3 + (randi() % 2)
		var k := 0
		while k < seg:
			ox += randf_range(-8.0, 8.0)
			oy += randf_range(6.0, 12.0)
			pts.append(Vector2(ox, oy))
			k += 1
		line.points = pts
		line.z_index = 1
		anim.add_child(line)
		_cracks.append(line)

func _die_for_real() -> void:
	_dying = true
	velocity = Vector2.ZERO
	for w in _waves:
		if is_instance_valid(w):
			w.queue_free()
	_waves.clear()
	for d in _decoys:
		if is_instance_valid(d["node"]):
			d["node"].queue_free()
	_decoys.clear()
	for e in _echoes:
		if is_instance_valid(e["node"]):
			e["node"].queue_free()
	_echoes.clear()
	hitbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	_play("dead")
	sfx_die.play()
	var parent := get_parent()
	if parent != null:
		Atmosphere.death_burst(parent, global_position + Vector2(0, -38), GLITCH_A)
		Atmosphere.death_burst(parent, global_position + Vector2(-16, -18), GLITCH_B)
		Atmosphere.spark_burst(parent, global_position + Vector2(0, -28), Color(1.0, 0.95, 1.0))
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and pl.has_method("add_shake"):
		pl.add_shake(8.0)
	set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(anim, "modulate:a", 0.0, 1.0)
	if _aura != null:
		tween.parallel().tween_property(_aura, "modulate:a", 0.0, 1.0)
	tween.finished.connect(func():
		defeated.emit()
		queue_free()
	)

func _play(n: String) -> void:
	if _cur != n:
		_cur = n
		anim.play(n)
