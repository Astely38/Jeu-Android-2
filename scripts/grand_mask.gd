extends CharacterBody2D
## « Le Grand Masque » — mini-boss du Puits de l'Ombre. Un masque d'Oni géant,
## émissaire du Cœur, qui FLOTTE au-dessus de l'arène et FONCE sur Eneko par
## charges télégraphiées : on esquive la ruée, puis on le frappe pendant sa
## récupération. À mi-vie, il se fissure et invoque deux petits masques.
## Vaincu, il n'ouvre pas encore le Cœur — ce n'est PAS le boss final.

signal defeated
signal health_changed(current: int, max_health: int)

const MAX_HEALTH := 6
const SMALL_MASK := preload("res://scenes/split_shade.tscn")

const RED := Color(0.72, 0.13, 0.12)
const RED_DARK := Color(0.5, 0.08, 0.09)
const BONE := Color(0.93, 0.88, 0.74)
const EYE := Color(1.0, 0.85, 0.2)

const HOVER_SPEED := 76.0
const LUNGE_SPEED := 430.0
const WINDUP_TIME := 0.7
const LUNGE_TIME := 0.42
const RECOVER_TIME := 0.85
const LUNGE_CD := 1.6
const HOVER_Y := 400.0     # hauteur de vol au repos

var health := MAX_HEALTH
var player: Node2D = null
var active := false
var arena_min_x := -INF
var arena_max_x := INF

var _dying := false
var _phase := 1
var _phase2_done := false
var _r := 40.0
var _t := 0.0
var _face := 1.0
var _state := "idle"     # idle / windup / lunge / recover
var _state_t := 0.0
var _cd := 1.4
var _lunge_dir := Vector2.ZERO
var _hurt_flash := 0.0

var _mask: Node2D
var _warn: Sprite2D
var _eyes: Array[Polygon2D] = []

@onready var hitbox: Area2D = $Hitbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_die: AudioStreamPlayer = $SfxDie
@onready var sfx_hurt: AudioStreamPlayer = $SfxHurt

func _ready() -> void:
	collision_mask = 0  # yokai spectral : flotte et traverse le décor
	z_index = 6
	_build_mask()
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_ignore_player_body()
	var sh := ContactShadow.new()
	sh.width = _r * 1.5
	sh.max_drop = 560.0
	add_child(sh)
	move_child(sh, 0)

func set_arena_bounds(min_x: float, max_x: float) -> void:
	arena_min_x = min_x
	arena_max_x = max_x

func activate() -> void:
	active = true

func _ignore_player_body() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl is PhysicsBody2D:
		add_collision_exception_with(pl)

