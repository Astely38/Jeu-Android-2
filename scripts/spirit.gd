extends CharacterBody2D
## Yūrei tireur : esprit spectral qui flotte sur place (aucune gravité)
## en ondulant, et crache des orbes corrompus vers Eneko quand il est à
## portée. Premier ennemi à distance du jeu : ses tirs s'esquivent d'une
## ruée ou se dissipent d'un coup de sabre. Lui-même meurt en un coup.

const ONRE := "res://assets/enemies/onre/"
const ORB_SCENE := preload("res://scenes/spirit_orb.tscn")

const FIRE_RANGE := 420.0
const FIRE_COOLDOWN := 2.4
const PROJECTILE_SPEED := 170.0

var player: Node2D = null
var _t := 0.0
var _cooldown := 1.4
var _dying := false
var _start_y := 0.0
var _hover_y := 0.0  # descente progressive vers Eneko quand il approche
var _base_tint := Color(1, 1, 1)

@onready var anim: AnimatedSprite2D = $Anim
@onready var hitbox: Area2D = $Hitbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_die: AudioStreamPlayer = $SfxDie

func _ready() -> void:
	_start_y = position.y
	anim.sprite_frames = SpriteSheet.build([
		{"name": "float", "path": ONRE + "Walk.png", "frames": 7, "fps": 7.0, "loop": true},
		{"name": "dead", "path": ONRE + "Dead.png", "frames": 6, "fps": 10.0, "loop": false},
	])
	anim.play("float")
	_base_tint = anim.modulate
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_ignore_player_body()

## Le corps d'Eneko n'est jamais un obstacle physique pour ce Yūrei
## (voir enemy.gd : indispensable pour que la ruée traverse).
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
	if player == null or not is_instance_valid(player):
		position.y = _start_y + sin(_t * 2.0) * 10.0
		return

	var to_player: Vector2 = player.global_position - global_position
	anim.flip_h = to_player.x < 0.0

	# Quand Eneko approche, le Yūrei fond lentement vers lui : il devient
	# plus menaçant... mais passe à portée de sabre.
	var target := 0.0
	if absf(to_player.x) < 260.0:
		target = clampf(player.global_position.y - 30.0 - _start_y, -20.0, 130.0)
	_hover_y = move_toward(_hover_y, target, 46.0 * delta)
	position.y = _start_y + _hover_y + sin(_t * 2.0) * 10.0

	_cooldown -= delta
	if _cooldown <= 0.0 and to_player.length() < FIRE_RANGE and absf(to_player.y) < 260.0:
		_cooldown = FIRE_COOLDOWN
		_fire(to_player.normalized())

func _fire(dir: Vector2) -> void:
	# Petit éclat au départ du tir, pour le télégraphier.
	anim.modulate = Color(1.6, 1.4, 1.9)
	var t := create_tween()
	t.tween_property(anim, "modulate", _base_tint, 0.3)
	var orb := ORB_SCENE.instantiate()
	orb.position = global_position + Vector2(0, -14)
	orb.direction = dir
	orb.speed = PROJECTILE_SPEED
	get_parent().add_child(orb)

func _on_hitbox_body_entered(body: Node2D) -> void:
	if _dying:
		return
	if body.has_method("take_damage"):
		body.take_damage(1, global_position)

## Tranché au sabre : flash blanc puis dissipation spirituelle.
func die() -> void:
	if _dying:
		return
	_dying = true
	velocity = Vector2.ZERO
	hitbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	anim.play("dead")
	sfx_die.play()
	anim.modulate = Color(1.8, 1.8, 1.8, 1.0)
	var tween := create_tween()
	tween.tween_property(anim, "modulate", _base_tint, 0.1)
	tween.tween_property(anim, "modulate:a", 0.0, 0.5)
	tween.finished.connect(queue_free)
