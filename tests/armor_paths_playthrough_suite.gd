extends "res://tests/trial_suite.gd"
const Paths=preload("res://scripts/armor_paths.gd")
const Rules=preload("res://scripts/armor_mechanics.gd")
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
 OS.add_logger(recorder)
 var runs:Array=[]
 for core:String in Paths.CORES:
  var fighter:Dictionary={"characterId":"fuhua","styleId":Paths.CORES[core].style,"appearanceId":"default"}
  var c=VolatileCampaign.new();c.begin_trial("mirror",105,fighter,core)
  var g=Combat.new();g.set_player_profile(fighter.styleId)
  var stages:Array=[]
  for stage in 6:
   g.start_encounter(c.encounter(),c.combat_carry())
   var result:=fight(g,core);stages.append(result)
   check(result.won,"six-stage legal-input clear: "+core+" / "+str(stage+1))
   check(result.minGap>=Combat.GAP-0.001 and result.contacts<=1,"safe spacing and readable attacks")
   if not result.won:break
   c.finish(g.snapshot())
   if stage<5:
    var selected:=-1
    for i in c.reward_options.size():
     if Paths.REWARDS.has(c.reward_options[i].id):selected=i;break
    if selected<0:selected=_reward_choice(c)
    check(c.choose_reward(selected),"legal upgrade advances stage")
  check(c.phase=="cleared","full run "+core)
  runs.append({"core":core,"stages":stages,"phase":c.phase})
  print("ARMOR_RUN ",core," ",c.phase)
 check(recorder.errors.is_empty(),"no runtime errors")
 FileAccess.open("res://build/armor-paths-playthrough.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":passed,"failures":failures,"errors":recorder.errors,"runs":runs}))
 OS.remove_logger(recorder)
 print("ARMOR_PLAYTHROUGH ",passed," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)

func fight(g,core:String) -> Dictionary:
 var elapsed:=0.0;var min_gap:=100.0;var contacts:=0
 var usage:Dictionary={}
 while not g.ended and elapsed<180.0:
  elapsed+=1.0/60.0
  var p:Dictionary=g.player;var s:Dictionary=p.armorState;var target:Dictionary=g.enemy
  var gap:float=absf(target.x-p.x)
  var movement:float=signf(target.x-p.x) if gap>1.25 else 0.0
  var guard:=false;var command:="";var threat:Dictionary={};var soon:=100.0
  for foe:Dictionary in g.enemies:
   if foe.hp<=0 or foe.state!="attack" or foe.attack.hasHit:continue
   var left:float=foe.attack.windup-foe.stateTime
   if left>=-0.02 and absf(foe.x-p.x)<=foe.attack.range+0.12 and left<soon:threat=foe;soon=left
  if g.ultimate.is_empty():
   if not threat.is_empty() and soon<=0.09:
    if threat.attack.unblockable or core=="fo_sky":command="dodge";movement=signf(p.x-threat.x)
    else:command="guard";guard=true
   elif p.state in ["idle","move","guard"]:
    if p.energy>=Rules.ultimate_cost(p,g.time) and not (p.style=="shadow_knight" and p.eclipseRemaining>0):command="ultimate"
    elif not threat.is_empty():movement=0.0
    elif gap<1.75:
     match str(p.style):
      "azure_empyrea":
       if int(s.yin)+int(s.yang)==3:command="ability"
       else:command="heavy" if core=="az_yin" or (core=="az_balance" and int(s.yang)>0 and int(s.yin)==0) else "light"
      "fenghuang":
       if p.skillCooldown<=0 and (str(s.branch)==str(p.stance) or (core=="ph_turn" and int(s.prana)==3)):command="ability"
       else:command="heavy" if int(s.prana)<3 or core=="ph_fire" else "light"
      "shadow_knight":
       if g.time<float(s.heavyUntil):command="heavy"
       elif p.skillCooldown<=0 or Rules.ability_ready(p,g.time):command="ability"
       else:command="light"
      "hawk_of_the_fog":
       if (core=="fo_flash" and g.time<float(s.linkUntil)) or (core=="fo_storm" and p.fogCharges==3):command="heavy"
       elif p.skillCooldown<=0:command="ability"
       else:command="light"
   elif p.state=="attack" and p.attack.name=="light":
    command="light" if core!="az_yin" and not (core=="az_balance" and int(s.yin)==0 and int(s.yang)>0) else "heavy"
   if not command.is_empty() and g.action(command):usage[command]=int(usage.get(command,0))+1
  g.update(1.0/60.0,movement,guard)
  var positions:Array=[float(p.x)];var live_contacts:=0
  for foe:Dictionary in g.enemies:
   if foe.hp<=0:continue
   positions.append(float(foe.x))
   if foe.state=="attack" and foe.stateTime>=foe.attack.windup and foe.stateTime<foe.attack.windup+foe.attack.active:live_contacts+=1
  contacts=maxi(contacts,live_contacts);positions.sort()
  for i in range(1,positions.size()):min_gap=minf(min_gap,positions[i]-positions[i-1])
 return {"won":g.winner=="player","seconds":elapsed,"hp":p_hp(g),"minGap":min_gap,"contacts":contacts,"actions":usage}

func p_hp(g) -> float:return g.player.hp
