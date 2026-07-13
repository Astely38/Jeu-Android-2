extends Node
## Système de défi : track les performances du joueur dans un niveau
## (orbes, dégâts, temps) et calcule une note/grade.
## Autoload (singleton) enregistré sous le nom "Challenge" dans project.godot.
## Pas de class_name ici : ça entrerait en conflit avec le nom de l'autoload.

## Ordre croissant des grades, pour comparer deux performances.
const GRADE_ORDER := ["BRONZE", "SILVER", "GOLD", "PLATINUM"]

## Noms affichés (français) et couleurs associées à chaque grade.
const GRADE_NAMES := {
	"BRONZE": "Bronze",
	"SILVER": "Argent",
	"GOLD": "Or",
	"PLATINUM": "Platine",
}
const GRADE_COLORS := {
	"BRONZE": Color(0.8, 0.55, 0.35),
	"SILVER": Color(0.8, 0.82, 0.88),
	"GOLD": Color(1.0, 0.8, 0.3),
	"PLATINUM": Color(0.75, 0.9, 1.0),
}

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

## Nom affiché (français) d'un grade interne.
func grade_name(grade: String) -> String:
	return GRADE_NAMES.get(grade, grade)

## Couleur associée à un grade (pour teinter le label de l'écran de victoire).
func grade_color(grade: String) -> Color:
	return GRADE_COLORS.get(grade, Color.WHITE)

## Termine le niveau : calcule les résultats, retient le meilleur grade
## dans la sauvegarde, remet les compteurs à zéro et renvoie les résultats.
func finish_level() -> Dictionary:
	var results := get_results()
	var grade := String(results["grade"])
	var prev := SaveManager.best_grade(level_id)
	if prev == "" or GRADE_ORDER.find(grade) > GRADE_ORDER.find(prev):
		SaveManager.set_best_grade(level_id, grade)
	reset()
	return results

func reset() -> void:
	level_id = ""
	start_time = 0.0
	orbs_collected = 0
	total_orbs = 0
	damage_taken = 0
