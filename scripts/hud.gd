extends CanvasLayer
## A compact battle HUD. Gameplay owns keyboard input; these controls also support multitouch.

signal action_requested(action: String)
signal move_changed(value: float)
signal guard_changed(held: bool)

const INK := Color("163244")
const BLUE := Color("37bce6")
const ORANGE := Color("ffae43")
const WHITE := Color("f4fbff")
const SentienceCombat = preload("res://scripts/sentience_combat.gd")
const FighterGuide = preload("res://scripts/fighter_guide.gd")
const EnemyHealthDisplay = preload("res://scripts/enemy_health_display.gd")
const ArmorPortraitStrip = preload("res://scripts/armor_portrait_strip.gd")

class SlantPanel extends Control:
	var tint := Color(0.055, 0.13, 0.20, 0.80)
	var accent := Color("37bce6")
	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - 16, h), Vector2(0, h)]), tint)
		draw_line(Vector2(0, 0), Vector2(w, 0), accent, 2.0, true)
		draw_line(Vector2(0, 0), Vector2(0, h), accent, 3.0, true)

class Gauge extends Control:
	var value := 100.0
	var tint := Color("37bce6")
	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var cut: float = minf(7.0, h * 0.6)
		draw_colored_polygon(PackedVector2Array([Vector2(cut, 0), Vector2(w, 0), Vector2(w - cut, h), Vector2(0, h)]), Color(0.03, 0.10, 0.16, 0.65))
		var fill: float = w * clampf(value / 100.0, 0.0, 1.0)
		if fill > cut:
			draw_colored_polygon(PackedVector2Array([Vector2(cut, 0), Vector2(fill, 0), Vector2(fill - cut, h), Vector2(0, h)]), tint)
		for index in range(1, 10):
			var x: float = w * float(index) / 10.0
			draw_line(Vector2(x, 1), Vector2(x - cut, h - 1), Color(0.03, 0.10, 0.16, 0.17), 1.0)
	func set_amount(amount: float) -> void:
		if not is_equal_approx(amount, value):
			value = amount
			queue_redraw()

class SkillButton extends Control:
	signal held_changed(held: bool)
	var accent := Color("d9f4ff")
	var active := false
	var enabled := true
	var finger := -1
	var mouse_held := false
	var hover := false
	var arrow := 0
	var cooldown_fraction := 0.0
	var title: Label
	var hint: Label
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): hover = true; queue_redraw())
		mouse_exited.connect(func(): hover = false; queue_redraw())
	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5 - 4.0
		var a: float = 1.0 if enabled else 0.40
		var base := Color(0.07, 0.17, 0.24, 0.67 if not active else 0.92)
		draw_circle(center, radius, base)
		draw_circle(center, radius - 7.0, Color(accent, (0.20 if hover or active else 0.07) * a))
		draw_arc(center, radius, 0, TAU, 60, Color(accent, 0.85 * a), 2.0, true)
		draw_arc(center, radius - 5.0, -1.4, -0.2, 20, Color(accent, 0.65 * a), 2.0, true)
		if active:
			draw_arc(center, radius + 3.0, 0, TAU, 60, Color(accent, 0.65), 2.0, true)
		if cooldown_fraction > 0.0:
			draw_arc(center,radius+2.0,-PI*0.5,-PI*0.5+TAU*(1.0-cooldown_fraction),60,Color(accent,0.95),3.0,true)
		if arrow != 0:
			var x: float = center.x - float(arrow) * 2.0
			draw_polyline(PackedVector2Array([Vector2(x-float(arrow)*6.0,center.y-12.0),Vector2(x+float(arrow)*5.0,center.y),Vector2(x-float(arrow)*6.0,center.y+12.0)]),Color(accent,a),3.5,true)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
			if event.pressed and enabled:
				mouse_held = true
				_set_active(true)
			elif mouse_held:
				mouse_held = false
				_set_active(false)
			accept_event()
	func _input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			if event.pressed and is_visible_in_tree() and enabled and finger == -1 and get_global_rect().has_point(event.position):
				finger = event.index
				_set_active(true)
				get_viewport().set_input_as_handled()
			elif not event.pressed and event.index == finger:
				finger = -1
				_set_active(false)
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and not event.pressed and mouse_held and event.button_index == MOUSE_BUTTON_LEFT:
			mouse_held = false
			_set_active(false)
	func _set_active(held: bool) -> void:
		if active == held:
			return
		active = held
		queue_redraw()
		held_changed.emit(held)
	func set_enabled(value: bool) -> void:
		if enabled == value:
			return
		enabled = value
		if not enabled:
			release()
		modulate.a = 1.0 if enabled else 0.65
		queue_redraw()
	func release() -> void:
		finger = -1
		mouse_held = false
		_set_active(false)
	func set_cooldown(fraction: float) -> void:
		if not is_equal_approx(cooldown_fraction,fraction):
			cooldown_fraction = clampf(fraction,0.0,1.0)
			queue_redraw()
	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
			release()

var _font: Font
var _number_font: Font
var _ui := Control.new()
var _battle := Control.new()
var _enemy_panel := Control.new()
var _player_panel := Control.new()
var _menu := SlantPanel.new()
var _brand: Label
var _enemy_name: Label
var _enemy_tag: Label
var _enemy_hp := Gauge.new()
var _enemy_posture := Gauge.new()
var _player_hp := Gauge.new()
var _player_sp := Gauge.new()
var _player_posture := Gauge.new()
var _hp_text: Label
var _sp_text: Label
var _player_name: Label
var _battlesuit: Label
var _stance_label: Label
var _combo: Label
var _notice: Label
var _menu_title: Label
var _menu_subtitle: Label
var _menu_detail: Label
var _menu_start: Button
var _menu_restart: Button
var _menu_practice: Button
var _menu_hint: Label
var _menu_back: Button
var _music_button: Button
var _voice_button: Button
var _menu_guide: Button
var _guide_overlay := Control.new()
var _guide_panel := SlantPanel.new()
var _guide_scroll := ScrollContainer.new()
var _guide_content := Control.new()
var _guide_title: Label
var _guide_tag: Label
var _guide_summary: Label
var _guide_close: Button
var _guide_footer: Label
var _guide_cards: Array[SlantPanel] = []
var _guide_parry := SlantPanel.new()
var _guide_chain: Label
var _guide_parry_note: Label
var _guide_tip: Label
var _guide_data: Dictionary = {}
var _guide_open := false
var _ko_active := false
var _health_display: Dictionary = {}
var _last_render_size := Vector2.ZERO
var _roster_group := Control.new()
var _armor_strip := ArmorPortraitStrip.new()
var _armor_previous: Button
var _armor_next: Button
var _menu_skill_summary: Label
var _preview_region := Control.new()
var _preview_hint: Label
var _style_caption: Label
var _appearance_caption: Label
var _style_choices: Array[Button] = []
var _appearance_choices: Array[Button] = []
var _roster: Dictionary = {}
var _fighter_identity: Dictionary = {}
var _roster_signature := ""
var _armor_signature := ""
var _mode_button: Button
var _pause_button: Button
var _instruction: Label
var _cinematic := Control.new()
var _cinematic_top := ColorRect.new()
var _cinematic_bottom := ColorRect.new()
var _ultimate_title: Label
var _ultimate_tag: Label
var _stage_panel := SlantPanel.new()
var _stage_title: Label
var _stage_objective: Label
var _stage_boons: Label
var _stage_marks: Array[ColorRect] = []
var _stage_banner := SlantPanel.new()
var _banner_title: Label
var _banner_detail: Label
var _banner_time := 0.0
var _reward_overlay := Control.new()
var _reward_group := Control.new()
var _reward_title: Label
var _reward_subtitle: Label
var _reward_boons: Label
var _reward_buttons: Array[Button] = []
var _reward_names: Array[Label] = []
var _reward_descriptions: Array[Label] = []
var _reward_locked := false
var _reward_signature := ""
var _result_overlay := Control.new()
var _result_panel := SlantPanel.new()
var _result_rank: Label
var _result_score: Label
var _result_boons: Label
var _result_values: Array[Label] = []
var _result_tag: Label
var _result_title: Label
var _result_detail: Label
var _result_again: Button
var _result_secondary: Button
var _result_replay: Button
var _victory_overlay := Control.new()
var _victory_heading := Control.new()
var _victory_identity := Control.new()
var _victory_name: Label
var _victory_style: Label
var _victory_skin: Label
var _victory_music: Button
var _victory_voice: Button
var _victory_skip: Button
var _victory_pause_panel := SlantPanel.new()
var _victory: Dictionary = {}
var _campaign: Dictionary = {}
var _campaign_mode := "trial"
var _phase := "menu"
var _previous_phase := "menu"
var _last_stage_index := -1
var _cooldown_max := 1.0
var _skills: Dictionary = {}
var _left: SkillButton
var _right: SkillButton
var _moving_left := false
var _moving_right := false
var _ready_to_play := false
var _started := false
var _paused := false
var _ended := false
var _notice_time := 0.0
var _last_size := Vector2.ZERO
var _menu_mode := ""
var _contract_panel := Control.new()
var _contract_heading: Label
var _contract_detail: Label
var _contract_buttons: Array[Button] = []
var _contract_signature := ""
var _contract_all: Button

func _ready() -> void:
	name = "BattleHUD"
	layer = 10
	_font = load("res://assets/fonts/hi3-sdk-zh-cn.ttf") as Font
	_number_font = load("res://assets/fonts/hi3-anton-regular.ttf") as Font
	_number_font.fallbacks = [_font]
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	_battle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_battle)
	_build_battle()
	_build_menu()
	_build_contracts()
	_build_campaign()
	_build_cinematic()
	_notice = _label(_ui, "", 30, WHITE)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_color_override("font_shadow_color", Color(0.03, 0.13, 0.22, 0.7))
	_notice.add_theme_constant_override("shadow_offset_y", 2)
	_build_victory()
	_build_fighter_guide()
	_layout()
	_set_menu("intro", "")
	_battle.visible = false

