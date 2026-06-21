class_name MainMenu
extends Control
## Главное меню с выбором уровней (прогресс — из GameState).

signal level_selected(index: int)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	SFX.play_music("music_menu")

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "HUNTER DEMONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.75))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Юкка • клинок «Кибер-Сакура» • охота на демонов"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 19)
	subtitle.add_theme_color_override("font_color", Color(0.45, 0.9, 1.0))
	vbox.add_child(subtitle)

	vbox.add_child(_spacer(24))

	for i in LevelData.LEVELS.size():
		var btn := Button.new()
		var unlocked: bool = i < GameState.unlocked_levels
		if unlocked:
			btn.text = "%d. %s" % [i + 1, LevelData.LEVELS[i]["name"]]
		else:
			btn.text = "%d. ・・・ (заблокировано)" % (i + 1)
		btn.disabled = not unlocked
		btn.custom_minimum_size = Vector2(430, 58)
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(_on_level_pressed.bind(i))
		vbox.add_child(btn)

	vbox.add_child(_spacer(18))

	var footer := Label.new()
	footer.text = "Прототип: вместо моделей — заглушки. Свои модели клади в assets/"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	vbox.add_child(footer)

func _on_level_pressed(index: int) -> void:
	SFX.play("ui_tap", -4.0)
	level_selected.emit(index)

func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer
