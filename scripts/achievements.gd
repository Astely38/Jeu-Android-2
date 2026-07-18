extends Node
## Autoload "Achievements" : les succès du jeu.
## - Les déblocages sont stockés dans la sauvegarde (SaveManager.data,
##   clés "achievements" et "stats") ; pas de class_name (conflit autoload).
## - unlock() affiche une notification dorée qui glisse du haut de l'écran
##   (empilées en file si plusieurs succès tombent d'un coup) et survit aux
##   changements de scène, car elle vit sur ce nœud persistant.
## - Les vérifications sont branchées dans Challenge (kills, combos, fin de
##   niveau), le joueur (morts), Léonie (bénédiction) et SaveManager
##   (découverte du Jardin Céleste).

const DEFS := [
	{"id": "premiers_pas", "name": "Premiers pas", "desc": "Terminer la Clairière des Bambous."},
	{"id": "voie_accomplie", "name": "La Voie accomplie", "desc": "Vaincre le Gardien Corrompu."},
	{"id": "jardin_celeste", "name": "Au-dessus des nuages", "desc": "Découvrir le Jardin Céleste.", "secret": true},
	{"id": "benediction", "name": "Sous sa lumière", "desc": "Recevoir la bénédiction de Léonie."},
	{"id": "intouchable", "name": "Intouchable", "desc": "Terminer un niveau sans le moindre dégât."},
	{"id": "moisson", "name": "Moisson d'esprits", "desc": "Ramasser toutes les orbes d'un niveau."},
	{"id": "survivant", "name": "Au bord du gouffre", "desc": "Atteindre le torii avec un seul cœur."},
	{"id": "eclair", "name": "Plus vite que le vent", "desc": "Terminer un niveau en moins de 90 secondes."},
	{"id": "combo_5", "name": "Lame liée", "desc": "Enchaîner 5 esprits sans être touché (combo ×5)."},
	{"id": "combo_8", "name": "Tempête d'acier", "desc": "Enchaîner 8 esprits sans être touché (combo ×8)."},
	{"id": "purificateur", "name": "Purificateur", "desc": "Trancher 100 esprits, toutes parties confondues."},
	{"id": "or_partout", "name": "La Voie dorée", "desc": "Obtenir au moins l'Or sur les cinq niveaux."},
	{"id": "platine_partout", "name": "Perfection", "desc": "Obtenir le Platine sur les cinq niveaux."},
	{"id": "la_chute", "name": "La chute enseigne", "desc": "Recommencer un niveau 10 fois. Ça arrive aux meilleurs."},
	{"id": "chasseur", "name": "Chasseur d'élites", "desc": "Vaincre une Ombre d'élite et cueillir son orbe dorée."},
	# Chapitre II — La Source de l'Ombre.
	{"id": "gardien_puits", "name": "Gardien du Puits", "desc": "Vaincre le Grand Masque, l'émissaire du Cœur."},
	{"id": "source_tarie", "name": "La Source tarie", "desc": "Vaincre le Cœur de l'Ombre et clore le Chapitre II."},
	{"id": "platine_ombre", "name": "Ombre immaculée", "desc": "Obtenir le Platine sur les cinq niveaux du Chapitre II."},
	# Chapitre III — L'Écho dans le Noir.
	{"id": "dans_le_miroir", "name": "De l'autre côté", "desc": "Franchir le seuil du royaume-miroir (Chapitre III)."},
	{"id": "galerie_reflets", "name": "Danse des reflets", "desc": "Traverser la Galerie des Reflets."},
]

var _queue: Array = []
var _showing := false

func _ready() -> void:
	# Les notifications continuent de défiler pendant le menu pause.
	process_mode = Node.PROCESS_MODE_ALWAYS

func _def(id: String) -> Dictionary:
	for d in DEFS:
		if String(d["id"]) == id:
			return d
	return {}

func is_unlocked(id: String) -> bool:
	return bool(SaveManager.data.get("achievements", {}).get(id, false))

func unlocked_count() -> int:
	var n := 0
	for d in DEFS:
		if is_unlocked(String(d["id"])):
			n += 1
	return n