func _label(parent: Node, text: String, font_size: int, color: Color = WHITE) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_override("font", _font)
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

func _place(item: Control, x: float, y: float, w: float, h: float) -> void:
	item.position = Vector2(x, y)
	item.size = Vector2(w, h)

func _rect_button(parent: Node, text: String, orange: bool = false) -> Button:
	var item := Button.new()
	item.text = text
	item.focus_mode = Control.FOCUS_NONE
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.add_theme_font_override("font", _font)
	item.add_theme_font_size_override("font_size", 18)
	item.add_theme_color_override("font_color", INK if orange else WHITE)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = ORANGE if orange else Color(0.06, 0.16, 0.23, 0.72)
		if state == "hover":
			style.bg_color = style.bg_color.lightened(0.13)
		elif state == "pressed":
			style.bg_color = style.bg_color.darkened(0.12)
		elif state == "disabled":
			style.bg_color = Color(0.36, 0.44, 0.50, 0.7)
		style.corner_radius_top_left = 2
		style.corner_radius_bottom_right = 12
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.border_width_bottom = 2
		style.border_color = ORANGE.lightened(0.3) if orange else BLUE
		item.add_theme_stylebox_override(state, style)
	parent.add_child(item)
	return item

func _request_action(action: String) -> void:
	if not _ko_active and not _guide_open:
		action_requested.emit(action)

func _skill(action: String, text: String, key: String, diameter: float, accent: Color = WHITE) -> SkillButton:
	var item := SkillButton.new()
	item.accent = accent
	item.size = Vector2(diameter, diameter)
	_battle.add_child(item)
	item.title = _label(item, text, 24 if diameter >= 90 else 19, accent)
	item.title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(item.title, 0, diameter * 0.29, diameter, 30)
	item.hint = _label(item, key, 12, Color(accent, 0.72))
	item.hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(item.hint, 0, diameter * 0.65, diameter, 20)
	item.held_changed.connect(func(held: bool):
		if action == "guard":
			guard_changed.emit(held)
		if held:
			_request_action(action)
	)
	_skills[action] = item
	return item

func _build_battle() -> void:
	_brand = _label(_ui, "太虚演武", 19, INK)
	var mark := _label(_brand, "VALKYRIE  /  TRAINING", 10, Color("4e788f"))
	_place(mark, 0, 27, 230, 18)
	_pause_button = _rect_button(_battle, "暂停")
	_pause_button.icon = load("res://assets/ui/hi3-icon-pause.png") as Texture2D
	_pause_button.add_theme_constant_override("icon_max_width", 17)
	_pause_button.add_theme_constant_override("h_separation", 8)
	_pause_button.pressed.connect(func(): _request_action("pause"))
	_mode_button = _rect_button(_battle, "实战对练  T")
	_mode_button.add_theme_font_size_override("font_size", 14)
	_mode_button.pressed.connect(func(): _request_action("training"))
	_battle.add_child(_enemy_panel)
	_enemy_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_name = _label(_enemy_panel, "识之律者", 21, INK)
	_place(_enemy_name, 0, 0, 220, 31)
	_enemy_tag = _label(_enemy_panel, "当前目标", 12, Color("527286"))
	_enemy_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(_enemy_tag, 260, 8, 240, 24)
	_enemy_hp.tint = Color("ef7653")
	_enemy_panel.add_child(_enemy_hp)
	_place(_enemy_hp, 0, 36, 500, 15)
	_enemy_posture.tint = ORANGE
	_enemy_panel.add_child(_enemy_posture)
	_place(_enemy_posture, 0, 57, 500, 4)
	_battle.add_child(_player_panel)
	_player_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var player_back := SlantPanel.new()
	player_back.tint = Color(0.035,0.12,0.19,0.87)
	player_back.accent = BLUE
	player_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_panel.add_child(player_back)
	_place(player_back,-15,-9,314,134)
	_player_name = _label(_player_panel, "符华", 27)
	_place(_player_name, 0, 0, 90, 39)
	_player_name.add_theme_color_override("font_shadow_color", INK)
	_player_name.add_theme_constant_override("shadow_offset_y", 1)
	_battlesuit = _label(_player_panel, "云墨丹心", 15, WHITE)
	_place(_battlesuit, 76, 12, 126, 24)
	_battlesuit.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_stance_label = _label(_player_panel, "", 14, ORANGE)
	_stance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(_stance_label, 205, 12, 69, 24)
	_stance_label.hide()
	_hp_text = _label(_player_panel, "HP  100 / 100", 13, WHITE)
	_place(_hp_text, 0, 40, 220, 24)
	_player_hp.tint = WHITE
	_player_panel.add_child(_player_hp)
	_place(_player_hp, 0, 67, 266, 11)
	_player_posture.tint = Color("ff7656")
	_player_panel.add_child(_player_posture)
	_place(_player_posture, 0, 82, 266, 4)
	_player_sp.tint = BLUE
	_player_panel.add_child(_player_sp)
	_place(_player_sp, 0, 96, 190, 6)
	_sp_text = _label(_player_panel, "SP 100", 12, BLUE)
	_place(_sp_text, 203, 88, 80, 22)
	_combo = _label(_battle, "", 43, WHITE)
	_combo.add_theme_font_override("font", _number_font)
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo.add_theme_color_override("font_shadow_color", INK)
	_combo.add_theme_constant_override("shadow_offset_y", 2)
	_skill("light", "连击", "J", 112, WHITE)
	_skill("heavy", "重击", "K", 82, WHITE)
	_skill("dodge", "闪避", "SPACE", 80, BLUE)
	_skill("guard", "格挡", "L", 76, BLUE)
	_skill("ability", "寸劲", "E", 78, Color("bceeff"))
	_skill("ultimate", "必杀", "Q · SP 100", 93, ORANGE)
	var ultimate_icon := TextureRect.new()
	ultimate_icon.texture = load("res://assets/ui/hi3-icon-skill.png") as Texture2D
	ultimate_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ultimate_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ultimate_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ultimate_icon.modulate = ORANGE
	_skills.ultimate.add_child(ultimate_icon)
	_place(ultimate_icon, 35, 14, 23, 23)
	_place(_skills.ultimate.title, 0, 36, 93, 28)
	_place(_skills.ultimate.hint, 0, 64, 93, 18)
	_left = SkillButton.new()
	_right = SkillButton.new()
	for item in [_left, _right]:
		item.size = Vector2(72, 72)
		item.accent = WHITE
		_battle.add_child(item)
		item.arrow = -1 if item == _left else 1
	_left.held_changed.connect(func(held: bool): _moving_left = held; _emit_movement())
	_right.held_changed.connect(func(held: bool): _moving_right = held; _emit_movement())
	_instruction = _label(_battle, "A / D 移动   ·   J 连击   ·   K 重击   ·   L 格挡   ·   E 寸劲   ·   空格闪避", 12, Color("d2e4ef"))
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.add_theme_color_override("font_shadow_color", Color(0.03,0.10,0.16,0.8))
	_instruction.add_theme_constant_override("shadow_offset_y", 1)

func _build_menu() -> void:
	_ui.add_child(_menu)
	_menu.tint = Color(0.055, 0.14, 0.21, 0.86)
	_menu.accent = BLUE
	var tag := _label(_menu, "VALKYRIE  /  001", 13, BLUE)
	_place(tag, 26, 20, 285, 26)
	_menu_title = _label(_menu, "符华", 58)
	_place(_menu_title, 24, 52, 300, 82)
	_menu_subtitle = _label(_menu, "云墨丹心", 24, WHITE)
	_place(_menu_subtitle, 28, 135, 285, 34)
	_menu_detail = _label(_menu, "三段旅程 · 六场战斗 · 自选强化", 14, Color("bcd5e5"))
	_menu_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_menu_detail, 28, 184, 300, 44)
	_menu_start = _rect_button(_menu, "资源载入中…", true)
	_menu_start.add_theme_font_size_override("font_size", 21)
	_place(_menu_start, 26, 250, 286, 55)
	_menu_start.disabled = true
	_menu_start.pressed.connect(_menu_primary)
	_menu_restart = _rect_button(_menu, "重新开始  R")
	_place(_menu_restart, 26, 319, 286, 37)
	_menu_restart.pressed.connect(func(): _request_action("practice" if _campaign_mode == "practice" else "restart"))
	_menu_restart.hide()
	_menu_practice = _rect_button(_menu,"与识之律者切磋")
	_place(_menu_practice,26,319,286,37)
	_menu_practice.pressed.connect(func(): _request_action("practice"))
	_menu_hint = _label(_menu, "短篇试炼   /   键鼠 · 触屏", 13, Color("9ebfd2"))
	_place(_menu_hint, 28, 373, 285, 25)
	_menu_back = _rect_button(_menu,"返回主页")
	_menu_back.add_theme_font_size_override("font_size",13)
	_place(_menu_back,26,371,286,29)
	_menu_back.pressed.connect(func(): _request_action("menu"))
	_menu_back.hide()
	_music_button = _rect_button(_menu,"音乐 开  M")
	_music_button.name = "MusicToggle"
	_music_button.add_theme_font_size_override("font_size",14)
	_place(_music_button,26,416,286,33)
	_music_button.pressed.connect(func(): _request_action("music"))
	_voice_button = _rect_button(_menu,"语音 开 V")
	_voice_button.name = "VoiceToggle"
	_voice_button.add_theme_font_size_override("font_size",14)
	_voice_button.pressed.connect(func(): _request_action("voice"))
	_menu_guide = _rect_button(_menu, "招式说明")
	_menu_guide.name = "FighterGuideEntry"
	_menu_guide.add_theme_font_size_override("font_size", 14)
	_menu_guide.pressed.connect(open_fighter_guide)
	_roster_group.name = "FighterSelection"
	_roster_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(_roster_group)
	_place(_roster_group, 26, 216, 286, 156)
	_style_caption = _label(_roster_group, "女武神装甲", 13, BLUE)
	_place(_style_caption, 0, 0, 286, 22)
	_roster_group.add_child(_armor_strip)
	_armor_strip.choice_requested.connect(func(identity: String): _select_roster("style", identity))
	_armor_previous = _rect_button(_roster_group, "<")
	_armor_previous.add_theme_font_size_override("font_size", 19)
	_armor_previous.pressed.connect(func(): _armor_strip.change_page(-1))
	_armor_next = _rect_button(_roster_group, ">")
	_armor_next.add_theme_font_size_override("font_size", 19)
	_armor_next.pressed.connect(func(): _armor_strip.change_page(1))
	_armor_strip.page_changed.connect(_update_armor_pages)
	_appearance_caption = _label(_roster_group, "外观", 13, BLUE)
	_place(_appearance_caption, 0, 79, 286, 22)
	_roster_group.hide()
	_menu_skill_summary = _label(_menu, "", 14, BLUE)
	_menu_skill_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_region.name = "FighterPreview"
	_preview_region.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_preview_region)
	_preview_hint = _label(_preview_region, "拖动旋转 · 双击复位", 14, Color("e1f1f6"))
	_preview_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_hint.add_theme_color_override("font_shadow_color", INK)
	_preview_hint.add_theme_constant_override("shadow_offset_y", 2)
	_preview_region.hide()

