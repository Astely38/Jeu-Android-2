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

## Construit le sanctuaire de Léonie : une estrade de pierre pâle cerclée
## d'or posée sur la plateforme d'accueil, encadrée de deux petites
## lanternes de pierre, baignée d'un halo chaud et de pétales dorés.
## `ground_y` est le niveau du sol (dessus de la plateforme d'accueil) ;
## l'estrade fait 26 px de haut, un petit saut suffit pour y monter.
static func build_sanctuary(level: Node2D, x: float, ground_y: float) -> void:
	var stone := Color(0.85, 0.82, 0.74)
	var stone_dark := Color(0.68, 0.65, 0.58)
	var gold := Color(0.88, 0.72, 0.32)

	# Sanctuaire à FLEUR DE SOL : aucune collision (Node2D, pas StaticBody2D),
	# rendu derrière les personnages. On marche à travers sans avoir à sauter.
	var shrine := Node2D.new()
	shrine.position = Vector2(x, ground_y)
	shrine.z_index = -1
	level.add_child(shrine)

	# Dalle de sanctuaire incrustée au ras du sol : fin liseré d'or + pierre.
	_poly(shrine, PackedVector2Array([
		Vector2(-92, -2), Vector2(92, -2), Vector2(92, 6), Vector2(-92, 6),
	]), gold)
	_poly(shrine, PackedVector2Array([
		Vector2(-88, 1), Vector2(88, 1), Vector2(88, 6), Vector2(-88, 6),
	]), stone)
	# Losange doré au centre de la dalle.
	_poly(shrine, PackedVector2Array([
		Vector2(-12, 2), Vector2(0, -3), Vector2(12, 2), Vector2(0, 7),
	]), gold)

	# Torii doré léger en fond (décoratif : on passe dessous).
	_poly(shrine, PackedVector2Array([
		Vector2(-60, 0), Vector2(-53, 0), Vector2(-53, -86), Vector2(-60, -86),
	]), gold)
	_poly(shrine, PackedVector2Array([
		Vector2(53, 0), Vector2(60, 0), Vector2(60, -86), Vector2(53, -86),
	]), gold)
	_poly(shrine, PackedVector2Array([
		Vector2(-72, -86), Vector2(72, -86), Vector2(68, -97), Vector2(-68, -97),
	]), gold)
	_poly(shrine, PackedVector2Array([
		Vector2(-84, -100), Vector2(84, -100), Vector2(78, -108), Vector2(-78, -108),
	]), Color(0.7, 0.56, 0.24))
	_poly(shrine, PackedVector2Array([
		Vector2(-60, -74), Vector2(60, -74), Vector2(60, -80), Vector2(-60, -80),
	]), Color(0.7, 0.56, 0.24))

	# Deux petites lanternes de pierre aux extrémités (posées sur le sol).
	for side in [-1.0, 1.0]:
		var lx := float(side) * 82.0
		_poly(shrine, PackedVector2Array([
			Vector2(lx - 3, 0), Vector2(lx + 3, 0), Vector2(lx + 3, -20), Vector2(lx - 3, -20),
		]), stone_dark)
		_poly(shrine, PackedVector2Array([
			Vector2(lx - 7, -20), Vector2(lx + 7, -20), Vector2(lx + 7, -32), Vector2(lx - 7, -32),
		]), stone)
		_poly(shrine, PackedVector2Array([
			Vector2(lx - 4, -22), Vector2(lx + 4, -22), Vector2(lx + 4, -30), Vector2(lx - 4, -30),
		]), Color(1.0, 0.85, 0.45, 0.9))
		_poly(shrine, PackedVector2Array([
			Vector2(lx - 9, -32), Vector2(lx + 9, -32), Vector2(lx + 5, -38), Vector2(lx - 5, -38),
		]), stone_dark)

	# Voile texturé doré qui tourne lentement derrière le halo : la clarté
	# des aïeux, vivante et matérielle.
	var aura := Sprite2D.new()
	aura.texture = TextureLab.cloud_veil()
	aura.modulate = Color(1.0, 0.86, 0.5, 0.14)
	aura.scale = Vector2(0.8, 0.8)
	aura.position = Vector2(0, -56)
	aura.z_index = -1
	shrine.add_child(aura)
	var atw := aura.create_tween().set_loops()
	atw.tween_property(aura, "rotation", TAU, 16.0)

	# Halo de lumière chaude et pétales dorés qui montent du sanctuaire.
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(1.0, 0.88, 0.55, 0.16)
	glow.scale = Vector2(3.4, 3.0)
	glow.position = Vector2(0, -56)
	shrine.add_child(glow)

	var petals := CPUParticles2D.new()
	petals.position = Vector2(0, -24)
	petals.amount = 8
	petals.lifetime = 4.0
	petals.preprocess = 4.0
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.emission_rect_extents = Vector2(80, 30)
	petals.direction = Vector2(0, -1)
	petals.spread = 30.0
	petals.gravity = Vector2(0, -14)
	petals.initial_velocity_min = 6.0
	petals.initial_velocity_max = 16.0
	petals.scale_amount_min = 1.2
	petals.scale_amount_max = 2.0
	petals.color = Color(1.0, 0.86, 0.5, 0.6)
	shrine.add_child(petals)

	# Lucioles dorées qui vagabondent doucement autour du sanctuaire.
	var flies := CPUParticles2D.new()
	flies.position = Vector2(0, -42)
	flies.amount = 7
	flies.lifetime = 3.6
	flies.preprocess = 3.6
	flies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flies.emission_rect_extents = Vector2(74, 42)
	flies.direction = Vector2(0, -1)
	flies.spread = 180.0
	flies.gravity = Vector2.ZERO
	flies.initial_velocity_min = 4.0
	flies.initial_velocity_max = 13.0
	flies.scale_amount_min = 1.2
	flies.scale_amount_max = 2.2
	flies.color = Color(1.0, 0.9, 0.5, 0.85)
	shrine.add_child(flies)

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

	# 1b) Grain de matière : voile de mouchetures sombres tuilé sur le corps,
	# pour que la pierre/terre ne paraisse plus lisse et plate. Décalé selon
	# la position du bloc pour éviter toute répétition visible.
	TextureLab.add_grain(parent, half_w, SURF_BOTTOM, 260.0,
		0.14 if cut else 0.18, float(seed_i % 128))

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

	# 7) Style naturel : la couche de surface déborde et retombe sur les
	# flancs, et quelques racines pendent sous les bords.
	if not cut:
		_poly(parent, PackedVector2Array([
			Vector2(-half_w - 4, TOP), Vector2(-half_w + 16, TOP),
			Vector2(-half_w + 10, TOP + 14), Vector2(-half_w - 2, TOP + 20),
		]), top_c)
		_poly(parent, PackedVector2Array([
			Vector2(half_w + 4, TOP), Vector2(half_w - 16, TOP),
			Vector2(half_w - 10, TOP + 14), Vector2(half_w + 2, TOP + 20),
		]), top_c)
		var root_c := Color(dark.r * 0.8, dark.g * 0.8, dark.b * 0.8)
		var rr := 0
		while rr < 2:
			var side := -1.0 if rr == 0 else 1.0
			var rx := side * (half_w - 26.0 - _h(seed_i, rr + 13, 20))
			_poly(parent, PackedVector2Array([
				Vector2(rx - 2, SURF_BOTTOM + 4), Vector2(rx + 2, SURF_BOTTOM + 4),
				Vector2(rx + 1 + side * 5.0, SURF_BOTTOM + 26.0 + _h(seed_i, rr + 21, 14)),
			]), root_c)
			rr += 1

	# 8) Mouchetis : petits éclats de texture dispersés dans le corps.
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

	# 9) Fin liseré très clair au tout bord supérieur : la lumière rasante
	# accroche l'arête et détache la plateforme du fond.
	_rect(parent, half_w - 2.0, TOP - 2.0, TOP, Color(top_light.r, top_light.g, top_light.b, 0.5))
