class_name HUD
extends CanvasLayer
## Мобильный HUD: джойстик слева, кнопки атаки/скиллов/ульты справа,
## полоса HP и заряд духа дракона.

var player: Player

var _joystick: VirtualJoystick
var _buttons := {}
var _hp_bar: ProgressBar
var _ult_bar: ProgressBar
var _wave_label: Label
var _title_label: Label
var _flash_rect: ColorRect
var _last_hp := -1.0

func _ready() -> void:
	layer = 5
	var ui := Control.new()
	ui.name = "UI"
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)

	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 0.1, 0.1, 0.0)
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_flash_rect)

	_joystick = VirtualJoystick.new()
	ui.add_child(_joystick)

	var name_label := Label.new()
	name_label.text = "ЮККА"
	name_label.position = Vector2(26, 14)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.8))
	ui.add_child(name_label)

	_hp_bar = _make_bar(Color(0.95, 0.25, 0.4))
	_hp_bar.position = Vector2(26, 44)
	_hp_bar.size = Vector2(300, 20)
	ui.add_child(_hp_bar)

	var ult_label := Label.new()
	ult_label.text = "ДУХ ДРАКОНА"
	ult_label.anchor_left = 1.0
	ult_label.anchor_right = 1.0
	ult_label.offset_left = -250
	ult_label.offset_right = -26
	ult_label.offset_top = 16
	ult_label.offset_bottom = 40
	ult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ult_label.add_theme_font_size_override("font_size", 16)
	ult_label.add_theme_color_override("font_color", Color(0.45, 0.9, 1.0))
	ui.add_child(ult_label)

	_ult_bar = _make_bar(Color(0.4, 0.9, 1.0))
	_ult_bar.anchor_left = 1.0
	_ult_bar.anchor_right = 1.0
	_ult_bar.offset_left = -250
	_ult_bar.offset_right = -26
	_ult_bar.offset_top = 44
	_ult_bar.offset_bottom = 60
	ui.add_child(_ult_bar)

	_wave_label = Label.new()
	_wave_label.anchor_right = 1.0
	_wave_label.offset_top = 14
	_wave_label.offset_bottom = 46
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.add_theme_font_size_override("font_size", 22)
	ui.add_child(_wave_label)

	_title_label = Label.new()
	_title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 50)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.85))
	_title_label.modulate.a = 0.0
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_title_label)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -14
	crosshair.offset_top = -22
	crosshair.offset_right = 14
	crosshair.offset_bottom = 22
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 32)
	crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(crosshair)

	_buttons["attack"] = _make_button("УДАР", Color(1.0, 0.45, 0.55), 64.0)
	_buttons["jump"] = _make_button("ПРЫЖОК", Color(0.45, 0.75, 1.0), 42.0)
	_buttons["skill1"] = _make_button("САКУРА", Color(1.0, 0.4, 0.8), 46.0)
	_buttons["skill2"] = _make_button("РЫВОК", Color(1.0, 0.7, 0.3), 46.0)
	_buttons["ult"] = _make_button("ДРАКОН", Color(0.4, 0.9, 1.0), 54.0)
	_layout()
	get_viewport().size_changed.connect(_layout)

func set_player(p: Player) -> void:
	player = p
	_last_hp = p.hp
	_buttons["skill1"]["btn"].pressed.connect(p.try_skill1)
	_buttons["skill2"]["btn"].pressed.connect(p.try_skill2)
	_buttons["ult"]["btn"].pressed.connect(p.try_ult)
	_buttons["jump"]["btn"].pressed.connect(p.try_jump)

func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.move_input = _joystick.output
	if _buttons["attack"]["btn"].is_pressed():
		player.try_attack()
	_hp_bar.value = 100.0 * player.hp / player.max_hp
	_ult_bar.value = player.ult_charge
	if player.hp < _last_hp:
		_flash()
	_last_hp = player.hp
	_update_cd("skill1", player.skill1_cd)
	_update_cd("skill2", player.skill2_cd)
	var ult_ready := player.ult_charge >= Player.ULT_MAX
	_buttons["ult"]["btn"].modulate.a = 1.0 if ult_ready else 0.4

func set_wave_text(text: String) -> void:
	_wave_label.text = text

func show_title(text: String) -> void:
	_title_label.text = text
	_title_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(2.2)
	tween.tween_property(_title_label, "modulate:a", 0.0, 0.8)

func _update_cd(key: String, value: float) -> void:
	var b: Dictionary = _buttons[key]
	b["cd"].visible = value > 0.0
	if value > 0.0:
		b["cd"].text = "%.1f" % value
	b["btn"].modulate.a = 0.45 if value > 0.0 else 1.0

func _flash() -> void:
	_flash_rect.color.a = 0.3
	var tween := create_tween()
	tween.tween_property(_flash_rect, "color:a", 0.0, 0.35)

func _layout() -> void:
	var s := get_viewport().get_visible_rect().size
	_place("attack", s + Vector2(-130, -130))
	_place("jump", s + Vector2(-405, -215))
	_place("skill1", s + Vector2(-285, -100))
	_place("skill2", s + Vector2(-100, -285))
	_place("ult", s + Vector2(-272, -250))

func _place(key: String, center: Vector2) -> void:
	var b: Dictionary = _buttons[key]
	b["btn"].position = center - Vector2(b["radius"], b["radius"])

# TouchScreenButton (а не Button) — чтобы мультитач работал вместе с джойстиком.
func _make_button(text: String, color: Color, radius: float) -> Dictionary:
	var btn := TouchScreenButton.new()
	btn.texture_normal = _circle_texture(radius, color)
	btn.texture_pressed = _circle_texture(radius, color.lightened(0.4))
	var shape := CircleShape2D.new()
	shape.radius = radius
	btn.shape = shape
	btn.shape_centered = true
	add_child(btn)

	var label := Label.new()
	label.text = text
	label.position = Vector2(0, radius * 2.0 + 2.0)
	label.size = Vector2(radius * 2.0, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	btn.add_child(label)

	var cd := Label.new()
	cd.position = Vector2(0, radius - 20.0)
	cd.size = Vector2(radius * 2.0, 40)
	cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd.add_theme_font_size_override("font_size", 30)
	cd.visible = false
	btn.add_child(cd)

	return {"btn": btn, "cd": cd, "radius": radius}

func _circle_texture(radius: float, color: Color) -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.78, 0.82, 1.0])
	gradient.colors = PackedColorArray([
		Color(color, 0.32), Color(color, 0.32), Color(color, 0.65), Color(color, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = int(radius * 2.0)
	tex.height = int(radius * 2.0)
	return tex

func _make_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar
