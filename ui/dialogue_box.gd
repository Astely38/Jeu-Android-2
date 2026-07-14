extends CanvasLayer
## Boîte de dialogue simple affichée en bas de l'écran.
## S'utilise via start([{ "name": ..., "text": ... }, ...]) et émet
## "finished" une fois toutes les répliques lues.

signal finished

var _lines: Array = []
var _index := 0

@onready var name_label: Label = $Panel/Name
@onready var text_label: Label = $Panel/Text
@onready var advance_button: Button = $Advance

func _ready() -> void:
	visible = false
	advance_button.pressed.connect(advance)

## Démarre une séquence de dialogue.
func start(lines: Array) -> void:
	_lines = lines
	_index = 0
	visible = true
	_show_current()

func _show_current() -> void:
	var line: Dictionary = _lines[_index]
	name_label.text = str(line.get("name", ""))
	text_label.text = str(line.get("text", ""))

## Passe à la réplique suivante (tap écran ou touche).
func advance() -> void:
	if not visible:
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
