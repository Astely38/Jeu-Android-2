extends Node
## Outil de capture d'écran pour la CI (autoload, inerte hors CI) : une fois
## le niveau chargé normalement (comme scène principale, exactement comme en
## jeu — pas d'instanciation manuelle, pour ne rien changer au comportement
## caméra/scène), téléporte le joueur à une série de points de repère
## répartis sur sa longueur et sauvegarde une image à chaque arrêt.
##
## N'agit QUE si la variable d'environnement CI_SHOOT_WAYPOINTS vaut "1" —
## sans ça, ce script ne fait strictement rien, en jeu comme dans le reste
## de la CI (smoke test, export). Niveau et dossier de sortie lus depuis
## CI_SHOOT_LEVEL / CI_SHOOT_OUT.

const WAYPOINTS := {
	# Points 850/1950/6425 ajoutés temporairement (preview) pour cadrer
	# pile sur un cratère RockSlide.
	"level_16": [850.0, 1950.0, 3600.0, 5000.0, 6950.0],
	"level_17": [230.0, 2020.0, 4340.0, 6050.0, 6650.0],
	"level_18": [100.0, 1300.0, 4700.0, 6425.0, 7150.0],
	"level_19": [100.0, 1200.0, 4100.0, 5800.0, 6850.0],
	"level_20": [230.0, 830.0, 1450.0, 2200.0],
}

func _ready() -> void:
	if OS.get_environment("CI_SHOOT_WAYPOINTS") != "1":
		return
	var level_name := OS.get_environment("CI_SHOOT_LEVEL")
	var out_dir := OS.get_environment("CI_SHOOT_OUT")
	if out_dir == "":
		out_dir = "ci_shots"
	if level_name == "" or not WAYPOINTS.has(level_name):
		push_error("CI_SHOOT_LEVEL manquant ou inconnu : '%s'" % level_name)
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

	# [preview] Capture qui attend volontairement un tir de cratère pour voir
	# les boules de lumière en plein vol — AVANT le tour normal des points de
	# repère, sinon le niveau est déjà gagné (dernier point = l'objectif) et
	# plus rien ne se passe.
	if level_name == "level_16":
		player.global_position = Vector2(850.0, _target_y(level, 850.0))
		if player is CharacterBody2D:
			(player as CharacterBody2D).velocity = Vector2.ZERO
		# Rafale de captures espacées de 0.6s (< FLIGHT_TIME=0.85s) sur toute
		# la fenêtre PERIOD+marge : garantit qu'au moins une image tombe en
		# plein vol d'une salve, quel que soit le déphasage de départ.
		var burst := 0
		while burst < 7:
			await get_tree().create_timer(0.6, true, false, true).timeout
			await get_tree().process_frame
			var imgb := get_viewport().get_texture().get_image()
			imgb.save_png("%s/%s_orb_%d.png" % [full_out, level_name, burst])
			burst += 1

	var points: Array = WAYPOINTS[level_name]
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
