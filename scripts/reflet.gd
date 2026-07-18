extends CharacterBody2D
## Boss final du Chapitre III : « Le Reflet ».
##
## Mécanique évoluée (parade-riposte) : le Reflet MIROITE Eneko — il se tient
## toujours à la position symétrique par rapport au centre de l'arène, hors de
## portée, protégé par un bouclier-miroir qui fait RICOCHER le sabre. On ne
## peut pas le frapper directement.
## Pour l'exposer, il faut RENVOYER ses propres lames-miroir : frapper au sabre
## la lame qu'il lance renvoie celle-ci ; touché par son reflet, son bouclier
## se brise et il s'effondre à ta portée un court instant — c'est là qu'on le
## tranche. Chaque phase le rend plus vif et multiplie ses lames.

signal defeated
signal health_changed(current: int, max_health: int)
signal phase_changed(new_phase: int)

const MAX_HEALTH := 12
const P2_HEALTH := 8
const P3_HEALTH := 4

const BLADE_SCRIPT := preload("res://scripts/mirror_blade.gd")

const SHIELD_Y := 430.0     # vol protégé, hors de portée du sabre
const EXPOSED_Y := 476.0    # s'effondre au sol, à portée
const MIRROR_LERP := [2.6, 3.6, 4.8]
const THROW_CD := [1.9, 1.4, 1.05]
const WIND_TIME := 0.45
const EXPOSE_TIME := 2.4
const BLADE_COUNT := [1, 2, 3]

var health := MAX_HEALTH
var phase := 1
var active := false

var _arena_min := 0.0
var _arena_max := 3000.0
var _center := 1500.0
var _player: Node2D
var _exposed := false
var _expose_t := 0.0
var _throw_t := 1.2
var _wind := 0.0
var _dying := false
var _t := 0.0
var _hurt_flash := 0.0
var _shield_flash := 0.0

var _sil: Node2D
var _shield_ring: Line2D
var _sword: Polygon2D
var _eyes: Array = []

@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var sfx_die: AudioStreamPlayer = $SfxDie
@onready var sfx_hurt: AudioStreamPlayer = $SfxHurt
@onready var sfx_clink: AudioStreamPlayer = $SfxClink

func _ready() -> void:
	_build_visual()
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	position.y = SHIELD_Y

func set_arena_bounds(min_x: float, max_x: float) -> void:
	_arena_min = min_x
	_arena_max = max_x
	_center = (min_x + max_x) * 0.5

func activate() -> void:
	active = true

# --- Boucle ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	_hurt_flash = maxf(0.0, _hurt_flash - delta * 5.0)
	_shield_flash = maxf(0.0, _shield_flash - delta * 5.0)
	_animate(delta)
	if not active or _dying:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return

	if _exposed:
		_expose_t -= delta
		global_position.y = lerpf(global_position.y, EXPOSED_Y, minf(1.0, delta * 6.0))
		if _expose_t <= 0.0:
			_exposed = false
		return

	# Bouclier levé : miroir d'Eneko, hors de portée, et jette ses lames.
	var target_x: float = clampf(2.0 * _center - _player.global_position.x, _arena_min + 60.0, _arena_max - 60.0)
	global_position.x = lerpf(global_position.x, target_x, minf(1.0, delta * float(MIRROR_LERP[phase - 1])))
	global_position.y = lerpf(global_position.y, SHIELD_Y, minf(1.0, delta * 4.0))
	_face_player()

	if _wind > 0.0:
		_wind -= delta
		if _wind <= 0.0:
			_throw_blades()
			_throw_t = float(THROW_CD[phase - 1])
	else:
		_throw_t -= delta
		if _throw_t <= 0.0:
			_wind = WIND_TIME

func _throw_blades() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var muzzle: Vector2 = global_position + Vector2(0, -6)
	var base := (_player.global_position - muzzle).normalized()
	var n: int = int(BLADE_COUNT[phase - 1])
	for i in n:
		var off := (float(i) - float(n - 1) * 0.5) * 0.2
		var dir := base.rotated(off)
		var b := BLADE_SCRIPT.new()
		b.setup(muzzle, muzzle + dir * 100.0, self, _player)
		get_parent().add_child(b)

## Le Reflet vient d'encaisser une de ses lames renvoyées : bouclier brisé,
## il s'effondre à portée pour un court instant.
func on_blade_reflected() -> void:
	if _dying or _exposed:
		return
	_exposed = true
	_expose_t = EXPOSE_TIME
	_wind = 0.0
	_throw_t = float(THROW_CD[phase - 1])
	_hurt_flash = 0.3
	Sfx.varied(sfx_clink, 0.8, 1.0)
	Atmosphere.spark_burst(get_parent(), global_position, Color(0.7, 0.9, 1.0))

