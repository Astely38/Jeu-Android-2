extends CharacterBody2D
## Le Sans-Visage : esprit du Chapitre IV, né du royaume qui ne renvoie plus
## aucune image. Il patrouille comme l'Onre, mais son corps n'est SOLIDE que
## par intermittence : il s'efface en une silhouette CREUSE et intangible —
## la lame la traverse sans effet, il ne blesse pas non plus — avant de se
## RE-MATÉRIALISER, télégraphié par un bref scintillement.
## Menace de rythme, inédite : il faut attendre la fenêtre solide pour frapper,
## et rester prudent quand elle revient (il redevient dangereux au contact).

@export var patrol_distance := 110.0
@export var speed := 68.0

const GRAVITY := 980.0

const SOLID_TIME := 2.0
const FADE_TIME := 0.35
const HOLLOW_TIME := 1.5
const FORM_TIME := 0.35

## Échelle du sprite peint : plus imposant qu'un simple Onre, à la mesure
## d'une menace qui traverse deux états (le joueur doit le voir venir de loin).
const VISUAL_SCALE := 0.56

const AURA := Color(0.62, 0.5, 0.95)  # halo spectral violet, marque sa position

const ART_DIR := "res://assets/enemies/sans_visage/"
## Nom d'animation -> (nombre de frames, images/seconde, en boucle).
const ANIMS := {
	"idle": [4, 5.0, true],
	"float": [7, 9.0, true],
	"solid": [2, 4.0, true],
	"hollow": [2, 3.0, true],
	"transition": [3, 8.5, false],
	"hurt": [4, 10.0, false],
	"death": [9, 7.0, false],
}

enum { SOLID, FADING, HOLLOW, FORMING }

var start_x := 0.0
var direction := 1.0
var _dying := false
var _state := SOLID
var _state_t := 0.0
var _t := 0.0

var _sprite: AnimatedSprite2D
var _aura: Sprite2D

@onready var hitbox: Area2D = $Hitbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_die: AudioStreamPlayer = $SfxDie

func _ready() -> void:
	start_x = position.x
	if Challenge.kensei:
		speed *= 1.25
	_apply_chapter_speed.call_deferred()
	z_index = 6
	_build_visual()
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_ignore_player_body()
	var sh := ContactShadow.new()
	sh.width = 32.0
	add_child(sh)
	move_child(sh, 0)

func _apply_chapter_speed() -> void:
	speed *= Challenge.speed_scale

func _ignore_player_body() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl is PhysicsBody2D:
		add_collision_exception_with(pl)

func _physics_process(delta: float) -> void:
	if _dying:
		return
	_t += delta
	_state_t += delta

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	if is_on_floor() and not _ground_ahead(direction):
		direction *= -1.0
	velocity.x = direction * speed
	move_and_slide()
	if absf(position.x - start_x) >= patrol_distance:
		direction *= -1.0

	match _state:
		SOLID:
			if _state_t >= SOLID_TIME:
				_enter(FADING)
		FADING:
			if _state_t >= FADE_TIME:
				_enter(HOLLOW)
				hitbox.set_deferred("monitoring", false)
		HOLLOW:
			if _state_t >= HOLLOW_TIME:
				_enter(FORMING)
		FORMING:
			if _state_t >= FORM_TIME:
				_enter(SOLID)
				hitbox.set_deferred("monitoring", true)

	_animate()

func _enter(s: int) -> void:
	_state = s
	_state_t = 0.0
	if _sprite == null:
		return
	match s:
		SOLID:
			_sprite.play("float")
		FADING:
			_sprite.play("transition")
		HOLLOW:
			_sprite.play("hollow")
		FORMING:
			_sprite.play("transition", 1.0, true)

## Y a-t-il du sol juste devant, dans la direction `dir` ?
func _ground_ahead(dir: float) -> bool:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(dir * 30.0, -2.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 64.0), 1)
	q.exclude = [get_rid()]
	return not space.intersect_ray(q).is_empty()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if _dying or _state == HOLLOW or _state == FADING:
		return
	if body.has_method("take_damage"):
		body.take_damage(1, global_position)

