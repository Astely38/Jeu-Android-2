extends CharacterBody2D
## Ombre corrompue : un guerrier spectral qui détecte Eneko, le poursuit
## et frappe au contact. Silhouette sombre (sprite shinobi teinté).
## Vaincue au sabre, elle se dissipe dans un fondu spirituel.

@export var speed := 104.0
@export var detect_range := 380.0
@export var attack_range := 46.0

const GRAVITY := 980.0
const SHINOBI := "res://assets/enemies/shinobi/"
const ORB_SCENE := preload("res://scenes/orb.tscn")

var player: Node2D = null
var lock_timer := 0.0
var _dying := false
var _cur := ""
## Ombre d'élite : plus grande, auréolée de pourpre, encaisse un coup
## d'armure avant de tomber, et libère une orbe dorée (3 orbes).
var elite := false
var _armor := 0
var _aura: Sprite2D

@onready var anim: AnimatedSprite2D = $Anim
@onready var hitbox: Area2D = $Hitbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_die: AudioStreamPlayer = $SfxDie

func _ready() -> void:
	if Challenge.kensei:
		speed *= 1.3
	anim.sprite_frames = SpriteSheet.build([
		{"name": "idle", "path": SHINOBI + "Idle.png", "frames": 6, "fps": 8.0, "loop": true},
		{"name": "run", "path": SHINOBI + "Run.png", "frames": 8, "fps": 12.0, "loop": true},
		{"name": "attack", "path": SHINOBI + "Attack_1.png", "frames": 5, "fps": 11.0, "loop": false},
		{"name": "dead", "path": SHINOBI + "Dead.png", "frames": 4, "fps": 9.0, "loop": false},
	])
	_play("idle")
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_ignore_player_body()
	var sh := ContactShadow.new()
	sh.width = 28.0
	add_child(sh)
	move_child(sh, 0)

## Transforme cette Ombre en Ombre d'élite. À appeler après add_child
## (les nœuds @onready doivent exister). Le sprite grandit mais la
## hitbox reste identique : imposante à l'œil, loyale au combat.
func make_elite() -> void:
	elite = true
	_armor = 1
	detect_range += 60.0
	anim.scale *= 1.3
	anim.position.y -= 9.0
	anim.modulate = Color(0.78, 0.52, 1.0)
	_aura = Sprite2D.new()
	_aura.texture = load("res://assets/mist.svg")
	_aura.modulate = Color(0.6, 0.3, 1.0, 0.3)
	_aura.scale = Vector2(2.2, 2.4)
	_aura.position = Vector2(0, -34)
	_aura.z_index = -1
	add_child(_aura)

## Le corps d'Eneko n'est jamais un obstacle physique pour cette Ombre
## (voir enemy.gd : indispensable pour que la ruée traverse).
func _ignore_player_body() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl is PhysicsBody2D:
		add_collision_exception_with(pl)

func _physics_process(delta: float) -> void:
	if _dying:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	if lock_timer > 0.0:
		lock_timer -= delta

	var moving := false
	if player != null and lock_timer <= 0.0:
		var dx: float = player.global_position.x - global_position.x
		var dy: float = player.global_position.y - global_position.y
		var dist := absf(dx)
		# Ignore le joueur s'il est sur une plateforme trop différente en
		# hauteur (sinon l'Ombre "sent" Eneko à travers plusieurs étages
		# et tombe dans le vide en essayant de le rejoindre).
		if dist < detect_range and absf(dy) < 90.0:
			var dir := signf(dx)
			if dir != 0.0:
				anim.flip_h = dir < 0.0
			if dist > attack_range:
				velocity.x = dir * speed
				moving = true
			else:
				velocity.x = 0.0
				_attack()
		else:
			velocity.x = move_toward(velocity.x, 0.0, speed)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)

	move_and_slide()

	if lock_timer <= 0.0:
		_play("run" if moving else "idle")

func _attack() -> void:
	# Petite pause + animation d'attaque ; les dégâts passent par le hitbox.
	lock_timer = 0.5
	_play("attack")

func _play(n: String) -> void:
	if _cur != n:
		_cur = n
		anim.play(n)

func _on_hitbox_body_entered(body: Node2D) -> void:
	if _dying:
		return
	if body.has_method("take_damage"):
		body.take_damage(1, global_position)

## Vaincue au sabre : animation de mort + fondu spirituel puis disparition.
## Renvoie true si le coup a réellement tué (false : armure d'élite).
func die() -> bool:
	if _dying:
		return false
	# L'armure spectrale de l'élite encaisse le premier coup : flash,
	# courte pause, et l'aura se fissure pour annoncer le coup de grâce.
	if _armor > 0:
		_armor -= 1
		lock_timer = 0.4
		velocity.x = 0.0
		var armor_tint := anim.modulate
		anim.modulate = Color(1.8, 1.8, 1.8, 1.0)
		var tw := create_tween()
		tw.tween_property(anim, "modulate", armor_tint, 0.2)
		if _aura != null:
			_aura.modulate.a = 0.14
		return false
	_dying = true
	Atmosphere.release_soul(get_parent(), global_position + Vector2(0, -22), Color(0.85, 0.7, 1.0))
	velocity = Vector2.ZERO
	hitbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	_play("dead")
	Sfx.varied(sfx_die, 0.9, 1.12)
	if elite:
		_drop_golden_orb()
		Achievements.unlock("chasseur")
	# Flash blanc à l'impact, puis fondu spirituel (la teinte violette de
	# l'Ombre revient pendant le fondu).
	var tint := anim.modulate
	anim.modulate = Color(1.8, 1.8, 1.8, 1.0)
	var tween := create_tween()
	tween.tween_property(anim, "modulate", tint, 0.1)
	tween.tween_property(anim, "modulate:a", 0.0, 0.5)
	tween.finished.connect(queue_free)
	return true

## L'orbe dorée s'échappe de l'Ombre d'élite vaincue et flotte sur place.
func _drop_golden_orb() -> void:
	var orb := ORB_SCENE.instantiate()
	orb.position = global_position + Vector2(0, -52)
	orb.set("value", 3)
	get_parent().call_deferred("add_child", orb)
