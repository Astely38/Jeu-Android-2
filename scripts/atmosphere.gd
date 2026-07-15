class_name Atmosphere
extends Object
## Utilitaires d'ambiance visuelle réutilisables entre les niveaux.

## Ajoute un plan de silhouettes sombres en avant-plan (feuillages suspendus
## en haut, herbes en bas), défilant plus vite que le décor pour créer de la
## profondeur. Basé sur Parallax2D (Node2D) : il respecte le z-index, donc il
## passe DEVANT le jeu mais reste SOUS l'interface (CanvasLayer). `tint` donne
## la teinte sombre propre au niveau (feuillage, pierre, brume…).
static func add_foreground(host: Node, tint: Color) -> void:
	var fg := Parallax2D.new()
	fg.scroll_scale = Vector2(1.55, 1.02)
	fg.repeat_size = Vector2(1500, 0)
	fg.z_index = 4
	host.add_child(fg)
	# Deux touffes de feuillage suspendues au haut de l'écran.
	for tx in [220.0, 900.0]:
		_frond_cluster(fg, Vector2(float(tx), -12.0), tint)
	# Herbes sombres qui montent du bas de l'écran.
	for bx in [560.0, 1230.0]:
		_grass_clump(fg, Vector2(float(bx), 560.0), tint)

static func _poly(parent: Node, points: PackedVector2Array, color: Color, pos: Vector2) -> void:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.position = pos
	parent.add_child(p)

## Grappe de feuillage qui pend du haut de l'écran (tige + feuilles molles).
static func _frond_cluster(parent: Node, top: Vector2, tint: Color) -> void:
	var dark := Color(tint.r * 0.7, tint.g * 0.7, tint.b * 0.7, tint.a)
	_poly(parent, PackedVector2Array([
		Vector2(-5, 0), Vector2(5, 0), Vector2(3, 150), Vector2(-3, 150),
	]), dark, top)
	var ly := 30.0
	var kk := 0
	while ly < 150.0:
		var side := 1.0 if kk % 2 == 0 else -1.0
		var w := 70.0 - ly * 0.2
		_poly(parent, PackedVector2Array([
			Vector2(0, ly - 14), Vector2(side * w, ly - 4),
			Vector2(side * (w + 10.0), ly + 20), Vector2(side * (w - 20.0), ly + 22),
			Vector2(0, ly + 12),
		]), tint, top)
		ly += 34.0
		kk += 1

## Bouquet d'herbes/silhouettes sombres montant du bas de l'écran.
static func _grass_clump(parent: Node, base: Vector2, tint: Color) -> void:
	var b := 0
	while b < 9:
		var bx := -70.0 + float(b) * 18.0
		var bh := 90.0 + float((b * 37) % 70)
		var lean := (float(b % 3) - 1.0) * 16.0
		_poly(parent, PackedVector2Array([
			Vector2(bx - 8, 0), Vector2(bx + 8, 0),
			Vector2(bx + lean + 3, -bh), Vector2(bx + lean - 3, -bh),
		]), tint, base)
		b += 1
