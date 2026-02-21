extends Node

func _ready():
	# Define our desired input map
	var inputs = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_forward": [KEY_W, KEY_UP],
		"move_backward": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE],
		"attack": [MOUSE_BUTTON_LEFT],
		"dodge": [KEY_SHIFT]
	}

	for action in inputs:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			print("Added action: ", action)
			
		for key in inputs[action]:
			var event
			if typeof(key) == TYPE_INT: # Key or Mouse Button
				if key < 10: # Mouse buttons are small integers
					event = InputEventMouseButton.new()
					event.button_index = key
				else:
					event = InputEventKey.new()
					event.keycode = key
			
			if event:
				InputMap.action_add_event(action, event)
				print("Mapped ", key, " to ", action)
