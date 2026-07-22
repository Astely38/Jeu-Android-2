class_name SlopePainter
extends Object
## Terrain incliné (montées/descentes), pour varier des plateformes plates
## utilisées jusqu'ici. Une pente est un quadrilatère : arête haute (le sol
## praticable, de (x0,y0) à (x1,y1)) et un socle épais qui plonge dessous.
## Godot gère nativement la marche en pente via move_and_slide() tant que
## l'angle reste sous floor_max_angle (45° par défaut) — on reste par
## prudence sous ~24° pour un ressenti naturel au saut.

const THICKNESS := 340.0

## Construit le corps physique + le rendu peint d'une pente entre deux points
## de surface. `theme` attend les mêmes clés que PlatformPainter (top,
## top_light, body_a, dark, speck).
static func build(parent: Node2D, x0: float, y0: float, x1: float, y1: float,
		theme: Dictionary) -> void:
	var body := StaticBody2D.new()
	var poly := PackedVector2Array([
		Vector2(x0, y0), Vector2(x1, y1),
		Vector2(x1, y1 + THICKNESS), Vector2(x0, y0 + THICKNESS),
	])
	var shape := CollisionPolygon2D.new()
	shape.polygon = poly
	body.add_child(shape)
	parent.add_child(body)
	_paint(body, poly, theme)

static func _paint(body: Node2D, poly: PackedVector2Array, theme: Dictionary) -> void:
	var body_a: Color = theme.get("body_a", Color(0.15, 0.13, 0.1))
	var top: Color = theme.get("top", Color(0.4, 0.34, 0.26))
	var top_light: Color = theme.get("top_light", Color(0.5, 0.44, 0.34))
	var speck: Color = theme.get("speck", Color(0.6, 0.5, 0.4))

	var fill := Polygon2D.new()
	fill.polygon = poly
	fill.color = body_a
	body.add_child(fill)

	# Arête haute éclairée : ruban qui longe la pente, un peu en retrait.
	var x0: float = poly[0].x
	var y0: float = poly[0].y
	var x1: float = poly[1].x
	var y1: float = poly[1].y
	var dir := Vector2(x1 - x0, y1 - y0).normalized()
	var normal := Vector2(-dir.y, dir.x)  # perpendiculaire, vers le bas
	if normal.y < 0.0:
		normal = -normal
	var edge_w := 14.0
	var ridge := Polygon2D.new()
	ridge.polygon = PackedVector2Array([
		Vector2(x0, y0), Vector2(x1, y1),
		Vector2(x1, y1) + normal * edge_w, Vector2(x0, y0) + normal * edge_w,
	])
	ridge.color = top
	body.add_child(ridge)
	var hi := Polygon2D.new()
	hi.polygon = PackedVector2Array([
		Vector2(x0, y0), Vector2(x1, y1),
		Vector2(x1, y1) + normal * 4.0, Vector2(x0, y0) + normal * 4.0,
	])
	hi.color = top_light
	body.add_child(hi)

	# Grain de matière sur le corps principal (cohérent avec les plateformes).
	TextureLab.grain_poly(body, poly, 0.1, Vector2(x0, y0))

	# Poussière de mouchetures éparses, comme sur les plateformes plates.
	var n := int(Vector2(x1 - x0, y1 - y0).length() / 90.0)
	for i in maxi(2, n):
		var f := float(i) / float(maxi(1, n))
		var px := lerpf(x0, x1, f) + randf_range(-14.0, 14.0)
		var py := lerpf(y0, y1, f) + edge_w + randf_range(10.0, 60.0)
		var s := Polygon2D.new()
		s.polygon = PackedVector2Array([
			Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2),
		])
		s.color = Color(speck.r, speck.g, speck.b, 0.3)
		s.position = Vector2(px, py)
		body.add_child(s)