func unlock(id: String) -> void:
	if is_unlocked(id) or _def(id).is_empty():
		return
	if not SaveManager.data.has("achievements"):
		SaveManager.data["achievements"] = {}
	SaveManager.data["achievements"][id] = true
	SaveManager.save_data()
	_queue.append(id)
	if not _showing:
		_next_toast()

# --- Compteurs cumulés (toutes parties) -----------------------------------

func add_kill() -> void:
	var stats: Dictionary = SaveManager.data.get("stats", {})
	stats["kills_total"] = int(stats.get("kills_total", 0)) + 1
	SaveManager.data["stats"] = stats
	if int(stats["kills_total"]) >= 100:
		unlock("purificateur")
	# On n'écrit pas le fichier à chaque coup de sabre : un lot de 10 suffit.
	elif int(stats["kills_total"]) % 10 == 0:
		SaveManager.save_data()

func add_death() -> void:
	var stats: Dictionary = SaveManager.data.get("stats", {})
	stats["deaths_total"] = int(stats.get("deaths_total", 0)) + 1
	SaveManager.data["stats"] = stats
	SaveManager.save_data()
	if int(stats["deaths_total"]) >= 10:
		unlock("la_chute")

func on_combo(combo: int) -> void:
	if combo >= 5:
		unlock("combo_5")
	if combo >= 8:
		unlock("combo_8")

## Appelé par Challenge.finish_level, juste après l'enregistrement du
## meilleur grade/temps et avant la remise à zéro des compteurs.
func on_level_finished(results: Dictionary) -> void:
	var lvl := String(results["level"])
	if lvl == "level_1":
		unlock("premiers_pas")
	if lvl == "level_5":
		unlock("voie_accomplie")
	if lvl == "level_9":
		unlock("gardien_puits")
	if lvl == "level_10":
		unlock("source_tarie")
	if lvl == "level_11":
		unlock("dans_le_miroir")
	if lvl == "level_12":
		unlock("galerie_reflets")
	if int(results["damage"]) == 0:
		unlock("intouchable")
	if int(results["orbs"]) >= int(results["total_orbs"]):
		unlock("moisson")
	if float(results["time"]) < 90.0:
		unlock("eclair")
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and int(pl.get("health")) == 1:
		unlock("survivant")
	_check_grades()

func _check_grades() -> void:
	var all_gold := true
	var all_plat := true
	for id in ["level_1", "level_2", "level_3", "level_4", "level_5"]:
		var g := SaveManager.best_grade(String(id))
		if g != "PLATINUM":
			all_plat = false
		if g != "GOLD" and g != "PLATINUM":
			all_gold = false
	if all_gold:
		unlock("or_partout")
	if all_plat:
		unlock("platine_partout")
	# Chapitre II : Platine sur les cinq niveaux (6 à 10).
	var all_plat2 := true
	for id in ["level_6", "level_7", "level_8", "level_9", "level_10"]:
		if SaveManager.best_grade(String(id)) != "PLATINUM":
			all_plat2 = false
	if all_plat2:
		unlock("platine_ombre")

# --- Notification dorée ----------------------------------------------------

func _next_toast() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var id: String = _queue.pop_front()
	var d := _def(id)

	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.09, 0.16, 0.95)
	sb.border_color = Color(1.0, 0.82, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var head := Label.new()
	head.text = "Succès débloqué !"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75, 0.85))
	box.add_child(head)
	var lbl := Label.new()
	lbl.text = String(d.get("name", id))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	box.add_child(lbl)

	var chime := AudioStreamPlayer.new()
	chime.stream = load("res://assets/sfx/checkpoint.wav")
	chime.volume_db = -6.0
	layer.add_child(chime)

	# Une frame pour que le panneau connaisse sa taille, puis glissade.
	await get_tree().process_frame
	panel.position = Vector2(480.0 - panel.size.x * 0.5, -panel.size.y - 6.0)
	chime.play()
	SaveManager.vibrate(30)
	var t := create_tween()
	t.tween_property(panel, "position:y", 14.0, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(2.6)
	t.tween_property(panel, "position:y", -panel.size.y - 6.0, 0.3)
	t.finished.connect(func() -> void:
		layer.queue_free()
		_next_toast()
	)
