extends CharacterBody2D
## Mort-vivant du temple : guerrier squelettique qui patrouille lentement.
## Dessiné en Polygon2D (silhouette osseuse verdâtre). Plus lent que l'Onre
## mais plus résistant (2 coups de sabre pour le vaincre).

@export var patrol_distance := 90.0
@export var speed := 42.0

const GRAVITY := 980.0

var start_x := 0.0
var direction := 1.0
var hp := 2
var _dying := false
var _anim_time := 0.0

@onready var hitbox: Area2D = $Hitbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_die: AudioStreamPlayer = $SfxDie
@onready var body_node: Node2D = $Body

func _ready() -> void:
	start_x = position.x
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_build_body()
	# Escalade de vitesse selon le chapitre (différée : le niveau fixe le
	# facteur après avoir posé ses ennemis, voir Challenge.start_level).
	_apply_chapter_speed.call_deferred()

## Applique le multiplicateur de vitesse du chapitre courant (le combat
## s'accélère de chapitre en chapitre). Appelé en différé depuis _ready.
func _apply_chapter_speed() -> void:
	speed *= Challenge.speed_scale

func _build_body() -> void:
	var bone_color := Color(0.72, 0.78, 0.68)
	var dark_bone := Color(0.48, 0.52, 0.44)
	var eye_color := Color(0.45, 0.9, 0.35)
	var rag_color := Color(0.28, 0.22, 0.18)

	# Crâne
	var skull := Polygon2D.new()
	skull.polygon = PackedVector2Array([
		Vector2(-8, -42), Vector2(8, -42), Vector2(10, -34),
		Vector2(8, -26), Vector2(-8, -26), Vector2(-10, -34),
	])
	skull.color = bone_color
	body_node.add_child(skull)

	# Orbites (yeux verts lumineux)
	var eye_l := Polygon2D.new()
	eye_l.polygon = PackedVector2Array([
		Vector2(-6, -38), Vector2(-2, -38), Vector2(-2, -34), Vector2(-6, -34),
	])
	eye_l.color = eye_color
	body_node.add_child(eye_l)
	var eye_r := Polygon2D.new()
	eye_r.polygon = PackedVector2Array([
		Vector2(2, -38), Vector2(6, -38), Vector2(6, -34), Vector2(2, -34),
	])
	eye_r.color = eye_color
	body_node.add_child(eye_r)

	# Mâchoire
	var jaw := Polygon2D.new()
	jaw.polygon = PackedVector2Array([
		Vector2(-6, -26), Vector2(6, -26), Vector2(5, -22), Vector2(-5, -22),
	])
	jaw.color = dark_bone
	body_node.add_child(jaw)

	# Colonne vertébrale
	var spine := Polygon2D.new()
	spine.polygon = PackedVector2Array([
		Vector2(-3, -22), Vector2(3, -22), Vector2(3, 4), Vector2(-3, 4),
	])
	spine.color = bone_color
	body_node.add_child(spine)

	# Côtes
	for side in [-1.0, 1.0]:
		for ry in [-16.0, -10.0, -4.0]:
			var rib := Polygon2D.new()
			rib.polygon = PackedVector2Array([
				Vector2(3 * side, ry), Vector2(12 * side, ry - 2),
				Vector2(12 * side, ry + 1), Vector2(3 * side, ry + 2),
			])
			rib.color = dark_bone
			body_node.add_child(rib)

	# Lambeaux de tissu (haillons)
	var rag := Polygon2D.new()
	rag.polygon = PackedVector2Array([
		Vector2(-10, -6), Vector2(10, -6), Vector2(14, 10),
		Vector2(8, 14), Vector2(-8, 12), Vector2(-14, 8),
	])
	rag.color = rag_color
	body_node.add_child(rag)

	# Bras (os)
	for side in [-1.0, 1.0]:
		var arm := Polygon2D.new()
		arm.polygon = PackedVector2Array([
			Vector2(12 * side, -18), Vector2(14 * side, -18),
			Vector2(18 * side, -4), Vector2(16 * side, -4),
		])
		arm.color = bone_color
		body_node.add_child(arm)

	# Jambes (os)
	for side in [-1.0, 1.0]:
		var leg := Polygon2D.new()
		leg.polygon = PackedVector2Array([
			Vector2(3 * side, 4), Vector2(5 * side, 4),
			Vector2(7 * side, 22), Vector2(4 * side, 22),
		])
		leg.color = bone_color
		body_node.add_child(leg)

	# Halo vert subtil autour du mort-vivant
	var glow := Polygon2D.new()
	var glow_pts := PackedVector2Array()
	for i in 16:
		var angle := i * TAU / 16.0
		glow_pts.append(Vector2(cos(angle) * 28.0, sin(angle) * 28.0 - 12.0))
	glow.polygon = glow_pts
	glow.color = Color(0.3, 0.8, 0.2, 0.08)
	body_node.add_child(glow)

func _physics_process(delta: float) -> void:
	if _dying:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	velocity.x = direction * speed
	move_and_slide()

	if absf(position.x - start_x) >= patrol_distance:
		direction *= -1.0

	body_node.scale.x = 1.0 if direction > 0.0 else -1.0

	_anim_time += delta
	body_node.position.y = sin(_anim_time * 3.0) * 2.0

func _on_hitbox_body_entered(body: Node2D) -> void:
	if _dying:
		return
	if body.has_method("take_damage"):
		body.take_damage(1, global_position)

func die() -> void:
	if _dying:
		return
	hp -= 1
	if hp > 0:
		var tween := create_tween()
		tween.tween_property(body_node, "modulate", Color(1, 0.3, 0.3), 0.1)
		tween.tween_property(body_node, "modulate", Color.WHITE, 0.15)
		return
	_dying = true
	velocity = Vector2.ZERO
	hitbox.set_deferred("monitoring", false)
	body_shape.set_deferred("disabled", true)
	Sfx.varied(sfx_die, 0.9, 1.12)
	var tween := create_tween()
	tween.tween_property(body_node, "modulate:a", 0.0, 0.7)
	tween.finished.connect(queue_free)
