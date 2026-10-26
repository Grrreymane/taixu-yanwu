extends SceneTree
## Standalone, read-only UI verification: godot --headless --script res://assets/ui/hud_check.gd

const HUD = preload("res://scripts/hud.gd")
var failures: Array[String] = []
var actions: Array[String] = []
var movements: Array[float] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

func _state(phase: String = "fight", mode: String = "trial") -> Dictionary:
	return {"started":phase!="menu","paused":false,"ended":phase in ["failed","cleared"],"winner":"player","combo":8,"ultimate":false,"player":{"hp":90,"maxHp":120,"energy":100,"posture":25,"skillCooldown":3.0,"skillCooldownMax":6.0},"enemy":{"hp":130,"maxHp":260,"posture":45,"name":"赤霄守影","boss":true},"campaign":{"mode":mode,"phase":phase,"stageIndex":5,"stageTotal":6,"title":"终试 · 赤霄","region":"赤霄坛","brief":"留意首领的蓄力预警","enemiesRemaining":1,"totalEnemies":1,"bestScore":4500,"bestRank":"S","rewards":[{"id":"a","title":"寸心如锋","description":"所有攻击伤害提高 16%。"},{"id":"b","title":"行云流水","description":"命中获得的 SP 提高 25%，更快释放必杀。"},{"id":"c","title":"生生不息","description":"生命上限增加 20，立即恢复 35 HP。"}],"boons":["寸心如锋","生生不息"],"stats":{"kills":11,"parries":7,"maxCombo":16,"damageTaken":45.5,"elapsed":123,"score":4500,"rank":"S"}}}

func _run() -> void:
	var hud = HUD.new()
	root.add_child(hud)
	hud.action_requested.connect(func(action: String): actions.append(action))
	hud.move_changed.connect(func(value: float): movements.append(value))
	await process_frame
	hud.set_ready(true)
	hud.update_status(_state("menu"))
	_check(hud._menu_practice.visible and hud._menu_start.text.contains("开始试炼"),"two menu entries")
	_check(hud._menu_hint.text.contains("4500"),"best score")
	hud.update_status(_state())
	_check(is_equal_approx(hud._player_hp.value,75.0),"player max HP percentage")
	_check(is_equal_approx(hud._enemy_hp.value,50.0),"boss max HP percentage")
	_check(hud._enemy_tag.text=="首领","boss label")
	_check(not hud._mode_button.visible,"trial hides training mode")
	_check(not hud._skills.ability.enabled and is_equal_approx(hud._skills.ability.cooldown_fraction,0.5),"ability cooldown")
	hud._left._set_active(true)
	hud.update_status(_state("reward"))
	_check(not movements.is_empty() and is_equal_approx(movements[-1],0.0),"reward releases held movement")
	_check(hud._reward_overlay.visible and not hud._battle.visible,"reward screen")
	_check(hud._reward_names[1].text=="行云流水","reward content")
	hud._reward_buttons[1].pressed.emit()
	hud._reward_buttons[2].pressed.emit()
	_check(actions==["reward_1"],"reward selection is emitted once")
	hud.update_status(_state("failed"))
	hud._menu_primary()
	_check(actions[-1]=="retry" and hud._menu_back.visible,"retry current encounter")
	hud.update_status(_state("cleared"))
	_check(hud._result_overlay.visible and hud._result_rank.text=="S","final score screen")
	_check(hud._result_values[4].text=="02:03","elapsed formatting")
	_check(hud._result_boons.text.contains("生生不息"),"final boons")
	hud.update_status(_state("fight","practice"))
	_check(hud._mode_button.visible,"practice exposes training mode")
	hud.update_status(_state("failed","practice"))
	hud._menu_primary()
	_check(actions[-1]=="practice","practice replay avoids trial retry")
	var paused := _state()
	paused.paused=true
	hud.update_status(paused)
	hud._menu_primary()
	_check(actions[-1]=="pause" and not hud._left.enabled,"pause resume and held control release")
	hud.queue_free()
	await process_frame
	if failures.is_empty():
		print("HUD_CHECK_PASS: menu, campaign, rewards, results, cooldown, HP ratios, held input, practice, pause")
		quit(0)
	else:
		for failure in failures:
			push_error("HUD_CHECK_FAIL: "+failure)
		quit(1)
