extends Area2D
class_name Relic
## Relique cachée : un collectible rare et FACULTATIF, une par niveau. Ne
## compte pas dans les orbes (n'affecte ni le grade ni la Platine). Sa collecte
## est mémorisée dans la sauvegarde ; réunir les douze débloque un succès.
##
## Usage : var r := Relic.new(); r.level_id = LEVEL_ID; r.position = ...;
##         add_child(r)
## Placée en un lieu à l'écart du chemin principal (fond de niveau, hauteur
## atteignable au Double Saut…), elle récompense la fouille.

var level_id := ""
var _taken := false
var _base_y := 0.0
var _t := 0.0
var _glow: Sprite2D
var _burst: Polygon2D

func _ready() -> void:
	# Déjà trouvée : on ne la fait pas réapparaître.
	if level_id != "" and SaveManager.has_relic(level_id):
		queue_free()
		return
	_base_y = position.y
	# Les reliques sont instanciées tôt dans le _ready des niveaux (avant les
	# plateformes et le décor) : sans z_index, une plateforme construite ensuite
	# les recouvrirait. On les pose au-dessus du sol, comme les orbes.
	z_index = 3
	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 26.0
	shape.shape = circ
	add_child(shape)
	_build_visual()
	body_entered.connect(_on_body_entered)

func _build_visual() -> void:
	# Halo doré diffus.
	_glow = Sprite2D.new()
	_glow.texture = load("res://assets/mist.svg")
	_glow.modulate = Color(1.0, 0.85, 0.4, 0.4)
	_glow.scale = Vector2(1.9, 1.9)
	add_child(_glow)
	# Éclat solaire qui tourne lentement derrière la pièce.
	_burst = Polygon2D.new()
	_burst.polygon = _star_points(8, 30.0, 13.0)
	_burst.color = Color(1.0, 0.8, 0.35, 0.5)
	add_child(_burst)
	# Pièce-mon dorée : disque, liseré clair, trou carré sombre au centre.
	var disc := Polygon2D.new()
	disc.polygon = _circle_points(20.0)
	disc.color = Color(0.98, 0.8, 0.32)
	add_child(disc)
	var rim := Polygon2D.new()
	rim.polygon = _circle_points(14.0)
	rim.color = Color(1.0, 0.92, 0.6)
	add_child(rim)
	var hole := Polygon2D.new()
	hole.polygon = PackedVector2Array([
		Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-5, 5),
	])
	hole.color = Color(0.16, 0.11, 0.06)
	add_child(hole)

func _circle_points(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 20:
		var a := i * TAU / 20.0
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	return pts

func _star_points(branches: int, r_out: float, r_in: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := branches * 2
	for i in n:
		var a := i * TAU / float(n)
		var r := r_out if i % 2 == 0 else r_in
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	return pts

func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * 2.4) * 5.0
	if _burst != null:
		_burst.rotation += delta * 0.7
	if _glow != null:
		_glow.modulate.a = 0.3 + 0.18 * (0.5 + 0.5 * sin(_t * 2.0))

func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	SaveManager.mark_relic(level_id)
	Achievements.on_relic_found()
	# Éclat doré + carillon, sur le PARENT pour survivre à la disparition.
	var parent := get_parent()
	if parent != null:
		Atmosphere.spark_burst(parent, global_position, Color(1.0, 0.85, 0.4))
		var chime := AudioStreamPlayer.new()
		chime.stream = load("res://assets/sfx/checkpoint.wav")
		chime.pitch_scale = 1.35
		chime.volume_db = -3.0
		parent.add_child(chime)
		chime.play()
		chime.finished.connect(chime.queue_free)
	SaveManager.vibrate(40)
	queue_free()
