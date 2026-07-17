extends Node
## Autoload (singleton) : sauvegarde locale en JSON (user://save.json).
## Retient les niveaux débloqués/terminés, le meilleur score d'orbes par
## niveau, et le dernier niveau joué (pour le bouton "Continuer").

const SAVE_PATH := "user://save.json"

## Ordre de progression des niveaux.
const LEVEL_ORDER := ["level_1", "level_2", "level_3", "level_4", "level_5", "level_6"]

const LEVEL_NAMES := {
	"level_1": "La Clairière des Bambous",
	"level_2": "Le Temple Oublié",
	"level_3": "Le Village des Ombres",
	"level_4": "La Montagne des Brumes",
	"level_5": "Le Sanctuaire Final",
	"level_6": "II · Les Rivages de Cendre",
	"level_secret": "✦ Le Jardin Céleste",
}

## Seuls les niveaux listés ici existent réellement pour l'instant ; les
## autres s'affichent comme "à venir" dans la sélection de niveaux.
const LEVEL_SCENES := {
	"level_1": "res://levels/level_1.tscn",
	"level_2": "res://levels/level_2.tscn",
	"level_3": "res://levels/level_3.tscn",
	"level_4": "res://levels/level_4.tscn",
	"level_5": "res://levels/level_5.tscn",
	"level_6": "res://levels/level_6.tscn",
	"level_secret": "res://levels/level_secret.tscn",
}

var data := {}

func _ready() -> void:
	load_data()

func load_data() -> void:
	data = {
		"unlocked_levels": ["level_1"],
		"completed_levels": [],
		"best_orbs": {},
		"best_grades": {},
		"best_times": {},
		"last_level": "level_1",
		"settings": {},
		"achievements": {},
		"stats": {},
		"kensei_done": [],
		"prologue_seen": false,
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

## Meilleur grade obtenu sur un niveau ("" si jamais terminé).
func best_grade(level_id: String) -> String:
	return str(data["best_grades"].get(level_id, ""))

func set_best_grade(level_id: String, grade: String) -> void:
	data["best_grades"][level_id] = grade
	save_data()

## Meilleur temps (en secondes) d'un niveau ; 0.0 si jamais terminé.
func best_time(level_id: String) -> float:
	return float(data["best_times"].get(level_id, 0.0))

func set_best_time(level_id: String, seconds: float) -> void:
	data["best_times"][level_id] = seconds
	save_data()

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

## Le Jardin Céleste vient d'être découvert (vieux torii moussu du
## niveau 1) : il apparaît désormais dans la sélection de niveaux.
## Absent de LEVEL_ORDER, il ne compte pas dans la progression normale.
func discover_secret() -> void:
	if not data["unlocked_levels"].has("level_secret"):
		data["unlocked_levels"].append("level_secret")
		save_data()
	Achievements.unlock("jardin_celeste")

## Niveaux terminés en mode Kensei.
func is_kensei_done(level_id: String) -> bool:
	return data.get("kensei_done", []).has(level_id)

func mark_kensei_done(level_id: String) -> void:
	if not data.has("kensei_done"):
		data["kensei_done"] = []
	if not data["kensei_done"].has(level_id):
		data["kensei_done"].append(level_id)
		save_data()

## Le mode Kensei se débloque en battant le Gardien une première fois.
func kensei_unlocked() -> bool:
	return is_completed("level_5")

## Prologue d'introduction : affiché une seule fois, au premier lancement.
func prologue_seen() -> bool:
	return bool(data.get("prologue_seen", false))

func set_prologue_seen() -> void:
	data["prologue_seen"] = true
	save_data()

## Réglages du joueur ("music", "sfx", "vibrations", "shake", "flash" —
## activés par défaut ; "assist" — désactivé par défaut). `default_on` permet
## de choisir la valeur par défaut d'une clé absente de la sauvegarde.
func setting_on(key: String, default_on: bool = true) -> bool:
	return bool(data.get("settings", {}).get(key, default_on))

## Mode détente (accessibilité) : désactivé par défaut ; offre des cœurs
## supplémentaires au joueur qui le souhaite.
func assist_on() -> bool:
	return setting_on("assist", false)

func bonus_hearts() -> int:
	return 2 if assist_on() else 0

func set_setting(key: String, value: bool) -> void:
	if not data.has("settings"):
		data["settings"] = {}
	data["settings"][key] = value
	save_data()

## Vibre uniquement si le joueur n'a pas coupé les vibrations.
func vibrate(ms: int) -> void:
	if setting_on("vibrations"):
		Input.vibrate_handheld(ms)

## Retient le dernier niveau entré (pour le bouton "Continuer").
func set_last_level(level_id: String) -> void:
	data["last_level"] = level_id
	save_data()

func get_last_level_scene() -> String:
	var id: String = data.get("last_level", "level_1")
	return LEVEL_SCENES.get(id, LEVEL_SCENES["level_1"])
