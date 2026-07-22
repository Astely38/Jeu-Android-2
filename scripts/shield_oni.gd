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

const ARMOR := Color(0.28, 0.31, 0.52)       # armure indigo spectrale
const ARMOR_HI := Color(0.48, 0.53, 0.78)    # reflet clair des plaques
const ARMOR_DARK := Color(0.14, 0.15, 0.27)  # creux / dessous
const LACE := Color(0.74, 0.22, 0.26)        # laçage rouge (odoshi)
const GOLD := Color(0.96, 0.79, 0.36)        # ornements dorés (maedate, blason)
const SHIELD := Color(0.44, 0.13, 0.15)      # laque rouge sombre du pavois
const SHIELD_HI := Color(0.66, 0.22, 0.24)   # reflet du pavois
const EDGE := Color(0.8, 0.86, 1.0)          # liseré spectral lumineux
const EYE := Color(1.0, 0.56, 0.2)           # œil ambre-braise
const AURA := Color(0.42, 0.48, 0.9)         # halo spectral bleu

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
	Atmosphere.death_burst(get_parent(), global_position + Vector2(0, -18), Color(0.6, 0.7, 1.0))
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

	# Halo spectral (fantôme + lisibilité).
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(AURA.r, AURA.g, AURA.b, 0.3)
	glow.scale = Vector2(1.9, 2.1)
	glow.position = Vector2(0, -6)
	_gfx.add_child(glow)

	# Jambes (sous la jupe d'armure).
	_fill(_gfx, PackedVector2Array([Vector2(-7, 22), Vector2(-2, 22), Vector2(-3, 12), Vector2(-7, 12)]), ARMOR_DARK)
	_fill(_gfx, PackedVector2Array([Vector2(2, 22), Vector2(7, 22), Vector2(7, 12), Vector2(3, 12)]), ARMOR_DARK)

	# Jupe d'armure (kusazuri) : plaques lacées de rouge.
	_shape(_gfx, PackedVector2Array([Vector2(-10, 2), Vector2(10, 2), Vector2(9, 15), Vector2(-9, 15)]), ARMOR)
	for yy in [6.0, 10.0]:
		_fill(_gfx, PackedVector2Array([Vector2(-9, yy), Vector2(9, yy), Vector2(9, yy + 1.6), Vector2(-9, yy + 1.6)]), LACE)

	# Torse (dō) : armure lamellaire lacée de rouge + reflet central.
	_shape(_gfx, PackedVector2Array([Vector2(-11, 3), Vector2(11, 3), Vector2(9, -17), Vector2(-9, -17)]), ARMOR)
	for yy in [-13.0, -8.0, -3.0]:
		_fill(_gfx, PackedVector2Array([Vector2(-9, yy), Vector2(9, yy), Vector2(9, yy + 1.8), Vector2(-9, yy + 1.8)]), LACE)
	_fill(_gfx, PackedVector2Array([Vector2(-2, -16), Vector2(2, -16), Vector2(2, 2), Vector2(-2, 2)]), ARMOR_HI)

	# Épaulières (sode).
	for s in [-1.0, 1.0]:
		_shape(_gfx, PackedVector2Array([
			Vector2(s * 8, -16), Vector2(s * 16, -14), Vector2(s * 15, -3), Vector2(s * 8, -5)]), ARMOR_HI)

	# Gorge sombre.
	_fill(_gfx, PackedVector2Array([Vector2(-6, -17), Vector2(6, -17), Vector2(5, -22), Vector2(-5, -22)]), ARMOR_DARK)

	# Casque (kabuto) : dôme + bord relevé.
	_shape(_gfx, PackedVector2Array([
		Vector2(-9, -22), Vector2(9, -22), Vector2(8, -33), Vector2(0, -39), Vector2(-8, -33)]), ARMOR)
	_fill(_gfx, PackedVector2Array([Vector2(-10, -22), Vector2(10, -22), Vector2(8, -25), Vector2(-8, -25)]), ARMOR_HI)
	# Cornes dorées (kuwagata) en V + maedate frontal.
	_shape(_gfx, PackedVector2Array([Vector2(-3, -34), Vector2(-13, -47), Vector2(-6, -33)]), GOLD)
	_shape(_gfx, PackedVector2Array([Vector2(3, -34), Vector2(13, -47), Vector2(6, -33)]), GOLD)
	_fill(_gfx, PackedVector2Array([Vector2(-3, -33), Vector2(3, -33), Vector2(2, -40), Vector2(-2, -40)]), GOLD)

	# Masque menpo sombre + yeux ambre-braise.
	_fill(_gfx, PackedVector2Array([Vector2(-7, -30), Vector2(7, -30), Vector2(6, -22), Vector2(-6, -22)]), ARMOR_DARK)
	for s in [-1.0, 1.0]:
		var eye := Polygon2D.new()
		var ep := PackedVector2Array()
		for i in 8:
			var a := i * TAU / 8.0
			ep.append(Vector2(cos(a) * 2.3, sin(a) * 1.6))
		eye.polygon = ep
		eye.position = Vector2(s * 4.0, -26.0)
		eye.color = EYE
		_gfx.add_child(eye)

	# Grand pavois DEVANT (côté +x ; le flip par scale.x le porte du côté du
	# regard). C'est l'élément clé : il montre le côté protégé.
	_shield = Node2D.new()
	_shield.position = Vector2(14, -8)
	_gfx.add_child(_shield)
	_shape(_shield, PackedVector2Array([
		Vector2(0, -30), Vector2(7, -27), Vector2(10, 0), Vector2(7, 27), Vector2(0, 30)]), SHIELD)
	_fill(_shield, PackedVector2Array([
		Vector2(2, -25), Vector2(4, -24), Vector2(6, 0), Vector2(4, 24), Vector2(2, 25)]), SHIELD_HI)
	# Renforts dorés haut et bas.
	_fill(_shield, PackedVector2Array([Vector2(1, -22), Vector2(8, -20), Vector2(8, -18), Vector2(1, -20)]), GOLD)
	_fill(_shield, PackedVector2Array([Vector2(1, 20), Vector2(8, 18), Vector2(8, 20), Vector2(1, 22)]), GOLD)
	# Blason (mon) doré cerclé.
	var mon := Polygon2D.new()
	var mp := PackedVector2Array()
	for i in 14:
		var a := i * TAU / 14.0
		mp.append(Vector2(5.0 + cos(a) * 5.0, sin(a) * 5.0))
	mon.polygon = mp
	mon.color = GOLD
	_shield.add_child(mon)
	var mon_in := Polygon2D.new()
	var mpi := PackedVector2Array()
	for i in 14:
		var a := i * TAU / 14.0
		mpi.append(Vector2(5.0 + cos(a) * 2.4, sin(a) * 2.4))
	mon_in.polygon = mpi
	mon_in.color = SHIELD
	_shield.add_child(mon_in)

## Polygone plein sans liseré (détails internes : lamelles, reflets, dorures).
func _fill(parent: Node, pts: PackedVector2Array, color: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color
	parent.add_child(p)

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
