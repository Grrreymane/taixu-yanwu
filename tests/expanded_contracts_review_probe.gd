extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Campaign=preload("res://scripts/campaign.gd")
const STEP:=1.0/120.0
var rows:Dictionary={}
func _initialize() -> void:
 _dummy_during_activation()
 _save_roundtrip()
 _boss_reachability()
 FileAccess.open("res://build/reports/expanded-contracts-review.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print(JSON.stringify(rows))
 quit()

func _dummy_during_activation() -> void:
 var game=Combat.new()
 game.set_player_profile("night_squire")
 game.start_sparring()
 for frame in 360:
  if game.enemy.state=="attack":break
  game.update(STEP,1.0)
 var before:Dictionary={"hp":game.player.hp,"state":game.enemy.state,"attack":game.enemy.attack.get("motion",""),"warningTime":game.enemy.stateTime,"distance":absf(game.enemy.x-game.player.x)}
 var accepted:bool=game.action("ultimate")
 game.set_training(true)
 for frame in 360:game.update(STEP)
 rows.dummyDuringActivation={"legalQAccepted":accepted,"before":before,"after":{"training":game.training,"hp":game.player.hp,"state":game.enemy.state,"damageTaken":game.stats.damageTaken}}

func _save_roundtrip() -> void:
 var original_path:String=ProjectSettings.globalize_path(Campaign.SAVE_PATH)
 var original_hash:String=FileAccess.get_sha256(original_path) if FileAccess.file_exists(original_path) else "absent"
 ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
 ProjectSettings.set_setting("application/config/custom_user_dir_name","ExpandedContractsReview/%d-%d"%[OS.get_process_id(),Time.get_ticks_usec()])
 var fixture_path:String=ProjectSettings.globalize_path(Campaign.SAVE_PATH)
 if fixture_path==original_path:
  rows.saveRoundtrip={"error":"could not isolate user path"}
  return
 DirAccess.make_dir_recursive_absolute(fixture_path.get_base_dir())
 var old:=ConfigFile.new()
 old.set_value("progress","completed_runs",1)
 old.set_value("progress","contract","flow")
 old.set_value("other","preserve","kept")
 old.save(Campaign.SAVE_PATH)
 var loaded=Campaign.new()
 var migrated:Dictionary={"selected":loaded.selected_contract_ids.duplicate(),"unlocked":loaded.snapshot({}).contractsUnlocked}
 loaded.select_all_contracts()
 var again=Campaign.new()
 var complete:Dictionary={"selected":again.selected_contract_ids.duplicate(),"unlocked":again.snapshot({}).contractsUnlocked}
 var file:=ConfigFile.new()
 file.load(Campaign.SAVE_PATH)
 file.set_value("progress","contracts",["invalid","breaker","breaker",19,"flow"])
 file.save(Campaign.SAVE_PATH)
 var sanitized=Campaign.new()
 rows.saveRoundtrip={"migrated":migrated,"multiSaved":complete,"sanitized":sanitized.selected_contract_ids.duplicate(),"otherSectionPreserved":file.get_value("other","preserve","")=="kept","userSaveUntouched":(FileAccess.get_sha256(original_path) if FileAccess.file_exists(original_path) else "absent")==original_hash}

func _boss_reachability() -> void:
 var game=Combat.new()
 game.start_sparring()
 game.enemy.hp=80.0
 game.enemy.phase=2
 var events:Array=[]
 game.event.connect(func(data:Dictionary):
  if data.type=="attack" and data.side=="enemy":events.append({"time":data.time,"motion":data.motion,"red":data.unblockable,"windup":data.windup}))
 # Ordinary held guard, no manual _attack or aiRound modifications.
 for frame in 12000:
  if game.ended:break
  game.update(STEP,0.0,true)
  if events.any(func(data):return data.motion=="senti_burst"):break
 rows.bossReachability={"nativeBurstReached":events.any(func(data):return data.motion=="senti_burst"),"attackSequence":events,"hp":game.player.hp,"time":game.time}
 for connection in game.event.get_connections():game.event.disconnect(connection.callable)
