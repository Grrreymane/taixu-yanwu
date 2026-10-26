extends Control
## Two visible rows. A future roster above six armors uses discrete pages,
## never a horizontal scrollbar or off-screen selection targets.
signal choice_requested(identity: String)
signal page_changed

const CARD_SIZE := Vector2(108, 104)
const COLUMNS := 3
const PAGE_SIZE := 6
const GAP := Vector2(10, 8)
const ACCENT := Color("43c8eb")
var buttons: Array[Button] = []
var page := 0
var _selected := ""

func _init() -> void:
	name = "ArmorPortraits"
	mouse_filter = Control.MOUSE_FILTER_STOP

func populate(options: Array, font: Font) -> void:
	for button: Button in buttons:
		button.free()
	buttons.clear()
	for option: Dictionary in options:
		var identity: String = str(option.get("id", ""))
		if identity.is_empty() or not bool(option.get("playable", true)):
			continue
		var button := Button.new()
		button.name = "StyleChoice_" + identity
		button.custom_minimum_size = CARD_SIZE
		button.size = CARD_SIZE
		button.focus_mode = Control.FOCUS_ALL
		button.toggle_mode = true
		button.clip_contents = true
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = str(option.get("name", "")) + " · " + str(option.get("roleTag", ""))
		button.set_meta("selection_id", identity)
		button.set_meta("portrait_path", str(option.get("portraitPath", "")))
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 16)
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("173b50")
			style.border_color = Color(ACCENT, 0.30)
			style.set_border_width_all(1)
			style.corner_radius_bottom_right = 10
			if state == "hover":
				style.bg_color = Color("28566c")
				style.border_color = ACCENT
			elif state in ["pressed", "hover_pressed"]:
				style.bg_color = Color("286178")
				style.border_color = Color("ffbf66")
				style.set_border_width_all(3)
			elif state == "focus":
				style.bg_color = Color.TRANSPARENT
				style.border_color = Color.WHITE
				style.set_border_width_all(2)
			button.add_theme_stylebox_override(state, style)
		add_child(button)
		var portrait := TextureRect.new()
		portrait.name = "Portrait"
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.position = Vector2(4, 4)
		portrait.size = Vector2(100, 72)
		var path: String = str(option.get("portraitPath", ""))
		if not path.is_empty() and ResourceLoader.exists(path):
			var source := load(path) as Texture2D
			var face := AtlasTexture.new()
			face.atlas = source
			# Original cards are tall half-body portraits. Keep the source's top
			# (head and shoulders), rather than a centered crop that cuts off hair.
			face.region = Rect2(0, 0, source.get_width(), minf(source.get_height(), source.get_width() * 0.80))
			portrait.texture = face
		button.add_child(portrait)
		var title := Label.new()
		title.name = "Title"
		title.text = str(option.get("name", ""))
		title.add_theme_font_override("font", font)
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override("font_color", Color("f4fbff"))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.position = Vector2(4, 78)
		title.size = Vector2(100, 22)
		button.add_child(title)
		var marker := Label.new()
		marker.name = "Selected"
		marker.text = "已选"
		marker.add_theme_font_override("font", font)
		marker.add_theme_font_size_override("font_size", 11)
		marker.add_theme_color_override("font_color", Color("ffbf66"))
		marker.add_theme_color_override("font_shadow_color", Color("102531"))
		marker.add_theme_constant_override("shadow_offset_x", 1)
		marker.add_theme_constant_override("shadow_offset_y", 1)
		marker.position = Vector2(81, 4)
		marker.size = Vector2(24, 25)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(marker)
		button.pressed.connect(func(): choice_requested.emit(identity))
		buttons.append(button)
	_selected = ""
	page = 0
	_layout_page()

func set_selection(identity: String, available: bool) -> void:
	var changed: bool = identity != _selected
	_selected = identity
	for button: Button in buttons:
		var chosen: bool = str(button.get_meta("selection_id")) == identity
		button.set_pressed_no_signal(chosen)
		button.disabled = not available
		button.get_node("Selected").visible = chosen
		if chosen and changed:
			page = buttons.find(button) / PAGE_SIZE
	if changed: _layout_page()

func page_count() -> int:
	return maxi(1, ceili(float(buttons.size()) / PAGE_SIZE))

func change_page(direction: int) -> void:
	page = clampi(page + direction, 0, page_count()-1)
	_layout_page()

func _layout_page() -> void:
	for index in buttons.size():
		var cell := index % PAGE_SIZE
		buttons[index].position = Vector2(cell % COLUMNS, cell / COLUMNS) * (CARD_SIZE + GAP)
		buttons[index].size = CARD_SIZE
		buttons[index].visible = index / PAGE_SIZE == page
	page_changed.emit()
