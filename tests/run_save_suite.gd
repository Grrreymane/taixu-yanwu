extends SceneTree
const Campaign=preload("res://scripts/campaign.gd")
const Store=preload("res://scripts/local_save.gd")
const FIGHTER={"characterId":"fuhua","styleId":"fenghuang","appearanceId":"fire_and_sword"}
class VolatileCampaign extends "res://scripts/campaign.gd":
 var saves:=0
 func _load_record() -> void: pass
 func _save_record() -> void: saves+=1
class ErrorRecorder extends Logger:
 var errors: Array=[]
 func _log_error(function: String,file: String,line: int,code: String,rationale: String,_notify: bool,error_type: int,_backtraces: Array[ScriptBacktrace]) -> void:
  if error_type!=Logger.ERROR_TYPE_WARNING: errors.append({"function":function,"file":file,"line":line,"code":code,"rationale":rationale})
var failures: Array[String]=[]
var checks:=0
var recorder:=ErrorRecorder.new()

func _initialize() -> void: call_deferred("_run")
func check(value: bool,label: String) -> void:
 checks+=1
 if not value: failures.append(label); print("CHECK FAILED: ",label)

func same_numbers(a: Dictionary,b: Dictionary) -> bool:
 if a.size()!=b.size(): return false
 for key: String in a:
  if not b.has(key) or not is_equal_approx(float(a[key]),float(b[key])): return false
 return true

func _state(campaign,winner: String="player") -> Dictionary:
 return {"winner":winner,"player":{"hp":65.0,"maxHp":campaign.carry.maxHp,"energy":25.0},"stats":{"kills":campaign.stages[campaign.stage_index].enemies.size(),"parries":0,"dodges":0,"maxCombo":1,"damageTaken":12.0,"damageDealt":150.0,"elapsed":2.0},"enemies":[]}

