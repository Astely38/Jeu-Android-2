extends Area2D
## Léonie, gardienne de la forêt (esprit kitsune). PNJ animé qui déclenche
## un dialogue la première fois qu'Eneko s'approche, crée une zone de protection,
## et émet une aura spirituelle pulsante avec des particules.

signal talk(lines)

const KITSUNE := "res://assets/character/kitsune/"
const PROTECTION_DURATION := 4.5  # durée de protection après dialogue

## Répliques par défaut (première rencontre, niveau 1).
const DEFAULT_LINES := [
	{ "name": "Léonie", "text": "Halte, jeune sabreur. Peu osent s'aventurer dans la Clairière des Bambous." },
	{ "name": "Léonie", "text": "Je suis Léonie, gardienne de cette forêt. Les esprits d'ici sont agités..." },
	{ "name": "Léonie", "text": "Ton sabre devra être aussi vif que ton regard. Tranche les esprits corrompus, mais garde-toi de leur contact." },
	{ "name": "Léonie", "text": "Le torii illuminé, plus loin, marque la sortie. Va, Eneko — la Voie du Sabre t'attend." },
	{ "name": "Eneko", "text": "Merci, Léonie. Je ne faiblirai pas." },
]

var lines: Array = DEFAULT_LINES
var _triggered := false
var _t := 0.0
var _start_y := 0.0

@onready var anim: AnimatedSprite2D = $Anim
@onready var aura: Polygon2D = $Aura
@onready var glow: Sprite2D = $Glow
@onready var petals: CPUParticles2D = $Petals

func _ready() -> void:
	_start_y = position.y

	if anim and is_instance_valid(anim):
		anim.sprite_frames = SpriteSheet.build([
			{"name": "idle", "path": KITSUNE + "Idle.png", "frames": 8, "fps": 8.0, "loop": true},
		])
		anim.play("idle")

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_t += delta

	# Pulsation de l'aura
	if aura and is_instance_valid(aura):
		var pulse := 1.0 + sin(_t * 2.0) * 0.15
		aura.scale = Vector2(pulse, pulse)

	# Animation du glow
	if glow and is_instance_valid(glow):
		var glow_alpha := 0.3 + sin(_t * 3.0) * 0.15
		glow.modulate.a = glow_alpha

	# Flottement léger vertical
	position.y = _start_y + sin(_t * 1.5) * 12.0

## Remplace les répliques par défaut.
func set_lines(new_lines: Array) -> void:
	lines = new_lines

func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if body.has_method("take_damage"):
		_triggered = true
		_create_protection_zone(body)
		talk.emit(lines)

func _create_protection_zone(player: CharacterBody2D) -> void:
	# Invulnérabilité du joueur pendant le dialogue + après
	player.invuln = PROTECTION_DURATION

	# Zone de protection visuelle autour de Léonie
	var zone := Area2D.new()
	zone.global_position = global_position
	get_parent().add_child(zone)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 200.0
	shape.shape = circle
	zone.add_child(shape)

	# Détruire la zone après le dialogue
	await get_tree().create_timer(PROTECTION_DURATION).timeout
	zone.queue_free()
