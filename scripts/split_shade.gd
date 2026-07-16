extends CharacterBody2D
## Masque d'Oni : un yokai — masque de démon japonais rouge à cornes et crocs —
## qui FLOTTE dans l'air en poursuivant Eneko. Tranché, il SE FEND en deux
## petits masques qui s'écartent en jaillissant, bien visibles. Les petits
## masques ne se refendent pas et meurent en un coup.

@export var speed := 74.0
@export var detect_range := 460.0
@export var small := false
@export var spawn_vel := Vector2.ZERO

const SELF_SCENE := preload("res://scenes/split_shade.tscn")
const RED := Color(0.72, 0.13, 0.12)
const RED_DARK := Color(0.5, 0.08, 0.09)
const BONE := Color(0.93, 0.88, 0.74)
const EYE := Color(1.0, 0.85, 0.2)

var player: Node2D = null
var _dying := false
var _t := 0.0
var _face := 1.0
var _r := 17.0
var _lunge_cd := 1.2

var _mask: Node2D
var _eyes: Array[Polygon2D] = []

@onready var hitbox: Area2D = $Hitbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_die: AudioStreamPlayer = $SfxDie

func _ready() -> void:
	# Yokai spectral : il flotte et traverse le décor (aucune collision monde).
	collision_mask = 0
	if Challenge.kensei:
		speed *= 1.25
	if small:
		_r = 11.0
		speed *= 1.4
		velocity = spawn_vel
	_build_mask()
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_ignore_player_body()
	var sh := ContactShadow.new()
	sh.width = _r * 1.4
	sh.max_drop = 520.0
	add_child(sh)
	move_child(sh, 0)

## Construit le masque d'Oni : lueur, face rouge, cornes, sourcils, yeux
## luisants, gueule à crocs.
func _build_mask() -> void:
	_mask = Node2D.new()
	add_child(_mask)
	var k := _r / 17.0

	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(1.0, 0.35, 0.25, 0.3)
	glow.scale = Vector2(k, k) * 2.0
	_mask.add_child(glow)

	# Cornes (derrière la face).
	for s in [-1.0, 1.0]:
		_poly(PackedVector2Array([
			Vector2(s * 8, -12), Vector2(s * 20, -30), Vector2(s * 14, -26),
			Vector2(s * 12, -12),
		]) , BONE, k)

	# Face : contour anguleux qui descend en menton pointu.
	_poly(PackedVector2Array([
		Vector2(-16, -12), Vector2(-14, -18), Vector2(0, -20), Vector2(14, -18),
		Vector2(16, -12), Vector2(14, 4), Vector2(6, 16), Vector2(0, 20),
		Vector2(-6, 16), Vector2(-14, 4),
	]), RED, k)
	# Ombrage du bas du visage.
	_poly(PackedVector2Array([
		Vector2(-14, 4), Vector2(14, 4), Vector2(6, 16), Vector2(0, 20), Vector2(-6, 16),
	]), RED_DARK, k)

	# Sourcils froncés.
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
			ep.append(Vector2(cos(a) * 3.2, sin(a) * 2.4))
		eye.polygon = ep
		eye.position = Vector2(s * 8.0 * k, -8.0 * k)
		eye.color = EYE
		_mask.add_child(eye)
		_eyes.append(eye)

	# Gueule sombre + crocs.
	_poly(PackedVector2Array([
		Vector2(-9, 6), Vector2(9, 6), Vector2(6, 13), Vector2(-6, 13),
	]), Color(0.1, 0.03, 0.04), k)
	for fx in [-6.0, -2.0, 2.0, 6.0]:
		var up := fx < 0.0
		if up:
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

func _ignore_player_body() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl is PhysicsBody2D:
		add_collision_exception_with(pl)

func _physics_process(delta: float) -> void:
	if _dying:
		return
	_t += delta
	_lunge_cd -= delta
	if player == null:
		player = get_tree().get_first_node_in_group("player")

	var desired := Vector2.ZERO
	if player != null and is_instance_valid(player):
		var to: Vector2 = player.global_position + Vector2(0, -24) - global_position
		if to.x != 0.0:
			_face = signf(to.x)
		if to.length() < detect_range:
			desired = to.normalized() * speed
			# Fonte rapide (« lunge ») de temps en temps quand il est proche.
			if _lunge_cd <= 0.0 and to.length() < 150.0:
				_lunge_cd = 2.0
				desired = to.normalized() * speed * 2.6

	# Poursuite flottante et souple, avec un léger flottement vertical.
	velocity = velocity.lerp(desired, 0.06)
	move_and_slide()
	position.y += sin(_t * 3.0) * 0.4

	# Le masque oscille (menaçant) et regarde Eneko.
	if _mask != null:
		_mask.scale.x = _face
		_mask.rotation = 0.08 * sin(_t * 2.2)

func _on_hitbox_body_entered(body: Node2D) -> void:
	if _dying:
		return
	if body.has_method("take_damage"):
		body.take_damage(1, global_position)

## Tranché : un grand masque se FEND en deux petits masques qui jaillissent
## (éclat au point de rupture), puis se dissout. Renvoie toujours true.
func die() -> bool:
	if _dying:
		return false
	_dying = true
	if not small:
		_split()
	hitbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	Sfx.varied(sfx_die, 0.85, 1.05)
	# Dissolution : le masque se disloque vers le haut en s'effaçant.
	if _mask != null:
		var tw := _mask.create_tween()
		tw.set_parallel(true)
		tw.tween_property(_mask, "position:y", -26.0, 0.3)
		tw.tween_property(_mask, "rotation", _face * 1.2, 0.3)
		tw.tween_property(_mask, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(queue_free)
	else:
		queue_free()
	return true

## Fait jaillir deux petits masques, l'un vers le haut-gauche, l'autre vers le
## haut-droite, bien séparés — le dédoublement est impossible à manquer.
func _split() -> void:
	var parent := get_parent()
	if parent == null:
		return
	Atmosphere.spark_burst(parent, global_position + Vector2(0, -6), Color(1.0, 0.5, 0.3))
	for s in [-1.0, 1.0]:
		var child := SELF_SCENE.instantiate()
		child.small = true
		child.spawn_vel = Vector2(s * 190.0, -150.0)
		child.position = global_position + Vector2(s * 14.0, -4.0)
		parent.call_deferred("add_child", child)
