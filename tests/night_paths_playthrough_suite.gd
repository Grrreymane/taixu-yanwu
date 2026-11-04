extends "res://tests/trial_suite.gd"
const Paths=preload("res://scripts/night_paths.gd")
const WHITE={"characterId":"fuhua","styleId":"night_squire","appearanceId":"default"}
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
 OS.add_logger(recorder)
 var seeds:Dictionary={}
 for seed_value in 60:
  var c=VolatileCampaign.new();c.begin_trial("mirror",seed_value,WHITE,"counter")
  seeds[c.stages[5].enemies[0].bossPattern]=seed_value
  if seeds.size()==3:break
 var runs:Array=[]
 for core:String in Paths.CORES:
  for pattern:String in seeds:
   var c=VolatileCampaign.new();c.begin_trial("mirror",seeds[pattern],WHITE,core)
   var g=Combat.new();g.set_player_profile("night_squire")
   var entries:Array=[]
   for stage in 6:
    g.start_encounter(c.encounter(),c.combat_carry())
    var result:=fight(g,core)
    entries.append(result)
    check(result.won,"%s / %s stage %d can clear"%[core,pattern,stage+1])
    check(result.minGap>=Combat.GAP-0.001 and result.contacts<=1,"readable contacts and physical spacing")
    if not result.won:break
    c.finish(g.snapshot())
    if stage<5:
     var selected:=-1
     for i in c.reward_options.size():
      if Paths.REWARDS.has(c.reward_options[i].id):selected=i;break
     if selected<0:selected=_reward_choice(c)
     check(c.choose_reward(selected),"legal reward advances stage")
   check(c.phase=="cleared","complete six stages "+core+" / "+pattern)
   runs.append({"core":core,"boss":pattern,"stages":entries})
   print("NIGHT_RUN ",core," / ",pattern," ",c.phase)
 check(recorder.errors.is_empty(),"no engine errors")
 var report:Dictionary={"passed":failures.is_empty(),"checks":passed,"failures":failures,"errors":recorder.errors,"runs":runs}
 FileAccess.open("res://build/night-paths-playthrough.json",FileAccess.WRITE).store_string(JSON.stringify(report))
 OS.remove_logger(recorder)
 print("NIGHT_PLAYTHROUGH ",passed," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)

func fight(g,core:String) -> Dictionary:
 var elapsed:=0.0;var min_gap:=100.0;var contacts:=0
 var mechanics:=0
 var observe:Callable=func(e:Dictionary):
  if e.type=="nightTechnique":pass
 g.event.connect(observe)
 while not g.ended and elapsed<140.0:
  elapsed+=1.0/60.0
  var p:Dictionary=g.player
  var target:Dictionary=g.enemy
  var gap:float=absf(target.x-p.x)
  var movement:float=signf(target.x-p.x) if gap>1.25 else 0.0
  var guard:=false;var command:=""
  var threat:Dictionary={};var soon:=100.0
  for foe:Dictionary in g.enemies:
   if foe.hp<=0.0 or foe.state!="attack" or foe.attack.hasHit:continue
   var left:float=foe.attack.windup-foe.stateTime
   if left>=-0.02 and absf(foe.x-p.x)<=foe.attack.range+0.12 and left<soon:threat=foe;soon=left
  if g.ultimate.is_empty():
   if not threat.is_empty() and soon<=0.09:
    if threat.attack.unblockable or core=="dodge":command="dodge";movement=signf(p.x-threat.x)
    else:command="guard";guard=true
   elif p.nightFlowUntil>g.time or p.nightChaseUntil>g.time:command="ability"
   elif p.riposteUntil>g.time and core=="counter":command="heavy"
   elif p.state in ["idle","move","guard"]:
    if p.nightResumeUntil>g.time:command="heavy" if Paths.has(p,"night_turn") and target.state=="guard" else "light"
    elif not threat.is_empty():movement=0.0
    elif p.energy>=100.0 and (core=="chain" or g.stats.parries+g.stats.dodges>=1):command="ultimate"
    elif gap<1.65:
     if (core=="counter" and g.stats.parries<1) or (core=="dodge" and g.stats.dodges<1):pass
     elif target.state=="guard":command="heavy" if core=="counter" else "ability" if p.skillCooldown<=0.0 else "heavy"
     else:command="light"
   elif p.state=="attack" and (p.attack.name=="light" or p.attack.get("nightFlow",false)):command="light"
   if not command.is_empty():g.action(command)
  g.update(1.0/60.0,movement,guard)
  if p.attack.get("nightFlow",false) or p.attack.get("nightImpact",false) or p.nightResumeUntil>g.time:mechanics+=1
  var positions:Array=[float(p.x)];var live_contacts:=0
  for foe:Dictionary in g.enemies:
   if foe.hp<=0.0:continue
   positions.append(float(foe.x))
   if foe.state=="attack" and foe.stateTime>=foe.attack.windup and foe.stateTime<foe.attack.windup+foe.attack.active:live_contacts+=1
  contacts=maxi(contacts,live_contacts)
  positions.sort()
  for i in range(1,positions.size()):min_gap=minf(min_gap,positions[i]-positions[i-1])
 g.event.disconnect(observe)
 return {"won":g.winner=="player","seconds":elapsed,"hp":g.player.hp,"mechanicFrames":mechanics,"minGap":min_gap,"contacts":contacts}
