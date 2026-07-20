extends Area2D
class_name MirrorBlade
## Lame-miroir lancée par le Reflet. Elle file vers Eneko ; s'il FRAPPE au
## sabre à bonne portée, elle est RENVOYÉE vers le Reflet et brise son bouclier
## (c'est le seul moyen de l'exposer). Non renvoyée, elle inflige un dégât.

const SPEED := 300.0
const REFLECT_SPEED := 780.0
## Fenêtre de renvoi généreuse : frapper au sabre près de la lame (même sans
## la viser parfaitement) la renvoie.
const REFLECT_RANGE := 100.0
## La lame INFLÉCHIT sa course vers Eneko un court instant (pour qu'elle vienne
## bien à lui — on doit l'esquiver ou la renvoyer), puis file tout droit
## (esquivable d'une ruée). Virage doux pour rester lisible.
const HOME_TURN := 2.3
const HOME_TIME := 1.25

var _dir := Vector2.RIGHT
var _reflected := false
var _boss: Node2D
var _player: Node2D
var _life := 5.0
var _home_t := HOME_TIME
var _blade: Polygon2D

## Appelé juste après l'instanciation, avant l'ajout à l'arbre.
func setup(from: Vector2, target: Vector2, boss: Node2D, player: Node2D) -> void:
	position = from
	_boss = boss
	_player = player
	_dir = (target - from).normalized()

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 12.0
	shape.shape = c
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_build_visual()
	rotation = _dir.angle()

func _build_visual() -> void:
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(0.6, 0.85, 1.0, 0.4)
	glow.scale = Vector2(0.55, 0.55)
	add_child(glow)
	_blade = Polygon2D.new()
	_blade.polygon = PackedVector2Array([
		Vector2(15, 0), Vector2(0, 7), Vector2(-15, 0), Vector2(0, -7),
	])
	_blade.color = Color(0.7, 0.92, 1.0, 0.95)
	add_child(_blade)

func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if _reflected and is_instance_valid(_boss):
		# Renvoyée : elle poursuit le Reflet où qu'il soit.
		_dir = (_boss.global_position - global_position).normalized()
	elif not _reflected and is_instance_valid(_player):
		# Encore hostile : elle infléchit doucement vers Eneko un court instant.
		_home_t -= delta
		if _home_t > 0.0:
			var want := (_player.global_position - global_position).angle()
			var cur := _dir.angle()
			var da := clampf(wrapf(want - cur, -PI, PI), -HOME_TURN * delta, HOME_TURN * delta)
			_dir = Vector2.RIGHT.rotated(cur + da)
	var spd := REFLECT_SPEED if _reflected else SPEED
	position += _dir * spd * delta
	rotation = _dir.angle()
	# Renvoi : Eneko frappe au sabre, à portée, la lame encore hostile.
	if not _reflected and is_instance_valid(_player):
		if bool(_player.get("attacking")) and global_position.distance_to(_player.global_position) < REFLECT_RANGE:
			_reflect()
	# Lame renvoyée qui atteint le Reflet : brise son bouclier.
	if _reflected and is_instance_valid(_boss):
		if global_position.distance_to(_boss.global_position) < 48.0:
			if _boss.has_method("on_blade_reflected"):
				_boss.on_blade_reflected()
			queue_free()

func _reflect() -> void:
	_reflected = true
	_blade.color = Color(1.0, 0.85, 0.4, 0.98)
	_life = 4.5  # de quoi rejoindre le Reflet même à l'autre bout de l'arène
	Atmosphere.spark_burst(get_parent(), global_position, Color(1.0, 0.9, 0.5))

func _on_body_entered(body: Node2D) -> void:
	if _reflected:
		return
	if body == _player and body.has_method("take_damage"):
		body.take_damage(1, global_position)
		queue_free()
	elif body is StaticBody2D:
		queue_free()
