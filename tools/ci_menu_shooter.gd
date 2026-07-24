extends Node
## Outil de capture d'écran CI pour les écrans hors-niveau (splash, menu
## principal + ses panneaux, sélection de niveau) — autoload inerte hors CI,
## même principe que ci_waypoint_shooter.gd (qui couvre le gameplay) mais
## pour l'interface.
##
## N'agit QUE si CI_SHOOT_MENU vaut "1". Écran ciblé et dossier de sortie
## lus depuis CI_SHOOT_SCENE / CI_SHOOT_OUT.

func _ready() -> void:
	if OS.get_environment("CI_SHOOT_MENU") != "1":
		return
	var scene_id := OS.get_environment("CI_SHOOT_SCENE")
	var out_dir := OS.get_environment("CI_SHOOT_OUT")
	if out_dir == "":
		out_dir = "ci_shots"
	if scene_id == "":
		push_error("CI_SHOOT_SCENE manquant")
		get_tree().quit(1)
		return
	await _run(scene_id, out_dir)
	get_tree().quit()

func _run(scene_id: String, out_dir: String) -> void:
	# Laisse le décor peint (soleil, particules) se poser avant la capture.
	await get_tree().create_timer(1.2, true, false, true).timeout
	var full_out := ProjectSettings.globalize_path("res://").path_join(out_dir)
	DirAccess.make_dir_recursive_absolute(full_out)
	match scene_id:
		"splash":
			await _shot(full_out, "splash")
		"level_select":
			await _run_level_select(full_out)
		"main_menu":
			await _run_main_menu(full_out)
		_:
			push_error("CI_SHOOT_SCENE inconnu : '%s'" % scene_id)

func _run_level_select(full_out: String) -> void:
	await _shot(full_out, "level_select_top")
	var scroll: ScrollContainer = get_tree().current_scene.get_node_or_null("Scroll")
	if scroll != null:
		scroll.scroll_vertical = 100000
		await get_tree().process_frame
		await _shot(full_out, "level_select_bottom")

## Menu principal : capture l'état de base, puis chaque panneau (options,
## crédits, succès) l'un après l'autre en refermant le précédent — jamais
## deux panneaux ouverts en même temps sur une même image.
func _run_main_menu(full_out: String) -> void:
	var menu: Node = get_tree().current_scene
	if menu == null:
		return
	# Le prologue s'ouvre seul au tout premier lancement (sauvegarde vide en
	# CI) : on le capture aussi, puis on le referme pour révéler le menu.
	var prologue = menu.get("_prologue")
	if prologue != null and is_instance_valid(prologue) and (prologue as Control).visible:
		await _shot(full_out, "main_menu_prologue")
		menu.call("_close_prologue")
		await get_tree().process_frame
		await get_tree().process_frame
	await _shot(full_out, "main_menu")
	menu.call("_open_options")
	await get_tree().create_timer(0.3, true, false, true).timeout
	await _shot(full_out, "main_menu_options")
	_hide(menu.get("_options"))
	menu.call("_open_credits")
	await get_tree().create_timer(0.3, true, false, true).timeout
	await _shot(full_out, "main_menu_credits")
	_hide(menu.get("_credits"))
	menu.call("_open_achievements")
	await get_tree().create_timer(0.3, true, false, true).timeout
	await _shot(full_out, "main_menu_achievements")

func _hide(panel) -> void:
	if panel != null and is_instance_valid(panel):
		(panel as Control).visible = false

func _shot(full_out: String, name: String) -> void:
	# Sécurité anti-frame-vide : force au moins deux frames rendues après le
	# dernier changement d'état avant de capturer.
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [full_out, name])
