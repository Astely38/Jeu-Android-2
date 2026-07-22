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

const ONI := "res://assets/enemies/shield_oni/"
## Le sprite fait face à DROITE par défaut (bouclier tenu du côté droit),
## comme les autres ennemis — flip_h standard, voir _animate().
const BASE_TINT := Color(0.8, 0.82, 1.05)   # pousse la teinte vers le spectral indigo
const FLASH_TINT := Color(2.2, 2.2, 2.4)    # éclat du pavois au ricochet
const AURA := Color(0.42, 0.48, 0.9)        # halo spectral bleu

var player: Node2D = null
var _dying := false
var _t := 0.0
var _face := -1.0                 # sens du regard / côté du bouclier
var _turn_t := 0.0
var _shield_flash := 0.0
var _cur := ""

@onready var anim: AnimatedSprite2D = $Anim
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
	_build_glow()
	anim.sprite_frames = SpriteSheet.build([
		{"name": "idle", "path": ONI + "Idle.png", "frames": 4, "fps": 5.0, "loop": true},
		{"name": "walk", "path": ONI + "Walk.png", "frames": 8, "fps": 10.0, "loop": true},
		{"name": "dead", "path": ONI + "Dead.png", "frames": 6, "fps": 10.0, "loop": false},
	])
	anim.scale = Vector2(1.25, 1.25)
	anim.modulate = BASE_TINT
	_play("idle")
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_ignore_player_body()
	var sh := ContactShadow.new()
	sh.width = 40.0
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

func _build_glow() -> void:
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(AURA.r, AURA.g, AURA.b, 0.6)
	glow.scale = Vector2(2.3, 2.5)
	glow.position = Vector2(0, -17)
	glow.z_index = -1
	add_child(glow)
	Atmosphere.breathe(glow, 0.25, 2.0)

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
	_animate(move_dir)

func _ground_ahead(dir: float) -> bool:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(dir * 28.0, -2.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 54.0), 1)
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
	_play("dead")
	var tw := anim.create_tween()
	tw.set_parallel(true)
	tw.tween_property(anim, "modulate:a", 0.0, 0.5)
	tw.tween_property(anim, "rotation", _face * 0.6, 0.5)
	tw.tween_property(anim, "position:y", anim.position.y + 10.0, 0.5)
	tw.chain().tween_callback(queue_free)

# --- Visuel -----------------------------------------------------------------

func _animate(move_dir: float) -> void:
	anim.flip_h = _face < 0.0
	_play("walk" if absf(move_dir) > 0.01 else "idle")
	# Balancement de marche.
	if absf(velocity.x) > 5.0:
		anim.rotation = 0.035 * sin(_t * 9.0)
	else:
		anim.rotation = lerpf(anim.rotation, 0.0, 0.2)
	# Tremblement quand il amorce sa volte-face (télégraphe de l'ouverture).
	anim.position.x = sin(_t * 40.0) * 1.6 if _turn_t > 0.0 else 0.0
	# Éclat du pavois au ricochet.
	anim.modulate = BASE_TINT.lerp(FLASH_TINT, clampf(_shield_flash * 2.0, 0.0, 1.0))
