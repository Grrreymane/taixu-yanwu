extends "res://tests/victory_presentation_suite.gd"
const Builds=preload("res://scripts/practice_builds.gd")
const Paths=preload("res://scripts/armor_paths.gd")
class PracticeMain extends "res://scripts/main.gd":
 func _load_fighter_choice() -> void:fighter=FighterRoster.resolve()
 func _save_fighter_choice() -> void:pass

func _run() -> void:
 _validation()
 await _flow()
 print(JSON.stringify({"suite":"practice_builds","checks":checks,"passed":failures.is_empty(),"failures":failures}))
 quit(0 if failures.is_empty() else 1)

func _validation() -> void:
 var builds=Builds.new()
 builds.restore({"azure_empyrea":{"core":"chain","perks":["night_open"]},"unknown":{"core":"counter"},"fenghuang":{"core":"ph_turn","perks":["ph_refill","ph_refill","az_echo","missing"]}})
 _check(builds.selection("azure_empyrea").core=="","foreign armor core rejected on load")
 _check(not builds.saved.has("unknown"),"unknown armor discarded")
 _check(builds.selection("fenghuang").perks==["ph_refill"],"foreign, duplicate and missing cards discarded")
 builds.restore(null);_check(builds.saved.is_empty(),"malformed preferences recover to baseline")
 for style in Paths.STYLES:
  builds.begin(style)
  for row in Paths.options(style):
   for mask in 4:
    builds.choose("");builds.choose(row.id)
    for i in 2:
     if mask&(1<<i):builds.toggle(row.rewards[i])
    builds.toggle("unknown")
    builds.commit()
    var roundtrip=Builds.new();roundtrip.restore(JSON.parse_string(JSON.stringify(builds.saved)))
    _check(roundtrip.selection(style)==builds.selection(style),"preference round trip: %s %d"%[row.id,mask])
  builds.choose("");builds.commit()
  _check(builds.selection(style)=={"core":"","perks":[]},"baseline clears both card slots")

func _open(world,core:String,perks:Array=[]) -> void:
 world._action("practice_build")
 world._action("practice_core:"+core)
 for id in perks:world._action("practice_perk:"+id)

func _flow() -> void:
 root.size=Vector2i(1440,900)
 var world=PracticeMain.new();world.campaign=VolatileCampaign.new();root.add_child(world);world.set_process(false)
 world._action("trial");world._action("night_core:az_balance");world._action("story_skip");world._action("menu")
 var checkpoint:Dictionary=world.campaign.resume_data.duplicate(true)
 _check(not checkpoint.is_empty(),"real trial checkpoint prepared before practice")
 for style in Paths.STYLES:
  world._action("menu");world._action("select_style:"+style);world._action("practice")
  world._action("training");world._action("practice_infinite_hp")
  for row in Paths.options(style):
   for mask in 4:
    var perks:Array=[]
    for i in 2:
     if mask&(1<<i):perks.append(row.rewards[i])
    # Clear the draft first, so each mask tests independent checkboxes.
    _open(world,"");world._action("practice_core:"+row.id)
    for id in perks:world._action("practice_perk:"+id)
    world._action("practice_build_apply")
    var p:Dictionary=world.game.player
    var prefix:String="night" if style=="night_squire" else "armor"
    _check(p[prefix+"Core"]==row.id and p[prefix+"Perks"].size()==perks.size(),"applied practice loadout: %s %d"%[row.id,mask])
    for id in perks:_check(p[prefix+"Perks"].has(id),"selected exclusive is active: "+id)
    _check(p.hp==p.maxHp and p.energy==100 and p.skillCooldown==0,"fresh resources after swap")
    _check(world.game.training and world.game.infinite_hp,"dummy/infinite settings retained")
    _check(not world.game.paused and not world.practice_picker.visible and world.game.started,"apply returns directly to playable practice")
    _check(world.campaign.resume_data==checkpoint and world.campaign.reward_ids.is_empty(),"practice never edits trial resume or rewards")
  # Restart also uses that armor's remembered build.
  var selected:Dictionary=world.practice_builds.selection(style)
  world._action("restart")
  _check(world.game.player.get("nightCore","")==selected.core or world.game.player.get("armorCore","")==selected.core,"restart keeps applied core")
  _open(world,"");world._action("practice_build_apply")
  _check(world.game.player.armorCore=="" and world.game.player.nightCore=="","baseline removes all core mechanics")
 # A genuine hit produces core resources; changing builds during its native
 # attack discards the input buffer, damage marks and cooldowns together.
 world._action("menu");world._action("select_style:azure_empyrea");world._action("practice");world._action("training")
 _open(world,"az_balance",["az_echo"]);world._action("practice_build_apply")
 world.game.player.x=-0.5;world.game.enemy.x=0.5
 world.game.action("light")
 for i in 70:world.game.update(1.0/120.0)
 _check(world.game.player.armorState.yang>0,"practice core is exercised by ordinary attack contact")
 world._action("light");world._action("heavy")
 var before:Dictionary=world.game.snapshot().duplicate(true)
 _open(world,"az_yang",["az_cycle"])
 var time:float=world.game.time
 _frames(world,12)
 _check(world.game.time==time and world.game.player.state==before.player.state,"editing freezes attack and combat time")
 world._action("practice_build_cancel")
 _check(world.game.player==before.player and world.game.ultimate=={} and not world.game.paused,"cancel preserves health, resources and current native move")
 _check(world.practice_builds.selection("azure_empyrea").core=="az_balance","cancel does not save draft")
 world._action("pause");_open(world,"az_yang");world._action("practice_build_cancel")
 _check(world.game.paused,"cancel restores an already-paused battle")
 world._action("pause")
 world._action("restart");world._action("ultimate");_frames(world,4)
 _check(not world.game.ultimate.is_empty(),"real ultimate running before config")
 _open(world,"az_yin",["az_fracture"])
 var ult:Dictionary=world.game.ultimate.duplicate(true)
 _frames(world,10)
 _check(world.game.ultimate==ult,"ultimate timeline freezes while selecting")
 world._action("practice_build_apply");_frames(world,1)
 _check(world.game.ultimate.is_empty() and not world.cinematic_running and not world.knockout.active,"applying interrupts old ultimate and camera cleanly")
 _check(world.game.player.armorState.yin==0 and world.game.player.armorState.yang==0,"old resource stacks removed")
 _check(world.game.enemy.get("inkUntil",0.0)<=0 and world.game.enemy.get("lihuoUntil",0.0)<=0,"old enemy marks removed")
 # Swap while the KO gate normally rejects restart actions.
 world.game.enemy.hp=0;world.game.enemy.state="dead";world.game._check_end()
 _check(world.knockout.active,"KO gate active")
 _open(world,"");world._action("practice_build_apply")
 _check(not world.knockout.active and not world.game.ended and world.game.enemy.hp>0,"configuration applies during KO")
 _finish_fixture(world,true)
 _check(world.victory.visible,"practice victory is presented")
 _open(world,"az_yang")
 var victory_time:float=world.victory.time
 _frames(world,10)
 _check(world.victory.time==victory_time,"result presentation freezes during config")
 world._action("practice_build_apply")
 _check(not world.victory.visible and world.campaign.phase=="fight","apply from result resumes practice")
 world._action("menu");world._action("continue");world._action("story_skip")
 _check(world.game.player.armorCore=="az_balance","saved trial resumes its own core")
 world._action("practice_build");world._action("practice_core:az_yin");world._action("practice_build_apply")
 _check(not world.practice_picker.visible and world.game.player.armorCore=="az_balance","practice commands cannot alter trial")
 world.free();await process_frame
