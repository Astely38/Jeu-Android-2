extends CanvasLayer
## Autoload « Transition » : fondus au noir entre les scènes.
##
## Toute navigation passe par Transition.goto(path) : on ferme au noir, on
## change de scène pendant le noir, puis on rouvre — fini les coupures sèches.
## Vit sur un CanvasLayer autoload au-dessus de tout, en PROCESS_MODE_ALWAYS
## pour survivre à la pause (menu).

const FADE := 0.4

var _fade: ColorRect
var _busy := false

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	# Tout premier démarrage : on révèle la scène de départ depuis le noir.
	_fade.color = Color(0, 0, 0, 1)
	_fade.visible = true
	_reveal()

## Ferme au noir, change de scène, rouvre.
func goto(path: String) -> void:
	if _busy:
		return
	_busy = true
	# On quitte la scène : plus de raison de rester en pause.
	get_tree().paused = false
	_fade.visible = true
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, FADE)
	t.tween_callback(func() -> void:
		get_tree().change_scene_to_file(path))
	t.tween_interval(0.05)
	t.tween_callback(func() -> void:
		_reveal()
		_busy = false)

func _reveal() -> void:
	_fade.visible = true
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, FADE)
	t.tween_callback(func() -> void:
		_fade.visible = false)

func _build() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