func _primary_enemy(data: Dictionary) -> Dictionary:
	# The encounter owns this plan; the current attack target may be a minion.
	if not data.has("enemies"):
		var foe: Dictionary = data.get("enemy", {})
		_health_display = {"primaryId":str(foe.get("id", "enemy")) if not foe.is_empty() else ""}
		return foe
	var enemies: Array = data.get("enemies", [])
	var display: Dictionary = data.get("healthDisplay", EnemyHealthDisplay.plan(enemies))
	_health_display = display
	var primary: String = str(display.get("primaryId", ""))
	if primary.is_empty():
		return {}
	for foe: Dictionary in enemies:
		if str(foe.get("id", "enemy")) == primary:
			return foe
	return {}

func _build_fighter_guide() -> void:
	_overlay(_guide_overlay)
	_guide_overlay.name = "FighterGuide"
	_guide_overlay.add_child(_guide_panel)
	_guide_panel.tint = Color(0.025, 0.085, 0.135, 0.98)
	_guide_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_guide_tag = _label(_guide_panel, "招式说明", 13, BLUE)
	_guide_title = _label(_guide_panel, "", 32, WHITE)
	_guide_summary = _label(_guide_panel, "", 16, Color("bad3e1"))
	_guide_summary.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_guide_close = _rect_button(_guide_panel, "关闭  ESC")
	_guide_close.name = "CloseFighterGuide"
	_guide_close.add_theme_font_size_override("font_size", 15)
	_guide_close.focus_mode = Control.FOCUS_ALL
	_guide_close.pressed.connect(close_fighter_guide)
	var close_focus := StyleBoxFlat.new()
	close_focus.bg_color = Color.TRANSPARENT
	close_focus.border_color = WHITE
	close_focus.set_border_width_all(2)
	_guide_close.add_theme_stylebox_override("focus", close_focus)
	_guide_panel.add_child(_guide_scroll)
	_guide_scroll.name = "GuideScroll"
	_guide_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_guide_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_guide_scroll.follow_focus = true
	_guide_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guide_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_scroll.add_child(_guide_content)
	for index in range(6):
		var card := SlantPanel.new()
		card.tint = Color("133446")
		card.accent = Color(BLUE, 0.30)
		card.name = "Move%d" % index
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_guide_content.add_child(card)
		var key := _label(card, "", 17, BLUE)
		key.name = "Key"
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var title := _label(card, "", 22)
		title.name = "Title"
		var body := _label(card, "", 16, Color("d2e5ee"))
		body.name = "Body"
		body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		var detail := _label(card, "", 12, Color("8eb8ce"))
		detail.name = "Detail"
		detail.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		_guide_cards.append(card)
	_guide_content.add_child(_guide_parry)
	_guide_parry.name = "CounterFollowup"
	_guide_parry.tint = Color("174454")
	_guide_parry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parry_title := _label(_guide_parry, "防反后，顺势接招", 19, BLUE)
	parry_title.name = "Title"
	_guide_chain = _label(_guide_parry, "", 20, WHITE)
	_guide_parry_note = _label(_guide_parry, "", 14, Color("d2e5ee"))
	_guide_tip = _label(_guide_parry, "", 14, Color("b6d0de"))
	for label: Label in [_guide_chain, _guide_parry_note, _guide_tip]:
		label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_guide_footer = _label(_guide_panel, "同一装甲的所有外观共用招式", 13, Color("8eb8ce"))
	_guide_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func open_fighter_guide() -> void:
	if _ko_active or not _ready_to_play or _phase != "menu" or _started or _paused:
		return
	_guide_open = true
	_preview_region.hide()
	_guide_overlay.show()
	_guide_scroll.scroll_vertical = 0
	# Opening immediately after resize must not depend on a later process tick.
	_layout()
	_update_fighter_guide()
	_refresh_roster_buttons()
	_update_contracts()
	_guide_close.grab_focus()

func close_fighter_guide() -> void:
	_guide_open = false
	_guide_overlay.hide()
	_guide_close.release_focus()
	_preview_region.visible = _roster_can_select()
	_refresh_roster_buttons()
	_update_contracts()

func is_guide_open() -> bool:
	return _guide_open

