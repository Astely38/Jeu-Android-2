extends Node
## Outil de capture d'écran pour la CI (autoload, inerte hors CI) : une fois
## le niveau chargé normalement (comme scène principale, exactement comme en
## jeu — pas d'instanciation manuelle, pour ne rien changer au comportement
## caméra/scène), téléporte le joueur à une série de points de repère
## répartis sur sa longueur et sauvegarde une image à chaque arrêt.
##
## Les points sont calculés automatiquement depuis `LEVEL_END` (répartition
## régulière, du départ jusqu'à l'approche de la sortie) : ça couvre tout
## niveau existant ou futur sans liste à maintenir à la main.
##
## N'agit QUE si la variable d'environnement CI_SHOOT_WAYPOINTS vaut "1" —
## sans ça, ce script ne fait strictement rien, en jeu comme dans le reste
## de la CI (smoke test, export). Niveau et dossier de sortie lus depuis
## CI_SHOOT_LEVEL / CI_SHOOT_OUT.

const START_MARGIN := 150.0
const END_MARGIN := 150.0
const POINT_COUNT := 6
const FALLBACK_LEVEL_END := 4000.0

func _ready() -> void:
	if OS.get_environment("CI_SHOOT_WAYPOINTS") != "1":
		return
	var level_name := OS.get_environment("CI_SHOOT_LEVEL")
	var out_dir := OS.get_environment("CI_SHOOT_OUT")
	if out_dir == "":
		out_dir = "ci_shots"
	if level_name == "":
		push_error("CI_SHOOT_LEVEL manquant")
		get_tree().quit(1)
		return
	await _run(level_name, out_dir)
	get_tree().quit()

func _run(level_name: String, out_dir: String) -> void:
	# Laisse l'intro (panoramique caméra vers l'objectif) se terminer avant
	# de reprendre la main sur le joueur/la caméra.
	await get_tree().create_timer(2.6, true, false, true).timeout

	var level: Node = get_tree().current_scene
	var player: Node2D = level.get_node_or_null("Player") if level != null else null
	if player == null:
		push_error("Player introuvable dans %s" % level_name)
		return

	var full_out := ProjectSettings.globalize_path("res://").path_join(out_dir)
	DirAccess.make_dir_recursive_absolute(full_out)

	var points := _waypoints(level)
	for i in points.size():
		var x: float = points[i]
		var y := _target_y(level, x)
		player.global_position = Vector2(x, y)
		if player is CharacterBody2D:
			(player as CharacterBody2D).velocity = Vector2.ZERO
		# Laisse la caméra (souvent lissée) rattraper le téléport et le
		# décor parallax se recaler.
		await get_tree().create_timer(0.6, true, false, true).timeout
		# Sécurité anti-frame-vide : force au moins deux frames rendues
		# après le dernier changement d'état avant de capturer.
		await get_tree().process_frame
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s_%02d.png" % [full_out, level_name, i])

## Répartition régulière de POINT_COUNT points entre START_MARGIN et
## (LEVEL_END - END_MARGIN) : couvre tout le niveau, du départ à l'approche
## de la sortie, quelle que soit sa longueur.
func _waypoints(level: Node) -> Array:
	var level_end := FALLBACK_LEVEL_END
	var le = level.get("LEVEL_END")
	if le != null:
		level_end = float(le)
	var span: float = level_end - START_MARGIN - END_MARGIN
	if span <= 0.0:
		return [level_end * 0.5]
	var xs := []
	for i in POINT_COUNT:
		var t := float(i) / float(POINT_COUNT - 1)
		xs.append(START_MARGIN + span * t)
	return xs

## Hauteur d'un point du niveau : utilise `_surface_y(x)` du niveau si elle
## existe (relief continu), sinon retombe sur sa constante GROUND_Y (sol
## plat), sinon une hauteur par défaut raisonnable.
func _target_y(level: Node, x: float) -> float:
	if level.has_method("_surface_y"):
		return float(level.call("_surface_y", x)) - 30.0
	var ground_y = level.get("GROUND_Y")
	if ground_y != null:
		return float(ground_y) - 30.0
	return 480.0
