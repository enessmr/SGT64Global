extends Node2D

var pscene = load("res://menu.tscn")
@export var animation_player: AnimationPlayer
func _process(delta):
	animation_player.play("RESET")
	await get_tree().create_timer(2.7, false).timeout
	animation_player.stop()
	await get_tree().create_timer(1, false).timeout
	get_tree().change_scene_to_packed(pscene)
 