func _viewport_pixel_rect(control: Control) -> Rect2:
	# global_rect stops at canvas coordinates. The project stretches that canvas
	# again to the window; browser clicks and screenshots use final viewport pixels.
	return get_viewport().get_final_transform() * control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func _rect_values(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func presentation_snapshot() -> Dictionary:
	var colors: Array[String] = []
	for button: Button in _reward_buttons:
		var style: StyleBoxFlat = button.get_theme_stylebox("normal")
		colors.append(style.bg_color.to_html())
	var pixels: Rect2 = get_viewport().get_final_transform() * get_viewport().get_visible_rect()
	return {"guideOpen":_guide_open, "guideStyle":str(_fighter_identity.get("styleId", "azure_empyrea")),
		"guideEntryRect":_rect_values(_viewport_pixel_rect(_menu_guide)),
		"guideCloseRect":_rect_values(_viewport_pixel_rect(_guide_close)),
		"voiceToggleRect":_rect_values(_viewport_pixel_rect(_voice_button)),
		"guidePanelRect":_rect_values(_viewport_pixel_rect(_guide_panel)),
		"viewportSize":[pixels.size.x, pixels.size.y],
		"primaryHealthVisible":_enemy_panel.is_visible_in_tree(), "primaryHealthId":str(_health_display.get("primaryId", "")),
		"rewardCardColors":colors, "previewRect":_rect_values(preview_rect()),
		"armorChoiceRects":_choice_rects(_style_choices), "appearanceChoiceRects":_choice_rects(_appearance_choices),
		"contractChoiceRects":_choice_rects(_contract_buttons), "contractAllRect":_rect_values(_viewport_pixel_rect(_contract_all))}

func _choice_rects(buttons: Array[Button]) -> Array:
	var result: Array = []
	for button: Button in buttons:
		result.append({"id":str(button.get_meta("selection_id", "")), "rect":_rect_values(_viewport_pixel_rect(button)), "selected":bool(button.get_meta("selected", button.button_pressed))})
	return result

func handle_modal_input(event: InputEvent) -> bool:
	if not _guide_open:
		return false
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			close_fighter_guide()
		# Leave key events available to GUI focus/scroll, but never to gameplay.
		return true
	return true

func _update_fighter_guide() -> void:
	if _guide_open and (_ko_active or _phase != "menu" or _started or _paused):
		close_fighter_guide()
	if not _guide_open:
		return
	var style_id: String = str(_fighter_identity.get("styleId", "azure_empyrea"))
	if str(_guide_data.get("styleId", "")) != style_id:
		_guide_data = FighterGuide.for_style(style_id)
		_guide_tag.text = "招式说明  /  " + str(_guide_data.tag)
		_guide_title.text = str(_guide_data.name)
		_guide_summary.text = str(_guide_data.summary)
		for index in _guide_cards.size():
			var move: Dictionary = _guide_data.moves[index]
			var card: Control = _guide_cards[index]
			card.get_node("Key").text = str(move.key)
			card.get_node("Title").text = str(move.title)
			card.get_node("Body").text = str(move.body)
			card.get_node("Detail").text = str(move.detail)
		_guide_chain.text = str(_guide_data.chain)
		_guide_parry_note.text = str(_guide_data.parryNote)
		_guide_tip.text = str(_guide_data.tip)
		_layout_fighter_guide()
		_layout_fighter_guide.call_deferred()

func _fit_guide_text(label: Label, x: float, y: float, width: float, minimum: float = 0.0) -> float:
	# Ask the active TextServer, not a guessed number of Chinese characters.
	# Native and Web may choose different glyph metrics and line breaks.
	label.position = Vector2(x, y)
	label.size = Vector2(width, 1.0)
	var line_count: int = maxi(1, label.get_line_count())
	var text_height := 0.0
	for line in line_count:
		text_height += float(label.get_line_height(line))
	text_height += float(maxi(0, line_count - 1) * label.get_theme_constant("line_spacing"))
	var height: float = maxf(minimum, maxf(text_height, label.get_minimum_size().y)) + 4.0
	label.size = Vector2(width, height)
	return height

func _layout_fighter_guide() -> void:
	if not is_instance_valid(_guide_close):
		return
	# Do not shrink a phone's help text with the battle control layout.
	var canvas_scale: float = get_viewport().get_final_transform().get_scale().x
	var readable_scale: float = maxf(1.0, 0.90 / maxf(0.01, _ui.scale.x * canvas_scale))
	_guide_overlay.scale = Vector2.ONE * readable_scale
	_guide_overlay.size = _ui.size / readable_scale
	var width: float = minf(1040.0, _guide_overlay.size.x - 40.0)
	var height: float = minf(728.0, _guide_overlay.size.y - 40.0)
	_place(_guide_panel, (_guide_overlay.size.x - width) * 0.5, (_guide_overlay.size.y - height) * 0.5, width, height)
	_place(_guide_tag, 28, 15, width - 200, 24)
	_place(_guide_title, 26, 39, width - 200, 45)
	_place(_guide_close, width - 164, 22, 132, 42)
	var summary_height: float = _fit_guide_text(_guide_summary, 28, 86, width - 60, 24)
	var scroll_top: float = maxf(138.0, 86.0 + summary_height + 18.0)
	_place(_guide_scroll, 28, scroll_top, width - 56, maxf(80.0, height - scroll_top - 42.0))
	_place(_guide_footer, 28, height - 33, width - 56, 24)
	var columns: int = 2 if width >= 900.0 else 1
	var content_width: float = width - 72.0
	var card_width: float = (content_width - 14.0 * float(columns - 1)) / float(columns)
	var rows: int = ceili(float(_guide_cards.size()) / float(columns))
	var cursor_y := 0.0
	for row in rows:
		var row_height := 0.0
		for column in columns:
			var index: int = row * columns + column
			if index >= _guide_cards.size():
				break
			var card: Control = _guide_cards[index]
			_place(card.get_node("Key"), 12, 14, 72, 32)
			_place(card.get_node("Title"), 92, 12, card_width - 110, 35)
			var body_height: float = _fit_guide_text(card.get_node("Body"), 17, 55, card_width - 36, 42)
			var detail_y: float = 55.0 + body_height + 12.0
			var detail_height: float = _fit_guide_text(card.get_node("Detail"), 17, detail_y, card_width - 36, 18)
			row_height = maxf(row_height, detail_y + detail_height + 14.0)
		for column in columns:
			var index: int = row * columns + column
			if index >= _guide_cards.size():
				break
			var card: Control = _guide_cards[index]
			_place(card, float(column) * (card_width + 14.0), cursor_y, card_width, row_height)
			card.queue_redraw()
		cursor_y += row_height + 12.0
	_place(_guide_parry.get_node("Title"), 18, 13, content_width - 38, 29)
	var chain_height: float = _fit_guide_text(_guide_chain, 18, 45, content_width - 38, 28)
	var note_y: float = 45.0 + chain_height + 12.0
	var note_height: float = _fit_guide_text(_guide_parry_note, 18, note_y, content_width - 38, 22)
	var tip_y: float = note_y + note_height + 10.0
	var tip_height: float = _fit_guide_text(_guide_tip, 18, tip_y, content_width - 38, 22)
	var parry_height: float = tip_y + tip_height + 18.0
	_place(_guide_parry, 0, cursor_y, content_width, parry_height)
	_guide_content.custom_minimum_size = Vector2(0, cursor_y + parry_height + 4.0)
	_guide_content.size = Vector2(content_width, cursor_y + parry_height + 4.0)
	_guide_panel.queue_redraw()
	_guide_parry.queue_redraw()

func _build_contracts() -> void:
	_ui.add_child(_contract_panel)
	_contract_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contract_heading = _label(_contract_panel, "识境演武 · 小识的规矩", 24)
	_contract_heading.add_theme_color_override("font_shadow_color", Color("142634"))
	_contract_heading.add_theme_constant_override("shadow_offset_y", 2)
	_contract_detail = _label(_contract_panel, "", 14, Color("dcecf0"))
	_contract_detail.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_contract_detail.add_theme_color_override("font_shadow_color", Color("142634"))
	_contract_detail.add_theme_constant_override("shadow_offset_y", 1)
	_contract_all = _rect_button(_contract_panel, "全部勾选")
	_contract_all.name = "AllContracts"
	_contract_all.add_theme_font_size_override("font_size", 14)
	_contract_all.pressed.connect(func():
		if bool(_campaign.get("contractsUnlocked", false)): _select_contract("contract_all")
	)

func _select_contract(action: String) -> void:
	if _phase == "menu" and _ready_to_play and not _started and not _paused:
		_request_action(action)

func _update_contracts() -> void:
	_contract_panel.visible = _phase == "menu" and _ready_to_play and not _ko_active and not _guide_open
	if not _contract_panel.visible: return
	var options: Array = _campaign.get("contracts", [])
	var selected: Array = _campaign.get("selectedContractIds", [str(_campaign.get("contractId", "mirror"))])
	var unlocked: bool = bool(_campaign.get("contractsUnlocked", false))
	var signature := JSON.stringify([options, selected, unlocked])
	_contract_all.disabled = not unlocked or options.is_empty()
	_contract_all.text = "全部已选" if not options.is_empty() and selected.size() == options.size() else "全部勾选"
	_contract_all.tooltip_text = "勾选全部规矩，再开始试炼" if unlocked else "通关一次解锁多选"
	if signature != _contract_signature:
		_contract_signature = signature
		for button in _contract_buttons: button.free()
		_contract_buttons.clear()
		for option in options:
			var id: String = str(option.id)
			var chosen: bool = id in selected
			var button := _rect_button(_contract_panel, "", chosen)
			button.name = "Contract_" + id
			button.set_meta("selection_id", id)
			button.set_meta("selected", chosen)
			button.pressed.connect(func(): _select_contract("contract:" + id))
			var title := _label(button, ("已选 · " if chosen else "") + str(option.title), 19, INK if chosen else WHITE)
			title.name = "Title"
			var description := _label(button, str(option.get("description", "")), 14, INK if chosen else Color("c0d7e3"))
			description.name = "Description"
			description.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			_contract_buttons.append(button)
		_layout_contracts()
		_layout_contracts.call_deferred()
	if unlocked:
		_contract_detail.text = "可同时勾选 · 已选 %d 项  /  %s" % [selected.size(), str(_campaign.get("challengeDescription", "规矩越多，挑战越强"))]
	else:
		_contract_detail.text = "通关一次解锁多选 · 当前每轮选择一条规矩"

func _layout_contracts() -> void:
	var narrow: bool = _ui.size.x < 1100.0
	var x: float = 32.0 if narrow else _menu.position.x + _menu.size.x + 30.0
	var width: float = maxf(280.0, _ui.size.x - x - 32.0)
	var y: float = _menu.position.y + _menu.size.y + 24.0 if narrow else _ui.size.y - 282.0
	_place(_contract_panel, x, y, width, 250)
	_place(_contract_heading, 0, 0, width - 150, 36)
	_contract_heading.add_theme_font_size_override("font_size", 20 if width < 650.0 else 24)
	_place(_contract_all, width - 134, 0, 134, 34)
	_place(_contract_detail, 0, 42, width, 50)
	var card_width: float = (width - 20.0) / 3.0
	var row_height := 146.0
	for button: Button in _contract_buttons:
		_place(button.get_node("Title"), 14, 12, card_width - 24, 33)
		var body_height: float = _fit_guide_text(button.get_node("Description"), 14, 52, card_width - 28, 68)
		row_height = maxf(row_height, 52.0 + body_height + 14.0)
	for index in _contract_buttons.size():
		_place(_contract_buttons[index], float(index) * (card_width + 10.0), 104, card_width, row_height)
	_contract_panel.size.y = 104.0 + row_height
	_layout_preview_region()

func _layout_preview_region() -> void:
	if not is_instance_valid(_preview_hint): return
	var x: float = _menu.position.x + _menu.size.x + 26.0
	var top := 86.0
	var bottom: float = minf(_ui.size.y - 38.0, _contract_panel.position.y - 18.0)
	_place(_preview_region, x, top, maxf(0.0, _ui.size.x - x - 32.0), maxf(0.0, bottom - top))
	_place(_preview_hint, 0, 0, _preview_region.size.x, 26)

func preview_rect() -> Rect2:
	if not _roster_can_select() or not _preview_region.is_visible_in_tree():
		return Rect2()
	return _viewport_pixel_rect(_preview_region)

func _rebuild_roster_choices(options: Array, buttons: Array[Button], kind: String, y: float) -> void:
	if kind == "style":
		_armor_strip.populate(options, _font)
		buttons.assign(_armor_strip.buttons)
		_style_caption.text = "女武神装甲  /  %02d" % buttons.size()
		return
	for old in buttons:
		old.free()
	buttons.clear()
	if options.is_empty():
		return
	var columns := mini(3, options.size())
	var width: float = (344.0 - 8.0 * float(columns - 1)) / float(columns)
	for index in options.size():
		var option: Dictionary = options[index]
		var identity: String = str(option.get("id", ""))
		if identity.is_empty():
			continue
		var button := _rect_button(_roster_group, str(option.get("name", "")))
		button.name = ("StyleChoice_" if kind == "style" else "AppearanceChoice_") + identity
		button.add_theme_font_size_override("font_size", 14 if width < 100.0 or str(option.get("name", "")).length() > 6 else 16)
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.tooltip_text = str(option.get("name", ""))
		button.toggle_mode = true
		button.set_meta("selection_id", identity)
		button.pressed.connect(_select_roster.bind(kind, identity))
		_place(button, float(index % columns) * (width + 8.0), y + (index / columns) * 44.0, width, 36)
		var selected := StyleBoxFlat.new()
		selected.bg_color = Color("245568")
		selected.border_color = ORANGE
		selected.border_width_left = 3
		selected.border_width_bottom = 3
		selected.corner_radius_bottom_right = 10
		selected.content_margin_left = 9
		selected.content_margin_right = 9
		button.add_theme_stylebox_override("pressed", selected)
		button.add_theme_stylebox_override("hover_pressed", selected)
		button.add_theme_color_override("font_pressed_color", WHITE)
		buttons.append(button)

func _roster_can_select() -> bool:
	return not _ko_active and not _guide_open and _ready_to_play and _phase == "menu" and not _started and not _paused and not bool(_victory.get("visible", false)) and bool(_roster.get("canSelect", false))

func _select_roster(kind: String, identity: String) -> void:
	# Main confirms the actual model selection in the next snapshot. A click
	# must never optimistically relabel an actor that has not loaded yet.
	if not _roster_can_select():
		return
	var options: Array = _roster.get("styles" if kind == "style" else "appearances", [])
	var current: String = str(_roster.get("styleId" if kind == "style" else "appearanceId", ""))
	for option: Dictionary in options:
		if not bool(option.get("playable", true)):
			continue
		if str(option.get("id", "")) == identity:
			if identity != current:
				_request_action("select_%s:%s" % [kind, identity])
			_refresh_roster_buttons()
			return

func _refresh_roster_buttons() -> void:
	var available := _roster_can_select()
	_armor_strip.set_selection(str(_roster.get("styleId", "")), available)
	_update_armor_pages()
	for button in _appearance_choices:
		button.set_pressed_no_signal(str(button.get_meta("selection_id")) == str(_roster.get("appearanceId", "")))
		button.disabled = not available

func _update_armor_pages() -> void:
	if not is_instance_valid(_armor_previous) or not is_instance_valid(_armor_next): return
	var overflow := _armor_strip.page_count() > 1
	_armor_previous.visible = overflow
	_armor_next.visible = overflow
	_armor_previous.disabled = not _roster_can_select() or _armor_strip.page == 0
	_armor_next.disabled = not _roster_can_select() or _armor_strip.page >= _armor_strip.page_count()-1
	_style_caption.text = "女武神装甲  /  %02d" % _style_choices.size()
	if overflow: _style_caption.text += "    %d / %d" % [_armor_strip.page+1,_armor_strip.page_count()]

func _update_roster(data: Dictionary) -> void:
	_roster = data.get("roster", {})
	_fighter_identity = data.get("fighter", {})
	var styles: Array = _roster.get("styles", [])
	var appearances: Array = _roster.get("appearances", [])
	var signature := JSON.stringify([styles, appearances])
	if signature != _roster_signature:
		_roster_signature = signature
		var armor_signature := JSON.stringify(styles)
		if armor_signature != _armor_signature:
			_armor_signature = armor_signature
			_rebuild_roster_choices(styles, _style_choices, "style", 28.0)
		_rebuild_roster_choices(appearances, _appearance_choices, "appearance", 224.0)
		_layout()
	var visible_choices: bool = _menu_mode == "intro" and _phase == "menu" and not styles.is_empty() and not appearances.is_empty()
	if _roster_group.visible != visible_choices:
		_roster_group.visible = visible_choices
		_layout()
	_refresh_roster_buttons()
	_preview_region.visible = _roster_can_select()
	_menu_skill_summary.visible = _roster_group.visible
	_menu_skill_summary.text = "E  %s     /     Q  %s" % [str(_fighter_identity.get("abilityName", "寸劲")), str(_fighter_identity.get("ultimateName", "太虚之握"))]
	if _menu_mode == "intro":
		_menu_title.text = str(_fighter_identity.get("characterName", "符华"))
		_menu_subtitle.text = str(_fighter_identity.get("styleName", "云墨丹心"))
		_menu_detail.text = str(_fighter_identity.get("description", "三段旅程 · 六场战斗 · 自选强化"))
		_menu_detail.tooltip_text = _menu_detail.text
	_player_name.text = str(_fighter_identity.get("characterName", "符华"))
	_battlesuit.text = str(_fighter_identity.get("styleName", "云墨丹心"))
	_battlesuit.tooltip_text = _battlesuit.text
	var ability_name: String = str(_fighter_identity.get("abilityName", "寸劲"))
	_skills.ability.title.text = ability_name
	_instruction.text = "A / D 移动   ·   J 连击   ·   K 重击   ·   L 格挡   ·   E %s   ·   空格闪避" % ability_name
	_ultimate_title.text = str(_fighter_identity.get("ultimateName", "太虚 · 云墨"))
	_ultimate_tag.text = "ULTIMATE / AZURE EMPYREA" if str(_fighter_identity.get("styleId", "azure_empyrea")) == "azure_empyrea" else "ULTIMATE"
	var has_stances: bool = bool(_fighter_identity.get("hasStances", str(_fighter_identity.get("styleId", "")) == "fenghuang"))
	_stance_label.visible = has_stances
	var player: Dictionary = data.get("player", {})
	_stance_label.text = "腿式" if str(player.get("stance", "punch")) == "kick" else "拳式"
	_stance_label.tooltip_text = ""
	if str(_fighter_identity.get("styleId", "")) == "night_squire":
		_ultimate_tag.text = "ULTIMATE / NIGHT SQUIRE"
		_stance_label.visible = true
		var burst:=float(player.get("nightBurstRemaining",0.0))
		_stance_label.text = "爆发 %.1fs" % burst if burst>0.0 else "烈波 %d / 3" % int(player.get("nightFocus",0))
	elif str(_fighter_identity.get("styleId", "")) == "shadow_knight":
		_ultimate_tag.text = "ULTIMATE / SHADOW KNIGHT"
		_stance_label.visible = true
		var eclipse := float(player.get("eclipseRemaining",0.0))
		_stance_label.text = "月食 %ds" % ceili(eclipse) if eclipse>0.0 else "月食待机"
		_stance_label.tooltip_text = "月食中：每 3 次命中追加雷击，受击伤害降低 20%。" if eclipse>0.0 else "100 SP 时按 Q 开启月食。"
	elif str(_fighter_identity.get("styleId", "")) == "hawk_of_the_fog":
		_ultimate_tag.text = "ULTIMATE / HAWK OF THE FOG"
		_stance_label.visible = true
		_stance_label.text = "雷闪 %d/3" % clampi(int(player.get("fogCharges",0)),0,3)
		_stance_label.tooltip_text = "E 或 J 第三段命中积攒雷闪；K 消耗全部层数强化重击。"

func _overlay(parent: Control) -> void:
	parent.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(parent)
	var veil := ColorRect.new()
	veil.color = Color(0.015,0.055,0.09,0.68)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.hide()

func _build_campaign() -> void:
	_stage_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_panel.tint = Color(0.035,0.12,0.19,0.86)
	_battle.add_child(_stage_panel)
	_stage_title = _label(_stage_panel,"01 / 06  晨岚台",17,WHITE)
	_place(_stage_title,14,7,280,27)
	_stage_objective = _label(_stage_panel,"击败识律幻身",12,Color("c1dbe9"))
	_place(_stage_objective,14,37,280,24)
	for index in range(6):
		var mark := ColorRect.new()
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage_panel.add_child(mark)
		_place(mark,15+float(index)*43.0,73,36,4)
		_stage_marks.append(mark)
	_stage_boons = _label(_stage_panel,"",11,Color("86cce6"))
	_stage_boons.mouse_filter = Control.MOUSE_FILTER_PASS
	_place(_stage_boons,14,84,270,20)
	_stage_banner.tint = Color(0.035,0.11,0.18,0.91)
	_stage_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_stage_banner)
	_banner_title = _label(_stage_banner,"",25,WHITE)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_banner_title,18,6,524,34)
	_banner_detail = _label(_stage_banner,"",13,Color("aed9ed"))
	_banner_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_banner_detail,18,43,524,25)
	_stage_banner.hide()
	_build_rewards()
	_build_results()