## Construit le grand masque d'Oni (mêmes traits que le petit yokai, en
## bien plus grand) + une lueur d'avertissement qui s'embrase à l'armement.
func _build_mask() -> void:
	_mask = Node2D.new()
	add_child(_mask)
	var k := _r / 17.0

	_warn = Sprite2D.new()
	_warn.texture = load("res://assets/mist.svg")
	_warn.modulate = Color(1.0, 0.3, 0.2, 0.0)
	_warn.scale = Vector2(k, k) * 3.2
	_mask.add_child(_warn)

	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(1.0, 0.35, 0.25, 0.32)
	glow.scale = Vector2(k, k) * 2.4
	_mask.add_child(glow)

	# Cornes.
	for s in [-1.0, 1.0]:
		_poly(PackedVector2Array([
			Vector2(s * 8, -12), Vector2(s * 22, -32), Vector2(s * 15, -27), Vector2(s * 12, -12),
		]), BONE, k)
	# Face.
	_poly(PackedVector2Array([
		Vector2(-16, -12), Vector2(-14, -18), Vector2(0, -20), Vector2(14, -18),
		Vector2(16, -12), Vector2(14, 4), Vector2(6, 16), Vector2(0, 20),
		Vector2(-6, 16), Vector2(-14, 4),
	]), RED, k)
	_poly(PackedVector2Array([
		Vector2(-14, 4), Vector2(14, 4), Vector2(6, 16), Vector2(0, 20), Vector2(-6, 16),
	]), RED_DARK, k)
	# Sourcils.
	for s in [-1.0, 1.0]:
		_poly(PackedVector2Array([
			Vector2(s * 3, -10), Vector2(s * 15, -13), Vector2(s * 15, -8), Vector2(s * 5, -5),
		]), RED_DARK, k)
	# Yeux luisants.
	for s in [-1.0, 1.0]:
		var eye := Polygon2D.new()
		var ep := PackedVector2Array()
		for i in 8:
			var a := i * TAU / 8.0
			ep.append(Vector2(cos(a) * 3.4, sin(a) * 2.6))
		eye.polygon = ep
		eye.position = Vector2(s * 8.0 * k, -8.0 * k)
		eye.color = EYE
		_mask.add_child(eye)
		_eyes.append(eye)
	# Gueule + crocs.
	_poly(PackedVector2Array([
		Vector2(-9, 6), Vector2(9, 6), Vector2(6, 13), Vector2(-6, 13),
	]), Color(0.1, 0.03, 0.04), k)
	for fi in 4:
		var fx := -6.0 + float(fi) * 4.0
		if fi % 2 == 0:
			_poly(PackedVector2Array([
				Vector2(fx, 6.5), Vector2(fx + 2.4, 6.5), Vector2(fx + 1.2, 11.5),
			]), BONE, k)
		else:
			_poly(PackedVector2Array([
				Vector2(fx, 12.5), Vector2(fx + 2.4, 12.5), Vector2(fx + 1.2, 8.0),
			]), BONE, k)

func _poly(pts: PackedVector2Array, c: Color, k: float) -> void:
	var p := Polygon2D.new()
	var scaled := PackedVector2Array()
	for v in pts:
		scaled.append(v * k)
	p.polygon = scaled
	p.color = c
	_mask.add_child(p)

func _physics_process(delta: float) -> void:
	if _dying:
		return
	_t += delta
	if _hurt_flash > 0.0:
		_hurt_flash -= delta
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	if not active or player == null or not is_instance_valid(player):
		velocity = velocity.lerp(Vector2.ZERO, 0.1)
		move_and_slide()
		_animate(delta)
		return

	var to_player: Vector2 = player.global_position + Vector2(0, -30) - global_position
	if absf(to_player.x) > 6.0:
		_face = signf(to_player.x)
	_state_t += delta

	match _state:
		"idle":
			# Vol de poursuite au-dessus d'Eneko, avec léger flottement.
			var target := Vector2(player.global_position.x, HOVER_Y)
			var desired := (target - global_position)
			if desired.length() > 4.0:
				desired = desired.normalized() * HOVER_SPEED * (1.0 + 0.35 * float(_phase - 1))
			else:
				desired = Vector2.ZERO
			velocity = velocity.lerp(desired, 0.08)
			_cd -= delta
			if _cd <= 0.0:
				_state = "windup"
				_state_t = 0.0
		"windup":
			# Télégraphe : il se fige, gonfle, et sa lueur rouge s'embrase.
			velocity = velocity.lerp(Vector2.ZERO, 0.2)
			if _state_t >= WINDUP_TIME / (1.0 + 0.25 * float(_phase - 1)):
				_lunge_dir = (player.global_position + Vector2(0, -20) - global_position).normalized()
				_state = "lunge"
				_state_t = 0.0
				Sfx.varied(sfx_hurt, 1.15, 1.3)
		"lunge":
			# Ruée : contact = dégât. Esquive-la !
			velocity = _lunge_dir * LUNGE_SPEED
			for b in hitbox.get_overlapping_bodies():
				if b == player and b.has_method("take_damage"):
					b.take_damage(1, global_position)
			if _state_t >= LUNGE_TIME:
				_state = "recover"
				_state_t = 0.0
		"recover":
			# Récupération : lent et vulnérable — la fenêtre pour le frapper.
			velocity = velocity.lerp(Vector2.ZERO, 0.12)
			if _state_t >= RECOVER_TIME / (1.0 + 0.2 * float(_phase - 1)):
				_state = "idle"
				_state_t = 0.0
				_cd = LUNGE_CD / (1.0 + 0.3 * float(_phase - 1))

	move_and_slide()
	# Reste dans l'arène et à hauteur visible.
	var half := _r
	global_position.x = clampf(global_position.x, arena_min_x + half, arena_max_x - half)
	global_position.y = clampf(global_position.y, 190.0, 470.0)
	_animate(delta)

