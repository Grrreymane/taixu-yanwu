extends SceneTree

const HUD = preload("res://scripts/hud.gd")
const Roster = preload("res://scripts/fighter_roster.gd")
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
	# Names are fixtures: the product gets all names from the verified roster.
	return {"started": false, "paused": false, "ended": false,
		"player": {"hp": 100.0, "energy": 100.0, "stance": "punch"}, "enemy": {},
		"campaign": {"phase": "menu", "mode": "trial"}, "victory": {},
		"fighter": {"characterName": "符华", "styleName": "云墨丹心", "skinName": "原装",
			"styleId": "azure_empyrea", "abilityName": "寸劲", "ultimateName": "太虚 · 云墨", "description": "拳脚连击 · 寸劲破势"},
		"roster": {"canSelect": true, "characterId": "fuhua", "styleId": "azure_empyrea", "appearanceId": "default",
			"styles": Roster.list_styles(),
			"appearances": [{"id": "default", "name": "原装"}, {"id": "test_skin", "name": "测试外观"}]}}

func _run() -> void:
	var hud = HUD.new()
	hud.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(hud)
	hud.action_requested.connect(func(action: String): actions.append(action))
	var data := _state()
	hud.update_status(data)
	_check(hud._style_choices.map(func(button): return str(button.get_meta("selection_id"))) == ["azure_empyrea", "fenghuang", "night_squire"] and hud._appearance_choices.size() == 2, "menu displays exactly the three playable armors and supplied appearances")
	_check(hud._style_choices[0].disabled and hud._appearance_choices[0].disabled, "selection cannot run before resources are ready")
	hud.set_ready(true)
	hud.update_status(data)
	_check(hud._roster_group.visible and hud._menu.size.y == 720.0, "ready home page has the expanded selection layout")
	_check(hud._menu_title.text == "符华" and hud._menu_subtitle.text == "云墨丹心", "menu identity comes from the current fighter snapshot")
	_check(hud._style_choices[0].button_pressed and not hud._style_choices[1].button_pressed, "the selected style is highlighted")
	hud._style_choices[1].pressed.emit()
	_check(actions == ["select_style:fenghuang"], "style click uses the established action channel and stable ID")
	_check(hud._menu_subtitle.text == "云墨丹心" and hud._style_choices[0].button_pressed, "a request cannot relabel the old model before main confirms it")
	actions.clear()
	hud._style_choices[0].pressed.emit()
	_check(actions.is_empty(), "clicking the current style does not reload the model")
	hud._appearance_choices[1].pressed.emit()
	_check(actions == ["select_appearance:test_skin"], "skin click emits only the appearance ID")
	actions.clear()
	hud._select_roster("appearance", "missing_skin")
	_check(actions.is_empty(), "unknown appearance IDs cannot be emitted from the selector")
	data.roster.appearanceId = "test_skin"
	data.fighter.skinName = "测试外观"
	hud.update_status(data)
	_check(hud._appearance_choices[1].button_pressed and not hud._appearance_choices[0].button_pressed, "confirmed skin updates the highlight without replacing the moveset")
	var current_button: Button = hud._style_choices[0]
	hud.update_status(data)
	_check(hud._style_choices[0] == current_button, "unchanged snapshots retain the existing controls")

	for viewport in [Vector2i(1440, 900), Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = viewport
		hud._layout()
		await process_frame
		var screen: Rect2 = root.get_visible_rect()
		_check(screen.encloses(hud._menu.get_global_rect()), "home menu remains inside viewport " + str(viewport))
		_check(hud._menu_start.position.y > hud._roster_group.position.y + hud._roster_group.size.y, "start button clears selector rows " + str(viewport))
		_check(hud._music_button.position.y + hud._music_button.size.y < hud._menu_hint.position.y, "music and record text do not overlap " + str(viewport))
		for button: Button in hud._style_choices + hud._appearance_choices:
			var font: Font = button.get_theme_font("font")
			var font_size: int = button.get_theme_font_size("font_size")
			_check(font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= button.size.x - 24.0, "choice label fits without clipping: " + button.text + " / " + str(viewport))

	data.roster.styleId = "fenghuang"
	data.roster.appearanceId = "default"
	data.roster.appearances = [{"id": "default", "name": "原装"}]
	data.fighter = {"characterName": "符华", "styleId": "fenghuang", "styleName": "炽翎", "skinName": "原装",
		"abilityName": "换式", "ultimateName": "迦楼罗", "description": "拳式快攻 · 腿式远击 · E 换式"}
	hud.update_status(data)
	_check(hud._appearance_choices.size() == 1 and hud._appearance_choices[0].button_pressed, "changing style replaces its skin list instead of carrying another armor's skin")
	_check(hud._menu_subtitle.text == data.fighter.styleName and hud._menu_detail.text == data.fighter.description, "confirmed style updates its title and combat summary")
	_check(hud._skills.ability.title.text == "换式" and hud._ultimate_title.text == "迦楼罗", "ability and ultimate names follow the selected moveset")
	_check(hud._stance_label.visible and hud._stance_label.text == "拳式", "a stance style has a clear fist-stance badge")
	data.player.stance = "kick"
	hud.update_status(data)
	_check(hud._stance_label.text == "腿式", "stance badge updates from combat state")
	_check(hud._battlesuit.text == data.fighter.styleName, "battle identity uses the selected armor")

	for phase in ["fight", "reward", "failed", "cleared"]:
		data.started = true
		data.campaign.phase = phase
		data.ended = phase in ["failed", "cleared"]
		# Even a stale permissive roster snapshot must not unlock combat selection.
		data.roster.canSelect = true
		hud.update_status(data)
		actions.clear()
		hud._select_roster("style", "azure_empyrea")
		_check(not hud._roster_group.visible and actions.is_empty() and hud._style_choices[0].disabled, "selection stays locked in " + phase)
	data.campaign.phase = "fight"
	data.ended = false
	data.paused = true
	hud.update_status(data)
	_check(hud._menu.visible and hud._menu.size.y == 468.0 and not hud._roster_group.visible, "pause retains the compact menu without character switching")
	_check(hud._music_button.position.y == 416.0 and hud._menu_start.position.y == 250.0, "pause button layout is restored after expanded home")
	data.campaign.phase = "cleared"
	data.ended = true
	data.paused = false
	data.victory = {"visible": true, "playing": false, "time": 4.4, "paused": false}
	hud.update_status(data)
	_check(hud._victory_overlay.visible and hud._result_overlay.visible and not hud._menu.visible, "victory keeps the established identity and result layout")
	_check(hud._victory_style.text == data.fighter.styleName and hud._victory_skin.text.contains("原装"), "victory identity reflects the selected style and skin")

	data = _state()
	hud.update_status(data)
	_check(hud._menu.size.y == 720.0 and not hud._stance_label.visible and hud._skills.ability.title.text == "寸劲", "returning to cloud-ink restores its UI and home selection")
	data.roster.canSelect = false
	hud.update_status(data)
	actions.clear()
	hud._select_roster("style", "fenghuang")
	_check(hud._style_choices[1].disabled and actions.is_empty(), "main can temporarily lock selection while loading")
	data.erase("roster")
	hud.update_status(data)
	_check(hud._style_choices.is_empty() and hud._appearance_choices.is_empty() and not hud._roster_group.visible and hud._menu.size.y == 468.0, "missing roster data creates no placeholder selection")
	hud.free()
	await process_frame
	print(JSON.stringify({"suite": "roster_hud", "checks": checks, "failures": failures, "passed": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
