extends Node2D

var pscene = load("res://node_3d.tscn")
@export var button: Button
@export var audio_player: AudioStreamPlayer2D

func _ready():
	# Connect the button's pressed signal
	if button:
		button.pressed.connect(_on_button_pressed)

func _on_button_pressed():
	if button:
		button.disabled = true
		if audio_player:
			audio_player.play()
		await get_tree().create_timer(1.2).timeout # Optional delay for audio to play
		get_tree().change_scene_to_packed(pscene)
