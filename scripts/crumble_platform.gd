extends StaticBody2D
## Plateforme effondrable : dès qu'Eneko pose le pied dessus, la dalle
## tremble un court instant, s'effondre dans le vide, puis se reforme
## quelques secondes plus tard. Tout (visuel, collision, détection) est
## construit en code à partir de half_width, donc chaque instance peut
## avoir sa propre largeur.

@export var half_width := 70.0

const SHAKE_TIME := 0.5
const RESPAWN_TIME := 3.2
const SLAB_TOP := -6.0
const SLAB_BOTTOM := 10.0

const STONE := Color(0.52, 0.5, 0.48)
const STONE_DARK := Color(0.38, 0.36, 0.35)

var _armed := true
var _visual: Node2D
var _shape: CollisionShape2D

func _ready() -> void:
	# Collision porteuse (le dessus de la dalle).
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(half_width * 2.0, SLAB_BOTTOM - SLAB_TOP)
	_shape.shape = rect
	_shape.position = Vector2(0, (SLAB_TOP + SLAB_BOTTOM) * 0.5)
	add_child(_shape)

	# Dalle visuelle : pierre pâle fissurée, pour signaler sa fragilité.
	_visual = Node2D.new()
	add_child(_visual)
	_poly(_visual, PackedVector2Array([
		Vector2(-half_width, SLAB_TOP), Vector2(half_width, SLAB_TOP),
		Vector2(half_width - 6, SLAB_BOTTOM), Vector2(-half_width + 6, SLAB_BOTTOM),
	]), STONE)
	_poly(_visual, PackedVector2Array([
		Vector2(-half_width, SLAB_TOP), Vector2(half_width, SLAB_TOP),
		Vector2(half_width, SLAB_TOP + 4), Vector2(-half_width, SLAB_TOP + 4),
	]), Color(0.62, 0.6, 0.57))
	# Fissures visibles sur le dessus.
	var cx := -half_width + 18.0
	while cx < half_width - 12.0:
		_poly(_visual, PackedVector2Array([
			Vector2(cx, SLAB_TOP + 1), Vector2(cx + 3, SLAB_TOP + 1),
			Vector2(cx + 7, SLAB_BOTTOM - 2), Vector2(cx + 4, SLAB_BOTTOM - 2),
		]), STONE_DARK)
		cx += 34.0

	# Détecteur posé juste au-dessus de la dalle : déclenche l'effondrement.
	var det := Area2D.new()
	var det_shape := CollisionShape2D.new()
	var det_rect := RectangleShape2D.new()
	det_rect.size = Vector2(half_width * 2.0 - 8.0, 14.0)
	det_shape.shape = det_rect
	det_shape.position = Vector2(0, SLAB_TOP - 7.0)
	det.add_child(det_shape)
	add_child(det)
	det.body_entered.connect(_on_body_entered)

func _poly(parent: Node, points: PackedVector2Array, color: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	parent.add_child(p)

func _on_body_entered(body: Node2D) -> void:
	if _armed and body.is_in_group("player"):
		_armed = false
		_crumble()

func _crumble() -> void:
	# Tremblement d'avertissement...
	var shake := create_tween()
	for i in 5:
		shake.tween_property(_visual, "position:x", 3.0 if i % 2 == 0 else -3.0, SHAKE_TIME / 5.0)
	shake.tween_property(_visual, "position:x", 0.0, 0.04)
	await shake.finished
	# ...puis chute : la collision disparaît et la dalle tombe en fondu.
	_shape.set_deferred("disabled", true)
	var fall := create_tween()
	fall.set_parallel(true)
	fall.tween_property(_visual, "position:y", 160.0, 0.5).set_ease(Tween.EASE_IN)
	fall.tween_property(_visual, "modulate:a", 0.0, 0.5)
	await fall.finished
	# Reformation après un délai.
	await get_tree().create_timer(RESPAWN_TIME).timeout
	_visual.position = Vector2.ZERO
	_visual.modulate.a = 0.0
	_shape.set_deferred("disabled", false)
	var back := create_tween()
	back.tween_property(_visual, "modulate:a", 1.0, 0.3)
	await back.finished
	_armed = true
