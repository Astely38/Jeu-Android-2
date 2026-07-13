extends Area2D
## Orbe corrompu craché par le Yūrei : vole en ligne droite vers l'endroit
## où était Eneko, le blesse au contact, se brise sur les murs, et peut
## être dissipé d'un coup de sabre (il expose die() comme les ennemis).

var direction := Vector2.RIGHT
var speed := 170.0

var _life := 4.0
var _t := 0.0
var _dead := false
var _core: Polygon2D
var _halo: Polygon2D

func _ready() -> void:
	# Collision.
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	add_child(shape)
	# Visuel : halo violet translucide + cœur lumineux.
	_halo = _circle_poly(12.0, Color(0.6, 0.3, 0.8, 0.35))
	_core = _circle_poly(6.5, Color(0.85, 0.55, 1.0, 0.95))
	body_entered.connect(_on_body_entered)

func _circle_poly(radius: float, color: Color) -> Polygon2D:
	var pts := PackedVector2Array()
	var k := 0
	while k < 12:
		var a := k * TAU / 12.0
		pts.append(Vector2(cos(a) * radius, sin(a) * radius))
		k += 1
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color
	add_child(p)
	return p

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	position += direction * speed * delta
	# Pulsation du cœur et du halo.
	var pulse := 1.0 + 0.18 * sin(_t * 10.0)
	_core.scale = Vector2(pulse, pulse)
	_halo.scale = Vector2(2.0 - pulse, 2.0 - pulse) * 0.9
	_life -= delta
	if _life <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if _dead:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1, global_position)
		die()
	elif body is StaticBody2D:
		# Se brise sur les murs et plateformes (mais traverse son tireur).
		die()

## Dissipé (sabre, impact) : petit éclat qui s'évanouit.
func die() -> void:
	if _dead:
		return
	_dead = true
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)
