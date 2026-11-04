extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Campaign=preload("res://scripts/campaign.gd")
const Paths=preload("res://scripts/night_paths.gd")
const Story=preload("res://scripts/sentience_story.gd")
class VolatileCampaign extends "res://scripts/campaign.gd":
 func _load_record() -> void:pass
var checks:=0
var failures:Array=[]
const FIGHTER={"characterId":"fuhua","styleId":"night_squire","appearanceId":"default"}

func check(value:bool,message:String) -> void:
 checks+=1
 if not value:failures.append(message);push_error(message)

func game(core:String,perks:Array=[],count:int=1):
 var g=Combat.new()
 g.set_player_profile("night_squire")
 var foes:Array=[]
 for i in count:foes.append({"id":"foe%d"%i,"hp":2000.0,"x":0.3+1.1*i})
 g.start_encounter({"playerX":-1.0,"training":true,"enemies":foes},{"hp":1000.0,"maxHp":1000.0,"energy":100.0,"nightCore":core,"nightPerkIds":perks})
 return g

func step(g,seconds:float) -> void:
 for i in ceili(seconds*120):g.update(1.0/120.0)

func hit() -> Dictionary:
 return {"name":"light","comboIndex":0,"damage":1.0,"postureDamage":1.0,"range":2.0,"push":0.0,"stun":0.2}

func parry_heavy(g) -> void:
 g.action("guard")
 g._receive(g.enemy,g.player,hit())
 step(g,0.20)
 check(g.action("heavy"),"parry K accepted")
 check(g.player.attack.get("nightImpact",false),"parry K has collision impulse")

