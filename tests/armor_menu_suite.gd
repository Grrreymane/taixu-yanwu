extends SceneTree

const HUD = preload("res://scripts/hud.gd")
const Roster = preload("res://scripts/fighter_roster.gd")
const Campaign = preload("res://scripts/campaign.gd")
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
	return {"started":false, "paused":false, "ended":false, "player":{"hp":100.0, "energy":100.0}, "enemy":{},
		"campaign":{"phase":"menu", "mode":"trial", "contracts":Campaign.CONTRACTS.values(), "contractId":"mirror", "selectedContractIds":["mirror"], "contractsUnlocked":false},
		"fighter":Roster.presentation_identity("fuhua", "azure_empyrea", "default"),
		"roster":{"canSelect":true, "styleId":"azure_empyrea", "appearanceId":"default", "styles":Roster.list_styles(), "appearances":Roster.list_appearances("fuhua", "azure_empyrea")}}

func _run() -> void:
	var hud = HUD.new()
	hud.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(hud)
	hud.action_requested.connect(func(action: String): actions.append(action))
	hud.set_ready(true)
	var state := _state()
	hud.update_status(state)
	await process_frame
	await process_frame
	_check(hud._style_choices.size() == 5, "all five implemented armors appear")
	for button: Button in hud._style_choices:
		var portrait: TextureRect = button.get_node("Portrait")
		_check(portrait.texture is AtlasTexture and portrait.texture.atlas.get_width() == 148, "portrait uses a verified original client image")
		_check(portrait.texture.region.position == Vector2.ZERO and portrait.texture.region.size.y <= 160.0, "portrait crop preserves the original head rather than cropping its center")
		_check(button.custom_minimum_size == Vector2(108, 104), "two-row portraits keep a readable fixed card size")
		_check(button.get_node("Title").text != "", "each armor portrait has its proper name")
		button.pressed.emit()
	_check(actions == ["select_style:fenghuang", "select_style:night_squire", "select_style:shadow_knight", "select_style:hawk_of_the_fog"], "portrait clicks preserve all armor selection IDs and skip the already selected armor")
	actions.clear()
	_check(not hud._armor_strip is ScrollContainer, "armor selection has no horizontal scrolling surface")
	_check(not hud._armor_previous.visible and not hud._armor_next.visible, "all current armors are visible without paging controls")
	var row_positions: Array = []
	for button: Button in hud._style_choices:
		if not row_positions.has(button.position.y): row_positions.append(button.position.y)
	_check(row_positions.size()==2, "five current armors occupy exactly two rows")
	_check(hud._menu_skill_summary.text.contains("寸劲") and hud._menu_skill_summary.text.contains("太虚之握"), "selected detail panel shows its E and Q moves")
	_check(hud._contract_detail.text.contains("通关一次解锁多选") and hud._contract_all.disabled, "first-clear lock is explained beside the rules")
	hud._contract_all.pressed.emit()
	_check(actions.is_empty(), "locked all-rules button cannot emit an action")
	_check(hud._contract_buttons.filter(func(button): return button.get_meta("selected")).size() == 1, "first run highlights one actual rule")
	state.campaign.contractsUnlocked = true
	state.campaign.selectedContractIds = ["mirror", "flow"]
	state.campaign.challengeLevel = 1
	state.campaign.challengeDescription = "敌人伤害提高，追击更频繁"
	hud.update_status(state)
	_check(not hud._contract_all.disabled and hud._contract_buttons.filter(func(button): return button.get_meta("selected")).size() == 2, "cleared progression can highlight two simultaneous rules")
	_check(hud._contract_detail.text.contains("已选 2 项") and hud._contract_detail.text.contains("追击更频繁"), "combined challenge consequence is visible before starting")
	hud._contract_buttons[1].pressed.emit()
	hud._contract_all.pressed.emit()
	_check(actions == ["contract:flow", "contract_all"], "multi-select and all-select keep the campaign action API")
	for viewport in [Vector2i(1440,900), Vector2i(1280,720), Vector2i(960,540), Vector2i(360,800)]:
		root.size = viewport
		hud._layout()
		await process_frame
		await process_frame
		_check(root.get_visible_rect().encloses(hud._menu.get_global_rect()), "portrait home stays inside viewport " + str(viewport))
		_check(root.get_visible_rect().encloses(hud._contract_panel.get_global_rect()), "rules remain on screen " + str(viewport))
		_check(not hud._menu.get_global_rect().intersects(hud._contract_panel.get_global_rect()), "rules do not overlap armor selection " + str(viewport))
		_check(hud._menu_start.position.y > hud._roster_group.position.y + hud._roster_group.size.y, "start button clears portrait and skin rows")
		var preview: Rect2 = hud.preview_rect()
		_check(preview.has_area() and Rect2(Vector2.ZERO, Vector2(viewport)).encloses(preview), "rotation hit area is inside the physical viewport")
		_check(not preview.intersects(hud._viewport_pixel_rect(hud._menu)) and not preview.intersects(hud._viewport_pixel_rect(hud._contract_panel)), "rotation avoids every menu and rule hit target")
		for button: Button in hud._contract_buttons:
			var description: Label = button.get_node("Description")
			_check(description.position.y + description.size.y <= button.size.y, "rule explanation remains visible without cropping")
		for index in Roster.list_styles().size():
			state.roster.styleId=Roster.list_styles()[index].id
			hud.update_status(state)
			await process_frame
			await process_frame
			_check(hud._style_choices.all(func(button):return button.visible and hud._armor_strip.get_global_rect().encloses(button.get_global_rect())), "every implemented armor remains visible after selection " + str(viewport))
		state.roster.styleId="azure_empyrea"
		hud.update_status(state)
	# Future roster growth is a fixture only; no unimplemented cards enter product data.
	state.roster.styleId = "night_squire"
	state.roster.appearances = Roster.list_appearances("fuhua","night_squire")
	state.fighter = Roster.presentation_identity("fuhua","night_squire","default")
	for viewport in [Vector2i(1440,900), Vector2i(960,540), Vector2i(360,800)]:
		root.size = viewport
		for outfit: Dictionary in state.roster.appearances:
			state.roster.appearanceId = outfit.id
			hud.update_status(state)
			hud._layout()
			await process_frame
			await process_frame
			_check(hud._appearance_choices.size()==5,"all five audited Night Squire outfits remain selectable")
			_check(root.get_visible_rect().encloses(hud._menu.get_global_rect()),"full wardrobe menu fits "+str(viewport))
			_check(hud._appearance_choices.all(func(button):return button.visible and hud._roster_group.get_global_rect().encloses(button.get_global_rect())),"all outfit buttons fit without scrolling or clipping")
			_check(hud._menu_start.position.y > hud._roster_group.position.y + hud._roster_group.size.y,"full wardrobe does not overlap start")
			_check(hud._appearance_choices.filter(func(button):return button.button_pressed).size()==1,"exactly one selected outfit after switching")
	state.roster.appearances = Roster.list_appearances("fuhua","azure_empyrea")
	state.fighter = Roster.presentation_identity()
	state.roster.appearanceId = "default"
	state.roster.styleId = "azure_empyrea"
	var expanded: Array = []
	for index in range(9):
		var option: Dictionary = Roster.list_styles()[index % Roster.list_styles().size()].duplicate(true)
		option.id = "fixture_%d" % index
		expanded.append(option)
	expanded.append({"id":"not_implemented", "name":"未实装", "playable":false})
	state.roster.styles = expanded
	state.roster.styleId = "fixture_0"
	hud.update_status(state)
	await process_frame
	await process_frame
	_check(hud._style_choices.size() == 9 and hud._style_choices.all(func(button): return button.custom_minimum_size == Vector2(108,104)), "future armors keep portrait size without showing locked placeholders")
	_check(hud._armor_next.visible and not hud._armor_next.disabled, "future roster over six uses explicit pages")
	hud._armor_next.pressed.emit()
	await process_frame
	_check(hud._armor_strip.page==1 and hud._style_choices.filter(func(button):return button.visible).size()==3, "next page reveals the final three armors without horizontal scrolling")
	state.roster.styleId = "fixture_8"
	hud.update_status(state)
	await process_frame
	await process_frame
	_check(hud._style_choices[8].visible and hud._armor_strip.get_global_rect().encloses(hud._style_choices[8].get_global_rect()), "confirmed future selection reveals its page")
	actions.clear()
	hud._select_roster("style", "not_implemented")
	_check(actions.is_empty(), "an unimplemented option cannot be selected programmatically")
	hud.open_fighter_guide()
	_check(not hud.preview_rect().has_area(), "help modal blocks drag rotation")
	hud.close_fighter_guide()
	state.started = true
	state.campaign.phase = "fight"
	state.campaign.objective = {"title":"完成 2 次极限防御 · 成功闪避 2 次攻击 · 打出 6 连击", "items":[{"id":"mirror","progress":1,"target":2},{"id":"flow","progress":0,"target":2},{"id":"breaker","progress":4,"target":6}]}
	hud.update_status(state)
	_check(hud._stage_boons.text == "防反 1/2 · 闪避 0/2 · 连击 4/6", "battle shows compact progress for all three goals")
	_check(hud._stage_boons.tooltip_text.contains("完成 2 次极限防御"), "full goal wording remains available in its tooltip")
	_check(not hud._roster_group.visible and not hud.preview_rect().has_area(), "combat hides selection and disables preview rotation")
	actions.clear()
	hud._contract_all.pressed.emit()
	hud._contract_buttons[0].pressed.emit()
	_check(actions.is_empty(), "rules cannot change from stale UI signals after starting")
	hud.free()
	await process_frame
	var report := {"suite":"armor_menu", "checks":checks, "failures":failures, "passed":failures.is_empty()}
	DirAccess.make_dir_recursive_absolute("res://build/reports")
	FileAccess.open("res://build/reports/armor-menu.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
