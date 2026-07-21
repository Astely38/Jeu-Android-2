extends CharacterBody2D
## Oni au pavois : guerrier spectral qui avance BOUCLIER EN AVANT vers Eneko.
## Les coups de sabre portés de FACE ricochent sur le pavois — il ne tombe
## qu'en le frappant DANS LE DOS. Comme il se retourne LENTEMENT quand Eneko
## passe de l'autre côté, la RUÉE (invincible, elle traverse les ennemis) est
## la clé : on s'en sert pour filer derrière lui et le trancher avant qu'il
## pivote. Inflige un dégât au contact.

@export var speed := 54.0
@export var detect_range := 760.0

const GRAVITY := 980.0
const TURN_TIME := 0.62            # délai de volte-face = fenêtre pour frapper le dos

const ARMOR := Color(0.3, 0.32, 0.44)
const ARMOR_DARK := Color(0.17, 0.18, 0.26)
const SHIELD := Color(0.5, 0.18, 0.2)
const SHIELD_HI := Color(0.88, 0.55, 0.32)
const EDGE := Color(0.72, 0.82, 0.98)
const EYE := Color(1.0, 0.78, 0.32)

var player: Node2D = null
var _dying := false
var _t := 0.0
var _face := -1.0                 # sens du regard / côté du bouclier
var _turn_t := 0.0
var _shield_flash := 0.0

var _gfx: Node2D
var _shield: Node2D

@onready var hitbox: Area2D = $Hitbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_die: AudioStreamPlayer = $SfxDie
@onready var sfx_clink: AudioStreamPlayer = $SfxClink

func _ready() -> void:
	if Challenge.kensei:
		speed *= 1.2
	# Escalade de vitesse selon le chapitre (différée : le niveau fixe le
	# facteur après avoir posé ses ennemis, voir Challenge.start_level).
	_apply_chapter_speed.call_deferred()
	_build_visual()
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_ignore_player_body()
	var sh := ContactShadow.new()
	sh.width = 34.0
	add_child(sh)
	move_child(sh, 0)

func _apply_chapter_speed() -> void:
	speed *= Challenge.speed_scale

## Le corps d'Eneko n'est jamais un obstacle physique (indispensable pour que
## la ruée le traverse et passe dans le dos).
func _ignore_player_body() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl is PhysicsBody2D:
		add_collision_exception_with(pl)

func _physics_process(delta: float) -> void:
	if _dying:
		return
	_t += delta
	_shield_flash = maxf(0.0, _shield_flash - delta * 5.0)

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	var move_dir := 0.0
	if player != null and is_instance_valid(player):
		var dx: float = player.global_position.x - global_position.x
		# Volte-face LENTE : il faut TURN_TIME pour se retourner quand Eneko
		# passe derrière — c'est là qu'on frappe le dos.
		var want := signf(dx)
		if want != 0.0 and want != _face:
			_turn_t += delta
			if _turn_t >= TURN_TIME:
				_face = want
				_turn_t = 0.0
		else:
			_turn_t = 0.0
		# Avance bouclier en avant s'il « voit » Eneko à portée.
		if absf(dx) < detect_range:
			move_dir = _face

	# Ne charge jamais dans le vide.
	if is_on_floor() and move_dir != 0.0 and not _ground_ahead(move_dir):
		move_dir = 0.0

	velocity.x = move_dir * speed
	move_and_slide()
	_animate()

func _ground_ahead(dir: float) -> bool:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(dir * 28.0, -2.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 54.0), 1)
	q.exclude = [get_rid()]
	return not space.intersect_ray(q).is_empty()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if _dying:
		return
	if body.has_method("take_damage"):
		body.take_damage(1, global_position)

## Frappé au sabre. De FACE (côté du pavois) le coup RICOCHE (renvoie false) ;
## DANS LE DOS, l'oni s'effondre (renvoie true).
func die() -> bool:
	if _dying:
		return false
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and is_instance_valid(pl):
		if signf(pl.global_position.x - global_position.x) == _face:
			_shield_flash = 0.35            # le pavois pare : ricochet
			Sfx.varied(sfx_clink, 0.9, 1.1)
			return false
	_die_for_real()
	return true