func _build_rewards() -> void:
	_overlay(_reward_overlay)
	_reward_overlay.name = "RewardSelection"
	_reward_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward_overlay.add_child(_reward_group)
	_reward_title = _label(_reward_group,"领悟新招",35,WHITE)
	_reward_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_reward_title,0,0,1000,55)
	_reward_subtitle = _label(_reward_group,"选择一项强化，继续下一战",16,Color("c0dceb"))
	_reward_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_reward_subtitle,0,58,1000,31)
	for index in range(3):
		var button := _rect_button(_reward_group,"")
		button.name = "RewardChoice%d" % index
		button.focus_mode = Control.FOCUS_ALL
		_place(button,10+float(index)*335.0,116,310,282)
		for state in ["normal","hover","pressed","disabled","focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("173748")
			style.corner_radius_bottom_right = 22
			style.border_width_left = 3
			style.border_width_top = 2
			style.border_color = BLUE
			if state == "hover":
				style.bg_color = Color("23556c")
			elif state == "pressed":
				style.bg_color = Color("123043")
			elif state == "disabled":
				style.bg_color = Color("20313c")
			elif state == "focus":
				style.bg_color = Color.TRANSPARENT
				style.border_color = WHITE
				style.set_border_width_all(2)
			button.add_theme_stylebox_override(state,style)
		var number := _label(button,"强化 0%d" % (index+1),13,BLUE)
		_place(number,25,20,260,25)
		var title := _label(button,"",25,WHITE)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_place(title,25,60,260,64)
		var description := _label(button,"",16,Color("c5deeb"))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_place(description,25,133,260,85)
		var choose := _label(button,"选择强化  %d" % (index+1),16,BLUE)
		_place(choose,25,237,260,28)
		button.pressed.connect(_choose_reward.bind(index))
		_reward_buttons.append(button)
		_reward_names.append(title)
		_reward_descriptions.append(description)
	_reward_boons = _label(_reward_group,"",13,Color("9bbfd3"))
	_reward_boons.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_boons.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_reward_boons,35,424,930,64)

