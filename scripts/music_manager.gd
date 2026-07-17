extends Node
## Autoload "Music" : musique d'ambiance et routage audio.
## - Thèmes distincts : monde du Chapitre I, monde du Chapitre II (plus
##   sombre), combat de boss, et boss FINAL (le Cœur de l'Ombre).
## - Transitions par FONDU ENCHAÎNÉ (deux lecteurs qui se croisent).
## - Crée deux bus audio ("Musique" et "Sons") et route automatiquement
##   tous les effets sonores vers "Sons" (coupe séparée dans les Réglages).

const WORLD_TRACK := "res://assets/music/world.wav"       # Chapitre I
const WORLD2_TRACK := "res://assets/music/world2.wav"     # Chapitre II
const BOSS_TRACK := "res://assets/music/boss.wav"         # boss standard
const FINAL_TRACK := "res://assets/music/bossfinal.wav"   # boss final
const MUSIC_DB := -9.0
const QUIET_DB := -60.0
const FADE := 1.1  # durée du fondu enchaîné (s)

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _current := ""
var _fade_tween: Tween

func _ready() -> void:
	# La musique continue pendant le menu pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	get_tree().node_added.connect(_on_node_added)
	# Deux lecteurs pour enchaîner les thèmes en fondu croisé.
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Musique"
		p.volume_db = QUIET_DB
		add_child(p)
		_players.append(p)
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

## Tout lecteur audio ajouté à l'arbre part sur le bus "Sons" — sauf les
## lecteurs de musique (déjà routés sur "Musique" avant leur entrée).
func _on_node_added(node: Node) -> void:
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

## Thème d'exploration. chapter=1 : Clairière→Sanctuaire ; chapter>=2 : le
## monde plus sombre des Rivages de Cendre et du Puits.
func play_world(chapter: int = 1) -> void:
	_play(WORLD2_TRACK if chapter >= 2 else WORLD_TRACK)

## Thème de combat. final=true : le Cœur de l'Ombre (boss final du Ch. II).
func play_boss(final: bool = false) -> void:
	_play(FINAL_TRACK if final else BOSS_TRACK)

func _load_stream(path: String) -> AudioStreamWAV:
	var s: AudioStreamWAV = load(path)
	if s == null:
		return null
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	# 16 bits mono : 2 octets par trame.
	s.loop_end = s.data.size() / 2
	return s

## Bascule vers `path` en fondu enchaîné : le lecteur entrant monte tandis
## que le sortant descend, puis s'arrête.
func _play(path: String) -> void:
	if _current == path:
		return
	_current = path
	var stream := _load_stream(path)
	if stream == null:
		return
	var incoming := 1 - _active
	var pin := _players[incoming]
	var pout := _players[_active]
	pin.stream = stream
	pin.volume_db = QUIET_DB
	pin.play()
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(pin, "volume_db", MUSIC_DB, FADE)
	_fade_tween.tween_property(pout, "volume_db", QUIET_DB, FADE)
	_fade_tween.chain().tween_callback(pout.stop)
	_active = incoming
