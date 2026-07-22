class_name TutorialSign
extends Object
## Pancarte en bois plantée au sol : enseigne une commande ou une mécanique
## au bon moment, sans bloquer le jeu (pas de dialogue modal). Réutilisée par
## plusieurs niveaux pour garder un langage visuel cohérent d'un chapitre à
## l'autre.

static func build(parent: Node, x: float, ground_y: float, text: String) -> void:
	var post := Node2D.new()
	post.position = Vector2(x, ground_y)
	parent.add_child(post)
	var wood := Color(0.44, 0.3, 0.17)
	var wood_dark := Color(0.32, 0.21, 0.12)
	# Poteau planté dans le sol.
	_poly(post, PackedVector2Array([
		Vector2(-4, 0), Vector2(4, 0), Vector2(4, -72), Vector2(-4, -72),
	]), wood_dark)
	# Planche gravée, cerclée d'un liseré plus sombre.
	_poly(post, PackedVector2Array([
		Vector2(-104, -72), Vector2(104, -72), Vector2(104, -108), Vector2(-104, -108),
	]), wood)
	_poly(post, PackedVector2Array([
		Vector2(-104, -72), Vector2(104, -72), Vector2(104, -76), Vector2(-104, -76),
	]), wood_dark)
	_poly(post, PackedVector2Array([
		Vector2(-104, -104), Vector2(104, -104), Vector2(104, -108), Vector2(-104, -108),
	]), wood_dark)
	var lbl := Label.new()
	lbl.text = text
	lbl.size = Vector2(208, 36)
	lbl.position = Vector2(-104, -108)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.99, 0.93, 0.8))
	lbl.add_theme_color_override("font_outline_color", Color(0.18, 0.1, 0.05))
	lbl.add_theme_constant_override("outline_size", 4)
	post.add_child(lbl)

static func _poly(parent: Node, pts: PackedVector2Array, c: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = c
	parent.add_child(p)
