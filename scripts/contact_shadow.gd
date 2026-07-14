class_name ContactShadow
extends Node2D
## Ombre de contact au sol : une petite ellipse sombre projetée sous une
## entité, sur la première surface trouvée en dessous (rayon vers le bas,
## masque du sol = couche 1). Plus l'entité s'éloigne du sol (saut, chute),
## plus l'ombre rétrécit et pâlit — ce qui ancre les personnages et donne
## de la profondeur, sans toucher au gameplay (purement décoratif).
##
## À ajouter comme enfant d'un CharacterBody2D, en premier enfant (pour
## passer derrière le sprite). `width` doit être réglé AVANT add_child.

@export var width := 30.0
## Distance maximale de projection vers le sol.
@export var max_drop := 320.0

var _ellipse: Polygon2D
var _exclude: Array = []

func _ready() -> void:
	_ellipse = Polygon2D.new()
	_ellipse.color = Color(0, 0, 0, 0.3)
	var pts := PackedVector2Array()
	for i in 18:
		var a := i * TAU / 18.0
		pts.append(Vector2(cos(a) * width, sin(a) * width * 0.32))
	_ellipse.polygon = pts
	add_child(_ellipse)
	var parent := get_parent()
	if parent is CollisionObject2D:
		_exclude = [parent.get_rid()]

func _physics_process(_delta: float) -> void:
	var space := get_world_2d().direct_space_state
	var from := global_position
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, max_drop), 1)
	q.collide_with_areas = false
	q.exclude = _exclude
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		_ellipse.visible = false
		return
	_ellipse.visible = true
	var pos: Vector2 = hit["position"]
	var drop: float = pos.y - from.y
	# k = 1 au ras du sol, décroît avec la hauteur.
	var k := clampf(1.0 - drop / max_drop, 0.4, 1.0)
	_ellipse.global_position = pos
	_ellipse.scale = Vector2(k, k)
	_ellipse.color.a = 0.32 * k
