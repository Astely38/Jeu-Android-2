extends CharacterBody2D
## Esprit Onre : démon corrompu qui patrouille sa plateforme de gauche à
## droite. Inflige des dégâts au contact ; n'est vaincu qu'au sabre et se
## dissipe alors dans un fondu spirituel.

@export var patrol_distance := 100.0
@export var speed := 74.0

const GRAVITY := 980.0
const ONRE := "res://assets/enemies/onre/"

var start_x := 0.0
var direction := 1.0
var _dying := false
var _cur := ""

@onready var anim: AnimatedSprite2D = $Anim
@onready var hitbox: Area2D = $Hitbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_die: AudioStreamPlayer = $SfxDie

func _ready() -> void:
	start_x = position.x
	if Challenge.kensei:
		speed *= 1.35
	# Escalade de vitesse selon le chapitre (différée : le niveau fixe le
	# facteur après avoir posé ses ennemis, voir Challenge.start_level).
	_apply_chapter_speed.call_deferred()
	anim.sprite_frames = SpriteSheet.build([
		{"name": "walk", "path": ONRE + "Walk.png", "frames": 7, "fps": 9.0, "loop": true},
		{"name": "dead", "path": ONRE + "Dead.png", "frames": 6, "fps": 10.0, "loop": false},
	])
	_play("walk")
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_ignore_player_body()
	var sh := ContactShadow.new()
	sh.width = 26.0
	add_child(sh)
	move_child(sh, 0)

## Applique le multiplicateur de vitesse du chapitre courant (le combat
## s'accélère de chapitre en chapitre). Appelé en différé depuis _ready.
func _apply_chapter_speed() -> void:
	speed *= Challenge.speed_scale

## Le corps d'Eneko n'est jamais un obstacle physique pour cet ennemi :
## sans ça, la dépénétration de l'ennemi « colle » Eneko pendant la ruée
## et empêche la traversée (le joueur partage la couche du sol). Les
## dégâts passent par la hitbox, pas par le blocage physique.
func _ignore_player_body() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl is PhysicsBody2D:
		add_collision_exception_with(pl)

func _physics_process(delta: float) -> void:
	if _dying:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	# Demi-tour au bord d'une plateforme : ne patrouille jamais dans le vide.
	if is_on_floor() and not _ground_ahead(direction):
		direction *= -1.0

	velocity.x = direction * speed
	move_and_slide()

	if absf(position.x - start_x) >= patrol_distance:
		direction *= -1.0

	anim.flip_h = direction < 0.0

## Y a-t-il du sol juste devant, dans la direction `dir` ?
func _ground_ahead(dir: float) -> bool:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(dir * 26.0, -2.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 52.0), 1)
	q.exclude = [get_rid()]
	return not space.intersect_ray(q).is_empty()

func _play(n: String) -> void:
	if _cur != n:
		_cur = n
		anim.play(n)

func _on_hitbox_body_entered(body: Node2D) -> void:
	if _dying:
		return
	if body.has_method("take_damage"):
		body.take_damage(1, global_position)

## Vaincu par le sabre : animation de mort + fondu, puis disparition.
func die() -> void:
	if _dying:
		return
	_dying = true
	Atmosphere.release_soul(get_parent(), global_position + Vector2(0, -22), Color(1.0, 0.86, 0.55))
	velocity = Vector2.ZERO
	hitbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	_play("dead")
	Sfx.varied(sfx_die, 0.9, 1.12)
	# Flash blanc à l'impact, puis fondu spirituel.
	anim.modulate = Color(1.8, 1.8, 1.8, 1.0)
	var tween := create_tween()
	tween.tween_property(anim, "modulate", Color(1, 1, 1, 1), 0.1)
	tween.tween_property(anim, "modulate:a", 0.0, 0.55)
	tween.finished.connect(queue_free)
