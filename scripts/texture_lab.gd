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
