class_name RockSlide
extends Node2D
## Piège du Chapitre IV, propre aux pentes : un surplomb instable qui, par
## intermittence, libère une volée d'éclats qui DÉVALENT la pente en
## tournoyant. Télégraphié par sa fissure qui s'illumine avant l'éboulis —
## un joueur attentif a le temps de s'écarter ou de franchir la pente avant
## la chute.
##
## Usage : RockSlide.new() ; `position` en haut de la pente, au point de
## contact du surplomb ; `fall_dir` = vecteur de chute normalisé (suit la
## pente, ex. Vector2(1, 0.4).normalized() pour une descente vers la
## droite) ; `phase` pour désynchroniser plusieurs éboulis d'un même niveau.

const ART_DIR := "res://assets/traps/rock_slide/"
const ART_SCALE := 0.22
const FALL_FRAMES := 6

const PERIOD := 3.6
const WARN := 0.7
const FALL_SPEED := 260.0
const RANGE := 420.0
## Rayons de collision des 3 tailles d'éclats de la planche (petit/moyen/grand).
const SHARD_SIZES := [
	{"radius": 8.0, "scale": 0.27},
	{"radius": 11.0, "scale": 0.36},
	{"radius": 15.0, "scale": 0.46},
]

@export var fall_dir := Vector2(1, 0.4)
@export var phase := 0.0
## Conservée pour compatibilité des appelants existants — sans effet sur les
## images peintes, dont les teintes sont fixes.
@export var tint := Color(0.5, 0.55, 0.65)

var _t := 0.0
var _alert: Sprite2D

func _ready() -> void:
	_t = phase
	fall_dir = fall_dir.normalized()
	z_index = 4

	# Le coin bas-droit de la planche (pointe du surplomb) est le point de
	# contact avec la pente : on décale le sprite pour que ce coin tombe
	# pile sur `position`.
	var rest := Sprite2D.new()
	rest.texture = load(ART_DIR + "overhang_rest.png")
	rest.centered = false
	rest.scale = Vector2(ART_SCALE, ART_SCALE)
	rest.position = -rest.texture.get_size() * ART_SCALE
	add_child(rest)

	_alert = Sprite2D.new()
	_alert.texture = load(ART_DIR + "overhang_alert.png")
	_alert.centered = false
	_alert.scale = Vector2(ART_SCALE, ART_SCALE)
	_alert.position = -_alert.texture.get_size() * ART_SCALE
	_alert.modulate.a = 0.0
	add_child(_alert)

	_build_warning_sign(-fall_dir * 56.0)

## Petit panneau triangulaire, toujours visible, planté un peu avant le
## surplomb sur le chemin du joueur — un repère lisible avant même que la
## fissure ne s'illumine.
func _build_warning_sign(offset: Vector2) -> void:
	var sign_sprite := Sprite2D.new()
	sign_sprite.texture = load(ART_DIR + "warning.png")
	sign_sprite.scale = Vector2(0.19, 0.19)
	sign_sprite.position = offset
	add_child(sign_sprite)

func _process(delta: float) -> void:
	_t += delta
	if _t >= PERIOD:
		_t -= PERIOD
		_release()
	# Télégraphe : la fissure s'illumine dans le dernier tiers du cycle.
	var warn := clampf((_t - (PERIOD - WARN)) / WARN, 0.0, 1.0)
	if _alert != null:
		_alert.modulate.a = warn

## Libère une volée d'éclats qui dévalent la pente en tournoyant, chacun
## infligeant un dégât au contact avant de disparaître à distance dans un
## nuage de poussière.
func _release() -> void:
	var host := get_parent()
	if host == null:
		return
	for i in SHARD_SIZES.size():
		var size_cfg: Dictionary = SHARD_SIZES[i]
		var radius: float = size_cfg["radius"]
		var art_scale: float = size_cfg["scale"]

		var shard := Area2D.new()
		var glow := Sprite2D.new()
		glow.texture = load("res://assets/mist.svg")
		glow.modulate = Color(0.8, 0.7, 0.95, 0.4)
		glow.scale = Vector2.ONE * (radius / 14.0)
		shard.add_child(glow)

		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = _build_shard_frames()
		sprite.scale = Vector2(art_scale, art_scale)
		sprite.play("fall")
		shard.add_child(sprite)

		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = radius
		shape.shape = circle
		shard.add_child(shape)
		shard.z_index = 3
		host.add_child(shard)

		var offset := Vector2(-fall_dir.y, fall_dir.x) * float(i - 1) * 16.0
		shard.global_position = global_position + offset
		shard.body_entered.connect(_on_shard_hit.bind(shard))
		var t := shard.create_tween()
		t.set_parallel(true)
		t.tween_property(shard, "position", shard.position + fall_dir * RANGE, RANGE / FALL_SPEED)
		t.chain().tween_callback(_on_shard_spent.bind(shard))

## Construit la SpriteFrames de l'éclat qui tombe en tournoyant — six frames
## peintes, aucune ressource .tres à part.
func _build_shard_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation("fall")
	sf.set_animation_speed("fall", 10.0)
	sf.set_animation_loop("fall", true)
	for i in FALL_FRAMES:
		sf.add_frame("fall", load("%sfall_%d.png" % [ART_DIR, i]))
	sf.remove_animation("default")
	return sf

func _on_shard_hit(body: Node2D, shard: Area2D) -> void:
	if not is_instance_valid(shard):
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1, shard.global_position)
		shard.queue_free()

## En fin de course, l'éclat s'efface dans le nuage de poussière peint au
## lieu de simplement disparaître — un petit impact qui vend sa masse.
func _on_shard_spent(shard: Area2D) -> void:
	if not is_instance_valid(shard):
		return
	var host := get_parent()
	if host != null:
		var puff := Sprite2D.new()
		puff.texture = load(ART_DIR + "dust.png")
		puff.scale = Vector2.ONE * 0.32
		puff.global_position = shard.global_position
		host.add_child(puff)
		var pt := puff.create_tween()
		pt.tween_property(puff, "scale", puff.scale * 1.3, 0.5)
		pt.parallel().tween_property(puff, "modulate:a", 0.0, 0.5)
		pt.tween_callback(puff.queue_free)
	shard.queue_free()