func _build_results() -> void:
	# The left half remains transparent so the winner shares the result screen.
	_result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(_result_overlay)
	_result_overlay.hide()
	_result_overlay.name = "TrialResults"
	_result_overlay.add_child(_result_panel)
	_result_panel.name = "VictoryResultsPanel"
	_result_panel.tint = Color(0.025,0.095,0.15,0.93)
	_result_panel.accent = ORANGE
	_result_tag = _label(_result_panel,"TRIAL COMPLETE",14,BLUE)
	_place(_result_tag,28,18,500,24)
	_result_title = _label(_result_panel,"太虚试炼完成",30,WHITE)
	_place(_result_title,28,47,504,43)
	_result_detail = _label(_result_panel,"六战已过，寸心不改",17,Color("b9d7e8"))
	_place(_result_detail,30,94,500,27)
	_result_rank = _label(_result_panel,"S",84,ORANGE)
	_result_rank.add_theme_font_override("font",_number_font)
	_result_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_result_rank,28,124,156,99)
	var rank_label := _label(_result_panel,"战斗评级",16,Color("bfd7e5"))
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(rank_label,28,216,156,25)
	var score_label := _label(_result_panel,"本轮得分",16,Color("92b5ca"))
	_place(score_label,222,143,296,25)
	_result_score = _label(_result_panel,"00000 分",37,WHITE)
	_result_score.add_theme_font_override("font",_number_font)
	_place(_result_score,222,174,296,53)
	var divider := ColorRect.new()
	divider.color = Color(BLUE,0.22)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_panel.add_child(divider)
	_place(divider,28,250,504,1)
	var names: Array[String] = ["击破对手","极限防御","最高连击","承受伤害","完成用时","获得强化"]
	for index in range(6):
		var x: float = 30.0 + float(index%3)*170.0
		var y: float = 265.0 + float(index/3)*68.0
		var key := _label(_result_panel,names[index],17,Color("a8c7d9"))
		_place(key,x,y,155,24)
		var value := _label(_result_panel,"0",28,WHITE)
		value.add_theme_font_override("font",_number_font)
		_place(value,x,y+24,155,37)
		_result_values.append(value)
	_result_boons = _label(_result_panel,"",15,Color("a9c8da"))
	_result_boons.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_boons.mouse_filter = Control.MOUSE_FILTER_PASS
	_result_boons.max_lines_visible = 2
	_result_boons.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place(_result_boons,30,402,500,40)
	_result_again = _rect_button(_result_panel,"再次试炼  ENTER",true)
	_result_again.name = "VictoryAgain"
	_place(_result_again,28,451,246,50)
	_result_again.pressed.connect(func(): _request_action("practice" if _campaign_mode == "practice" else "restart"))
	_result_secondary = _rect_button(_result_panel,"自由对练")
	_result_secondary.name = "VictoryOtherMode"
	_place(_result_secondary,288,451,244,50)
	_result_secondary.pressed.connect(func(): _request_action("trial" if _campaign_mode == "practice" else "practice"))
	var back := _rect_button(_result_panel,"返回主页")
	back.name = "VictoryMenu"
	back.add_theme_font_size_override("font_size",16)
	_place(back,28,515,246,35)
	back.pressed.connect(func(): _request_action("menu"))
	_result_replay = _rect_button(_result_panel,"重播演出")
	_result_replay.name = "VictoryReplay"
	_result_replay.add_theme_font_size_override("font_size",16)
	_place(_result_replay,288,515,244,35)
	_result_replay.pressed.connect(func(): _request_action("victory_replay"))

func _build_victory() -> void:
	_victory_overlay.name = "VictoryPresentation"
	_victory_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_victory_overlay)
	_victory_overlay.add_child(_victory_heading)
	_victory_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _label(_victory_heading,"VICTORY",68,WHITE)
	title.add_theme_font_override("font",_number_font)
	title.add_theme_color_override("font_shadow_color",Color(INK,0.7))
	title.add_theme_constant_override("shadow_offset_y",2)
	_place(title,0,0,460,90)
	var subtitle := _label(_victory_heading,"胜利  /  寸心不改",22,ORANGE)
	subtitle.add_theme_color_override("font_shadow_color",Color(INK,0.9))
	subtitle.add_theme_constant_override("shadow_offset_y",2)
	_place(subtitle,3,89,450,34)
	_victory_overlay.add_child(_victory_identity)
	_victory_identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var identity_line := ColorRect.new()
	identity_line.color = ORANGE
	identity_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_victory_identity.add_child(identity_line)
	_place(identity_line,0,8,4,115)
	_victory_name = _label(_victory_identity,"符华",54,WHITE)
	_place(_victory_name,19,0,450,74)
	_victory_style = _label(_victory_identity,"云墨丹心",24,WHITE)
	_place(_victory_style,22,76,450,35)
	_victory_skin = _label(_victory_identity,"装束  /  默认",16,Color("c2dbe8"))
	_place(_victory_skin,23,116,450,27)
	for item in [_victory_name,_victory_style,_victory_skin]:
		item.add_theme_color_override("font_shadow_color",Color(INK,0.9))
		item.add_theme_constant_override("shadow_offset_y",2)
	_victory_music = _rect_button(_victory_overlay,"音乐 开  M")
	_victory_music.name = "VictoryMusic"
	_victory_music.pressed.connect(func(): _request_action("music"))
	_victory_voice = _rect_button(_victory_overlay,"语音 开 V")
	_victory_voice.name = "VictoryVoice"
	_victory_voice.pressed.connect(func(): _request_action("voice"))
	_victory_skip = _rect_button(_victory_overlay,"跳过演出  ENTER")
	_victory_skip.name = "VictorySkip"
	_victory_skip.pressed.connect(func(): _request_action("victory_skip"))
	_victory_overlay.add_child(_victory_pause_panel)
	_victory_pause_panel.name = "VictoryPaused"
	_victory_pause_panel.tint = Color(0.025,0.095,0.15,0.95)
	_victory_pause_panel.accent = ORANGE
	var pause_title := _label(_victory_pause_panel,"演出已暂停",28,WHITE)
	_place(pause_title,24,17,320,42)
	var pause_hint := _label(_victory_pause_panel,"继续欣赏胜利姿态",17,Color("b9d7e8"))
	_place(pause_hint,25,66,320,28)
	var resume := _rect_button(_victory_pause_panel,"继续演出  ESC",true)
	resume.name = "VictoryResume"
	_place(resume,24,116,312,48)
	resume.pressed.connect(func(): _request_action("victory_pause"))
	_victory_overlay.hide()

func _choose_reward(index: int) -> void:
	if _ko_active or _guide_open or _paused or _reward_locked or _phase != "reward":
		return
	_reward_locked = true
	for button in _reward_buttons:
		button.disabled = true
	_request_action("reward_%d" % index)

func _build_cinematic() -> void:
	_cinematic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_cinematic)
	for band in [_cinematic_top,_cinematic_bottom]:
		band.color = Color(0.02,0.055,0.085,0.94)
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cinematic.add_child(band)
	_ultimate_title = _label(_cinematic,"太虚 · 云墨",29,WHITE)
	_ultimate_tag = _label(_cinematic,"ULTIMATE / AZURE EMPYREA",11,BLUE)
	_cinematic.hide()

func _emit_movement() -> void:
	move_changed.emit(float(_moving_right) - float(_moving_left))

func _menu_primary() -> void:
	if _ko_active or _guide_open or not _ready_to_play:
		return
	if _paused:
		_request_action("pause")
	elif _phase == "failed" and _campaign_mode == "trial":
		_request_action("retry")
	elif _campaign_mode == "practice" and _ended:
		_request_action("practice")
	elif _phase == "cleared" or _ended:
		_request_action("restart")
	else:
		_request_action("start")

func _layout() -> void:
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_last_size = viewport
	_last_render_size = (get_viewport().get_final_transform() * get_viewport().get_visible_rect()).size
	var ui_scale: float = clampf(minf(viewport.x / 1280.0, viewport.y / 800.0), 0.45, 1.7)
	_ui.scale = Vector2.ONE * ui_scale
	_ui.size = viewport / ui_scale
	_battle.size = _ui.size
	var w: float = _ui.size.x
	var h: float = _ui.size.y
	_place(_brand, 32, 25, 230, 31)
	_place(_pause_button, w - 130, 27, 100, 39)
	_place(_mode_button, w - 170, 79, 140, 33)
	_place(_enemy_panel, (w - 500) * 0.5, 29, 500, 65)
	_place(_stage_panel,26,24,300,111)
	_place(_player_panel, 36, h - 154, 290, 120)
	_place(_left, 38, h - 248, 72, 72)
	_place(_right, 124, h - 248, 72, 72)
	_place(_skills.light, w - 176, h - 164, 112, 112)
	_place(_skills.heavy, w - 271, h - 194, 82, 82)
	_place(_skills.dodge, w - 267, h - 99, 80, 80)
	_place(_skills.guard, w - 87, h - 245, 76, 76)
	_place(_skills.ultimate, w - 193, h - 280, 93, 93)
	_place(_skills.ability,w-284,h-287,78,78)
	_place(_combo, w - 260, 138, 220, 62)
	_place(_instruction, (w - 650) * 0.5, h - 27, 650, 22)
	_instruction.visible = w > 1100
	var selecting: bool = _menu_mode == "intro" and _roster_group.visible
	var appearance_columns := mini(3, maxi(1, _appearance_choices.size()))
	var appearance_rows := maxi(1, ceili(float(_appearance_choices.size()) / appearance_columns))
	var roster_height := 278.0 + appearance_rows * 44.0 - 8.0
	var start_y := 202.0 + roster_height + 10.0
	var menu_height: float = start_y + 201.0 if selecting else 468.0
	var inner_width: float = 344.0 if selecting else 286.0
	_place(_menu, maxf(24.0, w * 0.045), maxf(12.0 if selecting else 110.0, (h - menu_height) * 0.5), 396 if selecting else 346, menu_height)
	_place(_menu_title, 24, 46 if selecting else 52, inner_width, 42 if selecting else 82)
	_menu_title.add_theme_font_size_override("font_size", 36 if selecting else (58 if _menu_mode == "intro" else 42))
	_place(_menu_subtitle, 28, 92 if selecting else 135, inner_width, 30 if selecting else 34)
	_place(_menu_detail, 28, 128 if selecting else 184, inner_width, 34 if selecting else 44)
	_menu_detail.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_menu_detail.max_lines_visible = 2
	_menu_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place(_menu_skill_summary, 28, 168, inner_width, 22)
	_place(_roster_group, 26, 202, 344, roster_height)
	_place(_style_caption, 0, 0, 270, 24)
	_place(_armor_previous, 284, -2, 28, 27)
	_place(_armor_next, 316, -2, 28, 27)
	_place(_armor_strip, 0, 28, 344, 216)
	_place(_appearance_caption, 0, 250, 344, 22)
	var appearance_width := (344.0-8.0*(appearance_columns-1))/appearance_columns
	for index in _appearance_choices.size():
		_place(_appearance_choices[index], (index % appearance_columns)*(appearance_width+8.0), 278.0+(index / appearance_columns)*44.0, appearance_width, 36)
	_place(_menu_start, 26, start_y if selecting else 250, inner_width, 50 if selecting else 55)
	_place(_menu_practice, 26, start_y+62.0 if selecting else 319, inner_width, 37)
	var guide_entry: bool = _menu_mode == "intro" and not _ko_active
	_menu_guide.visible = guide_entry
	_menu_guide.disabled = not _ready_to_play
	var small_width: float = 108.0 if selecting else 90.0
	_place(_music_button, 26, start_y+113.0 if selecting else 416, small_width if guide_entry else 139, 33)
	_place(_voice_button, 144 if selecting else (122 if guide_entry else 173), start_y+113.0 if selecting else 416, small_width if guide_entry else 139, 33)
	_place(_menu_guide, 262 if selecting else 218, start_y+113.0 if selecting else 416, 108 if selecting else 94, 33)
	_place(_menu_hint, 28, start_y+158.0 if selecting else 373, inner_width, 25)
	# Leave the enlarged battle silhouettes clear below the status strip.
	_place(_notice, (w - 620) * 0.5, maxf(112.0, h * 0.145), 620, 55)
	_cinematic.size = _ui.size
	_place(_cinematic_top,0,0,w,32)
	_place(_cinematic_bottom,0,h-70,w,70)
	_place(_ultimate_title,42,h-65,420,40)
	_place(_ultimate_tag,44,h-27,420,18)
	_place(_stage_banner,(w-560)*0.5,108,560,76)
	_reward_overlay.size = _ui.size
	var reward_scale: float = minf(1.0,(w-50.0)/1000.0)
	_reward_group.scale = Vector2.ONE * reward_scale
	_place(_reward_group,(w-1000.0*reward_scale)*0.5,(h-490.0*reward_scale)*0.5,1000,490)
	_result_overlay.size = _ui.size
	var result_scale: float = minf(1.0,minf((w-60.0)/560.0,(h-120.0)/570.0))
	_result_panel.scale = Vector2.ONE * result_scale
	_place(_result_panel,w-40.0-560.0*result_scale,(h-570.0*result_scale)*0.5+12.0,560,570)
	_victory_overlay.size = _ui.size
	_place(_victory_heading,46,30,470,126)
	_place(_victory_identity,46,h-196,490,149)
	_place(_victory_music,w-210,30,170,42)
	_place(_victory_voice,w-210,82,170,42)
	_place(_victory_skip,w-310,h-98,270,54)
	_place(_victory_pause_panel,w-400,(h-192)*0.5,360,192)
	_menu.queue_redraw()
	_stage_panel.queue_redraw()
	_stage_banner.queue_redraw()
	_result_panel.queue_redraw()
	_victory_pause_panel.queue_redraw()
	_layout_contracts()
	_layout_fighter_guide()
	# Wrapped Label minimum sizes settle after their width changes. A second
	# layout prevents a previous narrow-screen height leaking into wider cards.
	if _guide_open:
		_layout_fighter_guide.call_deferred()

