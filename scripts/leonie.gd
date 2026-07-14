extends Area2D
## Léonie, gardienne kitsune. Au passage d'Eneko, elle le SOIGNE (tous
## ses cœurs sont restaurés, avec un éclat de lumière) et prononce ses
## répliques dans une bulle flottante au-dessus d'elle — sans jamais
## bloquer le jeu : le joueur garde la main pendant qu'elle parle.

## Signal conservé pour compatibilité (plus jamais émis : le dialogue
## bloquant a été remplacé par la bulle flottante).
signal talk(lines)

const KITSUNE := "res://assets/character/kitsune/"
const LINE_TIME := 2.6  # durée d'affichage de chaque réplique

## Répliques par défaut (niveau 1) ; un niveau peut les remplacer via
## set_lines() juste après l'instanciation.
const DEFAULT_LINES := [
	{ "name": "Léonie", "text": "Halte, jeune sabreur. Peu osent s'aventurer dans la Clairière des Bambous." },
	{ "name": "Léonie", "text": "Je suis Léonie, gardienne de cette forêt. Les esprits d'ici sont agités..." },
	{ "name": "Léonie", "text": "Ton sabre devra être aussi vif que ton regard. Va, Eneko — la Voie du Sabre t'attend." },
]

var lines: Array = DEFAULT_LINES
var _triggered := false

@onready var anim: AnimatedSprite2D = $Anim

func _ready() -> void:
	anim.sprite_frames = SpriteSheet.build([
		{"name": "idle", "path": KITSUNE + "Idle.png", "frames": 8, "fps": 8.0, "loop": true},
	])
	anim.play("idle")
	body_entered.connect(_on_body_entered)

## Remplace les répliques par défaut.
func set_lines(new_lines: Array) -> void:
	lines = new_lines

func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if body.has_method("take_damage"):
		_triggered = true
		_heal(body)
		_speak()

## Le refuge de Léonie : soin complet, point de contrôle ET bénédiction
## (le prochain coup encaissé est annulé), avec un éclat doré ascendant.
func _heal(body: Node2D) -> void:
	if body.has_method("heal_full"):
		body.heal_full()
	if body.has_method("set_checkpoint"):
		body.set_checkpoint(Vector2(global_position.x, body.global_position.y))
	if body.has_method("bless"):
		body.bless()
	# Carillon doux du soin.
	var chime := AudioStreamPlayer.new()
	chime.stream = load("res://assets/sfx/heal.wav")
	chime.volume_db = -4.0
	add_child(chime)
	chime.play()
	chime.finished.connect(chime.queue_free)
	var sparkle := CPUParticles2D.new()
	sparkle.position = Vector2(0, -30)
	sparkle.amount = 16
	sparkle.lifetime = 0.9
	sparkle.one_shot = true
	sparkle.explosiveness = 1.0
	sparkle.direction = Vector2(0, -1)
	sparkle.spread = 55.0
	sparkle.gravity = Vector2(0, -40)
	sparkle.initial_velocity_min = 40.0
	sparkle.initial_velocity_max = 90.0
	sparkle.scale_amount_min = 1.5
	sparkle.scale_amount_max = 2.6
	sparkle.color = Color(1.0, 0.85, 0.5, 0.9)
	add_child(sparkle)
	sparkle.emitting = true
	var cleanup := get_tree().create_timer(1.2)
	cleanup.timeout.connect(sparkle.queue_free)

## Fait défiler les répliques dans une bulle flottante non bloquante.
func _speak() -> void:
	var bubble := Label.new()
	bubble.position = Vector2(-150, -170)
	bubble.custom_minimum_size = Vector2(300, 0)
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.z_index = 10
	bubble.add_theme_font_size_override("font_size", 15)
	bubble.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
	bubble.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	bubble.add_theme_constant_override("shadow_offset_x", 1)
	bubble.add_theme_constant_override("shadow_offset_y", 2)
	add_child(bubble)
	for line in lines:
		var d: Dictionary = line
		if not is_instance_valid(bubble):
			return
		bubble.text = "%s — %s" % [str(d.get("name", "")), str(d.get("text", ""))]
		bubble.modulate.a = 0.0
		var fade_in := create_tween()
		fade_in.tween_property(bubble, "modulate:a", 1.0, 0.25)
		await get_tree().create_timer(LINE_TIME).timeout
	if not is_instance_valid(bubble):
		return
	var fade_out := create_tween()
	fade_out.tween_property(bubble, "modulate:a", 0.0, 0.4)
	fade_out.finished.connect(bubble.queue_free)
