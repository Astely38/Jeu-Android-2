class_name PlatformPainter
extends Object
## Peintre de plateformes : remplace les rectangles plats par des blocs
## avec du relief — strates ondulées, ombrage des bords et du dessous,
## liseré lumineux au sommet, bosses irrégulières sur la surface et
## mouchetis de texture. Chaque niveau fournit son thème de couleurs ;
## le style "cut" (pierre taillée) remplace les ondulations par des
## joints de maçonnerie réguliers pour le sanctuaire.
##
## Tout est déterministe (pseudo-hasard dérivé de la position du bloc),
## donc identique d'une partie à l'autre. La collision n'est pas touchée :
## uniquement du dessin.

const TOP := -50.0
const SURF_BOTTOM := -36.0
const BOTTOM := 450.0

## Pseudo-hasard stable dans [0, m) dérivé d'une graine et d'un index.
static func _h(seed_i: int, k: int, m: int) -> float:
	return float(absi(seed_i * 73856093 + k * 19349663) % maxi(1, m))

static func _poly(parent: Node, pts: PackedVector2Array, color: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color
	parent.add_child(p)

static func _rect(parent: Node, half_w: float, top: float, bottom: float, color: Color) -> void:
	_poly(parent, PackedVector2Array([
		Vector2(-half_w, top), Vector2(half_w, top),
		Vector2(half_w, bottom), Vector2(-half_w, bottom),
	]), color)

## Bande dont le bord supérieur ondule (séparation naturelle de strates).
static func _wavy_band(parent: Node, half_w: float, y_top: float, y_bottom: float,
		amp: int, seed_i: int, salt: int, color: Color) -> void:
	var pts := PackedVector2Array()
	var x := -half_w
	var k := 0
	while x < half_w:
		pts.append(Vector2(x, y_top + _h(seed_i, salt + k, amp)))
		x += 56.0
		k += 1
	pts.append(Vector2(half_w, y_top + _h(seed_i, salt + k, amp)))
	pts.append(Vector2(half_w, y_bottom))
	pts.append(Vector2(-half_w, y_bottom))
	_poly(parent, pts, color)

## Peint un bloc complet. Thème attendu :
##   top, top_light, body_a, body_b, dark, speck : Color
##   cut : bool (facultatif, pierre taillée au lieu de bords naturels)
static func paint(parent: Node2D, half_w: float, theme: Dictionary) -> void:
	var seed_i := int(absf(parent.position.x))
	var top_c: Color = theme["top"]
	var top_light: Color = theme["top_light"]
	var body_a: Color = theme["body_a"]
	var body_b: Color = theme["body_b"]
	var dark: Color = theme["dark"]
	var speck: Color = theme["speck"]
	var cut: bool = bool(theme.get("cut", false))

	# 1) Corps principal, puis strates de plus en plus sombres vers le bas
	# (ondulées en style naturel, rectilignes en pierre taillée).
	_rect(parent, half_w, TOP, BOTTOM, body_a)
	if cut:
		_rect(parent, half_w, 170.0, BOTTOM, body_b)
		_rect(parent, half_w, 330.0, BOTTOM, dark)
	else:
		_wavy_band(parent, half_w, 150.0, BOTTOM, 34, seed_i, 11, body_b)
		_wavy_band(parent, half_w, 320.0, BOTTOM, 40, seed_i, 47, dark)

	# 2) Ombrage des flancs : le bloc paraît arrondi au lieu de tranché.
	var side_shade := Color(dark.r, dark.g, dark.b, 0.5)
	_poly(parent, PackedVector2Array([
		Vector2(-half_w, TOP), Vector2(-half_w + 12, TOP + 20),
		Vector2(-half_w + 12, BOTTOM), Vector2(-half_w, BOTTOM),
	]), side_shade)
	_poly(parent, PackedVector2Array([
		Vector2(half_w, TOP), Vector2(half_w - 12, TOP + 20),
		Vector2(half_w - 12, BOTTOM), Vector2(half_w, BOTTOM),
	]), side_shade)

	# 3) Ombre portée juste sous la couche de surface.
	_rect(parent, half_w, SURF_BOTTOM, SURF_BOTTOM + 7.0, Color(0, 0, 0, 0.22))

	# 4) Couche de surface (herbe, neige, dallage...) avec de petites
	# bosses au-dessus de la ligne de sol en style naturel.
	_rect(parent, half_w, TOP, SURF_BOTTOM, top_c)
	if not cut:
		var hx := -half_w + 26.0
		var j := 0
		while hx < half_w - 26.0:
			var hw := 14.0 + _h(seed_i, j, 10)
			_poly(parent, PackedVector2Array([
				Vector2(hx - hw, TOP), Vector2(hx, TOP - 3.0 - _h(seed_i, j + 1, 4)),
				Vector2(hx + hw, TOP),
			]), top_c)
			hx += 48.0 + _h(seed_i, j + 2, 34)
			j += 1

	# 5) Liseré lumineux au sommet : la lumière accroche le bord.
	_rect(parent, half_w, TOP, TOP + 3.0, top_light)

	# 6) Style pierre taillée : joints de maçonnerie décalés + chanfrein.
	if cut:
		var row_y := 40.0
		var row := 0
		while row_y < BOTTOM - 40.0:
			_rect(parent, half_w - 6.0, row_y, row_y + 2.0, Color(0, 0, 0, 0.18))
			var jx := -half_w + 40.0 + float(row % 2) * 45.0
			while jx < half_w - 30.0:
				_poly(parent, PackedVector2Array([
					Vector2(jx, row_y - 66.0), Vector2(jx + 2, row_y - 66.0),
					Vector2(jx + 2, row_y), Vector2(jx, row_y),
				]), Color(0, 0, 0, 0.12))
				jx += 90.0
			row_y += 68.0
			row += 1
		_poly(parent, PackedVector2Array([
			Vector2(-half_w, TOP), Vector2(-half_w + 5, TOP),
			Vector2(-half_w + 5, BOTTOM), Vector2(-half_w, BOTTOM),
		]), Color(1, 1, 1, 0.14))

	# 7) Mouchetis : petits éclats de texture dispersés dans le corps.
	var count := maxi(3, int(half_w / 24.0))
	var s := 0
	while s < count:
		var sx := -half_w + 16.0 + _h(seed_i, s * 2 + 5, int(maxf(1.0, half_w * 2.0 - 32.0)))
		var sy := -18.0 + _h(seed_i, s * 2 + 6, 300)
		var r := 2.0 + _h(seed_i, s + 9, 3)
		_poly(parent, PackedVector2Array([
			Vector2(sx - r, sy), Vector2(sx, sy - r),
			Vector2(sx + r, sy), Vector2(sx, sy + r),
		]), speck)
		s += 1
