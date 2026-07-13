extends Area2D
## Léonie, gardienne de la forêt (esprit kitsune). PNJ simple qui déclenche
## un dialogue la première fois qu'Eneko s'approche.

signal talk(lines)

const KITSUNE := "res://assets/character/kitsune/"

## Répliques par défaut.
const DEFAULT_LINES := [
	{ "name": "Léonie", "text": "Halte, jeune sabreur. Peu osent s'aventurer dans la Clairière des Bambous." },
	{ "name": "Léonie", "text": "Je suis Léonie, gardienne de cette forêt. Les esprits d'ici sont agités..." },
	{ "name": "Léonie", "text": "Ton sabre devra être aussi vif que ton regard. Tranche les esprits corrompus, mais garde-toi de leur contact." },
	{ "name": "Léonie", "text": "Le torii illuminé, plus loin, marque la sortie. Va, Eneko — la Voie du Sabre t'attend." },
	{ "name": "Eneko", "text": "Merci, Léonie. Je ne faiblirai pas." },
]

var lines: Array = DEFAULT_LINES
var _triggered := false

@onready var anim: AnimatedSprite2D = $Anim

func _ready() -> void:
	anim.sprite_frames = SpriteSheet.build([
		{"name": "idle", "path": KITSUNE + "Idle.png", "frames": 8, "fps": 8.0, "loop": true},
	])
	anim.play("idle")
	body_entered.connect(_on_body_entered)

## Remplace les répliques par défaut.
func set_lines(new_lines: Array) -> void:
	lines = new_lines

func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if body.has_method("take_damage"):
		_triggered = true
		talk.emit(lines)
