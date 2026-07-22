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

const MAX_HEALTH := 15
const P2_HEALTH := 10
const P3_HEALTH := 5

const BLADE_SCRIPT := preload("res://scripts/mirror_blade.gd")
const SAMURAI := "res://assets/character/samurai/"

const SHIELD_Y := 392.0     # vol protégé, au-dessus d'Eneko (ne le bouscule pas)
const EXPOSED_Y := 477.0    # s'effondre au sol, à portée (hauteur d'Eneko)
const EXPOSE_REACH := 40.0  # distance latérale à laquelle il s'effondre (portée sabre ~43)
const MIRROR_LERP := [3.2, 4.4, 5.6]
const THROW_CD := [1.5, 1.1, 0.8]
const WIND_TIME := 0.4
const EXPOSE_TIME := 2.3
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
var _volley := 0
## Point figé où le Reflet s'effondre, calculé UNE SEULE FOIS à l'instant où
## son bouclier se brise (voir on_blade_reflected). Sans ça, sa cible étant
## recalculée chaque frame sur la position du joueur, il « suit » Eneko même
## couché au sol — ce qui casse toute lisibilité de la mise à terre.
var _expose_target := Vector2.ZERO
var _dying := false
var _t := 0.0
var _hurt_flash := 0.0
var _shield_flash := 0.0

var _anim: AnimatedSprite2D
var _shield_ring: Line2D
var _prev_x := 0.0

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
		# Brisé, le Reflet s'effondre sur un point FIGÉ dès l'instant où son
		# bouclier a cédé (voir on_blade_reflected) — il ne suit plus Eneko une
		# fois à terre, sans quoi la mise à terre perdrait toute lisibilité.
		global_position = global_position.lerp(_expose_target, minf(1.0, delta * 7.0))
		if _expose_t <= 0.0:
			_exposed = false
			# Le bouclier se reforme : il redevient solide (et miroite au loin).
			set_collision_layer_value(3, false)
			set_collision_layer_value(2, true)
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
	_volley += 1
	var muzzle: Vector2 = global_position + Vector2(0, -6)
	var base := (_player.global_position - muzzle).normalized()
	if _pick_pattern() == "fan":
		# Large éventail : les lames balaient un arc autour d'Eneko — on ne
		# l'esquive plus d'un simple pas de côté, il faut se placer ENTRE elles.
		var fan_n := 3 if phase == 2 else 5
		var arc := 1.1 if phase == 2 else 1.5
		_spawn_blades(muzzle, base, fan_n, arc)
	else:
		# Tir visé serré, droit sur Eneko (esquive latérale ou renvoi au sabre).
		var n: int = int(BLADE_COUNT[phase - 1])
		_spawn_blades(muzzle, base, n, 0.2 * float(maxi(1, n - 1)))

## Détermine le motif du prochain tir selon la phase : la phase 1 vise toujours,
## les phases 2-3 alternent tir visé et éventail (l'éventail est plus large et
## plus fourni en phase 3).
func _pick_pattern() -> String:
	if phase == 1:
		return "aimed"
	return "fan" if _volley % 2 == 0 else "aimed"

## Lance n lames-miroir réparties sur un arc `arc` (radians) centré sur `base`.
func _spawn_blades(muzzle: Vector2, base: Vector2, n: int, arc: float) -> void:
	for i in n:
		var frac := 0.0 if n <= 1 else (float(i) / float(n - 1) - 0.5)
		var dir := base.rotated(frac * arc)
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
	# Point d'effondrement calculé UNE FOIS, à portée de sabre d'Eneko — mais À
	# CÔTÉ, jamais superposé : juste devant le héros, du côté où il se trouve
	# déjà. Figé ici (pas recalculé chaque frame), sans quoi le Reflet couché
	# suivrait Eneko au lieu de rester immobile à terre.
	if _player != null and is_instance_valid(_player):
		var side := signf(global_position.x - _player.global_position.x)
		if side == 0.0:
			side = -1.0 if (_anim != null and _anim.flip_h) else 1.0
		var reach_x := clampf(_player.global_position.x + side * EXPOSE_REACH,
			_arena_min + 40.0, _arena_max - 40.0)
		_expose_target = Vector2(reach_x, EXPOSED_Y)
		# Même convention que _face_player() : flip_h vrai quand le joueur est
		# à gauche du point d'atterrissage (reach_x = player.x + side*REACH).
		if _anim != null:
			_anim.flip_h = side > 0.0
	else:
		_expose_target = Vector2(global_position.x, EXPOSED_Y)
	# Déphasé le temps de l'exposition : il ne BLOQUE plus Eneko (il ne le
	# pousse plus) mais reste tranchable (le sabre touche la couche 3).
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, true)
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
	t.tween_property(_anim, "modulate:a", 0.0, 1.1)
	t.tween_property(_anim, "scale", Vector2(0.4, 1.6), 1.1)
	if _shield_ring != null:
		t.tween_property(_shield_ring, "modulate:a", 0.0, 0.5)
	t.chain().tween_callback(queue_free)

