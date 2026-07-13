extends Node
## Système de défi : track les performances du joueur dans un niveau
## (orbes, dégâts, temps) et calcule une note/grade.
## Autoload (singleton) enregistré sous le nom "Challenge" dans project.godot.
## Pas de class_name ici : ça entrerait en conflit avec le nom de l'autoload.

var level_id: String = ""
var start_time: float = 0.0
var orbs_collected: int = 0
var total_orbs: int = 0
var damage_taken: int = 0  # nombre de fois le joueur a été frappé/tombé

func _ready() -> void:
	add_to_group("challenge")

func start_level(id: String, total_orbs_count: int) -> void:
	level_id = id
	start_time = float(Time.get_ticks_msec()) / 1000.0
	orbs_collected = 0
	total_orbs = maxf(1.0, float(total_orbs_count))
	damage_taken = 0

func register_damage() -> void:
	if damage_taken >= 0:
		damage_taken += 1

func register_orb() -> void:
	if orbs_collected >= 0:
		orbs_collected += 1

func get_time_elapsed() -> float:
	var now := float(Time.get_ticks_msec()) / 1000.0
	return maxf(0.0, now - start_time)

func get_results() -> Dictionary:
	var elapsed := get_time_elapsed()
	return {
		"level": level_id,
		"orbs": orbs_collected,
		"total_orbs": total_orbs,
		"damage": damage_taken,
		"time": elapsed,
		"grade": _calculate_grade(),
	}

func _calculate_grade() -> String:
	var orb_ratio: float = float(orbs_collected) / maxf(1.0, float(total_orbs))

	if damage_taken == 0 and orb_ratio == 1.0:
		return "PLATINUM"
	elif (damage_taken == 0 and orb_ratio >= 0.8) or (damage_taken <= 1 and orb_ratio == 1.0):
		return "GOLD"
	elif damage_taken <= 1 or orb_ratio >= 0.6:
		return "SILVER"
	else:
		return "BRONZE"

func reset() -> void:
	level_id = ""
	start_time = 0.0
	orbs_collected = 0
	total_orbs = 0
	damage_taken = 0
