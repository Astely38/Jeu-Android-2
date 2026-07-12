extends Node2D
## Logique du niveau : arrivée au torii (victoire), zone de chute (respawn),
## et déclenchement du dialogue de Léonie (pause du joueur pendant l'échange).

const SPAWN_Y := 477.0

@onready var player: CharacterBody2D = $Player
@onready var goal: Area2D = $Goal
@onready var kill_zone: Area2D = $KillZone
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var dialogue: CanvasLayer = $Dialogue
@onready var leonie: Area2D = $Leonie
@onready var checkpoint: Area2D = $Checkpoint

func _ready() -> void:
	win_label.visible = false
	goal.body_entered.connect(_on_goal_body_entered)
	kill_zone.body_entered.connect(_on_kill_zone_body_entered)
	leonie.talk.connect(_on_leonie_talk)
	dialogue.finished.connect(_on_dialogue_finished)
	menu_button.pressed.connect(_on_menu_pressed)
	checkpoint.body_entered.connect(_on_checkpoint_body_entered)

func _on_checkpoint_body_entered(body: Node2D) -> void:
	if body == player:
		player.set_checkpoint(Vector2(checkpoint.global_position.x, SPAWN_Y))
		# Bannière : passe au vert une fois le point de contrôle validé.
		checkpoint.get_node("Flag").color = Color(0.35, 0.8, 0.4, 1)

func _on_kill_zone_body_entered(body: Node2D) -> void:
	if body == player:
		player.respawn()

func _on_goal_body_entered(body: Node2D) -> void:
	if body == player:
		win_label.visible = true
		player.set_physics_process(false)

func _on_leonie_talk(lines: Array) -> void:
	# Pause d'Eneko le temps du dialogue.
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	dialogue.start(lines)

func _on_dialogue_finished() -> void:
	player.set_physics_process(true)

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
