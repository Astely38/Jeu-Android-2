extends CanvasLayer
## Autoload « Transition » : fondus au noir entre les scènes + carte-titre
## « Chapitre · Nom du niveau » à l'entrée d'un niveau.
##
## Toute navigation passe par Transition.goto(path) : on ferme au noir, on
## change de scène pendant le noir, puis on rouvre — et si la nouvelle scène
## est un niveau, une carte-titre élégante glisse un instant à l'écran.
## Vit sur un CanvasLayer autoload au-dessus de tout, en PROCESS_MODE_ALWAYS
## pour survivre à la pause (menu).

const FADE := 0.4
const CARD_HOLD := 1.7

## Chapitre de chaque niveau (0 = sanctuaire caché, hors progression).
const CHAPTER_OF := {
	"level_1": 1, "level_2": 1, "level_3": 1, "level_4": 1, "level_5": 1,
	"level_6": 2, "level_7": 2, "level_8": 2, "level_9": 2, "level_10": 2,
	"level_11": 3, "level_12": 3,
	"level_secret": 0,
}
const CHAPTER_LABEL := {
	0: "Sanctuaire Céleste",
	1: "Chapitre Premier",
	2: "Chapitre Deuxième",
	3: "Chapitre Troisième",
}
## Teinte d'accent par chapitre (émeraude · or · braise · argent-bleu).
const CHAPTER_TINT := {
	0: Color(0.55, 0.9, 0.7),
	1: Color(0.96, 0.8, 0.42),
	2: Color(0.9, 0.45, 0.3),
	3: Color(0.6, 0.82, 0.95),
}

var _fade: ColorRect
var _card: Control
var _card_band: ColorRect
var _card_chapter: Label
var _card_rule: ColorRect
var _card_name: Label
var _busy := false

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	# Tout premier démarrage : on révèle la scène de départ depuis le noir.
	_fade.color = Color(0, 0, 0, 1)
	_fade.visible = true
	_reveal()

## Ferme au noir, change de scène, rouvre (avec carte-titre si niveau).
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
		_after_load(path))

func _after_load(path: String) -> void:
	var id := _id_for(path)
	if id != "":
		_prepare_card(id)
		_reveal()
		_play_card()
	else:
		_reveal()
	_busy = false

# --- Fondu et carte -------------------------------------------------------

func _reveal() -> void:
	_fade.visible = true
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, FADE)
	t.tween_callback(func() -> void:
		_fade.visible = false)

func _play_card() -> void:
	_card.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_card, "modulate:a", 1.0, 0.5)
	t.tween_interval(CARD_HOLD)
	t.tween_property(_card, "modulate:a", 0.0, 0.6)

func _prepare_card(id: String) -> void:
	var chap: int = int(CHAPTER_OF.get(id, 1))
	var tint: Color = CHAPTER_TINT.get(chap, CHAPTER_TINT[1])
	_card_chapter.text = String(CHAPTER_LABEL.get(chap, "")).to_upper()
	_card_chapter.add_theme_color_override("font_color", tint)
	_card_rule.color = Color(tint.r, tint.g, tint.b, 0.85)
	_card_name.text = _clean_name(id)

## Nom du niveau sans son préfixe de chapitre (« II · », « ✦ »…).
func _clean_name(id: String) -> String:
	var raw := String(SaveManager.LEVEL_NAMES.get(id, id))
	for sep in ["·", "✦"]:
		var i := raw.rfind(sep)
		if i != -1:
			raw = raw.substr(i + sep.length())
	return raw.strip_edges()

func _id_for(path: String) -> String:
	for k in SaveManager.LEVEL_SCENES.keys():
		if String(SaveManager.LEVEL_SCENES[k]) == path:
			return String(k)
	return ""

# --- Construction de l'overlay --------------------------------------------

func _build() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_card = Control.new()
	_card.anchor_right = 1.0
	_card.anchor_bottom = 1.0
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.modulate = Color(1, 1, 1, 0)
	add_child(_card)

	# Bandeau sombre translucide pour la lisibilité par-dessus le décor.
	_card_band = ColorRect.new()
	_card_band.color = Color(0.02, 0.02, 0.04, 0.42)
	_card_band.anchor_right = 1.0
	_card_band.anchor_top = 0.5
	_card_band.anchor_bottom = 0.5
	_card_band.offset_top = -78.0
	_card_band.offset_bottom = 78.0
	_card_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_card_band)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	_card_chapter = Label.new()
	_card_chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_chapter.add_theme_font_size_override("font_size", 19)
	_card_chapter.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_card_chapter.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(_card_chapter)

	_card_rule = ColorRect.new()
	_card_rule.custom_minimum_size = Vector2(240, 2)
	_card_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_card_rule)

	_card_name = Label.new()
	_card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_name.add_theme_font_size_override("font_size", 40)
	_card_name.add_theme_color_override("font_color", Color(0.96, 0.96, 1.0))
	_card_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	_card_name.add_theme_constant_override("shadow_offset_y", 3)
	box.add_child(_card_name)
