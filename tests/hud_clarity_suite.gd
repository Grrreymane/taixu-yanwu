extends SceneTree

const HUD = preload("res://scripts/hud.gd")
const Guide = preload("res://scripts/fighter_guide.gd")
const Combat = preload("res://scripts/combat.gd")
const HealthDisplay = preload("res://scripts/enemy_health_display.gd")
var checks := 0
var failures: Array[String] = []
var actions: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _state() -> Dictionary:
	return {"started":false, "paused":false, "ended":false, "ko":{"active":false},
		"player":{"hp":100.0, "energy":100.0}, "enemy":{}, "enemies":[],
		"campaign":{"phase":"menu", "mode":"trial"}, "victory":{},
		"fighter":{"styleId":"azure_empyrea", "styleName":"云墨丹心", "skinName":"原装"}}

func _run() -> void:
	var hud = HUD.new()
	hud.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(hud)
	hud.action_requested.connect(func(action: String): actions.append(action))
	hud.set_ready(true)
	var state := _state()
	hud.update_status(state)
	_check(hud._menu_guide.visible and hud._menu_guide.text == "招式说明", "home exposes a separate guide entry")
	root.size = Vector2i(960, 540)
	await process_frame
	# HUD processing is disabled like the native capture fixture. Opening must
	# itself refresh an old canvas layout after a change in aspect ratio.
	hud.open_fighter_guide()
	await process_frame
	var resized: Dictionary = hud.presentation_snapshot()
	_check(absf(float(resized.guidePanelRect[0]) + float(resized.guidePanelRect[2]) * 0.5 - 480.0) < 0.1, "open after resize centers in final viewport pixels without a process tick")
	hud.close_fighter_guide()
	for visual_state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var baseline: StyleBoxFlat = hud._reward_buttons[0].get_theme_stylebox(visual_state)
		for button: Button in hud._reward_buttons:
			var style: StyleBoxFlat = button.get_theme_stylebox(visual_state)
			_check(style.bg_color == baseline.bg_color and style.border_color == baseline.border_color and style.border_width_left == baseline.border_width_left, "all reward choices share " + visual_state + " treatment")
			_check(button.focus_mode == Control.FOCUS_ALL, "every reward choice can receive keyboard focus")
	for button: Button in hud._reward_buttons:
		for child: Node in button.get_children():
			if child is Label:
				_check(child.get_theme_color("font_color") != hud.ORANGE, "no reward label carries a recommended gold accent")
		_check(not button.has_focus(), "reward selection does not preselect a card")
	for style_id in ["azure_empyrea", "fenghuang", "night_squire"]:
		state.fighter.styleId = style_id
		hud.update_status(state)
		hud._menu_guide.pressed.emit()
		await process_frame
		_check(hud.is_guide_open() and hud._guide_overlay.visible, "guide opens for " + style_id)
		_check(hud._guide_data.styleId == style_id, "guide follows current armor " + style_id)
		_check(hud._guide_data.moves.map(func(move): return move.key) == ["J", "K", "L", "SPACE", "E", "Q"], "all six action keys are explained for " + style_id)
		var model := Combat.new()
		model.set_player_profile(style_id)
		_check(is_equal_approx(float(hud._guide_data.cooldown), float(model.player.skillCooldownMax)), "guide cooldown matches actual combat for " + style_id)
		_check(hud._guide_data.riposteWindow == Combat.RIPOSTE_WINDOW, "counter followup timing matches combat")
		var original: String = JSON.stringify(hud._guide_data)
		state.fighter.skinName = "测试外观"
		hud.update_status(state)
		_check(JSON.stringify(hud._guide_data) == original, "changing appearance cannot alter help or moveset")
		actions.clear()
		hud._menu_start.pressed.emit()
		hud._menu_practice.pressed.emit()
		hud._menu_back.pressed.emit()
		_check(actions.is_empty(), "guide blocks underlying menu callbacks")
		for viewport in [Vector2i(1440,900), Vector2i(960,540), Vector2i(360,800), Vector2i(640,360)]:
			root.size = viewport
			hud._layout()
			await process_frame
			await process_frame
			var snapshot: Dictionary = hud.presentation_snapshot()
			var panel: Array = snapshot.guidePanelRect
			_check(absf(float(panel[0]) + float(panel[2]) * 0.5 - float(viewport.x) * 0.5) < 0.1, "guide is visually centered after canvas stretch " + str(viewport))
			_check(Vector2(float(snapshot.viewportSize[0]), float(snapshot.viewportSize[1])).distance_to(Vector2(viewport)) < 0.1, "snapshot coordinates use viewport pixels")
			_check(snapshot == hud.presentation_snapshot() and hud.is_guide_open(), "presentation snapshot is readonly")
			_check(root.get_visible_rect().encloses(hud._guide_panel.get_global_rect()), "guide stays on screen " + style_id + " / " + str(viewport))
			_check(hud._guide_scroll.size.y > 100 and hud._guide_content.custom_minimum_size.y >= hud._guide_scroll.size.y, "long instructions remain scrollable " + str(viewport))
			_check(hud._guide_close.get_global_rect().size.y >= 29.0, "guide close remains usable on small screens")
			for card: Control in hud._guide_cards:
				var body: Label = card.get_node("Body")
				var detail: Label = card.get_node("Detail")
				_check(body.autowrap_mode == TextServer.AUTOWRAP_ARBITRARY and detail.autowrap_mode == TextServer.AUTOWRAP_ARBITRARY, "Chinese mixed-key paragraphs use character wrapping on native and Web")
				_check(body.position.y + body.size.y + 8.0 <= detail.position.y, "wrapped description cannot overlap its cooldown/footer " + style_id + " / " + str(viewport))
				var pixel_scale: float = (root.get_final_transform() * body.get_global_transform_with_canvas()).get_scale().x
				_check(pixel_scale * float(body.get_theme_font_size("font_size")) >= 14.39, "body stays readable in physical pixels " + str(viewport))
				for node_name in ["Key", "Title", "Body", "Detail"]:
					var label: Label = card.get_node(node_name)
					_check(label.position.y + label.size.y <= card.size.y + 0.01, "guide label stays inside its card: " + style_id + " / " + node_name + " / " + str(viewport))
			_check(hud._guide_chain.position.y + hud._guide_chain.size.y + 8.0 <= hud._guide_parry_note.position.y and hud._guide_parry_note.position.y + hud._guide_parry_note.size.y + 8.0 <= hud._guide_tip.position.y, "counter explanation paragraphs stay separated after wrapping")
			var scroll_max: float = hud._guide_scroll.get_v_scroll_bar().max_value - hud._guide_scroll.get_v_scroll_bar().page
			hud._guide_scroll.scroll_vertical = int(scroll_max)
			await process_frame
			_check(hud._guide_scroll.scroll_vertical > 0, "small and large guides can reach the counter followup section")
		# Reproduce a TextServer choosing substantially more lines, independent
		# of which font backend this headless runner happens to use.
		var sample: Control = hud._guide_cards[0]
		var saved_body: String = sample.get_node("Body").text
		var saved_detail: String = sample.get_node("Detail").text
		sample.get_node("Body").text = "连续按 J\n衔接拳击\n爆发期间切换踢击\n第三段命中\n可缩短 E 的冷却\n结束"
		sample.get_node("Detail").text = "第一行\n第二行\n第三行"
		hud._layout_fighter_guide()
		await process_frame
		hud._layout_fighter_guide()
		var sample_body: Label = sample.get_node("Body")
		var sample_detail: Label = sample.get_node("Detail")
		_check(sample_detail.position.y > sample_body.position.y + sample_body.size.y and sample.size.y >= sample_detail.position.y + sample_detail.size.y + 10.0, "cards grow for longer Web line breaks without clipping text")
		_check(hud._guide_cards[2].position.y >= sample.position.y + sample.size.y + 10.0, "taller card pushes the following row down")
		sample.get_node("Body").text = saved_body
		sample.get_node("Detail").text = saved_detail
		hud._layout_fighter_guide()
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER
		enter.pressed = true
		_check(hud.handle_modal_input(enter) and hud.is_guide_open(), "Enter cannot start combat behind the guide")
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		_check(hud.handle_modal_input(escape) and not hud.is_guide_open(), "Escape closes the guide without pausing gameplay")
	_check(Guide.for_style("night_squire").burstDuration == Combat.NIGHT_BURST_DURATION, "burst help stays tied to combat duration")
	state.started = true
	state.campaign.phase = "fight"
	state.enemies = [{"id":"a", "hp":100.0, "maxHp":100.0, "name":"幻身甲"}, {"id":"b", "hp":100.0, "maxHp":100.0, "name":"幻身乙"}]
	state.enemy = state.enemies[0]
	hud.update_status(state)
	_check(hud._battle.visible and not hud._enemy_panel.visible, "group combat does not repeat an overhead health bar on top")
	state.enemies[0].hp = 0.0
	hud.update_status(state)
	_check(not hud._enemy_panel.visible, "last survivor of a group does not jump to top HUD")
	state.enemies = [{"id":"single", "hp":65.0, "maxHp":130.0, "name":"单人对手"}]
	hud.update_status(state)
	_check(hud._enemy_panel.visible and hud._enemy_name.text == "单人对手" and is_equal_approx(hud._enemy_hp.value, 50.0), "single opponent uses its correct main health bar")
	_check(hud._enemy_resources.text=="HP 65 / 130   ·   架势 0 / 100", "HP and posture have distinct visible labels")
	state.enemies = [{"id":"minion", "hp":80.0, "maxHp":80.0, "name":"幻身"}, {"id":"boss", "hp":120.0, "maxHp":200.0, "name":"识之律者", "boss":true}]
	state.enemy = state.enemies[0]
	state.healthDisplay = HealthDisplay.plan(state.enemies)
	hud.update_status(state)
	_check(hud._enemy_panel.visible and hud._enemy_name.text == "识之律者" and is_equal_approx(hud._enemy_hp.value, 60.0), "boss main HP stays correct while current target is a minion")
	_check(hud._enemy_hp.tint==Color("ef7653") and hud._enemy_posture.tint==HUD.ORANGE, "boss health and posture retain distinct colors")
	_check(hud.presentation_snapshot().primaryHealthId == "boss" and hud.presentation_snapshot().primaryHealthVisible, "readonly snapshot identifies the actual visible boss bar")
	for phase in ["fight", "reward", "menu", "failed"]:
		state.campaign.phase = phase
		state.started = phase != "menu"
		state.campaign.rewards = [{"title":"甲", "description":"甲"}, {"title":"乙", "description":"乙"}, {"title":"丙", "description":"丙"}]
		state.ko.active = true
		hud.update_status(state)
		actions.clear()
		hud._menu_start.pressed.emit()
		hud._menu_practice.pressed.emit()
		hud._menu_restart.pressed.emit()
		hud._menu_back.pressed.emit()
		hud._reward_buttons[0].pressed.emit()
		hud._menu_guide.pressed.emit()
		_check(not hud._battle.visible and not hud._enemy_panel.visible and not hud._menu.visible and not hud._reward_overlay.visible and not hud.is_guide_open(), "KO hides combat and transitional UI in " + phase)
		_check(actions.is_empty(), "KO refuses stale menu and reward actions in " + phase)
		_check(not hud._skills.light.enabled and not hud._left.enabled, "KO releases combat controls")
	state.ko.active = false
	state.started = true
	state.campaign.phase = "reward"
	hud.update_status(state)
	_check(hud._reward_overlay.visible, "reward selection becomes available after KO ends")
	hud._reward_buttons[0].grab_focus()
	_check(hud._reward_buttons[0].has_focus(), "player can intentionally focus a reward choice")
	state.campaign.phase = "fight"
	hud.update_status(state)
	state.campaign.phase = "reward"
	hud.update_status(state)
	_check(not hud._reward_buttons.any(func(button): return button.has_focus()), "new reward round does not inherit a recommended-looking focused choice")
	actions.clear()
	hud._reward_buttons[2].pressed.emit()
	_check(actions == ["reward_2"], "equal reward cards retain their distinct choice IDs")
	hud.free()
	await process_frame
	var report := {"suite":"hud_clarity", "checks":checks, "failures":failures, "passed":failures.is_empty()}
	DirAccess.make_dir_recursive_absolute("res://build/reports")
	var file := FileAccess.open("res://build/reports/hud-clarity.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
