extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const NativeCombat=preload("res://scripts/sentience_combat.gd")
const STEP:=1.0/120.0
var checks:=0
var failures: Array[String]=[]
var completed: Array[String]=[]
var evidence: Dictionary={"chains":[],"deflections":[],"redAttacks":[],"hooks":[],"pursuits":[],"aiReachability":[]}

class ErrorRecorder extends Logger:
 var errors: Array=[]
 func _log_error(_function: String,file: String,line: int,code: String,_rationale: String,_notify: bool,error_type: int,_backtraces: Array[ScriptBacktrace]) -> void:
  if error_type!=Logger.ERROR_TYPE_WARNING: errors.append({"file":file,"line":line,"code":code})
var recorder:=ErrorRecorder.new()

func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:
  failures.append(label)
  print("CHECK FAILED: ",label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
 OS.add_logger(recorder)
 var ai_only: bool="--ai-only" in OS.get_cmdline_user_args()
 if not ai_only:
  _chains()
  _parry_breaks()
  _red_attacks()
  _phase_and_sources()
  _build_hooks()
  _long_weapon_followups()
 _normal_ai_reachability()
 check(completed==(["aiReachability"] if ai_only else ["chains","parry","red","phase","hooks","pursuits","aiReachability"]),"all planned mechanism sections completed")
 if not ai_only: check(evidence.chains.size()==12 and evidence.deflections.size()==12 and evidence.redAttacks.size()==16 and evidence.hooks.size()==2 and evidence.pursuits.size()==32,"every player, facing and weapon fixture executed")
 check(evidence.aiReachability.size()==4,"normal AI was checked with both player styles and both starting facings")
 check(recorder.errors.is_empty(),"no nested engine or script errors")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
 var path: String="res://build/reports/sentience-native-ai-suite.json" if ai_only else "res://build/reports/sentience-native-combat-suite.json"
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors,"completed":completed,"evidence":evidence},"  "))
 OS.remove_logger(recorder)
 print(JSON.stringify({"suite":"sentience_native_combat","checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors.size()}))
 quit(0 if failures.is_empty() else 1)

func _fixture(profile: String="azure_empyrea",weapon: String="sword",direction: int=1,distance: float=1.25,boss: bool=true,phase: int=2,carry: Dictionary={}) -> Dictionary:
 var game=Combat.new()
 game.set_player_profile(profile)
 var supplied: Dictionary={"hp":120.0,"maxHp":120.0,"energy":30.0}
 supplied.merge(carry,true)
 game.start_encounter({"training":true,"playerX":-direction*distance*0.5,"enemies":[{"id":"native_foe","style":"sentience","type":"boss" if boss else "striker","boss":boss,"hp":300.0,"x":direction*distance*0.5,"weaponLock":weapon}]},supplied)
 game.enemy.phase=phase
 game.enemy.aiRound=1
 var events: Array=[]
 game.event.connect(func(event: Dictionary): events.append(event.duplicate(true)))
 return {"game":game,"events":events}

func _frames(game,seconds: float,guard: bool=false) -> void:
 for step in ceili(seconds/STEP): game.update(STEP,0.0,guard)

func _until(game,predicate: Callable,limit: float=5.0,guard: bool=false) -> bool:
 for step in ceili(limit/STEP):
  if predicate.call(): return true
  game.update(STEP,0.0,guard)
 return predicate.call()

func _events(events: Array,type: String) -> Array:
 return events.filter(func(event: Dictionary): return event.type==type)

func _chains() -> void:
 for profile: String in ["azure_empyrea","fenghuang"]:
  for direction in [-1,1]:
   for weapon: String in NativeCombat.WEAPONS:
    var fixture:=_fixture(profile,weapon,direction)
    var game=fixture.game
    game._attack(game.enemy,"light")
    var initial: Dictionary=game.enemy.attack.duplicate(true)
    check(initial.motion.begins_with("senti_"+weapon) and initial.range>=2.0,"native weapon starts its own motion and reach")
    check(initial.windup>=0.30 and initial.duration>initial.windup+initial.active,"weapon telegraph and recovery remain readable")
    check(_until(game,func(): return game.enemy.stateTime>=initial.windup-0.02,2.0),"initial weapon windup is reachable")
    check(game.player.hp==120.0,"damage cannot precede the contact window")
    check(_until(game,func(): return game.hit_stop>0.0,0.2),"actual collision creates impact stop")
    var frozen: Dictionary={"time":game.time,"enemyTime":game.enemy.stateTime,"playerTime":game.player.stateTime,"hp":game.player.hp,"x":game.player.x}
    game.update(0.02)
    check(game.time==frozen.time and game.enemy.stateTime==frozen.enemyTime and game.player.stateTime==frozen.playerTime and game.player.hp==frozen.hp and game.player.x==frozen.x,"weapon contact freezes all simulation values during hitstop")
    check(game.action("pause"),"weapon sequence can pause")
    var pause: Dictionary=game.snapshot().duplicate(true)
    _frames(game,0.3)
    check(game.snapshot()==pause,"pause freezes chain, damage and input clocks")
    game.action("pause")
    _frames(game,6.0)
    var attacks:=_events(fixture.events,"attack")
    var expected:=3 if weapon=="sword" else 2
    check(attacks.size()==expected and game.enemy.state=="idle","native boss chain completes its exact intended stages")
    var motions: Array=[]
    for event: Dictionary in attacks:
     motions.append(event.motion)
     check(event.sourceId=="native_foe" and event.style=="sentience" and event.weapon==weapon and event.telegraph,"every chain stage retains enemy weapon ownership and warning")
    check(game.player.style==profile and game.player.hp>0 and game.enemy.hp==300.0,"weapon attacks never inherit or overwrite the selected player style")
    evidence.chains.append({"profile":profile,"facing":direction,"weapon":weapon,"motions":motions,"damage":120.0-game.player.hp})
    var far:=_fixture(profile,weapon,direction,float(initial.range)+1.1)
    far.game._attack(far.game.enemy,"light")
    _frames(far.game,float(initial.windup)+float(initial.active)+0.04)
    check(far.game.player.hp==120.0 and _events(far.events,"hit").is_empty(),"out-of-range native swing cannot damage across the arena")
 completed.append("chains")

func _parry_breaks() -> void:
 for profile: String in ["azure_empyrea","fenghuang"]:
  for direction in [-1,1]:
   for weapon: String in NativeCombat.WEAPONS:
    var fixture:=_fixture(profile,weapon,direction)
    var game=fixture.game
    game._attack(game.enemy,"light")
    var windup: float=game.enemy.attack.windup
    _until(game,func(): return game.enemy.stateTime>=windup-0.05,2.0)
    check(game.action("guard"),"real L input can enter the perfect-defense window")
    check(_until(game,func(): return game.stats.parries==1,0.2,true),"actual native weapon contact produces a parry")
    check(game.enemy.state=="stagger" and game.player.hp==120.0 and game.enemy.attack.is_empty(),"parry interrupts the pending native chain rather than merely delaying it")
    _frames(game,2.0,true)
    check(_events(fixture.events,"attack").size()==1 and _events(fixture.events,"parry").size()==1,"cancelled native continuation never resumes after stagger")
    var parry: Dictionary=_events(fixture.events,"parry")[0] if not _events(fixture.events,"parry").is_empty() else {}
    check(parry.get("style","")==profile and parry.get("sourceId","")=="player","parry feedback belongs to defender's player style")
    evidence.deflections.append({"profile":profile,"facing":direction,"weapon":weapon,"interrupted":game.enemy.state})
 completed.append("parry")

func _red_attacks() -> void:
 for profile: String in ["azure_empyrea","fenghuang"]:
  for direction in [-1,1]:
   for weapon: String in ["chain","burst"]:
    for response: String in ["guard","dodge"]:
     var fixture:=_fixture(profile,"chain",direction)
     var game=fixture.game
     game._attack(game.enemy,"light",1 if weapon=="chain" else 0,weapon=="burst")
     var attack: Dictionary=game.enemy.attack.duplicate(true)
     check(attack.unblockable and attack.weapon==weapon,"red attack is explicitly marked and uses the intended weapon")
     _until(game,func(): return game.enemy.stateTime>=attack.windup-0.035,2.0)
     check(game.action(response),"normal input is accepted before red contact")
     _frames(game,0.13,response=="guard")
     if response=="guard":
      check(game.player.hp<120.0 and game.stats.parries==0 and _events(fixture.events,"block").is_empty(),"red warning bypasses both held and perfect-window guard")
     else:
      check(game.player.hp==120.0 and game.stats.dodges==1,"red warning is still avoidable by a correctly timed dodge")
     var warning: Dictionary=_events(fixture.events,"attack")[0]
     check(warning.telegraphColor=="red" and warning.unblockable,"red mechanical rule agrees with presentation event")
     evidence.redAttacks.append({"profile":profile,"facing":direction,"weapon":weapon,"response":response,"damage":120.0-game.player.hp})
 completed.append("red")

func _phase_and_sources() -> void:
 var fixture:=_fixture("fenghuang","sword",1,1.25,true,1)
 var game=fixture.game
 game.set_training(false)
 game.enemy.hp=154.0
 check(game.action("heavy"),"player attacks initiate actual half-health transition")
 check(_until(game,func(): return game.enemy.phase==2,1.5),"real damage below half HP starts phase two")
 check(game.enemy.state=="attack" and game.enemy.attack.weapon=="burst" and game.enemy.attack.phaseTransition and game.enemy.attack.armored,"phase two opens with the armored native burst")
 check(_events(fixture.events,"bossPhase").size()==1,"phase transition emits exactly once")
 var phase_event: Dictionary=_events(fixture.events,"bossPhase")[0] if not _events(fixture.events,"bossPhase").is_empty() else {}
 check(phase_event.get("style","")=="sentience" and phase_event.get("sourceId","")=="native_foe","phase transition retains enemy ownership")
 var health: float=game.enemy.hp
 game._receive(game.player,game.enemy,Combat.LIGHTS[0].duplicate(true))
 check(game.enemy.hp<health and game.enemy.state=="attack","ordinary hit damages armored startup without deleting the red attack")
 game._receive(game.player,game.enemy,Combat.ABILITY.duplicate(true))
 check(game.enemy.state=="stagger","ability still interrupts the armored native burst")
 game._check_boss_phase(game.enemy)
 check(_events(fixture.events,"bossPhase").size()==1,"repeated phase checking cannot repeat the opening burst")
 var rotating:=_fixture("azure_empyrea","",1,4.8,false,1)
 var seen: Dictionary={}
 for round_index in [1,2,3,4]:
  rotating.game.enemy.aiRound=round_index
  rotating.game._attack(rotating.game.enemy,"light")
  seen[rotating.game.enemy.attack.weapon]=true
 check(seen.size()==3,"ordinary enemies rotate sword, spear and chain across attack turns")
 var switches:=_events(rotating.events,"weaponChange")
 check(switches.size()==3,"weapon switches emit only when the active weapon changes")
 for event: Dictionary in switches:
  check(event.sourceId=="native_foe" and event.targetId=="player" and event.style=="sentience" and event.weapon in NativeCombat.WEAPONS,"weapon switch event cannot inherit player's Phoenix styling")
 completed.append("phase")

func _build_hooks() -> void:
 for profile: String in ["azure_empyrea","fenghuang"]:
  var fixture:=_fixture(profile,"sword",1,1.25,false,1,{"riposteBonus":0.5,"dodgeRefund":1.5,"finisherEnergy":10.0})
  var game=fixture.game
  check(game.player.riposteBonus==0.5 and game.player.dodgeRefund==1.5 and game.player.finisherEnergy==10.0,"all conditional reward fields reach actual combat")
  game._attack(game.enemy,"light")
  var windup: float=game.enemy.attack.windup
  _until(game,func(): return game.enemy.stateTime>=windup-0.05,2.0)
  game.action("guard")
  _until(game,func(): return game.stats.parries==1,0.2,true)
  check(game.action("light"),"riposte reward is tested through a real parry and queued J")
  _until(game,func(): return game.player.state=="attack",0.5)
  var base: float=game.player.attack.get("damage",0.0)
  check(bool(game.player.attack.get("parryFollowup",false)),"followup attack keeps its earned riposte tag")
  _until(game,func(): return game.enemy.hp<300.0,1.5)
  check(is_equal_approx(300.0-game.enemy.hp,base*1.5),"riposte bonus applies once to actual followup damage")
  var energy_case:=_fixture(profile,"sword",1,1.2,false,1,{"finisherEnergy":10.0,"energyGain":1.5,"energy":0.0})
  var energy_game=energy_case.game
  var finisher: Dictionary=Combat.LIGHTS[2].duplicate(true)
  energy_game._receive(energy_game.player,energy_game.enemy,finisher)
  check(is_equal_approx(energy_game.player.energy,25.5),"third-hit reward includes ordinary hit energy and uses existing energyGain")
  energy_game._receive(energy_game.player,energy_game.enemy,finisher)
  check(is_equal_approx(energy_game.player.energy,36.0),"same finisher cannot pay conditional energy twice")
  var dodge_case:=_fixture(profile,"sword",1,1.2,false,1,{"dodgeRefund":1.5})
  var dodge_game=dodge_case.game
  dodge_game.player.skillCooldown=5.0
  dodge_game._attack(dodge_game.enemy,"light")
  var before: float=dodge_game.enemy.attack.windup
  _until(dodge_game,func(): return dodge_game.enemy.stateTime>=before-0.035,2.0)
  var cd: float=dodge_game.player.skillCooldown
  dodge_game.action("dodge")
  check(dodge_game.player.skillCooldown==cd,"dodge button alone does not earn the success refund")
  _until(dodge_game,func(): return dodge_game.stats.dodges==1,0.15)
  check(dodge_game.stats.dodges==1 and dodge_game.player.skillCooldown<cd-1.49 and dodge_game.player.skillCooldown>cd-1.6,"successful evade alone receives the configured cooldown refund")
  game.reset()
  check(game.player.riposteBonus==0.0 and game.player.dodgeRefund==0.0 and game.player.finisherEnergy==0.0 and game.player.style==profile,"free reset clears trial hooks while retaining player's style")
  evidence.hooks.append({"profile":profile,"riposteDamage":base*1.5,"finisherEnergy":energy_game.player.energy,"dodgeRefund":cd-dodge_game.player.skillCooldown})
 completed.append("hooks")

func _long_weapon_followups() -> void:
 for profile: String in ["azure_empyrea","fenghuang"]:
  for direction in [-1,1]:
   for weapon: String in ["spear","chain"]:
    for mode: String in ["tip","edge","blocked","expired"]:
     var native: Dictionary=NativeCombat.attack(weapon,0,false,1)
     var fixture:=_fixture(profile,weapon,direction,float(native.range)-0.02,false,1)
     var game=fixture.game
     game.player.x=0.0
     game.enemy.x=direction*(float(native.range)-0.02)
     var opponent: Dictionary=game.enemy
     if mode=="edge":
      var shift: float=direction*(Combat.LIMIT-float(native.range)-0.03)
      game.player.x+=shift
      opponent.x+=shift
     if mode=="blocked":
      var blocker: Dictionary=game._fighter("enemy",direction*1.15,-direction)
      blocker.id="blocker"
      blocker.hp=200.0
      blocker.maxHp=200.0
      game.enemies.append(blocker)
     game._attack(opponent,"light")
     # Normal backward movement maintains spear/chain-tip spacing during
     # the telegraph; no position or health is altered after the attack starts.
     for tick in 360:
      if opponent.stateTime>=float(native.windup)-0.05: break
      var move: float=-direction if absf(opponent.x-game.player.x)<float(native.range)-0.04 else 0.0
      game.update(STEP,move,false)
     check(game.action("guard"),"long-weapon fixture enters defense through ordinary L")
     check(_until(game,func(): return game.stats.parries==1,0.2,true),"actual weapon tip makes a legal perfect-defense contact")
     var parry_gap: float=absf(opponent.x-game.player.x)
     var saved_reach: float=game.player.riposteReach
     var saved_advance: float=game.player.riposteAdvance
     check(parry_gap>=float(native.range)-0.18 and parry_gap<=float(native.range)+0.01,"parry occurs near the real weapon tip, not a close-range substitute")
     check(saved_advance>=1.55 and saved_advance<=2.6 and saved_reach<=4.8,"native parry earns the bounded long-weapon chase token")
     if mode=="expired":
      var expires: float=game.player.riposteUntil
      _until(game,func(): return game.time>expires+0.02,2.0,true)
     check(game.action("light"),"J requests a deliberate followup after real weapon parry")
     check(_until(game,func(): return game.player.state=="attack",0.5),"queued followup begins after the parry handoff")
     var attack: Dictionary=game.player.attack.duplicate(true)
     var base_range: float=2.05 if profile=="fenghuang" and mode!="expired" else 1.65 if profile=="fenghuang" else 1.75
     check(is_equal_approx(float(attack.range),base_range),"chase does not secretly enlarge short fist/counter hit range")
     var minimum_gap:=100.0
     var maximum_x:=0.0
     for tick in 190:
      game.update(STEP)
      maximum_x=maxf(maximum_x,absf(game.player.x))
      for foe: Dictionary in game.enemies:
       minimum_gap=minf(minimum_gap,absf(foe.x-game.player.x))
       maximum_x=maxf(maximum_x,absf(foe.x))
     var hits: Array=_events(fixture.events,"hit").filter(func(event: Dictionary): return event.side=="player")
     check(minimum_gap>=Combat.GAP-0.00001 and maximum_x<=Combat.LIMIT+0.00001,"weapon followup obeys real actor collision and arena boundaries")
     if mode=="expired":
      check(not bool(attack.get("parryFollowup",false)) and float(attack.get("followupAdvance",0.0))==0.0 and hits.is_empty(),"expired ordinary J neither chases nor hits a distant original target")
     else:
      check(bool(attack.get("parryFollowup",false)) and float(attack.get("followupAdvance",0.0))>0.55 and float(attack.followupAdvance)<=saved_advance,"native followup advances visibly within its specific earned allowance")
      check(float(attack.windup)<=0.55 and float(attack.windup)>0.16,"long chase adds a bounded visible preparation instead of teleporting")
      if mode=="blocked":
       check(opponent.hp==300.0 and hits.size()==1 and hits[0].targetId=="blocker","intervening body receives the punch instead of allowing pursuit through it")
      else: check(opponent.hp<300.0 and hits.size()==1 and hits[0].targetId=="native_foe","legally parried long weapon is actually reached by the earned J")
     evidence.pursuits.append({"profile":profile,"facing":direction,"weapon":weapon,"mode":mode,"parryGap":parry_gap,"sourceRange":native.range,"advance":attack.get("followupAdvance",0.0),"windup":attack.windup,"punchRange":attack.range,"targetDamage":300.0-opponent.hp,"minimumGap":minimum_gap,"maximumExtent":maximum_x})
 completed.append("pursuits")

func _normal_ai_reachability() -> void:
 var required: Array[String]=["senti_sword_1","senti_sword_2","senti_sword_3","senti_spear_1","senti_spear_2","senti_chain_1","senti_chain_2","senti_burst"]
 for profile: String in ["azure_empyrea","fenghuang"]:
  for direction in [-1,1]:
   var game=Combat.new()
   game.set_player_profile(profile)
   # Isolated low-half-health fixture: a normal J earns phase two. A larger
   # player HP budget allows observing every AI turn without manipulating
   # enemy states, attack calls, weapon locks, RNG or animation indices.
   game.start_encounter({"playerX":-direction*0.70,"enemies":[{"id":"ai_boss","name":"识之律者","type":"boss","boss":true,"maxHp":260.0,"hp":132.0,"x":direction*0.70}]},{"hp":2000.0,"maxHp":2000.0,"energy":0.0})
   var timeline: Array=[]
   var seen: Dictionary={}
   var observed: Dictionary={"phaseChanges":0,"periodicBursts":0,"blocks":0,"redHits":0}
   var observe: Callable=func(event: Dictionary):
    if event.type=="bossPhase": observed.phaseChanges+=1
    if event.type=="block" and event.get("targetId","")=="player": observed.blocks+=1
    if event.type=="hit" and event.get("sourceId","")=="ai_boss": observed.redHits+=1
    if event.type=="attack" and event.get("sourceId","")=="ai_boss":
     var row: Dictionary=event.duplicate(true)
     row.time=game.time
     row.aiRound=game.enemy.aiRound
     timeline.append(row)
     seen[str(event.get("motion",""))]=true
     if event.get("weapon","")=="burst" and not event.get("phaseTransition",false): observed.periodicBursts+=1
   game.event.connect(observe)
   check(not game.training and not game._legacy_mode and str(game.enemy.get("weaponLock","")).is_empty(),"reachability fixture uses real encounter AI with no weapon override")
   check(game.action("light"),"normal player J begins the genuine half-health trigger")
   var wall:=0.0
   while wall<65.0 and not game.ended:
    game.update(STEP,0.0,true)
    wall+=STEP
    if seen.size()>=required.size() and int(observed.periodicBursts)>=1: break
   check(game.enemy.phase==2 and int(observed.phaseChanges)==1 and game.stats.damageDealt==6.0,"ordinary player contact causes one real phase-two transition")
   check(game.player.hp>0.0 and game.enemy.hp>0.0 and not game.ended,"AI rotation is observed during an ongoing normal encounter")
   for motion: String in required: check(seen.has(motion),"normal phase-two AI can actually reach "+motion+" for "+profile+"/"+str(direction))
   check(int(observed.periodicBursts)>=1,"AI rotation reaches a later burst, not only the forced phase-opening burst")
   check(int(observed.blocks)>0 and int(observed.redHits)>0,"held defense receives real blockable contacts and red attacks during observation")
   var sword: Array=timeline.filter(func(event: Dictionary): return event.weapon=="sword")
   check(sword.size()>=3 and sword[0].motion=="senti_sword_1" and sword[1].motion=="senti_sword_2" and sword[2].motion=="senti_sword_3","actual AI sword turn preserves all three ordered stages")
   if sword.size()>=3:
    check(sword[0].aiRound==sword[1].aiRound and sword[1].aiRound==sword[2].aiRound,"sword followups belong to one continuous AI turn")
   for event: Dictionary in timeline:
    check(event.side=="enemy" and event.style=="sentience" and event.phase==2 and event.telegraph,"all naturally reached weapons keep native enemy ownership and warning data")
   evidence.aiReachability.append({"profile":profile,"facing":direction,"simTime":game.time,"wallTime":wall,"remainingHp":game.player.hp,"motions":seen.keys(),"observed":observed,"timeline":timeline})
   game.event.disconnect(observe)
 completed.append("aiReachability")
