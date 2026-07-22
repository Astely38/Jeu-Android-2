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

const ROBE := Color(0.14, 0.12, 0.18)
const ROBE_HI := Color(0.22, 0.19, 0.27)
const FACE := Color(0.86, 0.84, 0.88)
const EDGE := Color(0.6, 0.55, 0.7)

enum { SOLID, FADING, HOLLOW, FORMING }

var start_x := 0.0
var direction := 1.0
var _dying := false
var _state := SOLID
var _state_t := 0.0
var _t := 0.0

var _gfx: Node2D
var _face_poly: Polygon2D

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
	sh.width = 24.0
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

## Y a-t-il du sol juste devant, dans la direction `dir` ?
func _ground_ahead(dir: float) -> bool:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(dir * 24.0, -2.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 52.0), 1)
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
		Atmosphere.release_soul(parent, global_position + Vector2(0, -22), Color(0.75, 0.72, 0.85))
		Atmosphere.death_burst(parent, global_position + Vector2(0, -16), Color(0.8, 0.78, 0.9))
	velocity = Vector2.ZERO
	hitbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	Sfx.varied(sfx_die, 0.88, 1.08)
	if _gfx != null:
		var tw := _gfx.create_tween()
		tw.set_parallel(true)
		tw.tween_property(_gfx, "modulate:a", 0.0, 0.4)
		tw.tween_property(_gfx, "scale", _gfx.scale * 0.6, 0.4)
		tw.chain().tween_callback(queue_free)
	else:
		queue_free()
	return true

# --- Visuel ---------------------------------------------------------------

## Silhouette robée simple, capuche vide et visage pâle et VIERGE (ovale
## uni, sans traits) — « il n'a plus de visage à emprunter ».
func _build_visual() -> void:
	_gfx = Node2D.new()
	add_child(_gfx)

	# Robe : triangle évasé qui touche le sol.
	_shape(_gfx, PackedVector2Array([
		Vector2(-14, 24), Vector2(14, 24), Vector2(9, -6),
		Vector2(0, -12), Vector2(-9, -6),
	]), ROBE)
	# Pan plus clair, pour donner du volume.
	_shape(_gfx, PackedVector2Array([
		Vector2(-2, 24), Vector2(9, 24), Vector2(6, -8), Vector2(-1, -10),
	]), ROBE_HI)
	# Capuche.
	_shape(_gfx, PackedVector2Array([
		Vector2(-11, -8), Vector2(-8, -20), Vector2(0, -25),
		Vector2(8, -20), Vector2(11, -8), Vector2(6, -10),
		Vector2(0, -14), Vector2(-6, -10),
	]), ROBE)

	# Visage : ovale pâle et lisse, sans traits.
	_face_poly = Polygon2D.new()
	var fp := PackedVector2Array()
	for i in 14:
		var a := i * TAU / 14.0
		fp.append(Vector2(cos(a) * 6.0, sin(a) * 8.0))
	_face_poly.polygon = fp
	_face_poly.position = Vector2(0, -13)
	_face_poly.color = FACE
	_gfx.add_child(_face_poly)

	# Manches qui pendent, de part et d'autre.
	for s in [-1.0, 1.0]:
		_shape(_gfx, PackedVector2Array([
			Vector2(s * 8, -4), Vector2(s * 15, 10), Vector2(s * 9, 14), Vector2(s * 4, -2),
		]), ROBE)

## Polygone plein cerné d'un liseré (Line2D), même langage que les autres
## esprits récents — se détache des fonds sombres du royaume sans écho.
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
	_gfx.scale.x = direction if direction != 0.0 else 1.0
	# Balancement de marche, léger.
	_gfx.position.y = sin(_t * 8.0) * 1.4 if is_on_floor() else 0.0

	# Opacité selon l'état : plein en SOLID, creux et scintillant en HOLLOW,
	# transition télégraphiée (le joueur voit venir chaque bascule).
	var target_a := 1.0
	match _state:
		FADING:
			target_a = 1.0 - (_state_t / FADE_TIME) * 0.78
		HOLLOW:
			# Vacillement fantomatique pendant toute la phase creuse.
			target_a = 0.2 + 0.08 * sin(_t * 16.0)
		FORMING:
			target_a = 0.22 + (_state_t / FORM_TIME) * 0.78
	_gfx.modulate.a = target_a
