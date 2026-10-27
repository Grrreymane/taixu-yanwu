extends "res://tests/trial_suite.gd"
## Real actions through all six stages, including every defensive boss opener.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
 OS.add_logger(recorder)
 var selected: Dictionary={}
 for seed_value in 100:
  var sample:=VolatileCampaign.new()
  sample.begin_trial("mirror",seed_value)
  var boss_stage: Dictionary=sample.stages[5]
  if boss_stage.encounterRule.id=="measure":
   var key:=str(boss_stage.arrangementId)
   if not selected.has(key): selected[key]=seed_value
  if selected.size()==3: break
 check(selected.size()==3,"find all three defensive boss weapon plans")
 var runs: Array=[]
 for plan: String in selected:
  var campaign:=VolatileCampaign.new()
  var game:=Combat.new()
  campaign.begin_trial("mirror",int(selected[plan]))
  var stages_seen: Array=[]
  for stage in 6:
   start_stage(campaign,game)
   var result:=_bot_fight(game,"aggressive")
   stages_seen.append({"stage":stage,"won":result.won,"hp":result.hp,"minGap":result.minGap,"maxContactWindows":result.maxContactWindows,"bossPhases":result.observed.bossPhases,"rule":campaign.stages[stage].encounterRule.id,"formation":campaign.stages[stage].arrangementId})
   check(result.won,"ordinary move/strike/dodge/guard actions can complete seeded encounter %d:%d"%[selected[plan],stage])
   check(result.minGap>=Combat.GAP-0.0001,"variant never crosses character collision gaps")
   check(result.maxAttacking<=2 and result.maxContactWindows<=1,"faster recovery still never overlaps live hit windows")
   if not result.won: break
   campaign.finish(game.snapshot())
   if stage<5: check(campaign.choose_reward(_reward_choice(campaign)),"earned reinforcement advances exactly one stage")
  check(campaign.phase=="cleared","defensive boss variant is beatable after five legal reinforcement choices")
  runs.append({"seed":selected[plan],"bossPlan":plan,"stages":stages_seen})
 check(recorder.errors.is_empty(),"no engine errors during actual encounters")
 var report: Dictionary={"suite":"encounter_playthrough","checks":passed,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors,"runs":runs}
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
 FileAccess.open("res://build/reports/encounter-playthrough-suite.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 OS.remove_logger(recorder)
 print(JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
