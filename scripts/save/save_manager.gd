extends Node
## Autoload (singleton) : sauvegarde locale en JSON (user://save.json).
## Retient les niveaux débloqués/terminés, le meilleur score d'orbes par
## niveau, et le dernier niveau joué (pour le bouton "Continuer").

const SAVE_PATH := "user://save.json"

## Ordre de progression des niveaux.
const LEVEL_ORDER := ["level_1", "level_2", "level_3", "level_4", "level_5"]

const LEVEL_NAMES := {
	"level_1": "La Clairière des Bambous",
	"level_2": "Le Temple Oublié",
	"level_3": "Le Village des Ombres",
	"level_4": "La Montagne des Brumes",
	"level_5": "Le Sanctuaire Final",
}

## Seuls les niveaux listés ici existent réellement pour l'instant ; les
## autres s'affichent comme "à venir" dans la sélection de niveaux.
const LEVEL_SCENES := {
	"level_1": "res://levels/level_1.tscn",
	"level_2": "res://levels/level_2.tscn",
}

var data := {}

func _ready() -> void:
	load_data()

func load_data() -> void:
	data = {
		"unlocked_levels": ["level_1"],
		"completed_levels": [],
		"best_orbs": {},
		"last_level": "level_1",
	}
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		for key in data.keys():
			if parsed.has(key):
				data[key] = parsed[key]

func save_data() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func is_unlocked(level_id: String) -> bool:
	return data["unlocked_levels"].has(level_id)

func is_completed(level_id: String) -> bool:
	return data["completed_levels"].has(level_id)

func best_orbs(level_id: String) -> int:
	return int(data["best_orbs"].get(level_id, 0))

## Appelé quand Eneko atteint le torii : marque le niveau terminé, débloque
## le suivant dans LEVEL_ORDER, et retient le meilleur score d'orbes.
func complete_level(level_id: String, orbs: int) -> void:
	if not data["completed_levels"].has(level_id):
		data["completed_levels"].append(level_id)
	if orbs > best_orbs(level_id):
		data["best_orbs"][level_id] = orbs
	var idx: int = LEVEL_ORDER.find(level_id)
	if idx != -1 and idx + 1 < LEVEL_ORDER.size():
		var next_id: String = LEVEL_ORDER[idx + 1]
		if not data["unlocked_levels"].has(next_id):
			data["unlocked_levels"].append(next_id)
	save_data()

## Retient le dernier niveau entré (pour le bouton "Continuer").
func set_last_level(level_id: String) -> void:
	data["last_level"] = level_id
	save_data()

func get_last_level_scene() -> String:
	var id: String = data.get("last_level", "level_1")
	return LEVEL_SCENES.get(id, LEVEL_SCENES["level_1"])
