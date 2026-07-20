class_name AmbientDialogue
extends Node
## Dialogues passifs : de courtes répliques d'ambiance (pensées d'Eneko,
## murmures des lieux, esprits reconnaissants) qui s'affichent brièvement en
## bas de l'écran quand le joueur franchit certains points — sans jamais
## bloquer le jeu ni demander d'appui. Chaque réplique ne se déclenche
## qu'une fois.
##
## Usage : instancier, add_child au niveau, puis appeler add_line(x, ...) pour
## chaque déclencheur. La bande de détection est verticale et très haute, donc
## la hauteur du joueur n'a pas d'importance (fonctionne à plat comme en
## escalier).

var _panel: PanelContainer
var _caption: Label
var _tween: Tween

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -330.0
	_panel.offset_right = 330.0
	_panel.offset_top = -150.0
	_panel.offset_bottom = -104.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.1, 0.74)
	sb.border_color = Color(0.85, 0.7, 0.4, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(9.0)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.modulate.a = 0.0
	layer.add_child(_panel)

	_caption = Label.new()
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override("font_size", 17)
	_caption.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	_caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_caption.add_theme_constant_override("shadow_offset_y", 1)
	_panel.add_child(_caption)

## Ajoute un déclencheur à l'abscisse `x` : au passage du joueur, la réplique
## s'affiche puis s'efface. `host` est le niveau (Node2D) qui reçoit la zone.
func add_line(host: Node, x: float, speaker: String, text: String) -> void:
	var a := Area2D.new()
	a.position = Vector2(x, 250.0)
	var sh := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(36, 1100)
	sh.shape = r
	a.add_child(sh)
	host.add_child(a)
	a.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			_show(speaker, text)
			a.queue_free()
	)

func _show(speaker: String, text: String) -> void:
	if speaker != "":
		_caption.text = "%s — %s" % [speaker, text]
	else:
		_caption.text = text
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_panel.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.35)
	_tween.tween_interval(3.8)
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.6)
