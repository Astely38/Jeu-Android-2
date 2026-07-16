extends CharacterBody2D
## Gelée d'Ombre : une créature amorphe et gélatineuse (dessinée à la main,
## PAS le sprite humanoïde des autres ennemis) qui rampe vers Eneko en
## tremblotant. Tranchée, elle SE DÉDOUBLE bruyamment en deux gelées plus
## petites qui bondissent de chaque côté. Les petites meurent en un coup.

@export var speed := 92.0
@export var detect_range := 380.0
@export var attack_range := 40.0
## Petite gelée issue d'un dédoublement : ne se rescinde pas.
@export var small := false
## Élan donné aux petites gelées quand elles jaillissent.
@export var spawn_vx := 0.0
@export var spawn_vy := 0.0

const GRAVITY := 980.0
const SELF_SCENE := preload("res://scenes/split_shade.tscn")
## Corps froid et spectral, distinct des Ombres violettes et des braises.
const OOZE := Color(0.16, 0.4, 0.5)
const OOZE_RIM := Color(0.5, 0.95, 1.0)

var player: Node2D = null
var lock_timer := 0.0
var _dying := false
var _t := 0.0
var _face := 1.0
var _r := 15.0

var _body: Node2D
var _blob: Polygon2D
var _rim: Polygon2D
var _eyes: Array[Polygon2D] = []
var _glow: Sprite2D

@onready var hitbox: Area2D = $Hitbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_die: AudioStreamPlayer = $SfxDie

func _ready() -> void:
	if Challenge.kensei:
		speed *= 1.25
	if small:
		_r = 9.0
		speed *= 1.5
		detect_range += 80.0
		velocity = Vector2(spawn_vx, spawn_vy)
	_build_blob()
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_ignore_player_body()
	var sh := ContactShadow.new()
	sh.width = _r * 1.5
	add_child(sh)
	move_child(sh, 0)

## Construit la gelée : halo, corps rond, reflet et deux yeux luisants.
func _build_blob() -> void:
	_body = Node2D.new()
	# La demi-hauteur de la collision est 14 : on pose la gelée au sol.
	_body.position = Vector2(0, 13.0 - _r)
	add_child(_body)

	_glow = Sprite2D.new()
	_glow.texture = load("res://assets/mist.svg")
	_glow.modulate = Color(OOZE_RIM.r, OOZE_RIM.g, OOZE_RIM.b, 0.25)
	_glow.scale = Vector2(_r / 16.0, _r / 16.0) * 1.6
	_body.add_child(_glow)

	# Corps rond légèrement aplati.
	var pts := PackedVector2Array()
	for i in 20:
		var a := i * TAU / 20.0
		pts.append(Vector2(cos(a) * _r, sin(a) * _r * 0.82 + 2.0))
	_blob = Polygon2D.new()
	_blob.polygon = pts
	_blob.color = OOZE
	_body.add_child(_blob)

	# Liseré lumineux sur le dessus.
	var rim := PackedVector2Array()
	for i in 11:
		var a := PI + i * PI / 10.0
		rim.append(Vector2(cos(a) * _r * 0.92, sin(a) * _r * 0.72 + 1.0))
	_rim = Polygon2D.new()
	_rim.polygon = rim
	_rim.color = Color(OOZE_RIM.r, OOZE_RIM.g, OOZE_RIM.b, 0.5)
	_body.add_child(_rim)

	# Deux yeux luisants.
	for sx in [-0.4, 0.4]:
		var eye := Polygon2D.new()
		var ep := PackedVector2Array()
		for i in 10:
			var a := i * TAU / 10.0
			ep.append(Vector2(cos(a) * _r * 0.16, sin(a) * _r * 0.22))
		eye.polygon = ep
		eye.position = Vector2(sx * _r, -_r * 0.15)
		eye.color = Color(0.95, 1.0, 1.0, 0.95)
		_body.add_child(eye)
		_eyes.append(eye)

func _ignore_player_body() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl is PhysicsBody2D:
		add_collision_exception_with(pl)

func _physics_process(delta: float) -> void:
	if _dying:
		return
	_t += delta
	if player == null:
		player = get_tree().get_first_node_in_group("player")

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	if lock_timer > 0.0:
		lock_timer -= delta

	if player != null and lock_timer <= 0.0:
		var dx: float = player.global_position.x - global_position.x
		var dy: float = player.global_position.y - global_position.y
		var dist := absf(dx)
		if dist < detect_range and absf(dy) < 90.0:
			var dir := signf(dx)
			if dir != 0.0:
				_face = dir
			if dist > attack_range:
				velocity.x = dir * speed
			else:
				velocity.x = 0.0
				lock_timer = 0.5
		else:
			velocity.x = move_toward(velocity.x, 0.0, speed)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)

	move_and_slide()

	# Tremblotement gélatineux + regard qui glisse vers Eneko.
	if _body != null:
		var wob := 0.12 * sin(_t * 7.0)
		_body.scale = Vector2(1.0 + wob, 1.0 - wob)
		var i := 0
		for eye in _eyes:
			var base := (-0.4 if i == 0 else 0.4) * _r
			eye.position.x = base + _face * _r * 0.14
			i += 1

func _on_hitbox_body_entered(body: Node2D) -> void:
	if _dying:
		return
	if body.has_method("take_damage"):
		body.take_damage(1, global_position)

## Tranchée : si c'est une grande gelée, elle se DÉDOUBLE (jet d'étincelles +
## deux moitiés qui bondissent), puis se dissout. Renvoie toujours true.
func die() -> bool:
	if _dying:
		return false
	_dying = true
	if not small:
		_split()
	velocity = Vector2.ZERO
	hitbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	Sfx.varied(sfx_die, 1.1, 1.3)
	# Dissolution : le corps s'aplatit et s'efface.
	if _body != null:
		var tw := _body.create_tween()
		tw.set_parallel(true)
		tw.tween_property(_body, "scale", Vector2(1.6, 0.2), 0.28)
		tw.tween_property(_body, "modulate:a", 0.0, 0.28)
		tw.chain().tween_callback(queue_free)
	else:
		queue_free()
	return true

## Deux petites gelées jaillissent bien visiblement de part et d'autre, avec
## un éclat lumineux au point de scission.
func _split() -> void:
	var parent := get_parent()
	if parent == null:
		return
	Atmosphere.spark_burst(parent, global_position + Vector2(0, -_r), OOZE_RIM)
	for s in [-1.0, 1.0]:
		var child := SELF_SCENE.instantiate()
		child.small = true
		child.spawn_vx = s * 135.0
		child.spawn_vy = -250.0
		child.position = global_position + Vector2(s * 10.0, -8.0)
		parent.call_deferred("add_child", child)