func _set_menu(mode: String, winner: String) -> void:
	if _menu_mode == mode:
		return
	_menu_mode = mode
	_menu.visible = mode != ""
	_menu_restart.visible = mode in ["pause","failed"]
	_menu_practice.visible = mode == "intro"
	_menu_hint.visible = mode == "intro"
	_menu_back.visible = mode in ["pause","failed","practice_end"]
	if mode != "intro":
		_roster_group.hide()
	if mode == "intro":
		_menu_title.text = "符华"
		_menu_subtitle.text = "云墨丹心"
		_menu_detail.text = "三段旅程 · 六场战斗 · 自选强化"
		_menu_start.text = "开始试炼  ENTER" if _ready_to_play else "资源载入中…"
	elif mode == "pause":
		_menu_title.text = "对练暂停" if _campaign_mode == "practice" else "试炼暂停"
		_menu_title.add_theme_font_size_override("font_size", 42)
		_menu_subtitle.text = "调整呼吸，再战一轮"
		_menu_detail.text = "ESC 继续当前战斗"
		_menu_start.text = "继续战斗  ESC"
		_menu_restart.text = "重新对练" if _campaign_mode == "practice" else "重开试炼  R"
	elif mode == "failed":
		_menu_title.text = "试炼中断"
		_menu_title.add_theme_font_size_override("font_size",42)
		_menu_subtitle.text = "第 %02d 战  %s" % [int(_campaign.get("stageIndex",0))+1,str(_campaign.get("region","太虚试炼"))]
		_menu_subtitle.add_theme_font_size_override("font_size",19)
		_menu_detail.text = "调整出手节奏，再挑战一次"
		_menu_start.text = "重试当前战  ENTER"
		_menu_restart.text = "重新开始  R"
	elif mode == "practice_end":
		_menu_title.text = "训练完成" if winner == "player" else "胜负已分"
		_menu_title.add_theme_font_size_override("font_size", 42)
		_menu_subtitle.text = "寸心如墨 · 拳意不息"
		_menu_detail.text = "寻找更好的出手时机"
		_menu_start.text = "再来一轮  ENTER"
	if mode == "intro":
		_menu_title.add_theme_font_size_override("font_size", 58)
	if mode != "failed":
		_menu_subtitle.add_theme_font_size_override("font_size",24)
	_layout()

func set_ready(ready: bool) -> void:
	_ready_to_play = ready
	if is_instance_valid(_menu_start):
		_menu_start.disabled = not ready
		_menu_practice.disabled = not ready
		if _menu_mode == "intro":
			_menu_start.text = "开始试炼  ENTER" if ready else "资源载入中…"
	_refresh_roster_buttons()

func update_status(data: Dictionary) -> void:
	_ko_active = bool(data.get("ko", {}).get("active", false))
	_started = bool(data.get("started", false))
	_victory = data.get("victory",{})
	var showing_victory: bool = bool(_victory.get("visible",false))
	_paused = bool(data.get("paused", false)) or (showing_victory and bool(_victory.get("paused",false)))
	_ended = bool(data.get("ended", false))
	_campaign = data.get("campaign",{})
	_campaign_mode = str(_campaign.get("mode","practice"))
	_phase = str(_campaign.get("phase","fight" if _started else "menu"))
	var music_state: Dictionary = data.get("music",{})
	_music_button.text = "音乐 开  M" if bool(music_state.get("enabled",true)) else "音乐 关  M"
	_victory_music.text = _music_button.text
	var voice_state: Dictionary = data.get("voice",{})
	_voice_button.text = "语音 开 V" if bool(voice_state.get("enabled",true)) else "语音 关 V"
	_victory_voice.text = _voice_button.text
	var ultimate: bool = bool(data.get("ultimate", false))
	var player: Dictionary = data.get("player", {})
	var enemy: Dictionary = _primary_enemy(data)
	var hp: float = float(player.get("hp", 100.0))
	var max_hp: float = maxf(1.0,float(player.get("maxHp",100.0)))
	var enemy_max_hp: float = maxf(1.0,float(enemy.get("maxHp",100.0)))
	var energy: float = float(player.get("energy", 0.0))
	_player_hp.set_amount(hp/max_hp*100.0)
	_player_sp.set_amount(energy)
	_player_posture.set_amount(float(player.get("posture", 0.0)))
	_enemy_hp.set_amount(float(enemy.get("hp", 100.0))/enemy_max_hp*100.0)
	_enemy_posture.set_amount(float(enemy.get("posture", 0.0)))
	_hp_text.text = "HP  %03d / %03d" % [roundi(hp),roundi(max_hp)]
	_sp_text.text = "SP %03d" % roundi(energy)
	var combo: int = int(data.get("combo", 0))
	_combo.text = "%02d  连击" % combo if combo > 1 else ""
	_mode_button.text = "木人练习  T" if bool(data.get("training", false)) else "实战对练  T"
	_mode_button.visible = _campaign_mode == "practice" and _phase == "fight"
	var enemy_kind: String = str(enemy.get("type",""))
	var boss: bool = bool(enemy.get("boss",false)) or enemy_kind == "boss"
	var elite: bool = bool(enemy.get("elite",false)) or enemy_kind == "elite"
	_enemy_name.text = str(enemy.get("label",enemy.get("name","识之律者")))
	_enemy_tag.text = "首领" if boss else ("精英" if elite else "当前目标")
	if str(enemy.get("style",""))=="sentience":
		_enemy_tag.text=SentienceCombat.LABELS.get(str(enemy.get("weapon","sword")),"识之律者")
	var dusk_region: bool = int(_campaign.get("regionIndex",0)) == 2
	_enemy_name.add_theme_color_override("font_color",Color("fff2db") if dusk_region else INK)
	_enemy_tag.add_theme_color_override("font_color",Color("d3e9f1") if dusk_region else Color("527286"))
	if bool(data.get("training",false)) and _campaign_mode == "practice":
		_enemy_tag.text = "木人练习"
	_enemy_hp.tint = ORANGE if boss else (Color("ff915e") if elite else Color("ef7653"))
	_enemy_hp.queue_redraw()
	var in_fight: bool = _phase == "fight"
	_battle.visible = _started and in_fight and not ultimate and not showing_victory and not _ko_active
	_enemy_panel.visible = not enemy.is_empty() and not _ko_active
	_cinematic.visible = ultimate and not _paused and not showing_victory
	var ultimate_time: float = float(data.get("ultimateTime",0.0))
	var title_alpha: float = clampf((0.80-ultimate_time)/0.25,0.0,1.0)
	_ultimate_title.modulate.a = title_alpha
	_ultimate_tag.modulate.a = title_alpha
	_notice.visible = in_fight and not ultimate and not _paused and _banner_time < 0.3 and not showing_victory
	_brand.visible = not ultimate and not _started and not showing_victory and not (_menu_mode == "intro" and _roster_group.visible)
	var cooldown: float = maxf(0.0,float(player.get("skillCooldown",0.0)))
	if cooldown <= 0.0:
		_cooldown_max = 1.0
	else:
		_cooldown_max = maxf(_cooldown_max,cooldown)
	var cooldown_duration: float = maxf(0.01,float(player.get("skillCooldownMax",_cooldown_max)))
	_skills.ability.set_cooldown(cooldown/cooldown_duration)
	_skills.ability.hint.text = "E / %.1fs" % cooldown if cooldown > 0.05 else "E"
	var can_act: bool = not _ko_active and not _guide_open and _started and in_fight and not _paused and not _ended and not ultimate and not showing_victory and float(data.get("stageCountdown",0.0))<=0.0
	for action in _skills:
		var skill: SkillButton = _skills[action]
		var available: bool = (action != "ultimate" or energy >= 100.0) and (action != "ability" or cooldown <= 0.01)
		skill.set_enabled(can_act and available)
	_left.set_enabled(can_act)
	_right.set_enabled(can_act)
	_mode_button.disabled = _paused or _ended or ultimate
	_pause_button.disabled = _ended
	_update_campaign(ultimate)
	_update_victory(data)
	if showing_victory or _ko_active:
		_set_menu("", "")
	elif _paused:
		_set_menu("pause", "")
	elif _phase == "failed" and _campaign_mode == "trial":
		_set_menu("failed", "")
	elif _phase == "menu" or not _started:
		_set_menu("intro", "")
	elif _ended and _campaign_mode == "practice" and _phase in ["cleared","failed"]:
		_set_menu("practice_end",str(data.get("winner","")))
	else:
		_set_menu("", "")
	_update_roster(data)
	_update_contracts()
	_update_fighter_guide()
	if _ko_active:
		for overlay: Control in [_cinematic, _stage_panel, _stage_banner, _reward_overlay, _result_overlay, _victory_overlay, _notice, _brand]:
			overlay.hide()
	_previous_phase = _phase