# --- Dégâts ---------------------------------------------------------------

func _on_hitbox_body_entered(body: Node2D) -> void:
	if _dying or _exposed:
		return
	if body == _player and body.has_method("take_damage"):
		body.take_damage(1, global_position)

## Frappé au sabre. Tant que le bouclier tient (non exposé), le coup ricoche.
func die() -> bool:
	if _dying:
		return false
	if not _exposed:
		_shield_flash = 0.25
		Sfx.varied(sfx_clink, 0.95, 1.15)
		return false
	health -= 1
	health_changed.emit(health, MAX_HEALTH)
	_hurt_flash = 0.2
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
	hitbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	Sfx.varied(sfx_die, 0.7, 0.9)
	Atmosphere.spark_burst(get_parent(), global_position, Color(0.7, 0.9, 1.0))
	defeated.emit()
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_sil, "modulate:a", 0.0, 1.1)
	t.tween_property(_sil, "scale", Vector2(0.4, 1.6), 1.1)
	if _shield_ring != null:
		t.tween_property(_shield_ring, "modulate:a", 0.0, 0.5)
	t.chain().tween_callback(queue_free)

# --- Visuel ---------------------------------------------------------------

func _face_player() -> void:
	if _player != null and is_instance_valid(_player):
		var s := -1.0 if _player.global_position.x < global_position.x else 1.0
		_sil.scale.x = s

func _animate(_delta: float) -> void:
	# Bouclier visible tant qu'il n'est pas exposé ; pulsation + éclat au ricochet.
	if _shield_ring != null:
		_shield_ring.visible = not _exposed and not _dying
		var base := 0.5 + 0.35 * (0.5 + 0.5 * sin(_t * 3.0))
		_shield_ring.modulate.a = minf(1.0, base + _shield_flash * 2.0)
	# Épée levée qui s'illumine pendant la mise en garde (télégraphe).
	if _sword != null:
		var warn := clampf(1.0 - _wind / WIND_TIME, 0.0, 1.0) if _wind > 0.0 else 0.0
		_sword.color = Color(0.7, 0.9, 1.0).lerp(Color(1.0, 0.95, 0.6), warn)
	# Corps : plus clair quand exposé (vulnérable), éclat rouge quand touché.
	var tint := Color(0.4, 0.3, 0.6)
	if _exposed:
		tint = Color(0.7, 0.6, 0.9)
	tint = tint.lerp(Color(1.0, 0.6, 0.6), _hurt_flash)
	if _sil != null and _sil.get_child_count() > 0:
		var torso := _sil.get_child(0) as Polygon2D
		if torso != null:
			torso.color = tint

func _poly(parent: Node, pts: PackedVector2Array, c: Color, pos := Vector2.ZERO) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = c
	p.position = pos
	parent.add_child(p)
	return p

func _build_visual() -> void:
	_sil = Node2D.new()
	add_child(_sil)
	# Torse + jambes (index 0 : teinté dynamiquement).
	_poly(_sil, PackedVector2Array([
		Vector2(-16, 52), Vector2(16, 52), Vector2(13, -18), Vector2(0, -34), Vector2(-13, -18),
	]), Color(0.4, 0.3, 0.6))
	# Tête.
	_poly(_sil, PackedVector2Array([
		Vector2(-9, -34), Vector2(9, -34), Vector2(7, -52), Vector2(-7, -52),
	]), Color(0.32, 0.24, 0.5))
	# Yeux luisants.
	for sx in [-4.0, 4.0]:
		var e := _poly(_sil, PackedVector2Array([
			Vector2(sx - 2, -46), Vector2(sx + 2, -46), Vector2(sx + 2, -41), Vector2(sx - 2, -41),
		]), Color(0.7, 0.95, 1.0))
		_eyes.append(e)
	# Épée levée (renvoie la lumière) — index gardé dans _sword.
	_sword = _poly(_sil, PackedVector2Array([
		Vector2(14, -22), Vector2(19, -22), Vector2(40, -92), Vector2(34, -95),
	]), Color(0.7, 0.9, 1.0))
	# Bouclier-miroir : anneau de lumière autour du Reflet.
	_shield_ring = Line2D.new()
	_shield_ring.width = 3.0
	_shield_ring.default_color = Color(0.6, 0.9, 1.0, 0.7)
	_shield_ring.closed = true
	var rpts := PackedVector2Array()
	for i in 26:
		var a := i * TAU / 26.0
		rpts.append(Vector2(cos(a) * 46.0, sin(a) * 58.0))
	_shield_ring.points = rpts
	_shield_ring.position = Vector2(0, 2)
	add_child(_shield_ring)
