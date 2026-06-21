extends SceneTree
## Собирает героиню: chisa.fbx + все анимации из Una/ -> assets/MainHero/hero.tscn
## Запуск: godot --headless --path . -s res://tools/bake_hero.gd

const SRC_DIR := "res://assets/MainHero/Una"
const MODEL := SRC_DIR + "/chisa.fbx"
const OUT := "res://assets/MainHero/hero.tscn"
# Скелет модели уже даёт рост ~1.6 м; AABB меша врёт (данные в локальных
# единицах до скейла костей), поэтому корень не трогаем.
const ROOT_SCALE := 1.0
# Дорожки позиций с чистым смещением больше порога — это root motion, убираем его.
const TRAVEL_THRESHOLD := 0.25

func _init() -> void:
	var model_scene: PackedScene = load(MODEL)
	if model_scene == null:
		push_error("Не загрузился " + MODEL)
		quit(1)
		return
	var root := model_scene.instantiate()
	var anim_player: AnimationPlayer = root.get_node("AnimationPlayer")
	for lib_name in anim_player.get_animation_library_list():
		anim_player.remove_animation_library(lib_name)
	var library := AnimationLibrary.new()

	var dir := DirAccess.open(SRC_DIR)
	dir.list_dir_begin()
	var entry := dir.get_next()
	var count := 0
	while entry != "":
		if entry.to_lower().ends_with(".fbx") and entry != "chisa.fbx":
			var packed: PackedScene = load(SRC_DIR + "/" + entry)
			if packed:
				var inst := packed.instantiate()
				var ap: AnimationPlayer = inst.get_node_or_null("AnimationPlayer")
				if ap and ap.get_animation_list().size() > 0:
					var anim: Animation = ap.get_animation(ap.get_animation_list()[0]).duplicate(true)
					var anim_name := _clean_name(entry.get_basename())
					_strip_root_motion(anim, anim_name)
					if _is_loop(anim_name):
						anim.loop_mode = Animation.LOOP_LINEAR
					library.add_animation(anim_name, anim)
					count += 1
					print("+ %s (%.2fs)%s" % [anim_name, anim.length, " [loop]" if _is_loop(anim_name) else ""])
				inst.free()
		entry = dir.get_next()
	anim_player.add_animation_library("", library)
	print("Всего анимаций: ", count)

	_apply_scale(root)
	_set_owner_recursive(root, root)
	var out_scene := PackedScene.new()
	out_scene.pack(root)
	var err := ResourceSaver.save(out_scene, OUT)
	print("Сохранение ", OUT, ": ", error_string(err))
	root.free()
	quit(0 if err == OK else 1)

func _apply_scale(root: Node3D) -> void:
	root.scale = Vector3.ONE * ROOT_SCALE
	print("Scale корня: ", root.scale)

func _strip_root_motion(anim: Animation, anim_name: String) -> void:
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var keys := anim.track_get_key_count(i)
		if keys < 2:
			continue
		var first: Vector3 = anim.track_get_key_value(i, 0)
		var last: Vector3 = anim.track_get_key_value(i, keys - 1)
		var travel := first.distance_to(last)
		if travel < TRAVEL_THRESHOLD:
			continue
		var track_path := anim.track_get_path(i)
		print("  root motion %.2fм у %s в '%s' — убираю X/Y/Z" % [travel, track_path, anim_name])
		for k in keys:
			var value: Vector3 = anim.track_get_key_value(i, k)
			value.x = first.x
			value.y = first.y
			value.z = first.z
			anim.track_set_key_value(i, k, value)

static func _clean_name(base: String) -> String:
	var n := base.to_lower()
	n = n.replace("great sword ", "").replace("two handed sword ", "")
	n = n.replace("(", "").replace(")", "")
	return n.strip_edges().replace(" ", "_")

static func _is_loop(anim_name: String) -> bool:
	for prefix in ["idle", "walk", "run", "strafe", "crouching", "blocking"]:
		if anim_name.begins_with(prefix):
			return true
	return false

func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	if node != owner_node:
		node.owner = owner_node
	for child in node.get_children():
		_set_owner_recursive(child, owner_node)
