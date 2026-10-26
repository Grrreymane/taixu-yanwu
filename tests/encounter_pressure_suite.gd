extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Native=preload("res://scripts/sentience_combat.gd")
const STEP:=1.0/120.0
var checks:=0
var failures:Array[String]=[]
var evidence:Dictionary={}
class VolatileCampaign extends "res://scripts/campaign.gd":
 func _load_record() -> void:pass
 func _save_record() -> void:pass
class ErrorRecorder extends Logger:
 var errors:Array=[]
 func _log_error(_function:String,file:String,line:int,code:String,_rationale:String,_notify:bool,error_type:int,_backtraces:Array[ScriptBacktrace]) -> void:
  if error_type!=Logger.ERROR_TYPE_WARNING:errors.append({"file":file,"line":line,"code":code})
var recorder:=ErrorRecorder.new()

func check(value:bool,label:String) -> void:
 checks+=1
 if not value:
  failures.append(label)
  print("CHECK FAILED: ",label)
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
 OS.add_logger(recorder)
 _campaign()
 _retaliation()
 _turns()
 _ultimate()
 _resources_and_training()
 check(recorder.errors.is_empty(),"no nested runtime errors")
 var result={"suite":"encounter_pressure","checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors,"evidence":evidence}
 FileAccess.open("res://build/reports/encounter-pressure-suite.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 OS.remove_logger(recorder)
 print(JSON.stringify({"suite":"encounter_pressure","checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors.size()}))
 quit(0 if failures.is_empty() else 1)

func _frames(game,seconds:float,guard:bool=false) -> void:
 for frame in ceili(seconds/STEP):game.update(STEP,0.0,guard)
func _fixture(profile:String="azure_empyrea",boss:bool=true):
 var game=Combat.new()
 game.set_player_profile(profile)
 game.start_encounter({"pressureLevel":2,"playerX":0.0,"enemies":[{"id":"counter","type":"boss" if boss else "duelist","boss":boss,"elite":true,"hp":1000.0,"x":1.3}]},{"hp":1000.0,"maxHp":1000.0,"energy":0.0})
 game._ai_gap=10000.0
 return game

func _campaign() -> void:
 var slots:Dictionary={}
 for contract:String in ["mirror","flow","breaker"]:
  var contract_slots:Dictionary={}
  for seed_value in 24:
   var campaign:=VolatileCampaign.new()
   campaign.begin_trial(contract,seed_value)
   check(campaign.carry.energy==60 and campaign.carry.finisherEnergy==3,"trial starts below Q threshold but rewards completed J chain")
   var total_hp:=0.0
   var counts:Array=[]
   for stage:Dictionary in campaign.stages:
    counts.append(stage.enemies.size())
    for foe:Dictionary in stage.enemies:
     total_hp+=foe.hp
     for other:Dictionary in stage.enemies:
      if other.id!=foe.id and (foe.x-stage.playerX)*(other.x-stage.playerX)>0 and absf(foe.x-stage.playerX)>absf(other.x-stage.playerX):
       check(foe.weaponLock=="spear","rear escorts receive usable native long reach")
   check(total_hp==1000 and counts==[1,2,2,3,2,1],"encounter variety does not inflate original HP or enemy counts")
   check(campaign.stages[0].pressureLevel==0 and campaign.stages[5].pressureLevel==2,"pressure grows after introductory stages")
   var offered:Array=campaign._roll_rewards()
   check(offered==campaign._roll_rewards(),"reward order is deterministic for retry")
   var favored:String=campaign.CONTRACTS[contract].reward
   var chosen:=false
   for index in offered.size():
    if offered[index].id==favored:
     contract_slots[index]=true
     chosen=true
   check(chosen and offered.size()==3,"contract card is retained among three choices")
   var repeat:=VolatileCampaign.new()
   repeat.begin_trial(contract,seed_value)
   check(repeat.stages==campaign.stages,"same seed preserves actual weapon and flank layout")
  check(contract_slots.size()==3,"favored reward appears in all three slots across fixed seeds")
  slots[contract]=contract_slots.keys()
 var campaign:=VolatileCampaign.new()
 campaign.begin_trial("mirror",3103)
 campaign.finish({"winner":"player","player":{"hp":50.0,"maxHp":120.0,"energy":10.0},"stats":{}})
 check(campaign.carry.hp==56 and campaign.carry.energy==30,"ordinary clear supply preserves attrition and restores usable SP")
 check(campaign.snapshot({}).supply.contains("6 HP"),"displayed clear heal agrees with actual supply")
 campaign.begin_practice()
 check(campaign.carry.energy==100 and campaign.carry.finisherEnergy==0 and campaign.reward_ids.is_empty(),"free practice keeps full SP and no trial hooks")
 evidence.rewardSlots=slots

func _retaliation() -> void:
 var results:Array=[]
 for profile:String in ["azure_empyrea","fenghuang","night_squire"]:
  var game=_fixture(profile)
  for hit in 3:game._receive(game.player,game.enemy,Combat.LIGHTS[0].duplicate(true))
  check(game.enemy.escapePending and game.enemy.state=="stagger","boss schedules a response after three hits")
  game.hit_stop=0.0
  _frames(game,0.28)
  check(game.enemy.state=="stagger","response never steals confirmed hitstun")
  _frames(game,0.08)
  check(game.enemy.state=="dodge" and game.enemy.adaptiveCounter,"response uses native dodge only after full hitstun")
  game.enemy.aiRound=1
  game._attack(game.enemy,"light")
  var first:Dictionary=game.enemy.attack.duplicate(true)
  check(first.motion=="senti_sword_1" and first.windup>=0.64 and first.nativeNext==1,"retaliation keeps native boss chain and a full first warning")
  var old_hp:float=game.enemy.hp
  var old_posture:float=game.enemy.posture
  game._receive(game.player,game.enemy,Combat.LIGHTS[0].duplicate(true))
  check(game.enemy.state=="attack" and game.enemy.hp==old_hp-6 and game.enemy.posture==old_posture+5,"J deals full damage without canceling announced retaliation or gaining bonus posture")
  game.hit_stop=0.0
  for frame in 360:
   if game.enemy.attack.get("motion","")=="senti_sword_2":break
   game.update(STEP)
  check(game.enemy.state=="attack" and game.enemy.attack.motion=="senti_sword_2" and game.enemy.attack.counter,"retaliation reaches complete original next strike")
  check(is_equal_approx(float(game.enemy.attack.windup),float(Native.attack("sword",1,true,1).windup)),"native continuation warning is not accelerated")
  game.enemy.stateTime=game.enemy.attack.windup+0.02
  game._receive(game.player,game.enemy,Combat.LIGHTS[0].duplicate(true))
  check(game.enemy.state=="stagger","last native counter contact leaves a normal punishable recovery")
  for response:String in ["heavy","ability"]:
   var interrupt=_fixture(profile)
   interrupt.enemy.adaptiveCounter=true
   interrupt._attack(interrupt.enemy,"light")
   interrupt._receive(interrupt.player,interrupt.enemy,(Combat.HEAVY if response=="heavy" else Combat.ABILITY).duplicate(true))
   check(interrupt.enemy.state=="stagger" and not interrupt.enemy.escapePending,"K/E interrupt reactive armor and award a protected opening")
  var parry=_fixture(profile)
  parry.enemy.adaptiveCounter=true
  parry._attack(parry.enemy,"light")
  _frames(parry,float(parry.enemy.attack.windup)-0.05)
  parry.action("guard")
  _frames(parry,0.12,true)
  check(parry.stats.parries==1 and parry.enemy.state=="stagger" and not parry.enemy.escapePending,"perfect defense cancels full retaliation before its continuation")
  var until:float=parry.enemy.punishUntil
  for hit in 4:parry._receive(parry.player,parry.enemy,Combat.LIGHTS[0].duplicate(true))
  check(not parry.enemy.escapePending and parry.enemy.stateDuration>=until-parry.time,"parry reward cannot be stolen by adaptive escape during follow-up")
  var phase=_fixture(profile)
  phase.enemy.maxHp=200.0
  phase.enemy.hp=104.0
  phase._attack(phase.enemy,"light")
  _frames(phase,float(phase.enemy.attack.windup)-0.05)
  phase.action("guard")
  _frames(phase,0.12,true)
  var phase_opening:float=phase.enemy.punishUntil
  phase.action("light")
  for frame in 240:
   phase.update(STEP)
   if phase.enemy.phase==2:break
  check(phase.enemy.phase==2 and phase.enemy.phaseCounterPending and phase.enemy.state=="stagger" and phase.time<phase_opening,"half-health crossing during actual riposte defers the phase burst")
  for frame in 360:
   if phase.time>=phase_opening-0.02:break
   phase.update(STEP)
  check(phase.enemy.state=="stagger" and phase.enemy.phaseCounterPending,"boss keeps the entire earned follow-up opening before phase change")
  for frame in 240:
   if phase.enemy.state=="attack":break
   phase.update(STEP)
  check(phase.enemy.state=="attack" and phase.enemy.attack.phaseTransition and phase.enemy.attack.windup>=1.5 and not phase.enemy.phaseCounterPending,"deferred phase receives a fresh full red warning after protected hitstun")
  var red=Native.pressure_counter(Native.attack("chain",1,true,2),true,true)
  check(red.unblockable and red.motion=="senti_chain_2" and red.windup==0.74,"native red follow-up stays red with its original source timing")
  results.append({"profile":profile,"firstMotion":first.motion,"firstWindup":first.windup,"protectedParryUntil":until})
 evidence.retaliation=results

func _turns() -> void:
 var game=Combat.new()
 game.start_encounter({"pressureLevel":2,"playerX":0,"enemies":[{"id":"left","hp":1000,"x":-1.6,"weaponLock":"sword"},{"id":"right","hp":1000,"x":1.6,"weaponLock":"sword"},{"id":"rear","hp":1000,"x":3.4,"weaponLock":"spear"}]},{"hp":10000,"maxHp":10000,"energy":0})
 var max_states:=0
 var max_contacts:=0
 var participating:Dictionary={}
 for frame in 3600:
  var states:=0
  var contacts:=0
  for foe in game.enemies:
   if foe.state=="attack":
    states+=1
    participating[foe.id]=true
    if foe.stateTime>=foe.attack.windup and foe.stateTime<=foe.attack.windup+foe.attack.active:contacts+=1
  max_states=maxi(max_states,states)
  max_contacts=maxi(max_contacts,contacts)
  game.update(STEP,0.0,true)
 check(participating.size()==3,"front, opposite flank and rear spear all receive actual turns")
 check(max_states==2,"next full warning overlaps prior final recovery instead of waiting idly")
 check(max_contacts<=1,"two warning/recovery states never become simultaneous damage windows")
 evidence.turns={"participating":participating.keys(),"maximumAttackStates":max_states,"maximumContactWindows":max_contacts}

func _ultimate() -> void:
 var rows:Array=[]
 for profile:String in ["azure_empyrea","fenghuang"]:
  var game=Combat.new()
  game.set_player_profile(profile)
  game.start_encounter({"training":true,"playerX":0,"enemies":[{"id":"primary","hp":100,"x":1.2},{"id":"escort","hp":100,"x":2.3},{"id":"far","hp":100,"x":-4.8}]},{"energy":100})
  game._attack(game.enemies[2],"light")
  game.enemies[2].stateTime=0.2
  game.enemies[2].posture=47.0
  game.enemies[2].aiCooldown=0.39
  game.enemies[2].pushRemaining=0.12
  var remote:Dictionary=game.enemies[2].duplicate(true)
  var events:Array=[]
  game.event.connect(func(data:Dictionary):events.append(data.duplicate(true)))
  var original:Array=game.enemies.map(func(foe):return foe.x)
  check(game.action("ultimate"),"full resource still permits native ultimate")
  check(game.ultimate.targets==["primary","escort"],"ultimate retains nearby multi-target damage but excludes remote flank")
  check(game.enemies.map(func(foe):return foe.x)==original,"ultimate does not teleport or gather foes to manufacture range")
  for frame in 600:
   if game.ultimate.is_empty():break
   game.update(STEP)
  var expected:=40.0 if profile=="fenghuang" else 36.0
  check(game.enemies[0].hp==100-expected and game.enemies[1].hp==100-expected and game.enemies[2].hp==100,"only actual nearby targets take all native impact cues")
  check(game.enemies[2]==remote,"remote flank preserves entire attack, warning clock, posture, impulse and cooldown through cut-in")
  check(game.player.hp==game.player.maxHp,"paused remote attack cannot damage during cinematic")
  var impacts:Array=events.filter(func(data):return data.type=="ultimateImpact")
  check(impacts.size()==(2 if profile=="fenghuang" else 4) and impacts[-1].final,"one global impact per cue supports precise KO presentation")
  for connection in game.event.get_connections():game.event.disconnect(connection.callable)
  var lethal=Combat.new()
  lethal.set_player_profile(profile)
  lethal.start_encounter({"training":true,"playerX":0,"enemies":[{"id":"last","hp":1,"x":1.2}]},{"energy":100})
  var finals:Array=[]
  lethal.event.connect(func(data:Dictionary):
   if data.type in ["ultimateImpact","enemyDown","end"]:finals.append(data.duplicate(true)))
  lethal.action("ultimate")
  _frames(lethal,4.0)
  check(finals.filter(func(data):return data.type=="ultimateImpact" and data.final).size()==1,"final global cue fires exactly once even after earlier lethal hit")
  check(finals.filter(func(data):return data.type=="enemyDown").size()==1 and finals.filter(func(data):return data.type=="end").size()==1,"lethal cinematic does not double-count KO or clear")
  rows.append({"profile":profile,"targets":["primary","escort"],"impactCount":impacts.size(),"lethalEventOrder":finals.map(func(data):return data.type)})
  for connection in lethal.event.get_connections():lethal.event.disconnect(connection.callable)
 evidence.ultimates=rows

func _resources_and_training() -> void:
 var game=_fixture()
 game.player.skillCooldown=4.0
 game._break_posture(game.enemy)
 check(game.player.energy==8 and is_equal_approx(game.player.skillCooldown,3.3) and game.enemy.stateDuration==1.4,"posture break supplies a full punish and usable E/SP resources")
 game.enemy.hp=0
 game._mark_down(game.enemy)
 game._mark_down(game.enemy)
 check(game.player.energy==14 and is_equal_approx(game.player.skillCooldown,2.95) and game.stats.kills==1,"kill resource refund happens once per defeated enemy")
 var idle=_fixture()
 idle.enemy.escapePending=true
 idle.enemy.adaptiveCounter=true
 idle.enemy.counterPending=true
 idle.set_training(true)
 _frames(idle,3.0)
 check(idle.enemy.state=="idle" and not idle.enemy.escapePending and not idle.enemy.adaptiveCounter and not idle.enemy.counterPending,"wooden dummy toggle clears queued reactive attacks")
 idle.set_training(false)
 idle.enemy.adaptiveCounter=true
 idle._attack(idle.enemy,"light")
 idle.action("pause")
 var snapshot:Dictionary=idle.snapshot().duplicate(true)
 _frames(idle,2.0)
 check(idle.snapshot()==snapshot,"pause freezes reaction chain, clocks and resources")