func _run() -> void:
 OS.add_logger(recorder)
 var originals: Dictionary={}
 for relative: String in [Campaign.SAVE_PATH,Store.FILE_PATH,Store.FILE_PATH+".backup"]:
  var path:=ProjectSettings.globalize_path(relative)
  originals[path]=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
 ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
 ProjectSettings.set_setting("application/config/custom_user_dir_name","TaixuRunSaveSuite/%d-%d"%[OS.get_process_id(),Time.get_ticks_usec()])
 check(not originals.has(ProjectSettings.globalize_path(Campaign.SAVE_PATH)),"all fixtures use a separate player-data directory")
 if originals.has(ProjectSettings.globalize_path(Campaign.SAVE_PATH)): quit(1); return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Campaign.SAVE_PATH).get_base_dir())
 _clock_and_memory()
 _native_roundtrip()
 _recovery_and_validation()
 _monotonic_recovery()
 _records()
 for path: String in originals:
  var after:=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
  check(after==originals[path],"real user save remains untouched: "+path.get_file())
 check(recorder.errors.is_empty(),"no engine errors during save and restore")
 OS.remove_logger(recorder)
 var report: Dictionary={"suite":"run_save","checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors}
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
 FileAccess.open("res://build/reports/run-save-suite.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)

func _clock_and_memory() -> void:
 var campaign:=VolatileCampaign.new()
 campaign.tick_run(5.0)
 check(campaign.run_time==0.0,"menu cannot start timer")
 campaign.begin_trial("mirror",42)
 campaign.encounter()
 campaign.save_checkpoint(FIGHTER)
 campaign.tick_run(1.125)
 campaign.tick_run(2.5)
 campaign.tick_run(-1.0)
 campaign.tick_run(INF)
 campaign.tick_run(NAN)
 check(campaign.snapshot({}).runTimeMs==3625,"timer accumulates real milliseconds without accepting invalid deltas")
 campaign.finish(_state(campaign,"enemy"))
 campaign.tick_run(10.0)
 check(campaign.snapshot({}).runTimeMs==3625,"defeat freezes clock")
 campaign.save_checkpoint(FIGHTER)
 campaign.back_to_menu()
 var resumed:=campaign.resume_trial()
 check(resumed.phase=="fight" and resumed.fighter==FIGHTER,"failed checkpoint restores the selected fighter and retries")
 check(campaign.totals.retries==1 and campaign.run_resumes==1,"failed continue counts one retry and one resume")
 check(campaign.snapshot({}).runTimeMs==3625,"failure and resumption never erase spent time")
 campaign.tick_run(0.375)
 campaign.finish(_state(campaign))
 campaign.tick_run(9.0)
 check(campaign.snapshot({}).runTimeMs==4000,"reward choice time is excluded")
 campaign.save_checkpoint(FIGHTER)
 var retained:=campaign.resume_data.duplicate(true)
 campaign.back_to_menu()
 campaign.begin_practice()
 campaign.tick_run(6.0)
 campaign.save_checkpoint(FIGHTER)
 check(campaign.run_time==0.0 and campaign.resume_data==retained,"practice neither times a formal run nor replaces its save")
 check(campaign.saves==0,"volatile test checkpoints never call persistent record writes")

func _native_roundtrip() -> void:
 var old:=ConfigFile.new()
 old.set_value("record","score",4321)
 old.set_value("record","rank","S")
 old.set_value("progress","completed_runs",1)
 old.set_value("future_section","sentinel","keep me")
 old.save(Campaign.SAVE_PATH)
 var initial:=Campaign.new()
 check(initial.best_score==4321 and initial.completed_runs==1 and initial.best_time_ms==0,"legacy progress migrates without fabricating a timed clear")
 initial.begin_trial("flow",451)
 initial.encounter()
 initial.tick_run(7.125)
 check(initial.save_checkpoint(FIGHTER),"native checkpoint write succeeds")
 var first:=Campaign.new()
 check(first.phase=="menu" and first.has_resume(),"reopening shows continue without automatically entering combat")
 check(first.resume_summary().runTimeMs==7125 and first.resume_summary().fighter==FIGHTER,"menu summary retains duration and appearance")
 first.resume_trial()
 check(first.run_seed==451 and first.selected_contract=="flow" and first.stages==initial.stages,"continue preserves seed, contracts and encounters")
 check(first.carry==initial.checkpoint and first.snapshot({}).runTimeMs==7125,"combat resumes from the same stage-opening stats and cumulative timer")
 first.tick_run(0.875)
 first.finish(_state(first))
 first.save_checkpoint(FIGHTER)
 var offers:=first.reward_options.duplicate(true)
 var cleared_carry:=first.carry.duplicate(true)
 var earned_totals:=first.totals.duplicate(true)
 var reward_resume:=Campaign.new()
 reward_resume.resume_trial()
 check(reward_resume.phase=="reward" and reward_resume.reward_options==offers,"reward screen refresh preserves all three original choices")
 check(same_numbers(reward_resume.carry,cleared_carry) and same_numbers(reward_resume.totals,earned_totals),"refresh does not grant clear supplies or statistics twice")
 check(reward_resume.choose_reward(0),"restored reward can be selected once")
 check(not reward_resume.choose_reward(0),"duplicate choice cannot skip another stage")
 reward_resume.encounter()
 reward_resume.save_checkpoint(FIGHTER)
 var advanced:=Campaign.new()
 advanced.resume_trial()
 check(advanced.stage_index==1 and advanced.reward_ids.size()==1 and advanced.reward_options.is_empty(),"refresh after choosing resumes the next encounter with exactly one boon")
 check(advanced.carry==reward_resume.carry and advanced.boons==reward_resume.boons,"all earned build properties round-trip")
 check(advanced.snapshot({}).runTimeMs==8000 and advanced.run_resumes==3,"elapsed time remains exact across both reward and fight resumes")
 var preserved:=ConfigFile.new()
 preserved.load(Campaign.SAVE_PATH)
 check(preserved.get_value("future_section","sentinel","")=="keep me","new saves preserve unrelated legacy sections")

func _recovery_and_validation() -> void:
 var primary:=ProjectSettings.globalize_path(Store.FILE_PATH)
 var backup:=FileAccess.get_file_as_string(primary+".backup")
 check(not backup.is_empty(),"a validated backup exists before any corruption")
 FileAccess.open(primary,FileAccess.WRITE).store_string("{broken")
 var recovered:=Campaign.new()
 check(recovered.save_status=="recovered" and recovered.has_resume(),"malformed primary recovers the previous valid checkpoint")
 recovered.resume_trial()
 check(Campaign._valid_payload(JSON.parse_string(FileAccess.get_file_as_string(primary)).payload),"next save replaces the bad primary with valid recovered progress")
 var valid:=recovered._save_payload()
 for field: String in ["carry","checkpoint","totals","fighter","rewardIds","contracts","elapsedMs","stageIndex","phase"]:
  var damaged:=valid.duplicate(true)
  damaged.resume[field]=["wrong type"] if field in ["carry","checkpoint","totals","fighter"] else {"wrong":"type"}
  check(not Campaign._valid_payload(damaged),"invalid resume field is safely rejected: "+field)
 var invalid:=valid.duplicate(true)
 invalid.resume.elapsedMs=INF
 check(not Campaign._valid_payload(invalid),"non-finite clock is rejected")
 invalid=valid.duplicate(true)
 invalid.resume.stageIndex=1.5
 check(not Campaign._valid_payload(invalid),"fractional stage cannot enter a nonexistent encounter")
 invalid=valid.duplicate(true)
 invalid.progress.titles=[{"invalid":"title"}]
 check(not Campaign._valid_payload(invalid),"wrong title types cannot poison UI strings")
 invalid=valid.duplicate(true)
 invalid.resume.fighter.styleId="unknown_armor"
 check(not Campaign._valid_payload(invalid),"unknown armor cannot silently resume as another character")
 invalid=valid.duplicate(true)
 invalid.resume.fighter.appearanceId="unknown_skin"
 check(not Campaign._valid_payload(invalid),"unknown appearance cannot silently resume as another skin")
 FileAccess.open(primary,FileAccess.WRITE).store_string(JSON.stringify({"schemaVersion":999,"payload":valid}))
 var future:=Campaign.new()
 var future_bytes:=FileAccess.get_file_as_string(primary)
 check(future.save_status=="incompatible","a newer schema is recognized instead of parsed as the current format")
 future._save_record()
 check(FileAccess.get_file_as_string(primary)==future_bytes,"an older client does not overwrite a future-version save")
 # Restore only the isolated fixture, never the real player directory.
 FileAccess.open(primary,FileAccess.WRITE).store_string(JSON.stringify({"schemaVersion":1,"payload":valid}))

func _records() -> void:
 var campaign:=VolatileCampaign.new()
 for run in 23:
  campaign.begin_trial("mirror",run)
  campaign.save_checkpoint(FIGHTER)
  for index in 6:
   campaign.encounter()
   campaign.tick_run(2.0+float(run)*0.1)
   campaign.finish(_state(campaign))
   if index<5: campaign.choose_reward(0)
  campaign.save_checkpoint(FIGHTER)
  check(campaign.phase=="cleared" and not campaign.has_resume(),"clear removes the resumable attempt")
  check(campaign.new_time_record==(run==0),"only an actually faster clear claims a new time record")
 check(campaign.best_time_ms==12000 and campaign.recent_runs.size()==20,"best clear survives bounded twenty-entry history")
 var entry: Dictionary=campaign.recent_runs[0]
 check(entry.styleId==FIGHTER.styleId and entry.appearanceId==FIGHTER.appearanceId and entry.seed==22,"records include armor, appearance and seed")
 check(entry.contracts==["mirror"] and entry.rewardIds.size()==5 and entry.timingRule==Campaign.TIMING_RULE and entry.rulesVersion==Campaign.RUN_RULES_VERSION,"records carry rules and build metadata for future ranking")
 var count:=campaign.recent_runs.size()
 campaign.finish(_state(campaign))
 check(campaign.recent_runs.size()==count,"duplicate victory event does not append a result twice")
 check(Campaign._valid_payload(campaign._save_payload()),"all generated timed results validate for a real save")

func _monotonic_recovery() -> void:
 var campaign:=Campaign.new()
 campaign.resume_trial()
 var old_count:=campaign.completed_runs
 var stale: String=""
 for index in range(campaign.stage_index,6):
  campaign.encounter()
  campaign.tick_run(3.0)
  campaign.save_checkpoint(FIGHTER)
  if index==5: stale=FileAccess.get_file_as_string(Store.FILE_PATH)
  campaign.finish(_state(campaign))
  if index<5: campaign.choose_reward(0)
 var completed_id:=campaign.run_id
 var best:=campaign.best_time_ms
 check(campaign.completed_runs==old_count+1 and best>0,"fixture finishes a genuine timed run")
 FileAccess.open(Store.FILE_PATH,FileAccess.WRITE).store_string(stale)
 var loaded:=Campaign.new()
 check(loaded.completed_runs==campaign.completed_runs and loaded.contract_wins==campaign.contract_wins,"older JSON cannot roll back newer legacy unlocks")
 check(loaded.best_time_ms==best and loaded.recent_runs[0].runId==completed_id,"newest timed clear survives recovery of an older JSON copy")
 check(not loaded.has_resume(),"a backed-up final fight cannot replay an already committed clear")
 var legacy:=ConfigFile.new()
 legacy.load(Campaign.SAVE_PATH)
 legacy.set_value("record","score",99999)
 legacy.set_value("record","rank","S")
 legacy.save(Campaign.SAVE_PATH)
 var newest:=Campaign.new()
 check(newest.best_score==99999 and newest.best_rank=="S","older browser score cannot overwrite a newer best score and rank")
