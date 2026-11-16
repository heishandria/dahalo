extends Node
## Déclare les actions d'entrée par code (plus lisible et versionnable que project.godot).
## Les touches sont « physiques » : WASD en QWERTY = ZQSD en AZERTY, automatiquement.

func _ready() -> void:
	_touche("camera_haut", [KEY_W, KEY_UP])
	_touche("camera_bas", [KEY_S, KEY_DOWN])
	_touche("camera_gauche", [KEY_A, KEY_LEFT])
	_touche("camera_droite", [KEY_D, KEY_RIGHT])
	_touche("former_villageois", [KEY_1, KEY_KP_1])
	_touche("former_dahalo", [KEY_2, KEY_KP_2])
	_touche("former_pisteur", [KEY_3, KEY_KP_3])
	_touche("construire_enclos", [KEY_E])
	_touche("annuler", [KEY_ESCAPE])


func _touche(action: String, touches: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in touches:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
