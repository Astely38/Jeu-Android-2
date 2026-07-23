extends Node
## Outil de capture d'écran pour la CI (jamais utilisé en jeu) : charge un
## niveau, téléporte le joueur à une série de points de repère répartis sur
## sa longueur, laisse la caméra se stabiliser, puis sauvegarde une image à
## chaque arrêt — pour couvrir tout le niveau en un seul run headless au
## lieu d'un unique point de vue au spawn.
##
## Usage : godot --path . res://tools/ci_capture.tscn --rendering-driver
## opengl3 -- --level=level_16 --out=ci_shots
##
## Les points de repère évitent volontairement les refuges de Léonie
## (bulle de texte à l'écran, sans gravité) et, pour le niveau 20, le
## déclencheur d'arène (dialogue bloquant + activation du boss) : la
## capture s'arrête juste avant.

const WAYPOINTS := {
	"level_16": [100.0, 1500.0, 3600.0, 5000.0, 6950.0],
	"level_17": [230.0, 2020.0, 4340.0, 6050.0, 6650.0],
	"level_18": [100.0, 1300.0, 4700.0, 5900.0, 7150.0],
	"level_19": [100.0, 1200.0, 4100.0, 5800.0, 6850.0],
	"level_20": [230.0, 830.0, 1450.0, 2200.0],
}

func _ready() -> void:
	var level_name := ""
	var out_dir := "ci_shots"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			level_name = a.substr(8)
		elif a.begins_with("--out="):
			out_dir = a.substr(6)
	if level_name == "" or not WAYPOINTS.has(level_name):
		push_error("Usage: -- --level=level_XX [--out=dir] (niveau inconnu : '%s')" % level_name)
		get_tree().quit(1)
		return
	await _run(level_name, out_dir)
	get_tree().quit()

func _run(level_name: String, out_dir: String) -> void:
	var scene: PackedScene = load("res://levels/%s.tscn" % level_name)
	var level: Node = scene.instantiate()
	get_tree().root.add_child(level)
	# Laisse l'intro (panoramique caméra vers l'objectif) se terminer avant
	# de reprendre la main sur le joueur/la caméra.
	await get_tree().create_timer(2.6, true, false, true).timeout

	var player: Node2D = level.get_node_or_null("Player")
	if player == null:
		push_error("Player introuvable dans %s" % level_name)
		return

	var full_out := ProjectSettings.globalize_path("res://").path_join(out_dir)
	DirAccess.make_dir_recursive_absolute(full_out)

	var points: Array = WAYPOINTS[level_name]
	for i in points.size():
		var x: float = points[i]
		var y := _target_y(level, x)
		player.global_position = Vector2(x, y)
		if player is CharacterBody2D:
			(player as CharacterBody2D).velocity = Vector2.ZERO
		# Laisse la caméra (souvent lissée) rattraper le téléport et le
		# décor parallax se recaler avant la capture.
		await get_tree().create_timer(0.6, true, false, true).timeout
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
