class_name TextureLab
extends Object
## Atelier de textures PROCÉDURALES générées dans le moteur (FastNoiseLite +
## NoiseTexture2D). Aucun fichier image binaire n'est nécessaire : tout est
## calculé à la volée, tuilable (seamless) et léger sur mobile.
##
## On s'en sert pour donner de la MATIÈRE aux surfaces peintes à plat (grain
## de pierre/terre sur les plateformes, voiles nuageux, etc.) sans nuire à la
## lisibilité : les textures restent en surcouche discrète et sombre douce.

## Cache partagé : une seule texture de grain pour toutes les plateformes,
## déclinée ensuite par décalage (texture_offset) pour éviter la répétition.
static var _grain: NoiseTexture2D

## Nuage de mouchetures sombres tuilable. Le dégradé va d'un noir semi-opaque
## (`dark`) vers le transparent : appliqué en surcouche, cela crée des taches
## d'ombre douces, comme des variations de matière sur la pierre.
static func mottle(px: int, freq: float, seed_i: int, dark: float, octaves: int = 3) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.seed = seed_i
	n.fractal_octaves = octaves
	var tex := NoiseTexture2D.new()
	tex.width = px
	tex.height = px
	tex.seamless = true
	tex.generate_mipmaps = false
	var g := Gradient.new()
	g.set_color(0, Color(0.0, 0.0, 0.0, dark))
	g.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	tex.color_ramp = g
	tex.noise = n
	return tex

## Texture de grain partagée pour les plateformes (générée une fois).
static func platform_grain() -> NoiseTexture2D:
	if _grain == null:
		_grain = mottle(128, 0.05, 1337, 0.55, 3)
	return _grain

## Cache : texture de voile nuageux (nuages vaporeux tuilables).
static var _cloud: NoiseTexture2D

## Voile nuageux doux et tuilable : bruit fractal fondu vers le blanc, avec
## un seuil qui ne garde que les crêtes (aspect vaporeux, pas un aplat).
static func cloud_veil() -> NoiseTexture2D:
	if _cloud == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_PERLIN
		n.frequency = 0.014
		n.fractal_octaves = 4
		n.seed = 909
		var t := NoiseTexture2D.new()
		t.width = 256
		t.height = 256
		t.seamless = true
		t.generate_mipmaps = false
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
		g.set_color(1, Color(1.0, 1.0, 1.0, 0.9))
		g.add_point(0.52, Color(1.0, 1.0, 1.0, 0.0))
		t.color_ramp = g
		t.noise = n
		_cloud = t
	return _cloud

## Sème quelques voiles nuageux texturés dans une couche de ciel, chacun
## teinté par `tint` et animé d'une lente oscillation horizontale (dérive
## sans saut). `span` = largeur du niveau.
static func add_clouds(layer: Node2D, count: int, y0: float, y1: float,
		span: float, tint: Color) -> void:
	var i := 0
	while i < count:
		var s := Sprite2D.new()
		s.texture = cloud_veil()
		var bx := 200.0 + span * float(i) / float(count) + float((i * 137) % 200)
		var by := y0 + (y1 - y0) * float((i * 53) % 100) / 100.0
		s.position = Vector2(bx, by)
		s.scale = Vector2(2.6 + float(i % 3) * 0.7, 0.9 + float(i % 2) * 0.3)
		var a := tint.a * (0.7 + 0.3 * float(i % 3))
		s.modulate = Color(tint.r, tint.g, tint.b, a)
		layer.add_child(s)
		var drift := 26.0 + float(i % 3) * 12.0
		var dur := 7.0 + float(i % 4) * 2.0
		var tw := s.create_tween().set_loops()
		tw.tween_property(s, "position:x", bx + drift, dur).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "position:x", bx - drift, dur).set_trans(Tween.TRANS_SINE)
		i += 1

## Bancs de brume TEXTURÉE qui roulent au ras du sol : nappes larges et
## plates, très diffuses, qui dérivent lentement. `y` = hauteur du sol.
static func add_ground_mist(parent: Node2D, count: int, y: float, span: float,
		tint: Color, z: int = 2) -> void:
	var i := 0
	while i < count:
		var s := Sprite2D.new()
		s.texture = cloud_veil()
		var bx := 150.0 + span * float(i) / float(count) + float((i * 113) % 220)
		var by := y - float((i * 29) % 26)
		s.position = Vector2(bx, by)
		s.scale = Vector2(3.4 + float(i % 3) * 0.9, 0.5 + float(i % 2) * 0.18)
		s.z_index = z
		s.modulate = Color(tint.r, tint.g, tint.b, tint.a * (0.7 + 0.3 * float(i % 3)))
		parent.add_child(s)
		var drift := 40.0 + float(i % 4) * 14.0
		var dur := 6.0 + float(i % 4) * 2.0
		var tw := s.create_tween().set_loops()
		tw.tween_property(s, "position:x", bx + drift, dur).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "position:x", bx - drift, dur).set_trans(Tween.TRANS_SINE)
		i += 1

## Ajoute une surcouche de grain tuilé sur un polygone rectangulaire donné.
## `alpha` règle la force globale ; `off` décale la texture pour varier.
static func add_grain(parent: Node2D, half_w: float, top: float, bottom: float,
		alpha: float, off: float) -> void:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([
		Vector2(-half_w, top), Vector2(half_w, top),
		Vector2(half_w, bottom), Vector2(-half_w, bottom),
	])
	p.texture = platform_grain()
	p.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	p.texture_offset = Vector2(off, off * 0.6)
	p.color = Color(1.0, 1.0, 1.0, alpha)
	parent.add_child(p)

## Texture un polygone de forme quelconque (montagne, colline...) avec le
## grain de matière, à `pos`. Le grain suit les UV = sommets, donc il tuile
## naturellement sur toute la surface de la forme.
static func grain_poly(parent: Node2D, points: PackedVector2Array, alpha: float,
		off: Vector2, pos := Vector2.ZERO) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.position = pos
	p.texture = platform_grain()
	p.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	p.texture_offset = off
	p.color = Color(1.0, 1.0, 1.0, alpha)
	parent.add_child(p)
	return p