func _initialize() -> void:
 _campaigns()
 _counter()
 _dodge()
 _chain()
 _boss()
 print("NIGHT_PATHS ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)

func _campaigns() -> void:
 var patterns:Dictionary={}
 for core:String in Paths.CORES:
  for seed_value in 12:
   var c=VolatileCampaign.new()
   c.begin_trial("mirror",seed_value,FIGHTER,core)
   check(c.night_core==core and c.run_rules_version==Campaign.NIGHT_RULES_VERSION,"new white night rules")
   check(c.combat_carry().nightCore==core,"core carried into combat")
   patterns[c.stages[5].enemies[0].bossPattern]=true
   for stage in 5:
    c.finish({"winner":"player","player":{"hp":100.0,"maxHp":120.0,"energy":45.0},"stats":{}})
    check(c.reward_options.size()==3,"three rewards")
    if stage==0:
     var previous:Array=c.reward_options.map(func(row):return row.id)
     check(c.reroll_rewards(),"special draft supports reroll")
     for row:Dictionary in c.reward_options:check(row.id not in previous,"reroll changes all three offered cards")
    var desired:=-1
    for i in c.reward_options.size():
     var id:String=c.reward_options[i].id
     if Paths.REWARDS.has(id):
      check(Paths.REWARDS[id].core==core,"no incompatible card")
      desired=i
    if stage<2:check(desired>=0,"first two clears offer both core upgrades")
    check(c.save_checkpoint(FIGHTER) and c.has_resume(),"reward checkpoint valid")
    var resumed=VolatileCampaign.new()
    resumed.resume_data=c.resume_data.duplicate(true)
    var loaded:Dictionary=resumed.resume_trial()
    check(not loaded.is_empty() and resumed.stages==c.stages and resumed.night_core==core,"core and boss persist across resume")
    check(resumed.reward_options==c.reward_options,"reward choice preserved")
    if stage==4:check(str(c.snapshot({}).nextEncounter).contains(Paths.BOSS[c.stages[5].enemies[0].bossPattern].title),"boss preview on final reward")
    check(c.choose_reward(desired if desired>=0 else 0),"reward selection")
   var choice:Dictionary=Story.decision(c.snapshot({}))
   check(choice.choiceCount==5 and choice.finalChoice,"special cards count towards existing ending")
   check(c.reward_ids.has(Paths.CORES[core].rewards[0]) and c.reward_ids.has(Paths.CORES[core].rewards[1]),"both upgrades acquired")
   c.save_checkpoint(FIGHTER)
   var bad:Dictionary=c.resume_data.duplicate(true)
   bad.nightCore="invalid"
   check(not Campaign._valid_resume(bad),"invalid core rejected")
 check(patterns.size()==3,"all three boss styles generated")
 var old=VolatileCampaign.new();old.begin_trial("mirror",11)
 old.save_checkpoint(FIGHTER)
 var restored=VolatileCampaign.new();restored.resume_data=old.resume_data.duplicate(true);restored.resume_trial()
 check(restored.night_core.is_empty() and not restored.stages[5].enemies[0].has("bossPattern"),"previous rules retain previous boss")
 old.reward_options=old._roll_rewards()
 for row:Dictionary in old.reward_options:check(not Paths.REWARDS.has(row.id),"generic trials have no special cards")

func _counter() -> void:
 for perks:Array in [[],["night_shock"]]:
  var g=game("counter",perks,3)
  parry_heavy(g);step(g,1.8)
  check(g.enemies[1].hp<2000.0,"rear target struck by collision")
  check((g.enemies[2].hp<2000.0)==("night_shock" in perks),"second collision requires upgrade")
 var g=game("counter",["night_chase"],2)
 parry_heavy(g)
 for i in 120:
  g.update(1.0/120.0)
  if float(g.player.nightChaseUntil)>g.time:break
 check(g.player.nightChaseUntil>g.time,"counter hit opens chase")
 g.player.skillCooldown=9.0
 check(g.action("ability"),"chase queued through cooldown")
 for i in 160:
  g.update(1.0/120.0)
  if g.player.attack.get("name","")=="ability":break
 check(g.player.attack.get("motion","")=="ability" and g.player.nightChaseUntil<g.time,"chase uses native E and consumes ticket")
 var plain=game("counter")
 plain.action("heavy")
 check(not plain.player.attack.get("nightImpact",false),"ordinary K cannot collide")

func _dodge() -> void:
 var g=game("dodge")
 g.action("dodge");step(g,0.5)
 check(g.player.nightResumeUntil<g.time,"empty dodge earns no continuation")
 g=game("dodge",["night_turn","night_step"])
 g._attack(g.player,"light",1)
 g.player.attack.contactOutcome="hit"
 g.player.stateTime=g.player.attack.windup+g.player.attack.active+0.05
 check(g.action("dodge"),"dodge cancels native recovery")
 g._receive(g.enemy,g.player,hit())
 check(g.player.nightResume==2,"dodge remembers next strike")
 check(g.player.nextDodgeAt<=g.time,"step upgrade restores dodge")
 var reset_time:float=g.player.nightStepReadyAt
 g._receive(g.enemy,g.player,hit())
 check(g.player.nightStepReadyAt==reset_time,"multi-hit cannot repeatedly restore dodge")
 step(g,0.45)
 check(g.action("dodge"),"step permits a second dodge")
 g._receive(g.enemy,g.player,hit())
 check(g.player.nightResume==2,"consecutive successful dodges retain third-strike continuation")
 step(g,0.45)
 check(g.action("light") and g.player.attack.comboIndex==2 and g.player.attack.motion=="light3","resume actual third native strike")
 check(g.player.nightResumeUntil<g.time,"resume ticket consumed once")
 g=game("dodge",["night_turn"])
 g.action("dodge");g._receive(g.enemy,g.player,hit());step(g,0.45)
 check(g.action("heavy") and g.player.attack.unblockable,"dodge K gains guard penetration")
 g._state(g.enemy,"guard",1.0)
 g._receive(g.player,g.enemy,g.player.attack)
 check(g.player.attack.contactOutcome=="hit","guard penetration actually hits guard")
 g=game("dodge");g.action("dodge");g._receive(g.enemy,g.player,hit());step(g,2.0)
 g.action("light")
 check(g.player.attack.comboIndex==0,"expired dodge ticket returns normal combo")

func _chain() -> void:
 for upgraded:bool in [false,true]:
  var g=game("chain",["night_open","night_finish"] if upgraded else [])
  g.player.skillCooldown=8.0
  g.action("light")
  for i in 420:
   if g.player.state=="attack" and int(g.player.combo)<2:g.action("light")
   g.update(1.0/120.0)
   if g.player.nightFlowUntil>g.time:break
  check(g.player.nightFlowUntil>g.time,"real three-hit combo earns E link")
  var frozen:float=g.player.nightFlowUntil
  g.action("pause");step(g,2.0)
  check(not g.action("ability") and g.player.nightFlowUntil==frozen,"pause freezes ticket and rejects combat input")
  g.action("pause")
  check(g.action("ability"),"flow E queues during contact freeze")
  for i in 150:
   g.update(1.0/120.0)
   if g.player.attack.get("nightFlow",false):break
  check(g.player.attack.get("nightFlow",false) and g.player.attack.motion=="ability","flow uses unchanged E motion")
  check(g.player.nightFlowUsed and g.player.skillCooldown>0.0,"flow consumes once and starts cooldown")
  var count_before:int=g.combo_count
  check(g.action("light"),"E accepts queued followup")
  for i in 240:
   g.update(1.0/120.0)
   if g.player.attack.get("name","")=="light":break
  check(g.combo_count>=count_before+3,"all three E contacts finish before followup")
  check(g.player.attack.get("comboIndex",-1)==(1 if upgraded else 0),"correct continuation with and without upgrade")
  check(g.player.nightFlowUntil<g.time and g.player.nightFlowUsed,"cannot loop another free E")
  step(g,4.0)
  check(not g.player.nightFlowUsed,"broken combo restores one flow link")
 var g=game("chain",["night_open"])
 var strike:Dictionary=g._night_attack("ability",0,false)
 strike.nightFlow=true;strike.hitIndex=2
 g._state(g.enemy,"guard",3.0)
 g._receive(g.player,g.enemy,strike)
 check(g.enemy.state=="stagger" and g.enemy.posture==20.0,"flow E last hit breaks guard")
 g=game("chain")
 g.player.nightFlowUntil=g.time+1.0
 g._state(g.player,"stagger",0.5)
 check(g.player.nightFlowUntil<g.time,"taking a hit clears pending link")

func _boss() -> void:
 for pattern:String in Paths.BOSS:
  var g=game("counter")
  var boss:Dictionary=g.enemy
  boss.boss=true;boss.bossPattern=pattern;boss.weaponCycle=Paths.BOSS[pattern].cycle.duplicate();boss.aiRound=1
  g._sentience_attack(boss,"light",0,false)
  check(boss.attack.weapon==pattern,"boss signature weapon "+pattern)
  if pattern=="spear":check(boss.attack.nativeNext==-1,"first phase spear has punishable single thrust")
  if pattern=="chain":
   check(boss.attack.nativeNext==1,"first phase chain has second sweep")
   g._sentience_attack(boss,"light",1,false)
   check(boss.attack.unblockable and boss.attack.motion=="senti_chain_2","chain followup keeps original motion and red warning")
  if pattern=="sword":
   g._sentience_attack(boss,"light",1,false)
   boss.stateTime=boss.attack.duration-0.005
   g._advance_fighter(boss,0.01)
   check(boss.state=="dodge" and boss.dodgeDirection==-boss.facing,"sword retreats after chain")
  if pattern=="spear":
   boss.stateTime=boss.attack.duration-0.005
   g._advance_fighter(boss,0.01)
   check(boss.punishUntil>=g.time+0.84,"missed spear grants real punish window")
  boss.phase=2;boss.aiRound=5
  g._sentience_attack(boss,"light",0,false)
  check(boss.attack.weapon=="burst" and boss.attack.unblockable,"each pattern retains second-phase ultimate")
