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

## Ombre DOUCE : un dégradé radial aplati (mist.svg), sans bord dur, qui
## s'estompe naturellement — bien plus soigné qu'une ellipse polygonale.
var _shadow: Sprite2D
var _base := 1.0
var _exclude: Array = []

func _ready() -> void:
	_shadow = Sprite2D.new()
	_shadow.texture = load("res://assets/mist.svg")
	_shadow.modulate = Color(0.0, 0.0, 0.05, 0.45)
	add_child(_shadow)
	# mist.svg fait 64 px : on aplatit un disque doux à la largeur voulue.
	_base = (width * 2.1) / 64.0
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
		_shadow.visible = false
		return
	_shadow.visible = true
	var pos: Vector2 = hit["position"]
	var drop: float = pos.y - from.y
	# k = 1 au ras du sol, décroît avec la hauteur (ombre plus petite/pâle).
	var k := clampf(1.0 - drop / max_drop, 0.4, 1.0)
	_shadow.global_position = pos + Vector2(0.0, 1.0)
	_shadow.scale = Vector2(_base * k, _base * 0.42 * k)
	_shadow.modulate.a = 0.4 * k
