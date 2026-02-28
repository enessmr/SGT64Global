extends RayCast3D
func _process(delta):
	if is_colliding():
		var hitObj = get_collider()
		if hitObj.has_method("interact") && Input.is_action_just_pressed("player_interact"):
			# RayCast3D -> Camera3D -> PlayerMesh -> Player (RigidBody3D)
			var player = get_parent().get_parent().get_parent()
			hitObj.interact(player)
