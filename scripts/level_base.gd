class_name LevelBase
extends Node2D
## Classe de base commune à tous les niveaux (LevelBase).
## Regroupe les fonctions strictement identiques d'un niveau à l'autre —
## retour au menu, chute mortelle, affichage du bilan de défi et formatage
## du temps — pour éviter de les dupliquer dans les 16 scripts de niveaux.
##
## Les nœuds sont résolus à l'appel (get_node_or_null) plutôt que via des
## @onready : ainsi aucun conflit avec les @onready propres à chaque niveau,
## et un niveau qui n'a pas tel nœud (ex. un niveau-boss sans WinLabel) est
## simplement ignoré sans erreur.

## Bouton « Retour au menu » de l'écran de victoire / pause.
func _on_menu_pressed() -> void:
	Transition.goto("res://scenes/main_menu.tscn")

## Zone de mort (chute dans un trou) : coûte un cœur au joueur. On cible le
## joueur par son groupe, sans dépendre d'une référence @onready locale.
func _on_kill_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("fall_damage"):
		body.fall_damage()

## Construit la zone de mort (une longue bande sous le niveau qui coûte un
## cœur à la chute). `level_end` = longueur du niveau ; `y` et `height`
## couvrent les rares niveaux dont le vide descend plus bas (temple, gouffre).
func _build_kill_zone(level_end: float, y: float = 700.0, height: float = 100.0) -> void:
	var kz := Area2D.new()
	kz.position = Vector2(level_end / 2.0, y)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(level_end + 800.0, height)
	shape.shape = rect
	kz.add_child(shape)
	add_child(kz)
	kz.body_entered.connect(_on_kill_zone_body_entered)

## Fin d'un échange de dialogue : rend la main au joueur. Les niveaux-boss
## surchargent cette méthode pour, en plus, déclencher l'arène.
func _on_dialogue_finished() -> void:
	var p := get_node_or_null("Player")
	if p != null:
		p.set_physics_process(true)

## Victoire : Eneko atteint le torii. Fige le jeu, joue le carillon de fin,
## retient la progression et affiche le bilan. Les valeurs propres au niveau
## (identifiant, son de victoire) sont passées en argument par l'appelant —
## aucune dépendance cachée, donc aucun risque d'oublier de les fournir.
func _reach_goal(body: Node2D, id: String, win_sound: AudioStreamPlayer = null) -> void:
	if not body.is_in_group("player"):
		return
	body.set_physics_process(false)
	if win_sound != null:
		win_sound.play()
	SaveManager.complete_level(id, body.orbs)
	_display_challenge_results()
	var win_label := get_node_or_null("WinLabel")
	if win_label != null:
		win_label.visible = true

## mm:ss à partir d'un nombre de secondes.
func _format_time(seconds: float) -> String:
	var mins: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	return "%d:%02d" % [mins, secs]

## Renseigne le panneau de bilan (grade, orbes, dégâts, combo, temps) de
## l'écran de victoire et l'ajuste à la largeur du texte. Sans WinLabel
## (niveaux-boss à récap dédié), ne fait rien.
func _display_challenge_results() -> void:
	var win_label := get_node_or_null("WinLabel")
	if win_label == null:
		return
	var results := Challenge.finish_level()
	var challenge_stats = win_label.find_child("ChallengeStats", true, false)
	if challenge_stats == null:
		return
	var grade_label = challenge_stats.find_child("Grade", true, false)
	var orbs_label = challenge_stats.find_child("Orbs", true, false)
	var damage_label = challenge_stats.find_child("Damage", true, false)
	var time_label = challenge_stats.find_child("Time", true, false)
	if grade_label:
		grade_label.text = "Grade : %s" % Challenge.grade_name(results["grade"])
		grade_label.add_theme_color_override("font_color", Challenge.grade_color(results["grade"]))
	if orbs_label:
		orbs_label.text = "Orbes : %d/%d" % [results["orbs"], results["total_orbs"]]
	if damage_label:
		damage_label.text = "Dégâts : %d   •   Esprits vaincus : %d" % [results["damage"], results["kills"]]
		if int(results["combo"]) >= 2:
			damage_label.text += "   •   Combo ×%d" % int(results["combo"])
	if time_label:
		time_label.text = "Temps : %s" % _format_time(results["time"])
	# Élargit le panneau pour que la ligne la plus longue (combo) reste dedans.
	var stats_half := 150.0
	for child in challenge_stats.get_children():
		if child is Label:
			stats_half = maxf(stats_half, (child as Label).get_minimum_size().x * 0.5 + 10.0)
	challenge_stats.offset_left = -stats_half
	challenge_stats.offset_right = stats_half
	var stats_bg = win_label.find_child("StatsBG", true, false)
	if stats_bg != null:
		stats_bg.offset_left = -stats_half - 30.0
		stats_bg.offset_right = stats_half + 30.0
