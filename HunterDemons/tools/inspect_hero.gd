extends SceneTree
## Печатает структуру chisa.fbx и одного файла анимации (для отладки импорта).

func _init() -> void:
	for path in [
		"res://assets/MainHero/Una/chisa.fbx",
		"res://assets/MainHero/Una/great sword idle.fbx",
	]:
		print("\n=== ", path, " ===")
		var packed: PackedScene = load(path)
		if packed == null:
			print("  НЕ ЗАГРУЗИЛСЯ")
			continue
		var root := packed.instantiate()
		_dump(root, 0)
		root.free()
	quit(0)

func _dump(node: Node, depth: int) -> void:
	var info := "%s%s (%s)" % ["  ".repeat(depth), node.name, node.get_class()]
	if node is AnimationPlayer:
		info += " анимации: " + str(node.get_animation_list())
		for anim_name in node.get_animation_list():
			var anim: Animation = node.get_animation(anim_name)
			info += "\n%s  длина=%.2f, треков=%d, путь[0]=%s" % [
				"  ".repeat(depth), anim.length, anim.get_track_count(),
				anim.track_get_path(0) if anim.get_track_count() > 0 else "-",
			]
	if node is MeshInstance3D:
		info += " mesh=" + str(node.mesh != null)
	if node is Skeleton3D:
		info += " костей: %d, [0]=%s" % [node.get_bone_count(), node.get_bone_name(0)]
	print(info)
	if depth < 3:
		for child in node.get_children():
			_dump(child, depth + 1)
