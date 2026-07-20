extends CanvasLayer
## Boîte de dialogue en bas de l'écran, avec portrait animé du personnage,
## effet « machine à écrire », couleur d'accent par interlocuteur et un
## indicateur ▼ qui clignote quand on peut avancer.
## S'utilise via start([{ "name": ..., "text": ... }, ...]) et émet
## "finished" une fois toutes les répliques lues.

signal finished

const SAMURAI := "res://assets/character/samurai/"
const KITSUNE := "res://assets/character/kitsune/"
const CHARS_PER_SEC := 44.0

## Accents par personnage (le reste — L'Ombre, ???, Voix… — en violet).
const ACCENTS := {
	"Léonie": Color(0.96, 0.8, 0.42),
	"Eneko": Color(0.5, 0.85, 0.95),
}
const ACCENT_SHADOW := Color(0.82, 0.42, 0.9)

var _lines: Array = []
var _index := 0
var _full_text := ""
var _char_t := 0.0
var _revealing := false
var _blink_t := 0.0

var _samurai_frames: SpriteFrames
var _kitsune_frames: SpriteFrames
var _portrait: AnimatedSprite2D
var _mask: Node2D

@onready var panel: Panel = $Panel
@onready var portrait_frame: Panel = $Panel/PortraitFrame
@onready var name_label: Label = $Panel/Name
@onready var text_label: Label = $Panel/Text
@onready var advance_ind: Label = $Panel/AdvanceInd
@onready var advance_button: Button = $Advance

func _ready() -> void:
	visible = false
	advance_button.pressed.connect(advance)
	_samurai_frames = SpriteSheet.build([
		{"name": "idle", "path": SAMURAI + "Idle.png", "frames": 6, "fps": 8.0, "loop": true},
	])
	_kitsune_frames = SpriteSheet.build([
		{"name": "idle", "path": KITSUNE + "Idle.png", "frames": 8, "fps": 8.0, "loop": true},
	])
	# Portrait animé + masque procédural (pour les voix d'ombre), dans le cadre.
	_portrait = AnimatedSprite2D.new()
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.position = Vector2(57, 66)
	_portrait.scale = Vector2(0.86, 0.86)
	portrait_frame.add_child(_portrait)
	_mask = _build_mask()
	_mask.position = Vector2(57, 58)
	portrait_frame.add_child(_mask)

## Démarre une séquence de dialogue.
func start(lines: Array) -> void:
	_lines = lines
	_index = 0
	visible = true
	_show_current()

func _show_current() -> void:
	var line: Dictionary = _lines[_index]
	var who := str(line.get("name", ""))
	name_label.text = who
	var accent: Color = ACCENTS.get(who, ACCENT_SHADOW)
	_apply_accent(accent)
	_set_portrait(who)
	# Texte révélé caractère par caractère.
	_full_text = str(line.get("text", ""))
	text_label.text = _full_text
	text_label.visible_characters = 0
	_char_t = 0.0
	_revealing = true
	advance_ind.visible = false

## Teinte le nom, la bordure du cadre et l'indicateur selon l'interlocuteur.
func _apply_accent(accent: Color) -> void:
	name_label.add_theme_color_override("font_color", accent)
	advance_ind.add_theme_color_override("font_color", accent)
	var sb: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.9)
	panel.add_theme_stylebox_override("panel", sb)
	var sp: StyleBoxFlat = portrait_frame.get_theme_stylebox("panel").duplicate()
	sp.border_color = Color(accent.r, accent.g, accent.b, 0.7)
	portrait_frame.add_theme_stylebox_override("panel", sp)

## Choisit le portrait : Léonie (kitsune), Eneko (samurai), sinon un masque
## d'ombre procédural.
func _set_portrait(who: String) -> void:
	if who == "Léonie":
		_portrait.sprite_frames = _kitsune_frames
		_portrait.play("idle")
		_portrait.visible = true
		_mask.visible = false
	elif who == "Eneko":
		_portrait.sprite_frames = _samurai_frames
		_portrait.play("idle")
		_portrait.visible = true
		_mask.visible = false
	else:
		_portrait.visible = false
		_mask.visible = true

func _process(delta: float) -> void:
	if not visible:
		return
	if _revealing:
		_char_t += delta * CHARS_PER_SEC
		var n := int(_char_t)
		if n >= _full_text.length():
			text_label.visible_characters = -1
			_revealing = false
			advance_ind.visible = true
		else:
			text_label.visible_characters = n
	else:
		# Clignotement doux de l'indicateur ▼.
		_blink_t += delta
		advance_ind.modulate.a = 0.35 + 0.45 * (0.5 + 0.5 * sin(_blink_t * 4.0))

## Tap/touche : d'abord révéler tout le texte, puis passer à la suite.
func advance() -> void:
	if not visible:
		return
	if _revealing:
		text_label.visible_characters = -1
		_revealing = false
		advance_ind.visible = true
		return
	_index += 1
	if _index >= _lines.size():
		visible = false
		finished.emit()
	else:
		_show_current()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_X:
			advance()

## Petit masque d'ombre stylisé (pour L'Ombre, ???, Voix…) : face sombre,
## cornes, yeux luisants.
func _build_mask() -> Node2D:
	var m := Node2D.new()
	var k := 2.6
	_poly(m, PackedVector2Array([
		Vector2(-16, -12), Vector2(-14, -18), Vector2(0, -20), Vector2(14, -18),
		Vector2(16, -12), Vector2(14, 4), Vector2(6, 16), Vector2(0, 20),
		Vector2(-6, 16), Vector2(-14, 4),
	]), Color(0.16, 0.1, 0.22), k)
	for s in [-1.0, 1.0]:
		_poly(m, PackedVector2Array([
			Vector2(s * 8, -12), Vector2(s * 20, -30), Vector2(s * 14, -26), Vector2(s * 12, -12),
		]), Color(0.5, 0.4, 0.6), k)
	for s in [-1.0, 1.0]:
		var eye := Polygon2D.new()
		var ep := PackedVector2Array()
		for i in 8:
			var a := i * TAU / 8.0
			ep.append(Vector2(cos(a) * 3.2 * k, sin(a) * 2.4 * k))
		eye.polygon = ep
		eye.position = Vector2(s * 8.0 * k, -8.0 * k)
		eye.color = Color(0.85, 0.4, 0.95)
		m.add_child(eye)
	return m

func _poly(parent: Node, pts: PackedVector2Array, c: Color, k: float) -> void:
	var p := Polygon2D.new()
	var scaled := PackedVector2Array()
	for v in pts:
		scaled.append(v * k)
	p.polygon = scaled
	p.color = c
	parent.add_child(p)
