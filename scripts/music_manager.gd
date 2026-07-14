extends Node
## Autoload "Music" : musique d'ambiance et routage audio.
## - Joue en boucle le thème du monde (menu + niveaux) et bascule sur le
##   thème du combat quand l'arène du Gardien se referme.
## - Crée deux bus audio ("Musique" et "Sons") et route automatiquement
##   tous les effets sonores du jeu vers "Sons", pour pouvoir couper
##   musique et effets séparément depuis les Réglages.

const WORLD_TRACK := "res://assets/music/world.wav"
const BOSS_TRACK := "res://assets/music/boss.wav"
const MUSIC_DB := -9.0

var _player: AudioStreamPlayer
var _current := ""

func _ready() -> void:
	# La musique continue pendant le menu pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	get_tree().node_added.connect(_on_node_added)
	_player = AudioStreamPlayer.new()
	_player.bus = "Musique"
	_player.volume_db = MUSIC_DB
	add_child(_player)
	apply_settings()
	play_world()

func _make_buses() -> void:
	for raw_name in ["Musique", "Sons"]:
		var bus_name := str(raw_name)
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

## Tout lecteur audio ajouté à l'arbre (scènes ou créé en code) part sur le
## bus "Sons" — sauf le lecteur de musique lui-même.
func _on_node_added(node: Node) -> void:
	if node == _player:
		return
	if node is AudioStreamPlayer:
		var p := node as AudioStreamPlayer
		if str(p.bus) == "Master":
			p.bus = "Sons"
	elif node is AudioStreamPlayer2D:
		var p2 := node as AudioStreamPlayer2D
		if str(p2.bus) == "Master":
			p2.bus = "Sons"

## Applique les réglages sauvegardés (coupe/rétablit les bus).
func apply_settings() -> void:
	AudioServer.set_bus_mute(
		AudioServer.get_bus_index("Musique"), not SaveManager.setting_on("music"))
	AudioServer.set_bus_mute(
		AudioServer.get_bus_index("Sons"), not SaveManager.setting_on("sfx"))

func play_world() -> void:
	_play(WORLD_TRACK)

func play_boss() -> void:
	_play(BOSS_TRACK)

func _play(path: String) -> void:
	if _current == path:
		return
	_current = path
	var stream: AudioStreamWAV = load(path)
	if stream == null:
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	# 16 bits mono : 2 octets par trame.
	stream.loop_end = stream.data.size() / 2
	_player.stream = stream
	_player.play()
