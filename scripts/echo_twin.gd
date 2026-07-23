class_name EchoTwin
extends Node2D
## Le jumeau glitché du Chapitre IV : une réplique visuelle et RETARDÉE
## d'`target` (le joueur), qui rejoue son tracé quelques instants plus tard.
## N'est ni solide ni dangereux — la lame le traverse, il ne blesse pas —
## mais sa position sert de déclencheur aux Portes Muettes : certains
## passages n'admettent que celui qui a laissé son écho les franchir avant
## lui, ce qui impose d'attendre, immobile, que son propre reflet différé
## le rattrape.
##
## Usage : EchoTwin.new() ; assigner `target` (le joueur) juste après
## l'avoir ajouté à l'arbre ; `delay` règle le retard (secondes).

@export var delay := 1.4
@export var color_a := Color(0.85, 0.25, 0.55)
@export var color_b := Color(0.3, 0.75, 0.85)

var target: Node2D

var _clock := 0.0
var _history: Array = []
var _active := false
var _gfx: Node2D
var _bands: Array = []
var _t := 0.0
var _face := 1.0

func _ready() -> void:
	visible = false
	z_index = 5
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(color_a.r, color_a.g, color_a.b, 0.35)
	glow.scale = Vector2(1.6, 1.8)
	glow.position = Vector2(0, -10)
	glow.z_index = -1
	add_child(glow)
	_gfx = Node2D.new()
	add_child(_gfx)
	# Silhouette simplifiée, en aplat unique : ce n'est pas Eneko lui-même,
	# juste l'idée d'une trace qui lui ressemble — jamais un vrai second
	# personnage à animer en détail.
	_shape(_gfx, PackedVector2Array([
		Vector2(-9, 26), Vector2(9, 26), Vector2(11, -3), Vector2(6, -17),
		Vector2(-6, -17), Vector2(-11, -3),
	]), color_a)
	var head := Polygon2D.new()
	var hp := PackedVector2Array()
	for i in 10:
		var a := i * TAU / 10.0
		hp.append(Vector2(cos(a) * 7.0, sin(a) * 7.0))
	head.polygon = hp
	head.position = Vector2(0, -23)
	head.color = color_a
	_gfx.add_child(head)
	# Bandes de scintillement horizontales : lecture immédiate « ceci est un
	# glitch », jamais confondu avec un vrai personnage.
	for k in 4:
		var oy := -16.0 + float(k) * 10.0
		var band := _shape_fill(_gfx, PackedVector2Array([
			Vector2(-11, oy), Vector2(11, oy), Vector2(11, oy + 3), Vector2(-11, oy + 3),
		]), color_b)
		_bands.append({"node": band, "phase": float(k) * 1.1})

func _shape(parent: Node, pts: PackedVector2Array, fill: Color) -> void:
	_shape_fill(parent, pts, fill)
	var l := Line2D.new()
	l.points = pts
	l.closed = true
	l.width = 1.4
	l.default_color = Color(color_b.r, color_b.g, color_b.b, 0.8)
	parent.add_child(l)

func _shape_fill(parent: Node, pts: PackedVector2Array, fill: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = fill
	parent.add_child(p)
	return p

func _physics_process(delta: float) -> void:
	_clock += delta
	if target != null and is_instance_valid(target):
		_history.append({"t": _clock, "pos": target.global_position})
		while _history.size() > 1 and _history[0]["t"] < _clock - delay - 0.5:
			_history.pop_front()
	_update_echo()

func _process(delta: float) -> void:
	_t += delta
	for b in _bands:
		var node: Polygon2D = b["node"]
		node.modulate.a = 0.25 + 0.55 * absf(sin(_t * 10.0 + float(b["phase"])))
	if _gfx != null:
		_gfx.scale = Vector2(_face, 1.0)
		_gfx.modulate.a = 0.55 + 0.15 * sin(_t * 7.0)

func _update_echo() -> void:
	var want_t := _clock - delay
	if _history.is_empty() or want_t < float(_history[0]["t"]):
		if _active:
			_active = false
			visible = false
		return
	var prev: Dictionary = _history[0]
	var pos: Vector2 = _history[_history.size() - 1]["pos"]
	var found := false
	for entry in _history:
		if float(entry["t"]) >= want_t:
			var span: float = float(entry["t"]) - float(prev["t"])
			var f: float = 0.0 if span <= 0.0 else clampf((want_t - float(prev["t"])) / span, 0.0, 1.0)
			pos = (prev["pos"] as Vector2).lerp(entry["pos"] as Vector2, f)
			found = true
			break
		prev = entry
	if not found:
		pos = _history[_history.size() - 1]["pos"]
	var moved := pos - global_position
	if absf(moved.x) > 0.5:
		_face = signf(moved.x)
	global_position = pos
	if not _active:
		_active = true
		visible = true

## Vraie depuis que suffisamment d'historique existe pour afficher un écho
## cohérent — sert aux Portes Muettes à ignorer sa position tant qu'il n'a
## pas « pris vie ».
func is_active() -> bool:
	return _active
