extends SceneTree
const HUD = preload("res://scripts/hud.gd")
const Roster = preload("res://scripts/fighter_roster.gd")
var checks:=0
var failures: Array[String]=[]
var actions: Array[String]=[]

func _initialize() -> void: call_deferred("_run")
func check(condition: bool, label: String) -> void:
	checks+=1
	if not condition: failures.append(label)

func _state() -> Dictionary:
	return {"started":false,"paused":false,"ended":false,"ko":{"active":false},
		"player":{"hp":100.0,"energy":60.0},"enemy":{},"enemies":[],"victory":{},
		"campaign":{"mode":"trial","phase":"menu","runTimeMs":123456,"bestTimeMs":321098,"saveStatus":"saved","resume":{"available":false}},
		"fighter":{"characterName":"符华","styleName":"白夜执事","styleId":"night_squire","skinName":"原装"},
		"roster":{"canSelect":true,"characterId":"fuhua","styleId":"night_squire","appearanceId":"default","styles":Roster.list_styles(),"appearances":Roster.list_appearances("fuhua","night_squire")}}

func _run() -> void:
	var hud:=HUD.new()
	hud.process_mode=Node.PROCESS_MODE_DISABLED
	root.add_child(hud)
	hud.action_requested.connect(func(action: String): actions.append(action))
	hud.set_ready(true)
	var state:=_state()
	hud.update_status(state)
	check(HUD.format_run_time(0)=="00:00.00" and HUD.format_run_time(123456)=="02:03.45","timer uses centiseconds without rounding into the next second")
	check(HUD.format_run_time(3600010)=="60:00.01" and HUD.format_run_time(-1)=="00:00.00","timer supports long runs and clamps negative input")
	check(not hud._menu_new_trial.visible and hud._menu_start.text=="开始试炼  ENTER","fresh home has one clear start action")
	hud._menu_start.pressed.emit()
	check(actions==["start"],"fresh home starts a new run")
	actions.clear()
	state.campaign.resume={"available":true,"stageIndex":2,"phase":"fight","runTimeMs":123456}
	hud.update_status(state)
	check(hud._menu_new_trial.visible and "第03战" in hud._menu_start.text,"saved run replaces primary action with continue")
	check("本关开场继续" in hud._menu_hint.text and "05:21.09" in hud._menu_hint.text,"home explains restart point and displays local fastest time")
	check("替换" in hud._menu_new_trial.tooltip_text,"new-run action explains replacing the unfinished checkpoint")
	hud._menu_start.pressed.emit()
	hud._menu_new_trial.pressed.emit()
	check(actions==["continue","trial"],"continue and fresh trial have independent action IDs")
	for dimensions: Vector2i in [Vector2i(1440,900),Vector2i(960,540)]:
		root.size=dimensions
		hud._layout()
		await process_frame
		await process_frame
		var view:=Rect2(Vector2.ZERO,Vector2(dimensions))
		for item: Control in [hud._menu_start,hud._menu_new_trial,hud._menu_practice,hud._menu_hint,hud._armor_strip]:
			check(view.encloses(hud._viewport_pixel_rect(item)),"save controls and two-row armor roster fit "+str(dimensions)+" "+item.name)
		check(not hud._menu_new_trial.get_global_rect().intersects(hud._menu_practice.get_global_rect()),"new run and practice remain separate clickable regions "+str(dimensions))
		check(not hud._menu_start.get_global_rect().intersects(hud._menu_new_trial.get_global_rect()),"continue button does not overlap secondary actions "+str(dimensions))
	state.campaign.resume.phase="reward"
	hud.update_status(state)
	check("继续选择强化" in hud._menu_hint.text and "不重复" in hud._menu_start.tooltip_text,"reward checkpoint explains continuing the existing choice")
	for status: String in ["unavailable","damaged","incompatible","recovered"]:
		state.campaign.saveStatus=status
		hud.update_status(state)
		check(not "本地已保存" in hud._menu_hint.text,"save status does not falsely claim success: "+status)
	state.started=true
	state.campaign.phase="fight"
	state.campaign.saveStatus="saved"
	hud.update_status(state)
	check(hud._run_timer.is_visible_in_tree() and hud._run_timer.text=="通关计时  02:03.45","battle timer reads the authoritative campaign clock")
	check(not hud._menu_new_trial.visible,"new trial secondary action is hidden in battle")
	var before: String=hud._run_timer.text
	hud._process(5.0)
	check(hud._run_timer.text==before,"HUD never advances its own clock")
	state.paused=true
	hud.update_status(state)
	actions.clear()
	hud._menu_start.pressed.emit()
	check(actions==["pause"],"pause resume remains distinct from checkpoint continue")
	state.paused=false
	state.ended=true
	state.campaign.phase="cleared"
	state.campaign.runTimeMs=123456
	state.campaign.bestTimeMs=123456
	state.campaign.newTimeRecord=true
	state.campaign.stats={"elapsed":9999.0,"score":1000,"rank":"A"}
	hud.update_status(state)
	check(hud._result_values[4].text=="02:03.45","results use campaign time rather than slowed simulation elapsed")
	check("新纪录" in hud._result_record.text and "02:03.45" in hud._result_record.text,"result announces the recorded local best")
	state.campaign.mode="practice"
	hud.update_status(state)
	check(not hud._run_timer.visible and not hud._result_record.visible,"practice does not present official trial time records")
	hud.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
	var report: Dictionary={"suite":"run_save_hud","checks":checks,"passed":failures.is_empty(),"failures":failures}
	FileAccess.open("res://build/reports/run-save-hud.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