func _update_victory(data: Dictionary) -> void:
	var showing: bool = bool(_victory.get("visible",false))
	var playing: bool = bool(_victory.get("playing",false))
	var presentation_paused: bool = bool(_victory.get("paused",false))
	_victory_overlay.visible = showing
	# While the results are open, only the chrome's actual buttons intercept input.
	_victory_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if playing or presentation_paused else Control.MOUSE_FILTER_IGNORE
	_victory_skip.visible = playing and not presentation_paused
	_victory_pause_panel.visible = showing and presentation_paused
	_result_replay.visible = showing
	if not showing:
		return
	var fighter: Dictionary = data.get("fighter",{})
	_victory_name.text = str(fighter.get("characterName","符华"))
	_victory_style.text = str(fighter.get("styleName","云墨丹心"))
	_victory_skin.text = "装束  /  %s" % str(fighter.get("skinName","默认"))
	# State is supplied by main; no UI timer can advance through pause or a replay.
	_victory_overlay.set_meta("presentation_time",float(_victory.get("time",0.0)))
	_victory_overlay.set_meta("presentation_duration",float(_victory.get("duration",4.4)))
	_victory_overlay.set_meta("presentation_shot",str(_victory.get("shot","")))
	_stage_banner.hide()
	_reward_overlay.hide()
	_result_overlay.visible = not playing and not presentation_paused

func _boon_names() -> PackedStringArray:
	var names := PackedStringArray()
	for boon in _campaign.get("boons",[]):
		names.append(str(boon))
	return names

func _update_campaign(ultimate: bool) -> void:
	var stage: int = int(_campaign.get("stageIndex",0))
	var total: int = maxi(1,int(_campaign.get("stageTotal",6)))
	var region: String = str(_campaign.get("region","太虚试炼"))
	var title: String = str(_campaign.get("title",region))
	var boons: PackedStringArray = _boon_names()
	var best_score: int = int(_campaign.get("bestScore",0))
	_menu_hint.text = "最佳 %s / %d 分" % [str(_campaign.get("bestRank","")),best_score] if best_score > 0 else "短篇试炼   /   键鼠 · 触屏"
	_stage_panel.visible = _started and _phase == "fight"
	if _campaign_mode == "trial":
		_stage_title.text = "%02d / %02d  %s" % [stage+1,total,region]
		_stage_objective.text = "击败识之律者" if stage==total-1 else "击破幻身   剩余 %d / %d" % [int(_campaign.get("enemiesRemaining",1)),int(_campaign.get("totalEnemies",1))]
		var objective: Dictionary=_campaign.get("objective",{})
		var items: Array = objective.get("items", [])
		if items.size() > 1:
			var progress: PackedStringArray = []
			for item: Dictionary in items:
				var label: String = {"mirror":"防反", "flow":"闪避", "breaker":"连击"}.get(str(item.get("id", "")), "考验")
				progress.append("%s %d/%d" % [label, int(item.get("progress", 0)), int(item.get("target", 1))])
			_stage_boons.text = " · ".join(progress)
		else:
			_stage_boons.text = "%s %d/%d%s" % [str(objective.get("title","小识的考验")),int(objective.get("progress",0)),int(objective.get("target",1))," 已达成" if objective.get("complete",false) else ""]
		_stage_boons.tooltip_text = str(objective.get("title", "")) + "\n" + str(objective.get("bonus", ""))
	else:
		_stage_title.text = "自由对练"
		_stage_objective.text = "练习连击、格挡与闪避"
		_stage_boons.text = "T 切换木人练习"
	for index in range(_stage_marks.size()):
		var mark: ColorRect = _stage_marks[index]
		mark.visible = _campaign_mode == "trial" and index < total
		mark.color = BLUE if index < stage else (ORANGE if index == stage else Color(0.29,0.46,0.56,0.52))
	if _phase == "fight" and (stage != _last_stage_index or _previous_phase != "fight"):
		_last_stage_index = stage
		_banner_time = 2.1
		_banner_title.text = "%s / %s" % [region,title] if _campaign_mode == "trial" else "自由对练"
		_banner_detail.text = str(_campaign.get("brief","击破识律幻身，向下一站前进")) if _campaign_mode == "trial" else "切磋对手 · 识之律者"
	_stage_banner.visible = _phase == "fight" and not _paused and not ultimate and _banner_time > 0.0
	_reward_overlay.visible = _phase == "reward" and not _paused
	_result_overlay.visible = _phase == "cleared" and _campaign_mode == "trial" and not _paused and not bool(_victory.get("playing",false))
	if _phase == "reward":
		var rewards: Array = _campaign.get("rewards",[])
		var signature: String = JSON.stringify(rewards)
		if signature != _reward_signature or _previous_phase != "reward":
			_reward_signature = signature
			_reward_locked = false
			_reward_title.text = "第 %02d 战完成" % (stage+1)
			_reward_subtitle.text = "选好这一招，听听小识怎么说。" + str(_campaign.get("supply",""))
			var achievement: Dictionary=_campaign.get("lastAchievement",{})
			if not achievement.is_empty(): _reward_subtitle.text="考验达成，额外补给已领取。选好下一招，听听小识怎么说。"
			for index in range(_reward_buttons.size()):
				var present: bool = index < rewards.size()
				_reward_buttons[index].release_focus()
				_reward_buttons[index].visible = present
				_reward_buttons[index].disabled = not present
				if present:
					var reward: Dictionary = rewards[index]
					_reward_names[index].text = str(reward.get("title","强化"))
					_reward_descriptions[index].text = str(reward.get("description",""))
			_reward_boons.text = "已获强化：" + " / ".join(boons) if not boons.is_empty() else "每次领悟，都会影响接下来的战斗"
	else:
		_reward_locked = false
	if _phase == "cleared" or bool(_victory.get("visible",false)):
		var practice: bool = _campaign_mode == "practice"
		_result_tag.text = "PRACTICE COMPLETE" if practice else "TRIAL COMPLETE"
		_result_title.text = "自由对练完成" if practice else "太虚试炼完成"
		_result_detail.text = "拳意不息，再进一步" if practice else "%s · 完成 %d 项考验" % [str(_campaign.get("contract",{}).get("title","识境演武")),_campaign.get("achievements",[]).size()]
		if not practice and not str(_campaign.get("storyRoute","")).is_empty():
			_result_detail.text="%s · %s · 考验 %d" % [str(_campaign.storyRoute),str(_campaign.get("contract",{}).get("title","")),_campaign.get("achievements",[]).size()]
		_result_again.text = "再来一轮  ENTER" if practice else "再次试炼  ENTER"
		_result_secondary.text = "开始试炼" if practice else "自由对练"
		var stats: Dictionary = _campaign.get("stats",{})
		_result_rank.text = str(stats.get("rank","A"))
		_result_score.text = "%05d 分" % int(stats.get("score",0))
		var elapsed: int = maxi(0,int(stats.get("elapsed",0)))
		var values: Array[String] = [str(int(stats.get("kills",0))),str(int(stats.get("parries",0))),str(int(stats.get("maxCombo",0))),str(roundi(float(stats.get("damageTaken",0)))),"%02d:%02d" % [elapsed/60,elapsed%60],str(boons.size())]
		for index in range(_result_values.size()):
			_result_values[index].text = values[index]
		_result_boons.text = "本轮强化：" + " / ".join(boons) if not boons.is_empty() else ("自由对练 · 继续磨炼出手与防御时机" if practice else "本轮未获得强化")
		if not practice:
			var titles: Array=_campaign.get("unlockedTitles",[])
			if not titles.is_empty(): _result_boons.text+="\n识境称号："+" / ".join(PackedStringArray(titles))
		_result_boons.tooltip_text = _result_boons.text

func notify_text(text: String) -> void:
	if not is_instance_valid(_notice):
		return
	_notice.text = text
	_notice_time = 1.5
	_notice.modulate.a = 1.0

func _process(delta: float) -> void:
	if get_viewport().get_visible_rect().size != _last_size or (get_viewport().get_final_transform() * get_viewport().get_visible_rect()).size != _last_render_size:
		_layout()
	if not _paused: _notice_time = maxf(0.0, _notice_time - delta)
	_notice.modulate.a = clampf(_notice_time / 0.25, 0.0, 1.0)
	if not _paused:
		_banner_time = maxf(0.0,_banner_time-delta)
	_stage_banner.modulate.a = clampf(_banner_time/0.4,0.0,1.0)