# --- Visuel ---------------------------------------------------------------

func _face_player() -> void:
	if _anim != null and _player != null and is_instance_valid(_player):
		_anim.flip_h = _player.global_position.x < global_position.x

func _animate(delta: float) -> void:
	# Anneau-bouclier : visible tant qu'il n'est pas exposé ; éclat au ricochet.
	if _shield_ring != null:
		_shield_ring.visible = not _exposed and not _dying
		var base := 0.5 + 0.35 * (0.5 + 0.5 * sin(_t * 3.0))
		_shield_ring.modulate.a = minf(1.0, base + _shield_flash * 2.0)
	if _anim == null or _dying:
		return
	# Orientation figée pendant l'exposition (voir on_blade_reflected) : ne PAS
	# re-suivre le joueur ici, sans quoi le Reflet couché pivoterait avec lui.
	if not _exposed:
		_face_player()
	# Choix de l'animation d'Eneko selon l'état.
	var want := "idle"
	if not _exposed:
		if _wind > 0.0:
			want = "attack"
		elif absf(global_position.x - _prev_x) > 0.5:
			want = "run"
	else:
		want = "hurt"
	if _anim.animation != want:
		_anim.play(want)
	_prev_x = global_position.x
	# Posture : DEBOUT normalement ; À TERRE (couché, vulnérable) quand il est
	# exposé — il bascule au sol sous le choc de sa lame renvoyée, puis se
	# relève quand le bouclier se reforme.
	var want_rot := 0.0
	var want_pos := Vector2(0, -40)
	if _exposed:
		var fall := 1.0 if _anim.flip_h else -1.0
		want_rot = deg_to_rad(88.0) * fall
		# Couché AU SOL : le sprite (normalement calé à -40, torse en l'air) est
		# descendu près du contact-sol pour que le corps repose sur la plateforme
		# au lieu de flotter à mi-hauteur.
		want_pos = Vector2(fall * 26.0, 16.0)
	_anim.rotation = lerp_angle(_anim.rotation, want_rot, minf(1.0, delta * 9.0))
	_anim.position = _anim.position.lerp(want_pos, minf(1.0, delta * 9.0))
	# Teinte miroir : bleu froid ; plus clair quand exposé (vulnérable),
	# éclat rouge quand il encaisse un coup.
	var tint := Color(0.55, 0.74, 1.0)
	if _exposed:
		tint = Color(0.86, 0.93, 1.0)
	# Télégraphe : il s'illumine pendant la mise en garde, juste avant de lancer.
	if _wind > 0.0:
		tint = tint.lerp(Color(1.0, 1.0, 1.0), 0.7 * (1.0 - _wind / WIND_TIME))
	tint = tint.lerp(Color(1.0, 0.5, 0.5), _hurt_flash)
	_anim.modulate = tint

func _build_visual() -> void:
	# Le Reflet EST Eneko : même sprite, même taille, même calage au sol
	# (offset -40) que le héros — un vrai jumeau-miroir, teinté verre froid.
	_anim = AnimatedSprite2D.new()
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim.position = Vector2(0, -40)
	_anim.scale = Vector2(1.0, 1.0)
	_anim.sprite_frames = SpriteSheet.build([
		{"name": "idle", "path": SAMURAI + "Idle.png", "frames": 6, "fps": 8.0, "loop": true},
		{"name": "run", "path": SAMURAI + "Run.png", "frames": 8, "fps": 13.0, "loop": true},
		{"name": "attack", "path": SAMURAI + "Attack_1.png", "frames": 6, "fps": 14.0, "loop": false},
		{"name": "hurt", "path": SAMURAI + "Hurt.png", "frames": 2, "fps": 9.0, "loop": false},
	])
	_anim.play("idle")
	add_child(_anim)
	_prev_x = global_position.x
	# Bouclier-miroir : anneau de lumière autour du Reflet.
	_shield_ring = Line2D.new()
	_shield_ring.width = 3.0
	_shield_ring.default_color = Color(0.6, 0.9, 1.0, 0.7)
	_shield_ring.closed = true
	var rpts := PackedVector2Array()
	for i in 26:
		var a := i * TAU / 26.0
		rpts.append(Vector2(cos(a) * 40.0, sin(a) * 62.0))
	_shield_ring.points = rpts
	_shield_ring.position = Vector2(0, -40)
	add_child(_shield_ring)