## Tranché au sabre : seulement quand SOLIDE (HOLLOW/FADING = la lame passe
## au travers sans effet, aucun ricochet — il n'y a rien à toucher).
func die() -> bool:
	if _dying:
		return false
	if _state == HOLLOW or _state == FADING:
		return false
	_dying = true
	var parent := get_parent()
	if parent != null:
		Atmosphere.release_soul(parent, global_position + Vector2(0, -30), Color(0.75, 0.72, 0.85))
		Atmosphere.death_burst(parent, global_position + Vector2(0, -22), Color(0.8, 0.78, 0.9))
	velocity = Vector2.ZERO
	hitbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	Sfx.varied(sfx_die, 0.88, 1.08)
	if _aura != null:
		var atw := _aura.create_tween()
		atw.tween_property(_aura, "modulate:a", 0.0, 0.9)
	_play_death_sequence()
	return true

## Recul bref (hurt) puis dissolution (death), sans bloquer le retour
## synchrone de die() dont dépendent l'appelant (score/combo immédiats).
func _play_death_sequence() -> void:
	if _sprite == null:
		queue_free()
		return
	_sprite.play("hurt")
	await _sprite.animation_finished
	if not is_instance_valid(self):
		return
	_sprite.play("death")
	await _sprite.animation_finished
	if not is_instance_valid(self):
		return
	var tw := _sprite.create_tween()
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.3)
	await tw.finished
	queue_free()

# --- Visuel ---------------------------------------------------------------

## Silhouette peinte (planche fournie), capuche vide et visage pâle et VIERGE
## — « il n'a plus de visage à emprunter ». Sept animations : idle, float
## (patrouille), solid, hollow, transition (fondu solide<->creux, rejouée à
## l'envers pour FORMING), hurt et death.
func _build_visual() -> void:
	# Halo spectral, INDÉPENDANT de l'opacité du corps : il reste discrètement
	# visible même quand l'esprit est creux, pour qu'on repère toujours où il
	# se trouve (et qu'on sache quand le frapper de nouveau). Enfant direct,
	# derrière le corps.
	_aura = Sprite2D.new()
	_aura.texture = load("res://assets/mist.svg")
	_aura.modulate = Color(AURA.r, AURA.g, AURA.b, 0.5)
	_aura.scale = Vector2(2.2, 2.6)
	_aura.position = Vector2(0, -8)
	_aura.z_index = -1
	add_child(_aura)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_sprite_frames()
	_sprite.scale = Vector2(VISUAL_SCALE, VISUAL_SCALE)
	_sprite.position = Vector2(0, -4)
	add_child(_sprite)
	_sprite.play("float")

## Construit la SpriteFrames à partir des PNG découpés dans ART_DIR — aucune
## ressource .tres à part, cohérent avec le reste du projet (visuels bâtis
## en code, pas de fichiers d'édition annexes).
func _build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	for anim_name in ANIMS.keys():
		var cfg: Array = ANIMS[anim_name]
		var count: int = cfg[0]
		var fps: float = cfg[1]
		var loop: bool = cfg[2]
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, fps)
		sf.set_animation_loop(anim_name, loop)
		for i in count:
			var tex := load("%s%s_%d.png" % [ART_DIR, anim_name, i])
			sf.add_frame(anim_name, tex)
	sf.remove_animation("default")
	return sf

func _animate() -> void:
	if _sprite == null:
		return
	_sprite.flip_h = direction < 0.0
	# Balancement de marche, léger.
	_sprite.position.y = -4.0 + (sin(_t * 8.0) * 1.4 if is_on_floor() else 0.0)

	# Le halo suit l'état : franc quand l'esprit est SOLIDE (donc dangereux et
	# frappable), faible mais jamais nul quand il est creux (repérable) — les
	# frames elles-mêmes portent déjà la bonne opacité par état.
	var aura_a := 0.55
	match _state:
		FADING:
			aura_a = 0.55 - (_state_t / FADE_TIME) * 0.3
		HOLLOW:
			aura_a = 0.22 + 0.06 * sin(_t * 10.0)
		FORMING:
			aura_a = 0.25 + (_state_t / FORM_TIME) * 0.3
	if _aura != null:
		_aura.modulate.a = aura_a
