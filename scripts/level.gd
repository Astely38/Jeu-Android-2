extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var goal: Area2D = $Goal
@onready var kill_zone: Area2D = $KillZone
@onready var win_label: CanvasLayer = $WinLabel

func _ready() -> void:
	win_label.visible = false
	goal.body_entered.connect(_on_goal_body_entered)
	kill_zone.body_entered.connect(_on_kill_zone_body_entered)

func _on_kill_zone_body_entered(body: Node2D) -> void:
	if body == player:
		player.respawn()

func _on_goal_body_entered(body: Node2D) -> void:
	if body == player:
		win_label.visible = true
		player.set_physics_process(false)
