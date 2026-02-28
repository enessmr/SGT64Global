extends StaticBody3D
var toggle = false
var interactable = true
@onready var animation_player = $DoorAnim
var which_side = 0

func interact(player_body):  # <--- take player as parameter!!
	if interactable:
		interactable = false
		toggle = !toggle
		
		if toggle:
			# figure out which side player's on
			var door_forward = -global_transform.basis.z
			var to_player = (player_body.global_position - global_position).normalized()
			var dot_product = door_forward.dot(to_player)
			
			# open the right way
			if dot_product > 0:
				animation_player.play("RESET2")  # forward
				which_side = 1
			else:
				animation_player.play("RESET")  # backward
				which_side = 2
		else:
			# close based on which side!!
			if which_side == 1:
				animation_player.play("close2")
			else:
				animation_player.play("close")
		
		await get_tree().create_timer(1.0, false).timeout
		interactable = true