func _animate(delta: float) -> void:
	if _mask == null:
		return
	_mask.scale.x = _face
	# Flottement + gonflement à l'armement.
	var puff := 1.0
	if _state == "windup":
		puff = 1.0 + 0.18 * (_state_t / WINDUP_TIME)
	_mask.scale = Vector2(_face * puff, puff)
	_mask.position.y = sin(_t * 3.0) * 3.0
	_mask.rotation = 0.06 * sin(_t * 2.2)
	# Lueur d'avertissement : nulle au repos, vive pendant l'armement.
	if _warn != null:
		var wa := 0.0
		if _state == "windup":
			wa = 0.5 * (_state_t / WINDUP_TIME)
		elif _state == "lunge":
			wa = 0.5
		_warn.modulate.a = wa
	# Flash blanc quand il vient d'être touché.
	var tint := Color(1, 1, 1)
	if _hurt_flash > 0.0:
		tint = Color(2.2, 2.2, 2.2)
	_mask.modulate = _mask.modulate.lerp(tint, 0.5)

func _on_hitbox_body_entered(body: Node2D) -> void:
	# Le contact ne blesse que pendant la ruée (sinon on ne pourrait jamais
	# l'approcher pour le frapper). Le reste est géré par le sondage en ruée.
	if _dying or _state != "lunge":
		return
	if body.has_method("take_damage"):
		body.take_damage(1, global_position)

## Frappé au sabre : perd un point de vie. Renvoie false tant qu'il tient
## (le coup a porté sans tuer), true quand il tombe.
func die() -> bool:
	if _dying:
		return false
	health -= 1
	health_changed.emit(health, MAX_HEALTH)
	_hurt_flash = 0.18
	Sfx.varied(sfx_hurt, 0.85, 1.05)
	if health <= 0:
		_die_for_real()
		return true
	# À mi-vie : il se fissure, accélère et invoque deux petits masques.
	if not _phase2_done and health <= MAX_HEALTH / 2:
		_phase2_done = true
		_phase = 2
		_spawn_adds()
	return false

func _spawn_adds() -> void:
	var parent := get_parent()
	if parent == null:
		return
	Atmosphere.spark_burst(parent, global_position, Color(1.0, 0.5, 0.3))
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and pl.has_method("add_shake"):
		pl.add_shake(5.0)
	for s in [-1.0, 1.0]:
		var m := SMALL_MASK.instantiate()
		m.small = true
		m.spawn_vel = Vector2(s * 180.0, -140.0)
		m.position = global_position + Vector2(s * 30.0, -8.0)
		parent.call_deferred("add_child", m)

func _die_for_real() -> void:
	_dying = true
	active = false
	velocity = Vector2.ZERO
	hitbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	Sfx.varied(sfx_die, 0.8, 1.0)
	var parent := get_parent()
	Atmosphere.spark_burst(parent, global_position, Color(1.0, 0.55, 0.3))
	Atmosphere.death_burst(parent, global_position + Vector2(0, -10), Color(0.95, 0.6, 0.35))
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and pl.has_method("add_shake"):
		pl.add_shake(6.0)
	defeated.emit()
	# Dissolution : le grand masque se disloque vers le haut en s'effaçant.
	if _mask != null:
		var tw := _mask.create_tween()
		tw.set_parallel(true)
		tw.tween_property(_mask, "position:y", -60.0, 0.6)
		tw.tween_property(_mask, "rotation", _face * 1.4, 0.6)
		tw.tween_property(_mask, "scale", _mask.scale * 1.4, 0.6)
		tw.tween_property(_mask, "modulate:a", 0.0, 0.6)
		tw.chain().tween_callback(queue_free)
	else:
		queue_free()
