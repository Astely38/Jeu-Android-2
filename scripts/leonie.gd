extends Area2D
## Léonie, gardienne de la forêt. PNJ qui déclenche un dialogue la
## première fois qu'Eneko s'approche. Émet "talk" avec les répliques ;
## c'est le niveau qui met le joueur en pause et affiche la boîte.

signal talk(lines)

## Répliques de la première rencontre.
const LINES := [
	{ "name": "Léonie", "text": "Halte, jeune sabreur. Peu osent s'aventurer dans la Clairière des Bambous." },
	{ "name": "Léonie", "text": "Je suis Léonie, gardienne de cette forêt. Les esprits d'ici sont agités..." },
	{ "name": "Léonie", "text": "Ton sabre devra être aussi vif que ton regard. Tranche les esprits corrompus, mais garde-toi de leur contact." },
	{ "name": "Léonie", "text": "Le torii illuminé, plus loin, marque la sortie. Va, Eneko — la Voie du Sabre t'attend." },
	{ "name": "Eneko", "text": "Merci, Léonie. Je ne faiblirai pas." },
]

var _triggered := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# On ne déclenche qu'une fois, et seulement pour le joueur.
	if _triggered:
		return
	if body.has_method("take_damage"):
		_triggered = true
		talk.emit(LINES)
