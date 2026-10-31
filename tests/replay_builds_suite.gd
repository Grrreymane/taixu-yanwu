extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Campaign=preload("res://scripts/campaign.gd")
const Builds=preload("res://scripts/reward_builds.gd")
const Story=preload("res://scripts/sentience_story.gd")
const HUD=preload("res://scripts/hud.gd")
const FIGHTER={"characterId":"fuhua","styleId":"azure_empyrea","appearanceId":"default"}
class Volatile extends "res://scripts/campaign.gd":
 func _load_record() -> void: pass
 func _save_record() -> void: pass
class Errors extends Logger:
 var messages: Array=[]
 func _log_error(_function:String,file:String,line:int,code:String,_rationale:String,_notify:bool,kind:int,_backtraces:Array[ScriptBacktrace]) -> void:
  if kind!=Logger.ERROR_TYPE_WARNING: messages.append({"file":file,"line":line,"code":code})
var checks:=0
var failures: Array=[]
var errors:=Errors.new()
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok: failures.append(message); print("FAIL ",message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
 OS.add_logger(errors)
 _drafts()
 _legacy()
 _combat()
 _mastery()
 _story()
 await _hud()
 check(errors.messages.is_empty(),"no runtime errors")
 OS.remove_logger(errors)
 var report={"checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":errors.messages}
 FileAccess.open("res://build/reports/replay-builds-suite.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)

func _win(c) -> void:
 c.finish({"winner":"player","player":{"hp":c.carry.hp,"maxHp":c.carry.maxHp,"energy":25.0},"stats":{}})
func _ids(cards: Array) -> Array:
 return cards.map(func(card): return str(card.id))
func _drafts() -> void:
 var seen: Dictionary={}
 for seed_value in 60:
  var c:=Volatile.new()
  c.begin_trial("mirror",seed_value)
  check(not c.reroll_rewards(),"cannot reroll combat")
  for stage in 5:
   _win(c)
   var cards: Array=_ids(c.reward_options)
   check(cards.size()==3 and cards[0]!=cards[1] and cards[0]!=cards[2] and cards[1]!=cards[2],"three unique alternatives")
   for id: String in cards:
    seen[id]=true
    check(id not in c.reward_ids,"owned cards excluded")
   if stage in [0,2]:
    var before_time: float=c.run_time
    check(c.reroll_rewards(),"two whole-run redraws usable")
    var redrawn: Array=_ids(c.reward_options)
    check(redrawn.all(func(id): return id not in cards),"redraw replaces all three cards")
    check(c.run_time==before_time and c.reward_ids.size()==stage,"redraw changes neither clock nor owned build")
    check(c.save_checkpoint(FIGHTER) and Campaign._valid_resume(c.resume_data),"redraw checkpoint validates")
    var loaded:=Volatile.new()
    loaded.resume_data=c.resume_data.duplicate(true)
    loaded.resume_trial()
    check(loaded.reward_options==c.reward_options and loaded.rerolls_used==c.rerolls_used,"reload preserves offers and spent redraws")
    if stage==2: check(not loaded.reroll_rewards(),"reload cannot refill rerolls")
   check(c.choose_reward(seed_value%3),"pick advances")
   var raw:=c.carry.duplicate(true)
   check(c.combat_carry()==c.combat_carry() and raw==c.carry,"derived bonuses never accumulate into base save")
  check(not c.reroll_rewards(),"no reroll outside draft")
 check(seen.size()==18,"all eighteen rewards reachable across seeds")
 var c:=Volatile.new()
 c.begin_trial("flow",11)
 c.reward_ids.assign(["swift"])
 c.stage_index=1
 c.carry.hp=18.0
 _win(c)
 var offer: Array=_ids(c.reward_options)
 check(offer.has("windstep") or offer.has("crosswind"),"continuation offered when a build can reach two")
 check(offer.has("breath") or offer.has("sustain") or offer.has("reflection") or offer.has("calm"),"low health offers a recovery choice")
 c.phase="failed"
 c.encounter()
 var before:=c.combat_carry()
 c.retry()
 check(c.rerolls_used==0 and c.combat_carry().skillCooldownScale==before.skillCooldownScale,"retry preserves build")

func _legacy() -> void:
 var c:=Volatile.new()
 c.begin_trial("mirror",44)
 c.run_rules_version=Campaign.LEGACY_RULES_VERSION
 c.stages=c._make_stages(true)
 _win(c)
 c.save_checkpoint(FIGHTER)
 # A real old checkpoint has neither new counter field.
 c.resume_data.erase("rerollsUsed")
 c.resume_data.erase("stageRerolls")
 var loaded:=Volatile.new()
 loaded.resume_data=c.resume_data.duplicate(true)
 check(Campaign._valid_resume(c.resume_data),"previous-version checkpoint accepted")
 loaded.resume_trial()
 check(loaded.stages==c.stages and loaded.reward_options==c.reward_options,"old seed keeps original difficulty and cards")
 check(loaded.combat_carry()==loaded.carry and not loaded.reroll_rewards(),"old run keeps original bonus rules")
 check(loaded.stages[5].pressureLevel==2 and not loaded.stages[5].enemies[0].has("combatTrait"),"legacy boss unchanged")
 loaded.phase="fight"
 loaded.stage_index=5
 loaded.run_time=30.0
 _win(loaded)
 check(loaded.recent_runs[0].rulesVersion==Campaign.LEGACY_RULES_VERSION,"legacy record retains its rules version")

func _game(ids: Array=[],profile: String="azure_empyrea"):
 var c:=Volatile.new()
 c.begin_trial("mirror",1)
 c.reward_ids.assign(ids)
 var game:=Combat.new()
 game.set_player_profile(profile)
 game.start_encounter({"playerX":0.0,"enemies":[{"id":"target","x":1.2,"hp":1000.0}]},c.combat_carry())
 game.player.energy=0.0
 game._ai_gap=1000.0
 return game
func _hit(game,kind: String="light",index: int=0) -> void:
 game._state(game.enemy,"idle")
 game._attack(game.player,kind,index)
 game._receive(game.player,game.enemy,game.player.attack)

func _combat() -> void:
 for profile: String in ["azure_empyrea","fenghuang","night_squire","shadow_knight","hawk_of_the_fog"]:
  var game=_game(["crosswind"],profile)
  game._state(game.player,"dodge",0.4)
  game._receive(game.enemy,game.player,Combat.LIGHTS[0].duplicate(true))
  check(game.player.dodgeStrikeUntil==4.0,"successful dodge primes next strike "+profile)
  _hit(game)
  check(is_equal_approx(float(game.player.attack.dodgeStrikeBonus),0.45) and game.player.dodgeStrikeUntil<0,"next attack consumes dodge power "+profile)
  var expected: float=game.player.attack.damage*1.45
  check(is_equal_approx(game.stats.damageDealt,expected),"dodge bonus changes actual health damage "+profile)
  _hit(game)
  check(game.player.attack.dodgeStrikeBonus==0,"following attack does not reuse dodge power "+profile)
  game=_game(["crosswind"],profile)
  game.player.dodgeStrikeUntil=0.1
  game.time=0.2
  _hit(game)
  check(game.player.attack.dodgeStrikeBonus==0,"dodge buff expires "+profile)
  game=_game(["chainflow","fist","iron"],profile)
  game.player.skillCooldown=6.0
  _hit(game,"light",2)
  var refund: float=1.8+(0.65 if profile=="night_squire" else 0.0)
  check(is_equal_approx(game.player.skillCooldown,6.0-refund),"three-card chain cooldown payoff "+profile)
  check(game.enemy.posture>=17.0,"two-card finisher breaks more posture "+profile)
  var cooldown: float=game.player.skillCooldown
  game._receive(game.player,game.enemy,game.player.attack)
  check(game.player.skillCooldown==cooldown,"multihit cannot pay finisher refund twice "+profile)
  game=_game(["focus"],profile)
  game.player.skillCooldown=5.0
  game._state(game.player,"guard")
  game.player.parryUntil=1.0
  game._receive(game.enemy,game.player,Combat.LIGHTS[0].duplicate(true))
  _hit(game,"ability")
  check(is_equal_approx(game.player.skillCooldown,3.0),"parry followup actually refunds skill "+profile)
  game=_game(["crack"],profile)
  game._break_posture(game.enemy)
  _hit(game)
  check(is_equal_approx(game.stats.damageDealt,game.player.attack.damage*1.25),"posture break creates vulnerability "+profile)
  game=_game(["afterglow","flow","risk"],profile)
  game.player.energy=100
  game._begin_ultimate()
  var duration: float=game.ultimate.duration
  game._advance_ultimate(duration+0.01)
  check(game.player.energy==12 and game.player.afterglowUntil==game.time+6,"all native ultimates grant timed aftermath and fixed refund "+profile)
  check(is_equal_approx(game.player.afterglowBonus,0.40),"three-piece burst combines with card "+profile)
 var game=_game(["sustain"])
 game.player.hp=30
 game.enemy.hp=0
 game._mark_down(game.enemy)
 check(game.player.hp==34 and game.player.energy==14,"kill pays extra heal and energy")
 game._mark_down(game.enemy)
 check(game.player.hp==34 and game.player.energy==14,"kill award cannot be paid twice")
 var c:=Volatile.new()
 c.begin_trial()
 var base:=c.carry.duplicate(true)
 var set_bonus:=Builds.carry(base,["reflection","riposte","focus","swift","windstep"])
 check(set_bonus.parryEnergy==5 and set_bonus.dodgeEnergy==6 and is_equal_approx(set_bonus.riposteBonus,0.35),"independent two-and-three piece sets coexist")
 check(c.carry==base,"set computation leaves original stats intact")

func _mastery() -> void:
 var types: Dictionary={}
 for seed_value in 24:
  var c:=Volatile.new()
  c.begin_trial("mirror",seed_value)
  check(c.stages[0].pressureLevel==0 and c.stages[5].pressureLevel==3,"pressure ramps from tutorial to boss")
  for stage: Dictionary in c.stages:
   for foe: Dictionary in stage.enemies:
    if foe.has("combatTrait"): types[foe.combatTrait]=true
 check(types.size()==4,"all three elite techniques and boss plan occur")
 for mastery: String in ["brace","pursuit","linked","boss"]:
  var game:=Combat.new()
  game.start_encounter({"enemies":[{"id":"probe","hp":1000,"elite":true,"boss":mastery=="boss","combatTrait":mastery,"weaponLock":"spear"}]})
  game.enemy.aiRound=1
  game._attack(game.enemy,"light")
  if mastery in ["brace","boss"]:
   check(game.enemy.attack.armored and game.enemy.attack.windup>=0.64,"brace is telegraphed and interruptible")
   game._receive(game.player,game.enemy,Combat.HEAVY.duplicate(true))
   check(game.enemy.state=="stagger","heavy breaks elite brace")
  if mastery=="linked": check(game.enemy.attack.nativeNext==1,"linked spear uses original second strike")

func _story() -> void:
 for id: String in Builds.NEW_IDS:
  var decision:=Story.decision({"rewardIds":["fist","flow",id],"stageIndex":3})
  check(decision.choiceCount==3 and decision.latestId==id,"new choice contributes to story route")
  check(Story.lines("reward",{"rewardIds":[id],"stageIndex":1}).size()==2,"new card has its own two-line exchange")
  check(not Story.lines("victory",{"rewardIds":[id]}).is_empty(),"new card retains authored ending")

func _hud() -> void:
 var hud:=HUD.new()
 root.add_child(hud)
 hud.process_mode=Node.PROCESS_MODE_DISABLED
 hud.set_ready(true)
 var c:=Volatile.new()
 c.begin_trial("mirror",3)
 c.stage_index=3
 c.reward_ids.assign(["fist","iron","reflection"])
 c.phase="reward"
 c.reward_options=[Campaign.REWARDS.chainflow.duplicate(true),Campaign.REWARDS.focus.duplicate(true),Campaign.REWARDS.breath.duplicate(true)]
 var state: Dictionary={"started":true,"ended":true,"player":{"hp":50,"energy":20},"enemy":{},"enemies":[],"campaign":c.snapshot({}),"fighter":{},"roster":{}}
 var actions: Array=[]
 hud.action_requested.connect(func(action): actions.append(action))
 hud.update_status(state)
 check(hud._reward_builds[0].text.contains("激活 3 招"),"card previews resulting synergy")
 check(hud._reward_builds[1].text.contains("激活 2 招"),"second family previews independently")
 for dimensions: Vector2i in [Vector2i(1440,900),Vector2i(960,540)]:
  root.size=dimensions
  await process_frame
  hud._layout()
  await process_frame
  var view:=Rect2(Vector2.ZERO,Vector2(dimensions))
  for control: Control in [hud._reward_buttons[0],hud._reward_buttons[2],hud._reward_boons,hud._reward_next,hud._reward_reroll]:
   check(view.encloses(hud._viewport_pixel_rect(control)),"reward controls fit "+str(dimensions))
  check(not hud._reward_buttons[0].get_global_rect().intersects(hud._reward_reroll.get_global_rect()),"reroll never overlaps a pick")
 hud._reward_reroll.pressed.emit()
 check(actions==["reroll_rewards"],"reroll uses its own action instead of picking slot zero")
 hud._choose_reward(0)
 hud._choose_reward(1)
 check(actions==["reroll_rewards","reward_0"],"card is committed once")
 hud.free()
