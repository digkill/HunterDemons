class_name NarrationOverlay
extends CanvasLayer
## Сюжетный экран: реплики с эффектом печатной машинки, тап — дальше.

signal finished

const CHARS_PER_SEC := 45.0

const NAME_COLORS := {
	"Юкка": Color(1.0, 0.55, 0.8),
	"Тэцурю": Color(0.45, 0.9, 1.0),
}

var _lines: Array = []
var _index := 0
var _visible_chars := 0.0
var _typing := false
var _name_label: Label
var _text_label: Label

func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.0, 0.05, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_on_gui_input)
	add_child(bg)

	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.04, 0.12, 0.95)
	sb.border_color = Color(1.0, 0.4, 0.75)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.06
	panel.anchor_right = 0.94
	panel.anchor_top = 0.66
	panel.anchor_bottom = 0.94
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(panel)

	_name_label = Label.new()
	_name_label.position = Vector2(22, 10)
	_name_label.add_theme_font_size_override("font_size", 24)
	panel.add_child(_name_label)

	_text_label = Label.new()
	_text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text_label.offset_left = 22
	_text_label.offset_right = -22
	_text_label.offset_top = 46
	_text_label.offset_bottom = -12
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 21)
	panel.add_child(_text_label)

	var hint := Label.new()
	hint.text = "коснитесь, чтобы продолжить…"
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -320
	hint.offset_right = -14
	hint.offset_top = -30
	hint.offset_bottom = -8
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	panel.add_child(hint)

func show_lines(lines: Array) -> void:
	if lines.is_empty():
		finished.emit()
		queue_free()
		return
	_lines = lines
	_index = 0
	_apply()

func _apply() -> void:
	var line: Dictionary = _lines[_index]
	var who: String = line.get("name", "")
	_name_label.text = who
	_name_label.add_theme_color_override("font_color", NAME_COLORS.get(who, Color.WHITE))
	_text_label.text = line.get("text", "")
	_text_label.visible_characters = 0
	_visible_chars = 0.0
	_typing = true

func _process(delta: float) -> void:
	if not _typing:
		return
	_visible_chars += delta * CHARS_PER_SEC
	_text_label.visible_characters = int(_visible_chars)
	if _text_label.visible_characters >= _text_label.text.length():
		_text_label.visible_characters = -1
		_typing = false

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_advance()

func _advance() -> void:
	SFX.play("ui_next", -8.0)
	if _typing:
		_typing = false
		_text_label.visible_characters = -1
	elif _index + 1 < _lines.size():
		_index += 1
		_apply()
	else:
		finished.emit()
		queue_free()
