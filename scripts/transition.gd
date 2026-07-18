extends CanvasLayer
## Autoload « Transition » : fondus au noir entre les scènes + écran-titre à
## l'entrée d'un niveau.
##
## Toute navigation passe par Transition.goto(path) : on ferme au noir, on
## change de scène pendant le noir, puis on rouvre.
## Pour un NIVEAU, l'écran reste noir et affiche le nom du niveau pendant que
## le survol d'introduction se joue en coulisse (donc sans rien dévoiler du
## niveau) ; l'écran-titre se retire une fois la caméra revenue sur Eneko.
## Un tap passe l'écran-titre.
## Vit sur un CanvasLayer autoload au-dessus de tout, en PROCESS_MODE_ALWAYS
## pour survivre à la pause (menu).

const FADE := 0.4
## Durée d'affichage du nom, calibrée pour couvrir le survol d'intro (~1.8 s)
## avant de dévoiler le niveau.
const TITLE_HOLD := 1.5

## Chapitre de chaque niveau (0 = sanctuaire caché, hors progression).
const CHAPTER_OF := {
	"level_1": 1, "level_2": 1, "level_3": 1, "level_4": 1, "level_5": 1,
	"level_6": 2, "level_7": 2, "level_8": 2, "level_9": 2, "level_10": 2,
	"level_11": 3, "level_12": 3, "level_13": 3,
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
var _title: Control
var _title_chapter: Label
var _title_rule: ColorRect
var _title_name: Label
var _title_tween: Tween
var _busy := false

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	# Tout premier démarrage : on révèle la scène de départ depuis le noir.
	_fade.color = Color(0, 0, 0, 1)
	_fade.visible = true
	_reveal()

## Ferme au noir, change de scène, rouvre (écran-titre si c'est un niveau).
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
		_show_title(id)
	else:
		_reveal()
		_busy = false

# --- Fondu simple ---------------------------------------------------------

func _reveal() -> void:
	_fade.visible = true
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, FADE)
	t.tween_callback(func() -> void:
		_fade.visible = false)

# --- Écran-titre ----------------------------------------------------------

## Affiche le nom sur le noir opaque (le survol se joue derrière), patiente,
## puis retire l'écran pour dévoiler le niveau. Skippable au tap.
func _show_title(id: String) -> void:
	_prepare_title(id)
	_fade.visible = true
	_fade.color = Color(0, 0, 0, 1)
	_title.visible = true
	_title.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_title, "modulate:a", 1.0, 0.4)
	t.tween_interval(TITLE_HOLD)
	t.tween_property(_fade, "color:a", 0.0, 0.6)
	t.parallel().tween_property(_title, "modulate:a", 0.0, 0.6)
	t.tween_callback(func() -> void:
		_fade.visible = false
		_title.visible = false
		_title_tween = null
		_busy = false)
	_title_tween = t

func _prepare_title(id: String) -> void:
	var chap: int = int(CHAPTER_OF.get(id, 1))
	var tint: Color = CHAPTER_TINT.get(chap, CHAPTER_TINT[1])
	_title_chapter.text = String(CHAPTER_LABEL.get(chap, "")).to_upper()
	_title_chapter.add_theme_color_override("font_color", tint)
	_title_rule.color = Color(tint.r, tint.g, tint.b, 0.85)
	_title_name.text = _clean_name(id)

## Un tap/touche pendant l'écran-titre le termine aussitôt (dévoile le niveau).
func _input(event: InputEvent) -> void:
	if _title_tween == null or not _title_tween.is_valid() or not _title_tween.is_running():
		return
	if (event is InputEventScreenTouch or event is InputEventKey) and event.is_pressed():
		_title_tween.custom_step(999.0)

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

	_title = Control.new()
	_title.anchor_right = 1.0
	_title.anchor_bottom = 1.0
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.modulate = Color(1, 1, 1, 0)
	_title.visible = false
	add_child(_title)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	_title_chapter = Label.new()
	_title_chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_chapter.add_theme_font_size_override("font_size", 20)
	box.add_child(_title_chapter)

	_title_rule = ColorRect.new()
	_title_rule.custom_minimum_size = Vector2(240, 2)
	_title_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_title_rule)

	_title_name = Label.new()
	_title_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_name.add_theme_font_size_override("font_size", 42)
	_title_name.add_theme_color_override("font_color", Color(0.96, 0.96, 1.0))
	box.add_child(_title_name)
