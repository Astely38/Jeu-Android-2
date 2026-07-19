extends CanvasLayer
class_name ChapterRecap
## Écran de fin de chapitre, PAGINÉ et épuré : une idée par page plutôt qu'un
## seul écran surchargé.
##   1) Épilogue  — la conclusion de l'histoire.
##   2) Bilan     — le résultat de CE combat (grade, temps, orbes…).
##   3) À suivre   — l'amorce du chapitre suivant + les boutons.
##
## Usage :
##   var r := ChapterRecap.new(); add_child(r)
##   r.show_recap({ "title":…, "accent":Color, "epilogue":…, "special":…,
##                  "results":Dictionary, "next_title":…, "hook":…,
##                  "next_scene":… })

const CREAM := Color(0.95, 0.92, 0.86)
const WRAP := 660.0

var _cfg: Dictionary = {}
var _pages: Array = []
var _idx := -1
var _hint: Label
var _fade_tween: Tween

func show_recap(cfg: Dictionary) -> void:
	_cfg = cfg
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	var accent: Color = cfg.get("accent", CREAM)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_pages = [_page_epilogue(), _page_stats(), _page_next()]
	for p in _pages:
		add_child(p)
		p.visible = false

	# Indice discret « touche pour continuer », comme sur les écrans-titres.
	_hint = Label.new()
	_hint.text = "Touche pour continuer  ▸"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -66.0
	_hint.offset_bottom = -30.0
	_hint.add_theme_font_size_override("font_size", 17)
	_hint.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.75))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_show_page(0)

## Un tap/touche fait défiler les pages, tant qu'on n'est pas sur la dernière
## (où les boutons de choix prennent le relais). Comme les écrans-titres.
func _input(event: InputEvent) -> void:
	if _idx >= _pages.size() - 1:
		return
	if (event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
		_advance()

func _advance() -> void:
	_show_page(mini(_idx + 1, _pages.size() - 1))

func _show_page(i: int) -> void:
	if i == _idx:
		return
	_idx = i
	for k in _pages.size():
		_pages[k].visible = (k == i)
	# La page apparaît en fondu, comme le texte d'un écran-titre.
	var page: Control = _pages[i]
	page.modulate.a = 0.0
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(page, "modulate:a", 1.0, 0.6)
	# L'indice ne s'affiche pas sur la dernière page (les boutons décident).
	var last := (i >= _pages.size() - 1)
	_hint.visible = not last

# --- Pages ----------------------------------------------------------------

func _page_root() -> Array:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 40.0
	center.offset_right = -40.0
	center.offset_top = 24.0
	center.offset_bottom = -96.0
	root.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	return [root, box]

func _page_epilogue() -> Control:
	var rb := _page_root()
	var box: VBoxContainer = rb[1]
	var accent: Color = _cfg.get("accent", CREAM)
	box.add_child(_title(String(_cfg.get("title", "")), accent, 32))
	box.add_child(_rule(accent))
	box.add_child(_para(String(_cfg.get("epilogue", "")), CREAM, 18))
	var special := String(_cfg.get("special", ""))
	if special != "":
		box.add_child(_para(special, Color(1.0, 0.86, 0.5), 16))
	return rb[0]

func _page_stats() -> Control:
	var rb := _page_root()
	var box: VBoxContainer = rb[1]
	var accent: Color = _cfg.get("accent", CREAM)
	var res: Dictionary = _cfg.get("results", {})
	box.add_child(_title("Bilan du combat", accent, 24))
	box.add_child(_rule(accent))
	var grade := str(res.get("grade", ""))
	var g := _line("Grade   —   %s" % Challenge.grade_name(grade), 30)
	g.add_theme_color_override("font_color", Challenge.grade_color(grade))
	box.add_child(g)
	box.add_child(_line("Temps   —   %s" % _fmt_time(float(res.get("time", 0.0))), 22))
	box.add_child(_line("Orbes   —   %d / %d" % [int(res.get("orbs", 0)), int(res.get("total_orbs", 1))], 22))
	box.add_child(_line("Esprits vaincus   —   %d" % int(res.get("kills", 0)), 22))
	if int(res.get("combo", 0)) >= 2:
		box.add_child(_line("Meilleur combo   —   ×%d" % int(res.get("combo", 0)), 22))
	return rb[0]

func _page_next() -> Control:
	var rb := _page_root()
	var box: VBoxContainer = rb[1]
	var accent: Color = _cfg.get("accent", CREAM)
	var next_title := String(_cfg.get("next_title", ""))
	if next_title != "":
		box.add_child(_title("À suivre", accent, 22))
		box.add_child(_title(next_title, CREAM, 27))
		box.add_child(_rule(accent))
		box.add_child(_para(String(_cfg.get("hook", "")), Color(0.84, 0.82, 0.88), 16))
	else:
		box.add_child(_title("Fin du chapitre", accent, 28))
		box.add_child(_rule(accent))
		box.add_child(_para(String(_cfg.get("hook", "")), Color(0.84, 0.82, 0.88), 16))
	box.add_child(_spacer(10.0))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	box.add_child(buttons)
	var next_scene := String(_cfg.get("next_scene", ""))
	if next_scene != "":
		var nb := _button("Chapitre suivant  →", accent)
		nb.pressed.connect(func() -> void: Transition.goto(next_scene))
		buttons.add_child(nb)
	var replay := _button("Rejouer", Color(0.7, 0.62, 0.55))
	replay.pressed.connect(func() -> void: get_tree().reload_current_scene())
	buttons.add_child(replay)
	var menu := _button("Menu", Color(0.6, 0.5, 0.5))
	menu.pressed.connect(func() -> void: Transition.goto("res://scenes/main_menu.tscn"))
	buttons.add_child(menu)
	return rb[0]

# --- Éléments -------------------------------------------------------------

func _title(text: String, col: Color, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WRAP, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l

func _para(text: String, col: Color, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WRAP, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _line(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", CREAM)
	return l

func _rule(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(col.r, col.g, col.b, 0.7)
	r.custom_minimum_size = Vector2(200, 2)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return r

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _button(text: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 52)
	b.add_theme_font_size_override("font_size", 22)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.16, 0.94)
	sb.border_color = accent
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8.0)
	var hov: StyleBoxFlat = sb.duplicate()
	hov.bg_color = Color(0.18, 0.18, 0.26, 0.96)
	var prs: StyleBoxFlat = sb.duplicate()
	prs.bg_color = Color(0.24, 0.24, 0.32, 0.98)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", prs)
	b.add_theme_color_override("font_color", CREAM)
	return b

func _fmt_time(seconds: float) -> String:
	var mins: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	return "%d:%02d" % [mins, secs]