func _die_for_real() -> void:
	_dying = true
	velocity = Vector2.ZERO
	hitbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	Sfx.varied(sfx_die, 0.85, 1.05)
	Atmosphere.release_soul(get_parent(), global_position + Vector2(0, -22), Color(0.7, 0.8, 1.0))
	if _gfx != null:
		var tw := _gfx.create_tween()
		tw.set_parallel(true)
		tw.tween_property(_gfx, "modulate:a", 0.0, 0.5)
		tw.tween_property(_gfx, "rotation", _face * 0.6, 0.5)
		tw.tween_property(_gfx, "position:y", 10.0, 0.5)
		tw.chain().tween_callback(queue_free)
	else:
		queue_free()

# --- Visuel ---------------------------------------------------------------

func _build_visual() -> void:
	_gfx = Node2D.new()
	add_child(_gfx)

	# Jambes.
	_shape(_gfx, PackedVector2Array([
		Vector2(-9, 22), Vector2(-2, 22), Vector2(-2, 4), Vector2(-9, 4)]), ARMOR_DARK)
	_shape(_gfx, PackedVector2Array([
		Vector2(2, 22), Vector2(9, 22), Vector2(9, 4), Vector2(2, 4)]), ARMOR_DARK)

	# Torse (armure).
	_shape(_gfx, PackedVector2Array([
		Vector2(-11, 5), Vector2(11, 5), Vector2(9, -18), Vector2(-9, -18)]), ARMOR)
	# Ceinture sombre.
	_shape(_gfx, PackedVector2Array([
		Vector2(-11, 5), Vector2(11, 5), Vector2(10, 0), Vector2(-10, 0)]), ARMOR_DARK)

	# Casque (kabuto) + cornes.
	_shape(_gfx, PackedVector2Array([
		Vector2(-9, -18), Vector2(9, -18), Vector2(7, -31), Vector2(0, -37), Vector2(-7, -31)]), ARMOR)
	_shape(_gfx, PackedVector2Array([
		Vector2(-2, -33), Vector2(-9, -44), Vector2(-4, -32)]), SHIELD_HI)
	_shape(_gfx, PackedVector2Array([
		Vector2(2, -33), Vector2(9, -44), Vector2(4, -32)]), SHIELD_HI)

	# Yeux luisants sous le casque.
	for s in [-1.0, 1.0]:
		var eye := Polygon2D.new()
		eye.polygon = PackedVector2Array([
			Vector2(s * 2, -24), Vector2(s * 6, -24), Vector2(s * 6, -21), Vector2(s * 2, -21)])
		eye.color = EYE
		_gfx.add_child(eye)

	# Grand pavois DEVANT (côté +x ; le flip par scale.x le fait passer du
	# côté du regard). C'est l'élément clé : il montre le côté protégé.
	_shield = Node2D.new()
	_shield.position = Vector2(13, -7)
	_gfx.add_child(_shield)
	_shape(_shield, PackedVector2Array([
		Vector2(0, -27), Vector2(8, -24), Vector2(11, 0), Vector2(8, 24), Vector2(0, 27)]), SHIELD)
	# Renfort vertical + blason.
	_shape(_shield, PackedVector2Array([
		Vector2(3, -24), Vector2(6, -24), Vector2(6, 24), Vector2(3, 24)]), SHIELD_HI)
	var mon := Polygon2D.new()
	var mp := PackedVector2Array()
	for i in 12:
		var a := i * TAU / 12.0
		mp.append(Vector2(5 + cos(a) * 4.5, cos(a) * 0.0 + sin(a) * 4.5))
	mon.polygon = mp
	mon.color = SHIELD_HI
	_shield.add_child(mon)

func _shape(parent: Node, pts: PackedVector2Array, fill: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = fill
	parent.add_child(p)
	var l := Line2D.new()
	l.points = pts
	l.closed = true
	l.width = 1.6
	l.default_color = EDGE
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	parent.add_child(l)

func _animate() -> void:
	if _gfx == null:
		return
	_gfx.scale.x = _face
	# Balancement de marche.
	if absf(velocity.x) > 5.0:
		_gfx.rotation = 0.035 * sin(_t * 9.0)
	else:
		_gfx.rotation = lerpf(_gfx.rotation, 0.0, 0.2)
	# Tremblement quand il amorce sa volte-face (télégraphe de l'ouverture).
	_gfx.position.x = sin(_t * 40.0) * 1.6 if _turn_t > 0.0 else 0.0
	# Éclat du pavois au ricochet.
	if _shield != null:
		_shield.modulate = Color(1, 1, 1).lerp(Color(2.2, 2.2, 2.4), clampf(_shield_flash * 2.0, 0.0, 1.0))
