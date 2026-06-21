extends Node
## Глобальное состояние: прогресс прохождения, сохранение, регистрация управления.

const SAVE_PATH := "user://save.json"

var unlocked_levels := 1

func _ready() -> void:
	_register_input_actions()
	load_game()

func unlock_level(index: int) -> void:
	if index + 1 > unlocked_levels:
		unlocked_levels = index + 1
		save_game()

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"unlocked_levels": unlocked_levels}))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		unlocked_levels = int(data.get("unlocked_levels", 1))

# Клавиатура — для отладки на десктопе; на телефоне всё управление через HUD.
func _register_input_actions() -> void:
	var actions := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"attack": [KEY_SPACE, KEY_J],
		"skill_1": [KEY_Q],
		"skill_2": [KEY_E],
		"ult": [KEY_R],
		"interact": [KEY_F, KEY_ENTER, KEY_K],
	}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in actions[action]:
				var event := InputEventKey.new()
				event.physical_keycode = key
				InputMap.action_add_event(action, event)
