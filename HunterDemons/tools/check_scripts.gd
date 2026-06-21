extends SceneTree
## Проверка компиляции всех скриптов:
## godot --headless --path . -s res://tools/check_scripts.gd

func _init() -> void:
	var bad := 0
	var stack: Array[String] = ["res://scripts"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			var path := dir_path.path_join(entry)
			if dir.current_is_dir():
				if not entry.begins_with("."):
					stack.append(path)
			elif entry.ends_with(".gd"):
				var script: Script = load(path)
				if script == null or not script.can_instantiate():
					push_error("СКРИПТ С ОШИБКОЙ: " + path)
					bad += 1
				else:
					print("OK ", path)
			entry = dir.get_next()
	if bad == 0:
		print("Все скрипты в порядке.")
	quit(bad)
