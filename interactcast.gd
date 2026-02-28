extends RayCast3D

@export var push_force: float = 200.0  # tune in inspector no recompile 🔥

func _physics_process(_delta: float) -> void:
	if not get_parent().is_multiplayer_authority(): return
	
	if is_colliding():
		var hit = get_collider()
		if hit.name == "door":
			var door_forward = hit.global_basis.z
			var is_rotated = abs(door_forward.dot(Vector3.RIGHT)) > 0.5
			var parent_basis = get_parent().global_basis
			
			if Input.is_action_just_pressed("player_interact"):
				var force = -parent_basis.x * 70.0 if is_rotated else -parent_basis.z * 50.0
				_push_door.rpc(hit.get_path(), force)
			if Input.is_action_just_pressed("player_interact2"):
				var force = parent_basis.x * 70.0 if is_rotated else parent_basis.z * 50.0
				_push_door.rpc(hit.get_path(), force)

@rpc("any_peer", "call_local")
func _push_door(door_path: NodePath, force: Vector3) -> void:
	var door = get_node_or_null(door_path)
	if door:
		door.apply_force(force)
		door.apply_torque(Vector3(0, force.x + force.z, 0) * 0.5)
