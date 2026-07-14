class_name SpriteSheet
extends RefCounted
## Utilitaire : construit un SpriteFrames à partir de bandes horizontales
## de frames CARRÉES (taille frame = hauteur de l'image). Chaque définition :
##   { "name": String, "path": String, "frames": int, "fps": float, "loop": bool }

static func build(defs: Array) -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for d in defs:
		var tex: Texture2D = load(d["path"])
		var size: int = tex.get_height()
		var count: int = int(d["frames"])
		var anim_name: String = d["name"]
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, d.get("loop", true))
		sf.set_animation_speed(anim_name, d.get("fps", 8.0))
		for i in count:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * size, 0, size, size)
			sf.add_frame(anim_name, at)
	return sf
