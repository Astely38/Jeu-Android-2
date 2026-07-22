class_name SpriteSheet
extends RefCounted
## Utilitaire : construit un SpriteFrames à partir de feuilles de sprites.
## Par défaut : bande horizontale de frames CARRÉES (taille frame = hauteur
## de l'image), comme avant. Pour une feuille en GRILLE (plusieurs lignes,
## frames non carrées), on précise "frame_w"/"frame_h"/"cols" — les frames
## sont alors lues en ligne par ligne (la dernière ligne peut être incomplète).
## Chaque définition :
##   { "name": String, "path": String, "frames": int, "fps": float, "loop": bool,
##     "frame_w": int (optionnel), "frame_h": int (optionnel), "cols": int (optionnel) }

static func build(defs: Array) -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for d in defs:
		var tex: Texture2D = load(d["path"])
		var count: int = int(d["frames"])
		var anim_name: String = d["name"]
		var fw: int = int(d.get("frame_w", tex.get_height()))
		var fh: int = int(d.get("frame_h", tex.get_height()))
		var cols: int = int(d.get("cols", int(tex.get_width() / fw)))
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, d.get("loop", true))
		sf.set_animation_speed(anim_name, d.get("fps", 8.0))
		for i in count:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2((i % cols) * fw, int(i / cols) * fh, fw, fh)
			sf.add_frame(anim_name, at)
	return sf
