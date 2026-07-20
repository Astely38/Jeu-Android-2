extends Node
## Autoload "Music" : musique du menu, une piste d'ambiance par niveau et un
## thème de combat commun aux boss, le tout en fondu enchaîné.
## - Pistes réelles (OGG/MP3) au thème japonais ; le chargement gère aussi les
##   WAV générés (compat).
## - Transitions par FONDU ENCHAÎNÉ (deux lecteurs qui se croisent).
## - Crée deux bus audio ("Musique" et "Sons") et route automatiquement
##   tous les effets sonores vers "Sons" (coupe séparée dans les Réglages).

## Écran-titre et sélection de niveaux.
const MENU_TRACK := "res://assets/music/evening_calm.ogg"

## Une piste d'exploration par niveau (thème japonais). Les niveaux-boss
## démarrent sur leur ambiance puis basculent sur COMBAT_TRACK à l'arène.
const LEVEL_TRACKS := {
	# Chapitre I — de la clairière au sanctuaire (doux vers solennel).
	"level_1": "res://assets/music/dream_sakura.ogg",        # Clairière des bambous
	"level_2": "res://assets/music/moonlight_harp.ogg",      # Temple oublié (nuit)
	"level_3": "res://assets/music/mysterious_kyoto.ogg",    # Village des ombres
	"level_4": "res://assets/music/mountain_shrine.ogg",     # Montagne des brumes
	"level_5": "res://assets/music/honobono_teahouse.ogg",   # Sanctuaire (boss ch.I)
	# Chapitre II — rivages de cendre et Puits (plus sombre).
	"level_6": "res://assets/music/travel_asia.ogg",
	"level_7": "res://assets/music/samurai_flute.ogg",
	"level_8": "res://assets/music/samurai_meditation.ogg",
	"level_9": "res://assets/music/dark_temple_yokai.ogg",   # mini-boss (Grand Masque)
	"level_10": "res://assets/music/samurai_azian.ogg",      # boss ch.II (Cœur de l'Ombre)
	# Chapitre III — royaume-miroir (tendu).
	"level_11": "res://assets/music/samurai_loop.ogg",
	"level_12": "res://assets/music/samurai_code.ogg",
	"level_13": "res://assets/music/genji_rise.ogg",
	"level_14": "res://assets/music/revolt_samurai.ogg",     # Gouffre aux anneaux
	"level_15": "res://assets/music/shamisen_rock.ogg",      # boss final (avant arène)
	"level_secret": "res://assets/music/danse_samurais.ogg",
}

## Thème de combat épique commun à tous les boss (bushido cinématique).
const COMBAT_TRACK := "res://assets/music/last_samurai_epic.ogg"

## Volume musique bas : les vraies pistes sont masterisées fort, on laisse la
## place aux bruitages de gameplay (bus "Sons").
const MUSIC_DB := -14.0
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
	play_menu()

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

## Musique du menu / sélection de niveaux.
func play_menu() -> void:
	_play(MENU_TRACK)

## Musique d'exploration d'un niveau, d'après son ID (« level_7 »). Repli sur
## la piste du menu si le niveau n'a pas d'entrée dédiée.
func play_level(id: String) -> void:
	_play(String(LEVEL_TRACKS.get(id, MENU_TRACK)))

## Thème de combat (boss). L'argument est ignoré pour l'instant (thème unique)
## mais gardé pour un futur thème par boss.
func play_combat(_id: String = "") -> void:
	_play(COMBAT_TRACK)

func _load_stream(path: String) -> AudioStream:
	var s: AudioStream = load(path)
	if s == null:
		return null
	# Boucle sans couture selon le type de flux.
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / 2  # 16 bits mono : 2 octets/trame
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
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
