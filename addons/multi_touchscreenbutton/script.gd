@icon("icon/icon.svg")
extends TextureButton

@export var action: String

@onready var _texture_normal := texture_normal
@onready var _texture_pressed := texture_pressed

func _gui_input(event):
	# Only touch InputEventScreenTouch because others do NOT have .position
	if event is InputEventScreenTouch:
		var event_pos_adjusted: Vector2 = event.position + global_position

		var inside: bool = (
			event_pos_adjusted.x > position.x
			and event_pos_adjusted.y > position.y
			and event_pos_adjusted.x < position.x + size.x
			and event_pos_adjusted.y < position.y + size.y
		)

		if event.pressed and inside:
			if toggle_mode:
				toggled.emit()
				button_pressed = true
				texture_normal = _texture_pressed
			else:
				pressed.emit()
				button_down.emit()

			if action:
				Input.action_press(action)

			texture_normal = _texture_pressed

		elif inside or (not event.pressed and not inside):
			button_up.emit()
			button_pressed = false
			texture_normal = _texture_normal

			if action:
				Input.action_release(action)
