extends RefCounted

signal event(data: Dictionary)
const FenghuangCombat = preload("res://scripts/fenghuang_combat.gd")
const SentienceCombat = preload("res://scripts/sentience_combat.gd")
const LightningCombat = preload("res://scripts/lightning_combat.gd")

const LIMIT := 5.5
# Keep the body silhouettes apart when an advancing strike reaches contact.
const GAP := 0.92
const LIGHTS := [
 {"name":"light","comboIndex":0,"duration":0.66,"windup":0.18,"active":0.10,"damage":6.0,"postureDamage":12.0,"range":1.75,"push":0.13,"stun":0.32},
 {"name":"light","comboIndex":1,"duration":0.55,"windup":0.14,"active":0.10,"damage":7.0,"postureDamage":14.0,"range":1.90,"push":0.16,"stun":0.38},
 {"name":"light","comboIndex":2,"duration":0.95,"windup":0.80,"active":0.10,"damage":10.0,"postureDamage":22.0,"range":2.10,"push":0.48,"stun":0.46}
]
const HEAVY := {"name":"heavy","comboIndex":0,"duration":1.12,"windup":0.72,"active":0.12,"damage":15.0,"postureDamage":38.0,"range":2.20,"push":0.60,"stun":0.55}
const ABILITY := {"name":"ability","comboIndex":0,"duration":1.18,"windup":0.68,"active":0.12,"damage":18.0,"postureDamage":58.0,"range":2.65,"push":0.85,"stun":0.75}
# The player can link strikes sooner without shortening enemy warning windows.
const PLAYER_LIGHT_TIMING := [Vector2(0.16,0.46),Vector2(0.13,0.42),Vector2(0.40,0.72)]
# Night Squire keeps its C3 fist/kick clips; only this side-view demo's damage
# and link windows are authored here. Q is the native 1.5833 s burst activation.
const NIGHT_SKILL_COOLDOWN := 5.5
const NIGHT_BURST_DURATION := 8.0
const NIGHT_BURST_ACTIVATION := 1.583333
const NIGHT_LIGHTS := [
 {"duration":0.70,"windup":0.25,"damage":6.0,"postureDamage":12.0,"range":1.68,"push":0.07,"stun":0.32},
 {"duration":0.64,"windup":0.17,"damage":7.0,"postureDamage":14.0,"range":1.80,"push":0.09,"stun":0.36},
 {"duration":0.84,"windup":0.32,"damage":11.0,"postureDamage":25.0,"range":1.95,"push":0.42,"stun":0.50}
]
const NIGHT_BURST_LIGHTS := [
 {"duration":0.58,"windup":0.23,"damage":9.0,"postureDamage":17.0,"range":1.95,"push":0.09,"stun":0.35},
 {"duration":0.56,"windup":0.14,"damage":11.0,"postureDamage":20.0,"range":2.10,"push":0.11,"stun":0.38},
 {"duration":0.70,"windup":0.20,"damage":16.0,"postureDamage":33.0,"range":2.30,"push":0.50,"stun":0.60}
]
var player: Dictionary
var enemy: Dictionary
var enemies: Array[Dictionary] = []
var time := 0.0
var started := false
var paused := false
var ended := false
var winner := ""
var training := false
var infinite_hp := false
var _sparring := false
var hit_stop := 0.0
var ultimate: Dictionary = {}
var combo_count := 0
var combo_time := 0.0
var stats: Dictionary = {}
var _guard_held := false
var _last_move := 0.0
var _ai_cooldown := 0.8
var _ai_round := 0
var _ai_gap := 0.8
var _ai_cursor := 0
var _legacy_mode := true
var _pressure_level := 1
var _encounter_rule: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var player_profile := "azure_empyrea"
const INPUT_BUFFER_WINDOW := 0.12
const PARRY_HANDOFF := 0.075
const RIPOSTE_WINDOW := 1.0
var _buffered_action := ""
var _buffer_until := -1.0

func _init() -> void:
 reset()

func set_player_profile(profile: String) -> bool:
 if profile not in ["azure_empyrea","fenghuang","night_squire","shadow_knight","hawk_of_the_fog"] or (started and not ended): return false
 player_profile=profile
 _configure_player()
 return true

func _configure_player() -> void:
 player.style=player_profile
 player.stance="punch"
 player.counterUntil=-1.0
 player.riposteUntil=-1.0
 player.riposteReadyAt=-1.0
 player.riposteAt=-1.0
 player.riposteTarget=""
 player.riposteReach=3.0
 player.riposteAdvance=0.55
 player.skillCooldownMax=_base_skill_cooldown()
 player.nightBurstRemaining=0.0
 player.nightFocus=0
 player.nightFocusMax=3
 player.eclipseRemaining=0.0
 player.lightningHits=0
 player.fogCharges=0
 player.riposteBonus=0.0
 player.dodgeRefund=0.0
 player.finisherEnergy=0.0

func _base_skill_cooldown() -> float:
 if LightningCombat.supported(player_profile): return LightningCombat.cooldown(player_profile)
 return FenghuangCombat.SWITCH_COOLDOWN if player_profile=="fenghuang" else NIGHT_SKILL_COOLDOWN if player_profile=="night_squire" else 8.0

func _fighter(side: String, x: float, facing: int) -> Dictionary:
 return {"id":side,"side":side,"characterId":"herrscher_of_sentience" if side=="enemy" else "fuhua","style":"sentience" if side=="enemy" else player_profile,"type":"duelist","name":"识之律者" if side=="enemy" else "Fu Hua","tint":Color.WHITE,"boss":false,"elite":false,"phase":1,"x":x,"facing":facing,"hp":100.0,"maxHp":100.0,"posture":0.0,"energy":100.0 if side=="player" else 0.0,"state":"idle","stateTime":0.0,"stateDuration":0.0,"attack":{},"combo":0,"queuedCombo":false,"queuedHeavy":false,"parryUntil":-1.0,"lastContact":-10.0,"dodgeDirection":-facing,"nextDodgeAt":0.0,"skillCooldown":0.0,"skillCooldownMax":8.0,"damageMultiplier":1.0,"damageScale":1.0,"energyGain":1.0,"postureMultiplier":1.0,"skillCooldownScale":1.0,"parryHeal":0.0,"speed":1.95,"aiCooldown":0.8,"aiRound":0,"counterPending":false,"downEmitted":false}

func reset() -> void:
 _clear_buffer()
 player=_fighter("player",-1.65,1)
 _configure_player()
 enemy=_fighter("enemy",1.65,-1)
 enemies.assign([enemy])
 time=0.0
 started=false
 paused=false
 ended=false
 winner=""
 hit_stop=0.0
 ultimate={}
 combo_count=0
 combo_time=0.0
 stats={"kills":0,"parries":0,"dodges":0,"maxCombo":0,"damageTaken":0.0,"damageDealt":0.0,"elapsed":0.0}
 _guard_held=false
 _last_move=0.0
 _ai_cooldown=0.8
 _ai_round=0
 _ai_gap=0.8
 _ai_cursor=0
 _legacy_mode=true
 _sparring=false
 infinite_hp=false
 _pressure_level=1
 _encounter_rule.clear()
 _rng.seed=3103
 _emit("reset")

func start() -> void:
 # Free sparring keeps the previous training toggle and timing.
 reset()
 started=true
 _emit("start")

func start_sparring() -> void:
 # The visible opponent is the real Sentience, including her second phase;
 # use the same weapon/turn scheduler as the boss rather than the old dummy AI.
 var dummy:=training
 var keep_infinite:=infinite_hp
 start_encounter({"playerX":-1.65,"pressureLevel":1,"training":dummy,"enemies":[{"id":"sparring_sentience","type":"boss","boss":true,"name":"识之律者","hp":180.0,"x":1.65,"damageScale":1.0}]},{"hp":120.0,"maxHp":120.0,"energy":100.0})
 _sparring=true
 set_infinite_hp(keep_infinite)

func set_infinite_hp(enabled: bool) -> void:
 if not _sparring or ended: return
 infinite_hp=enabled
 if enabled:
  player.hp=player.maxHp
  for foe in enemies:
   foe.hp=foe.maxHp
   foe.practiceDamage=0.0
 _emit("practiceHealth",{"enabled":infinite_hp})

func _take_health(fighter: Dictionary, damage: float) -> void:
 # Only health changes are suppressed. Contacts, stun, posture, hit-stop and
 # damage statistics still run so an active opponent can be practised against.
 if not infinite_hp: fighter.hp=maxf(0.0,float(fighter.hp)-damage)
 elif fighter.side=="enemy": fighter.practiceDamage=float(fighter.get("practiceDamage",0.0))+damage

func start_encounter(config: Dictionary, carry: Dictionary={}) -> void:
 reset()
 _legacy_mode=false
 _pressure_level=clampi(int(config.get("pressureLevel",1)),0,4)
 _encounter_rule=config.get("encounterRule",{}).duplicate(true)
 _encounter_rule.attackIntervalScale=clampf(float(_encounter_rule.get("attackIntervalScale",1.0)),0.70,1.30)
 _encounter_rule.turnGapScale=clampf(float(_encounter_rule.get("turnGapScale",1.0)),0.70,1.30)
 training=bool(config.get("training",false))
 player.maxHp=maxf(1.0,float(carry.get("maxHp",120.0)))
 player.hp=clampf(float(carry.get("hp",player.maxHp)),0.0,player.maxHp)
 player.energy=clampf(float(carry.get("energy",100.0)),0.0,100.0)
 player.x=clampf(float(config.get("playerX",-3.25)),-LIMIT,LIMIT)
 for key in ["damageMultiplier","energyGain","postureMultiplier"]:
  player[key]=clampf(float(carry.get(key,1.0)),0.1,5.0)
 player.skillCooldownScale=clampf(float(carry.get("skillCooldownScale",1.0)),0.2,3.0)
 player.skillCooldownMax=_base_skill_cooldown()*player.skillCooldownScale
 player.parryHeal=clampf(float(carry.get("parryHeal",0.0)),0.0,player.maxHp)
 for key in ["riposteBonus","dodgeRefund","finisherEnergy"]:
  player[key]=maxf(0.0,float(carry.get(key,0.0)))
 enemies.clear()
 var used_ids: Dictionary={"player":true}
 var definitions: Array=config.get("enemies",[])
 for i in definitions.size():
  if not definitions[i] is Dictionary: continue
  var spec: Dictionary=definitions[i]
  var foe: Dictionary=_fighter("enemy",float(spec.get("x",0.8+i*1.2)),-1)
  var identity: String=str(spec.get("id","enemy_%d"%i))
  if identity.is_empty() or used_ids.has(identity): identity="enemy_%d_%d"%[i,used_ids.size()]
  used_ids[identity]=true
  foe.id=identity
  foe.type=str(spec.get("type","striker"))
  foe.boss=bool(spec.get("boss",false)) or foe.type=="boss"
  if foe.boss: foe.type="boss"
  foe.elite=bool(spec.get("elite",foe.boss or foe.type in ["guardian","duelist"]))
  foe.name=str(spec.get("name",foe.type.capitalize()))
  foe.tint=spec.get("tint",Color(1.0,0.55,0.3) if foe.boss else Color(0.45,0.7,0.9))
  foe.maxHp=maxf(1.0,float(spec.get("maxHp",spec.get("hp",100.0))))
  foe.hp=clampf(float(spec.get("hp",foe.maxHp)),1.0,foe.maxHp)
  foe.damageScale=clampf(float(spec.get("damageScale",1.0)),0.1,4.0)
  var base_speed: float=2.5 if foe.boss else 2.3 if foe.type=="striker" else 1.4 if foe.type=="guardian" else 1.8
  foe.speed=clampf(float(spec.get("speed",base_speed)),0.5,4.0)
  foe.aiCooldown=0.65-0.08*_pressure_level+i*0.18
  foe.weaponLock=str(spec.get("weaponLock",""))
  foe.tactic=str(spec.get("tactic",""))
  if foe.tactic not in ["press","guard","flank","range"]: foe.tactic=""
  foe.weaponCycle=spec.get("weaponCycle",[]).duplicate()
  foe.weapon=SentienceCombat.weapon_for(foe,1)
  foe.pressureHits=0
  foe.pressureUntil=-1.0
  foe.escapePending=false
  foe.escapeReadyAt=0.0
  foe.adaptiveCounter=false
  foe.punishUntil=-1.0
  enemies.append(foe)
 _ai_gap=_turn_gap(0.38-0.08*_pressure_level)
 _orient_duel_spawn()
 _separate_spawns()
 _refresh_target()
 # The countdown freezes simulation, so spawn facing must already be valid
 # before the first _step. In a pincer the left phantom faces right.
 for foe in enemies:
  foe.facing=1 if foe.x<=player.x else -1
 if enemy.hp>0.0: player.facing=1 if player.x<=enemy.x else -1
 started=true
 _emit("start",{"encounter":true,"enemyCount":enemies.size()})
 _check_end()

func set_training(enabled: bool) -> void:
 training=enabled
 if training and not ended:
  for foe in enemies:
   if foe.hp>0.0:
    _state(foe,"idle")
    foe.escapePending=false
    foe.adaptiveCounter=false
    foe.counterPending=false
    foe.phaseCounterPending=false
    foe.pressureHits=0
 _ai_cooldown=0.8
 _ai_gap=0.8
 _emit("training",{"enabled":training})

func action(command: String) -> bool:
 if command=="pause":
  if not started or ended: return false
  paused=not paused
  _clear_buffer()
  _emit("pause",{"paused":paused})
  return true
 if not started or paused or ended or not ultimate.is_empty(): return false
 # Preserve the visible deflection through contact freeze and its short
 # follow-through. Inputs are remembered without replacing that pose.
 if _has_riposte() and player.state in ["idle","move","guard"] and (hit_stop>0.0 or time<float(player.riposteReadyAt)) and command in ["light","heavy","ability","ultimate","dodge"]:
  return _queue_riposte(command)
 if player.state=="attack":
  var light_chain: bool=player.attack.get("name","")=="light" or bool(player.attack.get("counterLink",false))
  if light_chain and command=="heavy":
   player.queuedHeavy=true
   player.queuedCombo=false
   return true
  if light_chain and command=="light" and player.combo<2 and not player.queuedHeavy:
   player.queuedCombo=true
   return true
  # Defense can cancel recovery, but never the attack's committed startup.
  if (command in ["guard","dodge"] or (command=="ability" and player_profile in ["fenghuang","night_squire","shadow_knight","hawk_of_the_fog"] and player.skillCooldown<=0.0)) and _can_defend(player):
   if command=="dodge" and time<player.nextDodgeAt: return false
   _state(player,"idle")
  else: return _try_buffer(command)
 if not player.state in ["idle","move","guard"]: return _try_buffer(command)
 _refresh_target()
 if command in ["light","heavy"]:
  _attack(player,command)
  return true
 if command=="ability":
  if player.skillCooldown>0.0: return false
  player.skillCooldown=player.skillCooldownMax
  if player_profile=="fenghuang":
   player.stance="kick" if player.stance=="punch" else "punch"
   player.counterUntil=-1.0
  _attack(player,"ability")
  _emit("stanceChange" if player_profile=="fenghuang" else "ability",{"side":"player","sourceId":player.id,"targetId":enemy.id,"x":player.x,"facing":player.facing,"range":player.attack.range,"windup":player.attack.windup,"stance":player.get("stance","punch")})
  return true
 if command=="guard":
  if not _guard_held: player.parryUntil=time+0.13
  _guard_held=true
  if player.state!="guard": _state(player,"guard")
  return true
 if command=="dodge":
  if time<player.nextDodgeAt: return false
  player.dodgeDirection=_last_move if _last_move!=0.0 else -player.facing
  player.nextDodgeAt=time+0.72
  _state(player,"dodge",0.40)
  _emit("dodge",{"side":"player","sourceId":player.id,"x":player.x,"direction":player.dodgeDirection})
  return true
 if command=="ultimate" and player.energy>=100.0 and not (player_profile=="night_squire" and player.nightBurstRemaining>0.0):
  _begin_ultimate()
  return true
 return false

func _clear_buffer() -> void:
 _buffered_action=""
 _buffer_until=-1.0

func _has_riposte() -> bool:
 return time<float(player.get("riposteUntil",-1.0))

func _clear_riposte() -> void:
 player.riposteUntil=-1.0
 player.riposteReadyAt=-1.0
 player.riposteAt=-1.0
 player.riposteTarget=""
 player.riposteReach=3.0
 player.riposteAdvance=0.55
 player.counterUntil=-1.0

func _queue_riposte(command: String) -> bool:
 if command=="ultimate" and player_profile=="night_squire" and player.nightBurstRemaining>0.0: return false
 if command=="ultimate" and player.energy<100.0: return false
 if command=="ability" and player.skillCooldown>0.0: return false
 if command=="dodge" and player.nextDodgeAt>time: return false
 _buffered_action=command
 _buffer_until=maxf(time,float(player.riposteReadyAt))+INPUT_BUFFER_WINDOW+1.0/120.0
 return true

func _try_buffer(command: String) -> bool:
 if command=="ultimate" and player_profile=="night_squire" and player.nightBurstRemaining>0.0: return false
 if command not in ["light","heavy","ability","ultimate","dodge"]: return false
 if player.state not in ["attack","stagger","dodge"]: return false
 var remaining: float=float(player.stateDuration)-float(player.stateTime)
 if remaining<0.0 or remaining>INPUT_BUFFER_WINDOW: return false
 if player.state=="attack" and player.stateTime<player.attack.windup+player.attack.active: return false
 if command=="ultimate" and player.energy<100.0: return false
 if command=="ability" and player.skillCooldown>remaining: return false
 if command=="dodge" and player.nextDodgeAt>time+remaining: return false
 _buffered_action=command
 _buffer_until=time+INPUT_BUFFER_WINDOW+1.0/120.0
 return true

func _consume_buffer() -> void:
 if _buffered_action.is_empty(): return
 if _has_riposte() and time<float(player.riposteReadyAt): return
 if time>_buffer_until:
  _clear_buffer()
  return
 if player.state in ["idle","move","guard"]:
  var command:=_buffered_action
  _clear_buffer()
  action(command)

func update(delta: float, movement: float=0.0, guard: bool=false) -> void:
 if not started or paused or not is_finite(delta) or delta<=0.0: return
 if ended:
  var end_delta: float=minf(delta,0.25)
  var release_delta: float=maxf(0.0,end_delta-hit_stop)
  hit_stop=maxf(0.0,hit_stop-end_delta)
  # The final blow retains its physical follow-through without restarting
  # combat clocks, AI, damage, rewards or the victory transition.
  if release_delta>0.0:
   if player.hp<=0.0: _advance_impulse(player,release_delta)
   for foe in enemies:
    if foe.hp<=0.0: _advance_impulse(foe,release_delta)
  return
 var remaining: float=minf(delta,0.25)
 while remaining>0.000001 and not ended:
  var step: float=minf(remaining,1.0/120.0)
  _step(step,signf(movement),guard)
  remaining-=step

func _step(dt: float,movement: float,guard: bool) -> void:
 if hit_stop>0.0:
  hit_stop=maxf(0.0,hit_stop-dt)
  return
 time+=dt
 stats.elapsed=time
 player.skillCooldown=maxf(0.0,player.skillCooldown-dt)
 if player.eclipseRemaining>0.0:
  player.eclipseRemaining=maxf(0.0,float(player.eclipseRemaining)-dt)
  if player.eclipseRemaining==0.0: _emit("burstEnd",{"sourceId":player.id,"x":player.x})
 if player_profile=="night_squire" and player.nightBurstRemaining>0.0:
  player.nightBurstRemaining=maxf(0.0,float(player.nightBurstRemaining)-dt)
  if player.nightBurstRemaining==0.0: _emit("burstEnd",{"sourceId":player.id,"x":player.x})
 combo_time=maxf(0.0,combo_time-dt)
 if combo_time==0.0: combo_count=0
 if not ultimate.is_empty():
  _advance_ultimate(dt)
  return
 _refresh_target()
 if enemy.hp>0.0: player.facing=1 if player.x<=enemy.x else -1
 for foe in enemies:
  if foe.hp>0.0: foe.facing=1 if foe.x<=player.x else -1
 _last_move=movement
 if guard and not _guard_held: action("guard")
 _guard_held=guard
 if not guard and player.state=="guard": _state(player,"idle")
 if guard and player.state=="attack" and _can_defend(player) and not player.queuedCombo and not player.queuedHeavy: _state(player,"guard")
 if guard and player.state in ["idle","move"]: _state(player,"guard")
 if player.state in ["idle","move"]:
  var next_state: String="move" if movement!=0.0 else "idle"
  if player.state!=next_state: _state(player,next_state)
  _move(player,movement*(3.8 if player_profile=="night_squire" and player.nightBurstRemaining>0.0 else 3.6 if player_profile in ["fenghuang","night_squire"] else 3.4)*dt)
 _advance_fighter(player,dt)
 if not ended and hit_stop<=0.0: _consume_buffer()
 if ended or hit_stop>0.0: return
 for foe in enemies:
  if foe.hp>0.0: _advance_fighter(foe,dt)
  else: _advance_impulse(foe,dt)
  if ended or hit_stop>0.0: return
 if not training:
  if _legacy_mode: _ai(dt)
  else: _encounter_ai(dt)
 var all_fighters: Array=[player]
 all_fighters.append_array(enemies)
 for who in all_fighters:
  if who.hp>0.0 and time-who.lastContact>1.1 and not who.state in ["guard","stagger"]:
   who.posture=maxf(0.0,who.posture-18.0*dt)
 _check_end()

func _can_defend(who: Dictionary) -> bool:
 if who.state!="attack":return false
 var final_contact:float=who.attack.hitWindows[-1] if who.attack.has("hitWindows") else who.attack.windup
 return who.stateTime>=final_contact+float(who.attack.active)+0.04

func _advance_impulse(who: Dictionary,dt: float) -> void:
 # Contact freezes first; the body then carries the impulse across several frames.
 # Consume even the part blocked by a wall, so it cannot resume later as a shove.
 var impulse: float=float(who.get("pushRemaining",0.0))
 if absf(impulse)>0.001:
  var displacement: float=impulse*(1.0-exp(-dt*20.0))
  _move(who,displacement)
  who.pushRemaining=impulse-displacement
 else: who.pushRemaining=0.0

func _advance_fighter(who: Dictionary,dt: float) -> void:
 _advance_impulse(who,dt)
 who.stateTime+=dt
 if who.state=="attack":
  var attack: Dictionary=who.attack
  if who.stateTime<attack.windup+0.04:
   var drive: float=smoothstep(maxf(0.0,float(attack.windup)-0.12),float(attack.windup),float(who.stateTime))
   _move(who,who.facing*(0.4+1.9*drive)*float(attack.get("drive",1.0))*dt)
   if who.side=="player" and who.stateTime<=attack.windup and float(attack.get("followupAdvanceLeft",0.0))>0.0:
    for target in enemies:
     if target.id!=str(attack.get("followupTarget","")) or target.hp<=0.0: continue
     var distance: float=(float(target.x)-float(who.x))*float(who.facing)
     if distance<=0.0 or distance>float(attack.get("followupReach",3.0)): break
     var pace: float=float(attack.followupAdvance)/maxf(0.08,float(attack.windup))
     var step: float=minf(float(attack.followupAdvanceLeft),minf(pace*dt,maxf(0.0,distance-float(attack.range)+0.12)))
     _move(who,who.facing*step)
     attack.followupAdvanceLeft-=step
     break
  var window_start:float=attack.windup
  if attack.has("hitWindows"):
   var hit_index:int=int(attack.get("hitIndex",0))
   if hit_index+1<attack.hitWindows.size() and who.stateTime>=float(attack.hitWindows[hit_index+1]):
    hit_index+=1
    attack.hitIndex=hit_index
    attack.hasHit=false
   window_start=float(attack.hitWindows[hit_index])
   attack.damage=float(attack.hitDamages[hit_index])
  if not attack.hasHit and who.stateTime>=window_start and who.stateTime<=window_start+attack.active:
   var targets: Array[Dictionary]=[]
   if who.side=="player":
    var nearby: Array[Dictionary]=_living_enemies()
    var followup_target: String=str(attack.get("followupTarget",""))
    nearby.sort_custom(func(a: Dictionary,b: Dictionary)->bool:
     if not followup_target.is_empty() and (a.id==followup_target)!=(b.id==followup_target): return a.id==followup_target
     return absf(a.x-who.x)<absf(b.x-who.x))
    for target in nearby:
     var in_front: bool=(target.x-who.x)*who.facing>=0.0 or attack.name=="ability"
     if absf(who.x-target.x)<=attack.range and in_front:
      targets.append(target)
      if attack.name=="light": break
   elif absf(who.x-player.x)<=attack.range and (player.x-who.x)*who.facing>=0.0:
    targets.append(player)
   if not targets.is_empty():
    attack.hasHit=true
    for target in targets:
     _receive(who,target,attack)
     if who.state!="attack" or ended: break
  if who.state!="attack" or ended: return
  var connected: bool=str(attack.get("contactOutcome","")) in ["hit","block"]
  var link_at: float=maxf(float(attack.windup)+float(attack.active),float(attack.windup)+0.11)
  var linkable: bool=attack.name=="light" or bool(attack.get("counterLink",false))
  var can_link: bool=who.side=="player" and linkable and connected and who.stateTime>=link_at and (who.queuedCombo or who.queuedHeavy)
  var native_next: int=int(attack.get("nativeNext",-1))
  var native_link: bool=who.side=="enemy" and native_next>=0 and who.stateTime>=float(attack.duration)
  if native_link:
   _attack(who,"light",native_next)
   return
  if who.stateTime>=attack.duration or can_link:
   if who.queuedHeavy and linkable:
    _attack(who,"heavy",0,false,bool(attack.get("counterLink",false)) and attack.get("contactOutcome","")=="hit")
   elif who.queuedCombo and linkable and who.combo<2:
    var confirmed: bool=who.side=="player" and str(attack.get("contactOutcome",""))=="hit"
    _attack(who,"light",who.combo+1,false,confirmed)
   else:
    _state(who,"idle")
    if who.side=="enemy":
     _ai_cooldown=0.78+_rng.randf()*0.35
     who.aiCooldown=float(attack.get("recovery",1.0))+_rng.randf()*0.25 if _legacy_mode else 0.38-0.06*_pressure_level+float(attack.get("recovery",0.85))*0.35+_rng.randf()*0.12
     if who.boss and not _legacy_mode:
      who.aiCooldown=maxf(0.12,0.26-0.045*_pressure_level+float(attack.get("recovery",0.85))*0.18+_rng.randf()*0.06)
     if not _legacy_mode: who.aiCooldown=_enemy_recovery(who,float(who.aiCooldown))
     if _legacy_mode: _ai_gap=maxf(_ai_gap,0.5)
 elif who.state=="dodge":
  var window: float=0.27 if who.side=="player" else 0.18
  var speed: float=6.4 if who.side=="player" else 2.8
  if who.stateTime<=window: _move(who,who.dodgeDirection*speed*dt)
  if who.stateTime>=who.stateDuration:
   _state(who,"idle")
   if who.side=="enemy" and who.counterPending: who.aiCooldown=0.05
 elif who.state=="stagger":
  if who.stateTime>=who.stateDuration:
   _state(who,"idle")
   if who.side=="enemy":
    if bool(who.get("phaseCounterPending",false)):_begin_phase_counter(who)
    else:_try_pressure_escape(who)
 elif who.side=="enemy" and who.state=="guard" and who.stateTime>=who.stateDuration:
  _state(who,"idle")
  _ai_cooldown=0.35
  who.aiCooldown=0.05 if bool(who.get("adaptiveCounter",false)) else 0.35

func _attack(who: Dictionary,kind: String,index: int=0,phase_entry: bool=false,confirmed_chain: bool=false) -> void:
 if who.side=="enemy" and who.get("style","")=="sentience":
  _sentience_attack(who,kind,index,phase_entry)
  return
 var counter: bool=who.counterPending
 var parry_followup: bool=who.side=="player" and _has_riposte()
 var followup_target: String=str(player.riposteTarget) if parry_followup else str(who.attack.get("followupTarget","")) if who.side=="player" and confirmed_chain else ""
 var followup_reach: float=float(player.get("riposteReach",3.0)) if parry_followup else float(who.attack.get("followupReach",3.0))
 var after_counter: bool=who.side=="player" and bool(who.attack.get("counterLink",false))
 var night_continuation:bool=who.state=="attack" and who.attack.has("nightBurst") and (index>0 or (kind=="heavy" and who.attack.get("name","")=="light"))
 var night_chain_burst:bool=bool(who.attack.get("nightBurst",false)) if night_continuation else float(who.get("nightBurstRemaining",0.0))>0.0
 var eclipse_continuation:bool=who.state=="attack" and who.attack.has("eclipse") and (index>0 or (kind=="heavy" and who.attack.get("name","")=="light"))
 var eclipse_chain:bool=bool(who.attack.get("eclipse",false)) if eclipse_continuation else float(who.get("eclipseRemaining",0.0))>0.0
 who.counterPending=false
 _state(who,"attack")
 who.combo=index
 who.attack=(ABILITY if kind=="ability" else HEAVY if kind=="heavy" else LIGHTS[index]).duplicate(true)
 if who.side=="player":
  if player_profile=="fenghuang":
   var use_counter: bool=kind=="light" and index==0 and time<float(who.get("counterUntil",-1.0))
   who.attack=FenghuangCombat.attack(kind,index,str(who.stance),use_counter)
   if use_counter: who.counterUntil=-1.0
  elif player_profile=="night_squire":
   who.attack=_night_attack(kind,index,night_chain_burst)
   if kind in ["light","heavy"] and int(who.nightFocus)>0:
    who.nightFocus-=1
    who.attack.damage*=1.18
    who.attack.postureDamage*=1.30
    who.attack.nightFocused=true
  elif LightningCombat.supported(player_profile):
   who.attack=LightningCombat.attack(player_profile,kind,index,eclipse_chain)
   if player_profile=="hawk_of_the_fog" and kind=="heavy" and int(who.fogCharges)>0:
    who.attack.damage+=5.0*int(who.fogCharges)
    who.attack.postureDamage+=7.0*int(who.fogCharges)
    who.attack.fogCharges=who.fogCharges
    who.fogCharges=0
  elif kind=="light":
   who.attack.windup=PLAYER_LIGHT_TIMING[index].x
   who.attack.duration=PLAYER_LIGHT_TIMING[index].y
  elif kind=="heavy":
   who.attack.windup=0.50
   who.attack.duration=0.88
  who.attack.parryFollowup=parry_followup
  who.attack.followupTarget=followup_target
  who.attack.followupReach=followup_reach
  who.attack.counterLink=str(who.attack.get("motion","")).begins_with("counter_")
  if after_counter and kind=="light" and index==1 and player_profile=="fenghuang":
   # Both native counter clips are also the ordinary second-strike clips.
   # Follow with the alternate first strike rather than rewind the same hit.
   who.attack.motion="kick_light1" if who.stance=="kick" else "light1"
  if parry_followup:
   # Reuse the native strike and contact pose; trim the repeated preparation
   # after the parry has already brought the hands into an attacking position.
   var cap: float=0.19 if who.attack.counterLink else 0.16 if kind=="light" else 0.28 if kind=="heavy" else 0.30
   var before: float=who.attack.windup
   who.attack.windup=minf(before,cap)
   who.attack.duration-=before-float(who.attack.windup)
   if who.attack.has("hitWindows"):
    for window in who.attack.hitWindows.size(): who.attack.hitWindows[window]-=before-float(who.attack.windup)
   for target in enemies:
    if target.id==str(player.riposteTarget) and kind=="light":
     # A blocked long-reaching attack may leave the short fist just outside
     # reach. Close only that small gap during startup, with normal collision.
     var gap: float=absf(float(target.x)-float(who.x))+absf(float(target.get("pushRemaining",0.0)))
     who.attack.followupAdvance=minf(float(player.get("riposteAdvance",0.55)),maxf(0.0,gap-float(who.attack.range)+0.12))
     who.attack.followupAdvanceLeft=who.attack.followupAdvance
     # Deflecting the tip of a native spear earns a short chase, not extra
     # hitbox range. Give the visible approach time and keep collision active.
     if who.attack.followupAdvance>0.55:
      var added: float=minf(0.34,(float(who.attack.followupAdvance)-0.55)*0.17)
      who.attack.windup+=added
      who.attack.duration+=added
    if target.id==str(player.riposteTarget) and target.state=="stagger" and is_equal_approx(float(target.get("parryOpening",-2.0)),float(player.riposteAt)):
     target.stateDuration=maxf(float(target.stateDuration),float(target.stateTime)+float(who.attack.windup)+0.04)
   _clear_riposte()
  if kind=="heavy" and confirmed_chain:
   var before: float=who.attack.windup
   who.attack.windup=minf(before,0.32)
   who.attack.duration-=before-float(who.attack.windup)
  if kind=="light" and index==2 and confirmed_chain:
   # Preserve the original follow-through length and source contact pose.
   var old_windup: float=who.attack.windup
   who.attack.windup=minf(old_windup*0.65,0.26)
   who.attack.duration-=old_windup-float(who.attack.windup)
  if kind=="light" and index<2:
   var next_windup: float=FenghuangCombat.attack("light",index+1,str(who.stance)).windup if player_profile=="fenghuang" else _night_attack("light",index+1,night_chain_burst).windup if player_profile=="night_squire" else PLAYER_LIGHT_TIMING[index+1].x
   if LightningCombat.supported(player_profile): next_windup=LightningCombat.attack(player_profile,"light",index+1,float(who.eclipseRemaining)>0.0).windup
   if index==1: next_windup=minf(next_windup*0.65,0.26)
   # A confirmed chain holds through the next contact, including one frame
   # of scheduling margin. No extra damage or enemy warning changes.
   who.attack.stun=maxf(float(who.attack.stun),maxf(float(who.attack.active),0.11)+next_windup+0.035)
 who.attack.hasHit=false
 who.attack.contactOutcome=""
 who.attack.unblockable=false
 who.attack.armored=false
 who.attack.phaseTransition=phase_entry
 if who.side=="enemy":
  var extra: float=0.22 if kind=="heavy" else 0.12
  who.attack.damage=(12.0 if kind=="heavy" else 7.0)*who.damageScale
  if _legacy_mode:
   who.queuedCombo=kind=="light" and index==0 and _ai_round%2==1
  else:
   extra=0.24 if kind=="light" else 0.18
   if who.type=="striker":
    extra=0.18 if kind=="light" else 0.2
    who.attack.damage*=0.88
    who.queuedCombo=kind=="light" and index==0
   elif who.type=="guardian":
    who.attack.damage*=1.15
    who.attack.postureDamage*=1.35
   elif who.type=="duelist" and counter:
    extra=0.22
    who.attack.damage*=1.1
    who.attack.range=2.1
   elif who.boss:
    who.attack.damage*=1.2 if who.phase==2 else 1.05
    who.queuedCombo=kind=="light" and index==0 and who.phase==2
    if kind=="heavy" and who.phase==2:
     extra=0.36
     who.attack.range=2.65
     who.attack.postureDamage=65.0
     who.attack.unblockable=true
     who.attack.armored=true
     if phase_entry:
      extra+=0.25
      who.phaseCounterPending=false
   who.attack.counter=counter
  who.attack.windup+=extra
  who.attack.duration+=extra
  _ai_gap=maxf(_ai_gap,0.55)
 who.stateDuration=who.attack.duration
 _emit("attack",{"side":who.side,"sourceId":who.id,"targetId":enemy.id if who.side=="player" else player.id,"x":who.x,"facing":who.facing,"name":who.attack.name,"motion":who.attack.get("motion",""),"combo":index,"duration":who.attack.duration,"windup":who.attack.windup,"range":who.attack.range,"parryFollowup":parry_followup,"chaseAdvance":who.attack.get("followupAdvance",0.0),"telegraph":who.side=="enemy","boss":who.boss,"elite":who.elite,"enemyType":who.type,"phase":who.phase,"unblockable":who.attack.unblockable,"armored":who.attack.armored,"phaseTransition":phase_entry,"telegraphColor":"red" if who.attack.unblockable else "amber"})

func _night_attack(kind:String,index:int,burst:bool) -> Dictionary:
 var data:Dictionary
 if kind=="ability":
  data={"name":"ability","duration":1.25,"windup":0.40,"damage":6.0,"postureDamage":18.0,"range":2.30,"push":0.10,"stun":0.48,"motion":"ability","drive":1.65,
   "hitWindows":[0.40,0.60,0.833333],"hitDamages":[6.0,7.0,10.0],"hitIndex":0}
 elif kind=="heavy":
  data={"name":"heavy","duration":1.05 if burst else 0.75,"windup":0.52 if burst else 0.25,"damage":24.0 if burst else 15.0,"postureDamage":50.0 if burst else 36.0,"range":2.40 if burst else 2.05,"push":0.56 if burst else 0.40,"stun":0.64 if burst else 0.56,"motion":"kick_heavy" if burst else "heavy"}
 else:
  data=(NIGHT_BURST_LIGHTS[index] if burst else NIGHT_LIGHTS[index]).duplicate(true)
  data.name="light"
  data.motion=("kick_light" if burst else "light")+str(index+1)
 data.comboIndex=index
 data.active=0.09
 data.nightBurst=burst
 data.nightFocused=false
 return data

func _sentience_attack(who: Dictionary,kind: String,index: int,phase_entry: bool) -> void:
 var counter_chain: bool=index>0 and bool(who.attack.get("pressureChain",false))
 var adaptive_counter: bool=counter_chain or (bool(who.get("adaptiveCounter",false)) and index==0 and not phase_entry)
 var previous_weapon: String=str(who.get("weapon","sword"))
 var round_index: int=_ai_round if _legacy_mode else int(who.aiRound)
 var weapon: String=previous_weapon if index>0 else SentienceCombat.weapon_for(who,round_index)
 if phase_entry: weapon="burst"
 # Explicit heavy requests retain a readable heavy option in training/tests.
 elif kind=="heavy" and weapon=="sword": weapon="chain"
 who.counterPending=false
 _state(who,"attack")
 who.weapon=weapon
 who.combo=index
 who.attack=SentienceCombat.attack(weapon,index,who.boss,who.phase,phase_entry)
 if adaptive_counter:
  # A complete source strike with an explicit amber warning. Only its
  # startup resists repeated J; K, E, a parry or posture break still stop it.
  who.attack=SentienceCombat.pressure_counter(who.attack,who.boss,counter_chain)
  who.adaptiveCounter=false
 who.attack.damage*=who.damageScale
 who.attack.hasHit=false
 who.attack.contactOutcome=""
 who.stateDuration=who.attack.duration
 if phase_entry: who.phaseCounterPending=false
 _ai_gap=maxf(_ai_gap,_turn_gap(0.55))
 if previous_weapon!=weapon:
  _emit("weaponChange",{"side":"enemy","sourceId":who.id,"targetId":player.id,"x":who.x,"facing":who.facing,"weapon":weapon,"label":who.attack.label})
 _emit("attack",{"side":"enemy","sourceId":who.id,"targetId":player.id,"x":who.x,"facing":who.facing,
  "name":who.attack.name,"motion":who.attack.motion,"weapon":weapon,"label":who.attack.label,"combo":index,
  "duration":who.attack.duration,"windup":who.attack.windup,"range":who.attack.range,"contactHeight":who.attack.get("contactHeight",1.3),"telegraph":true,
  "boss":who.boss,"elite":who.elite,"enemyType":who.type,"phase":who.phase,
  "unblockable":who.attack.unblockable,"armored":who.attack.armored,"phaseTransition":phase_entry,"counter":adaptive_counter,
  "telegraphColor":"red" if who.attack.unblockable else "amber"})

func _receive(attacker: Dictionary,defender: Dictionary,attack: Dictionary) -> void:
 # Runtime attacks are mutable instances; callers may also supply a template.
 if attack.is_read_only(): attack=attack.duplicate(true)
 if defender.hp<=0.0 or defender.state=="ultimate": return
 if defender.state=="dodge" and defender.stateTime<=0.23:
  attack.contactOutcome="evade"
  if defender.side=="player":
   stats.dodges+=1
   defender.skillCooldown=maxf(0.0,defender.skillCooldown-float(defender.get("dodgeRefund",0.0)))
  _emit("evade",{"side":defender.side,"sourceId":attacker.id,"targetId":defender.id,"x":defender.x,"direction":defender.dodgeDirection})
  return
 defender.lastContact=time
 var force_direction: float=signf(float(defender.x)-float(attacker.x))
 if force_direction==0.0: force_direction=float(attacker.facing)
 var contact_x: float=float(defender.x)-force_direction*0.22
 var posture_damage: float=attack.postureDamage*(attacker.postureMultiplier if attacker.side=="player" else 1.0)
 if defender.state=="guard":
  if defender.parryUntil>=time and not bool(attack.get("unblockable",false)):
   attack.contactOutcome="parry"
   defender.posture=maxf(0.0,defender.posture-18.0)
   _gain_energy(defender,12.0)
   attacker.posture=minf(100.0,attacker.posture+35.0*(defender.postureMultiplier if defender.side=="player" else 1.0))
   attacker.lastContact=time
   _state(attacker,"stagger",0.70 if not _legacy_mode else 0.58)
   attacker.parryOpening=time
   attacker.escapePending=false
   attacker.pressureHits=0
   attacker.punishUntil=time+1.35
   if defender.side=="player":
    _clear_buffer()
    stats.parries+=1
    defender.hp=minf(defender.maxHp,defender.hp+defender.parryHeal)
    defender.riposteUntil=time+RIPOSTE_WINDOW
    defender.riposteReadyAt=time+PARRY_HANDOFF
    defender.riposteAt=time
    defender.riposteTarget=attacker.id
    if str(attack.get("motion","")).begins_with("senti_"):
     defender.riposteReach=minf(4.8,maxf(3.0,float(attack.range)+0.45))
     defender.riposteAdvance=2.6
    if player_profile=="fenghuang": defender.counterUntil=time+1.0
   _ai_gap=maxf(_ai_gap,0.7)
   attacker.pushRemaining=-force_direction*0.18
   hit_stop=0.09
   _emit("parry",{"side":defender.side,"targetSide":attacker.side,"sourceId":defender.id,"targetId":attacker.id,"x":(defender.x+attacker.x)*0.5,"contactX":contact_x,"facing":-force_direction,"hitStop":hit_stop})
   if attacker.posture>=100.0: _break_posture(attacker)
   return
  elif not attack.get("unblockable",false):
   attack.contactOutcome="block"
   defender.posture=minf(100.0,defender.posture+posture_damage)
   _gain_energy(defender,2.0)
   defender.pushRemaining=force_direction*attack.push*0.35
   hit_stop=0.07 if attack.name in ["heavy","ability"] else 0.05
   _emit("block",{"side":defender.side,"targetSide":defender.side,"sourceId":attacker.id,"targetId":defender.id,"x":defender.x,"contactX":contact_x,"contactHeight":attack.get("contactHeight",1.3),"facing":force_direction,"hitStop":hit_stop,"heavy":attack.name in ["heavy","ability"],"name":attack.name,"skill":attack.name=="ability"})
   if defender.posture>=100.0: _break_posture(defender)
   return
 var riposte_bonus: float=1.0+float(attacker.get("riposteBonus",0.0)) if attacker.side=="player" and bool(attack.get("parryFollowup",false)) else 1.0
 var resistance: float=0.8 if defender.side=="player" and float(defender.get("eclipseRemaining",0.0))>0.0 else 1.0
 var damage: float=minf(defender.hp,attack.damage*(attacker.damageMultiplier if attacker.side=="player" else 1.0)*riposte_bonus*resistance)
 attack.contactOutcome="hit"
 # A boss's announced retaliation owns its native chain until the final
 # contact. K/E, perfect defense and posture breaks still interrupt it; the
 # last strike's recovery remains completely open to ordinary attacks.
 var armor_window: bool=defender.state=="attack" and (defender.stateTime<float(defender.attack.get("windup",0.0)) or (bool(defender.attack.get("pressureChain",false)) and int(defender.attack.get("nativeNext",-1))>=0))
 var armored: bool=armor_window and defender.attack.get("armored",false) and attack.name!="ability" and not (attack.name=="heavy" and defender.attack.get("heavyBreaksArmor",false))
 _take_health(defender,damage)
 if attacker.side=="player" and attacker.style=="shadow_knight" and float(attacker.eclipseRemaining)>0.0:
  attacker.lightningHits+=1
  if int(attacker.lightningHits)%3==0:
   var discharge:=minf(defender.hp,8.0*float(attacker.damageMultiplier))
   _take_health(defender,discharge)
   damage+=discharge
   _emit("lightningDischarge",{"sourceId":attacker.id,"targetId":defender.id,"x":defender.x,"damage":discharge})
 if attacker.side=="player" and attacker.style=="hawk_of_the_fog" and not bool(attack.get("fogChargePaid",false)) and (attack.name=="ability" or (attack.name=="light" and int(attack.comboIndex)==2)):
  attacker.fogCharges=mini(3,int(attacker.fogCharges)+1)
  attack.fogChargePaid=true
  _gain_energy(attacker,5.0)
  _emit("fogCharge",{"sourceId":attacker.id,"x":attacker.x,"charges":attacker.fogCharges})
 # Reactive armor must not make J *better* at breaking posture than an
 # ordinary hit. K/E retain their full opening tools; light hits keep the
 # normal five points and full health damage throughout the retaliation.
 var light_into_counter: bool=armored and attack.name=="light" and bool(defender.attack.get("counter",false))
 defender.posture=minf(100.0,defender.posture+(posture_damage if attack.name=="ability" or (armored and not light_into_counter) else 5.0))
 _gain_energy(attacker,7.0)
 if attacker.side=="player" and attacker.get("style","")=="night_squire" and attack.name=="ability" and not bool(attack.get("nightFocusPaid",false)):
  attacker.nightFocus=attacker.nightFocusMax
  attack.nightFocusPaid=true
  _emit("nightFocus",{"sourceId":attacker.id,"targetId":defender.id,"x":attacker.x,"charges":attacker.nightFocus})
 if attacker.side=="player" and attack.name=="light" and int(attack.comboIndex)==2 and not bool(attack.get("finisherPaid",false)):
  _gain_energy(attacker,float(attacker.get("finisherEnergy",0.0)))
  if attacker.get("style","")=="night_squire":
   attacker.skillCooldown=maxf(0.0,float(attacker.skillCooldown)-0.65)
   _gain_energy(attacker,3.0)
  attack.finisherPaid=true
 _gain_energy(defender,4.0)
 if attacker.side=="player" and defender.side=="enemy" and not _legacy_mode and not training:
  if time>float(defender.get("pressureUntil",-1.0)): defender.pressureHits=0
  defender.pressureHits=int(defender.get("pressureHits",0))+1
  defender.pressureUntil=time+2.3
  if (defender.elite or defender.boss) and defender.pressureHits>=(3 if defender.boss else 4) and time>=float(defender.get("escapeReadyAt",0.0)) and time>=float(defender.get("punishUntil",-1.0)):
   defender.escapePending=true
  if defender.state=="attack" and defender.attack.get("counter",false) and not armored:
   defender.escapePending=false
   defender.punishUntil=time+0.85
 if not armored: defender.pushRemaining=force_direction*attack.push
 if defender.hp<=0.0 or not armored: _state(defender,"dead" if defender.hp<=0.0 else "stagger",maxf(float(attack.stun),float(defender.get("punishUntil",-1.0))-time) if defender.side=="enemy" else attack.stun)
 var heavy: bool=attack.name in ["heavy","ability"] or attack.comboIndex==2
 var contact_stop: float=0.12 if attack.name=="ability" else 0.11 if attack.name=="heavy" else 0.095 if attack.comboIndex==2 else 0.07 if attack.comboIndex==1 else 0.06
 hit_stop=maxf(hit_stop,contact_stop)
 if attacker.side=="player":
  _combo_hit()
  stats.damageDealt+=damage
 else:
  stats.damageTaken+=damage
  _ai_gap=maxf(_ai_gap,0.65)
 _emit("hit",{"side":attacker.side,"targetSide":defender.side,"sourceId":attacker.id,"targetId":defender.id,"x":defender.x,"contactX":contact_x,"contactHeight":attack.get("contactHeight",1.3),"facing":force_direction,"hitStop":hit_stop,"damage":damage,"heavy":heavy,"combo":attack.comboIndex,"name":attack.name,"skill":attack.name=="ability","armored":armored})
 if defender.side=="enemy":
  _mark_down(defender)
  _check_boss_phase(defender)
 if defender.hp>0.0 and defender.posture>=100.0: _break_posture(defender)
 _refresh_target()
 _check_end()

func _gain_energy(who: Dictionary,amount: float) -> void:
 who.energy=minf(100.0,who.energy+amount*(who.energyGain if who.side=="player" else 1.0))

func _combo_hit() -> void:
 combo_count+=1
 combo_time=2.2
 stats.maxCombo=maxi(stats.maxCombo,combo_count)

func _break_posture(who: Dictionary) -> void:
 who.posture=20.0
 who.escapePending=false
 who.pressureHits=0
 who.punishUntil=time+1.4
 _state(who,"stagger",1.4)
 if who.side=="enemy" and not _legacy_mode:
  _gain_energy(player,8.0)
  player.skillCooldown=maxf(0.0,player.skillCooldown-0.7)
 _emit("guardBreak",{"side":who.side,"sourceId":player.id if who.side=="enemy" else enemy.id,"targetId":who.id,"x":who.x,"facing":-who.facing})

func _begin_ultimate() -> void:
 if player_profile=="night_squire":
  _begin_night_burst()
  return
 player.energy=0.0
 _refresh_target()
 player.facing=1 if player.x<=enemy.x else -1
 # Moving by collision preserves the order of every fighter on the one-dimensional lane.
 var desired: float=clampf(enemy.x-player.facing*1.35,-LIMIT,LIMIT)
 _move(player,desired-player.x)
 var duration: float=LightningCombat.ultimate_duration(player_profile) if LightningCombat.supported(player_profile) else 3.8 if player_profile=="fenghuang" else 3.3
 _state(player,"ultimate",duration)
 player.pushRemaining=0.0
 var targets: Array[String]=[]
 # Damage covers the actual impact neighborhood, including nearby escorts.
 # No foe is moved or gathered into range; remote flankers survive the cut-in.
 for foe in enemies:
  if foe.hp>0.0 and (_legacy_mode or absf(foe.x-enemy.x)<=3.4): targets.append(str(foe.id))
 for foe in enemies:
  if not str(foe.id) in targets:continue
  foe.pushRemaining=0.0
  _state(foe,"stagger",duration+0.5)
 ultimate={"time":0.0,"duration":duration,"hitIndex":0,"targetX":enemy.x,"targets":targets,"radius":3.4}
 hit_stop=0.0
 _emit("ultimate",{"side":"player","sourceId":player.id,"targetId":enemy.id,"x":player.x,"targetX":enemy.x,"duration":duration,"targets":targets.duplicate()})

func _advance_ultimate(dt: float) -> void:
 if player_profile=="night_squire":
  _advance_night_activation(dt)
  return
 ultimate.time+=dt
 player.stateTime=ultimate.time
 for foe in enemies:
  if str(foe.id) in ultimate.targets:foe.stateTime+=dt
 var cues: Array=[2.10,2.82] if player_profile=="fenghuang" else [0.9,1.4,1.9,2.65]
 if LightningCombat.supported(player_profile): cues=LightningCombat.ultimate_cues(player_profile)
 while ultimate.hitIndex<cues.size() and ultimate.time>=cues[ultimate.hitIndex]:
  var index: int=ultimate.hitIndex
  var final: bool=index==cues.size()-1
  ultimate.hitIndex+=1
  for foe in enemies:
   if foe.hp<=0.0 or not str(foe.id) in ultimate.targets: continue
   var base_damage: float=(30.0 if final else 10.0) if player_profile=="fenghuang" else (18.0 if final else 6.0)
   if LightningCombat.supported(player_profile): base_damage=LightningCombat.ultimate_damage(player_profile,index)
   var damage: float=minf(foe.hp,base_damage*player.damageMultiplier)
   _take_health(foe,damage)
   stats.damageDealt+=damage
   foe.lastContact=time
   foe.stateTime=0.0
   if final and foe.hp>0.0: _move(foe,signf(foe.x-player.x)*0.85)
   _emit("ultHit",{"side":"player","targetSide":"enemy","sourceId":player.id,"targetId":foe.id,"x":foe.x,"damage":damage,"final":final,"index":index})
   _mark_down(foe)
   _check_boss_phase(foe)
  _combo_hit()
  _emit("ultimateImpact",{"side":"player","sourceId":player.id,"x":ultimate.targetX,"final":final,"index":index})
 if ultimate.time>=ultimate.duration:
  var targets: Array=ultimate.targets
  ultimate={}
  _state(player,"idle")
  if player_profile=="shadow_knight":
   player.eclipseRemaining=LightningCombat.ECLIPSE_DURATION
   player.lightningHits=0
   player.skillCooldown=0.0
   _emit("burstBegin",{"sourceId":player.id,"x":player.x,"duration":LightningCombat.ECLIPSE_DURATION})
  for foe in enemies:
   # Outside the impact circle the cut-in is only a global pause. Preserve
   # the exact pending attack, warning clock, posture and recovery cooldown.
   if not str(foe.id) in targets:continue
   _state(foe,"dead" if foe.hp<=0.0 else "stagger",0.55)
   foe.posture=0.0
   foe.aiCooldown=0.85 if _legacy_mode else 0.25
   if foe.hp>0.0 and foe.get("phaseCounterPending",false): _begin_phase_counter(foe)
  _ai_cooldown=0.85
  _ai_gap=0.85 if _legacy_mode else 0.25
  _refresh_target()
  _emit("ultimateEnd")
  _check_end()

func _begin_night_burst() -> void:
 player.energy=0.0
 _refresh_target()
 player.facing=1 if player.x<=enemy.x else -1
 # ND_Ultra is a burst activation, not an arena-wide damage move. Its native
 # pose plays where the player stood and never teleports or gathers enemies.
 _state(player,"ultimate",NIGHT_BURST_ACTIVATION)
 player.pushRemaining=0.0
 ultimate={"time":0.0,"duration":NIGHT_BURST_ACTIVATION,"hitIndex":0,"targetX":enemy.x,"activation":true}
 hit_stop=0.0
 _emit("ultimate",{"side":"player","sourceId":player.id,"targetId":enemy.id,"x":player.x,"targetX":enemy.x,"duration":NIGHT_BURST_ACTIVATION,"activation":true,"targets":[]})

func _advance_night_activation(dt:float) -> void:
 ultimate.time+=dt
 player.stateTime=ultimate.time
 if ultimate.time<float(ultimate.duration):return
 ultimate={}
 _state(player,"idle")
 player.nightBurstRemaining=NIGHT_BURST_DURATION
 player.nightFocus=player.nightFocusMax
 player.skillCooldown=0.0
 _emit("burstBegin",{"sourceId":player.id,"x":player.x,"duration":NIGHT_BURST_DURATION,"charges":player.nightFocus})
 _emit("ultimateEnd",{"sourceId":player.id,"burst":true})

func _ai(dt: float) -> void:
 if not enemy.state in ["idle","move"]: return
 _ai_cooldown-=dt
 var preferred: float=2.5 if SentienceCombat.weapon_for(enemy,_ai_round+1)=="spear" else 1.75
 if absf(enemy.x-player.x)>preferred:
  if enemy.state!="move": _state(enemy,"move")
  _move(enemy,enemy.facing*1.95*dt)
  return
 if enemy.state=="move": _state(enemy,"idle")
 if _ai_cooldown>0.0: return
 _ai_round+=1
 if _ai_round%4==0:
  _state(enemy,"guard",0.8)
  enemy.parryUntil=-1.0
 else:
  _attack(enemy,"light" if enemy.get("style","")=="sentience" else "heavy" if _ai_round%3==0 else "light")

func _encounter_ai(dt: float) -> void:
 _ai_gap=maxf(0.0,_ai_gap-dt)
 var active_attacks: int=0
 for foe in enemies:
  if foe.hp<=0.0: continue
  foe.aiCooldown=maxf(0.0,foe.aiCooldown-dt)
  if foe.state=="attack": active_attacks+=1
  if not foe.state in ["idle","move"]: continue
  var rank: int=0
  for other in enemies:
   if other.id!=foe.id and other.hp>0.0 and (other.x-player.x)*(foe.x-player.x)>0.0 and absf(other.x-player.x)<absf(foe.x-player.x): rank+=1
  var preferred: float=2.45 if SentienceCombat.weapon_for(foe,int(foe.aiRound)+1)=="spear" else 1.25 if foe.boss else 1.45
  var tactic: String=str(foe.get("tactic",""))
  if tactic=="range": preferred=3.15 if SentienceCombat.weapon_for(foe,int(foe.aiRound)+1)=="spear" else 2.0
  elif tactic=="press": preferred=1.18
  elif tactic=="guard": preferred=1.70
  var spacing: float=preferred+rank*0.94
  var speed_scale: float=1.12 if tactic=="press" else 1.08 if tactic=="flank" else 1.0
  if absf(foe.x-player.x)>spacing+0.05:
   if foe.state!="move": _state(foe,"move")
   _move(foe,foe.facing*foe.speed*speed_scale*dt)
  elif tactic=="range" and rank==0 and foe.aiCooldown>0.12 and absf(foe.x-player.x)<1.75 and time>=float(foe.get("punishUntil",-1.0)):
   # The spear carrier creates space only during recovery. Collision still
   # preserves lane order; it cannot teleport through a body or evade a punish.
   if foe.state!="move": _state(foe,"move")
   _move(foe,-foe.facing*foe.speed*0.75*dt)
  elif foe.state=="move": _state(foe,"idle")
 # The next warning may begin during a completed final strike's recovery.
 # Never overlap live contacts or cut in under an unfinished native chain.
 if active_attacks>=2 or _ai_gap>0.0 or player.state in ["stagger","dead"]: return
 for foe in enemies:
  if foe.hp<=0.0 or foe.state!="attack": continue
  var handoff: float=0.28*float(_encounter_rule.turnGapScale) if _encounter_rule.has("id") else 0.10
  if int(foe.attack.get("nativeNext",-1))>=0 or foe.stateTime<float(foe.attack.windup)+float(foe.attack.active)+handoff: return
 for offset in enemies.size():
  var index: int=(_ai_cursor+offset)%enemies.size()
  var foe: Dictionary=enemies[index]
  if foe.hp<=0.0 or not foe.state in ["idle","move"] or foe.aiCooldown>0.0: continue
  if time<float(foe.get("punishUntil",-1.0)): continue
  var next_weapon: String=SentienceCombat.weapon_for(foe,int(foe.aiRound)+1)
  var reach: float=float(SentienceCombat.attack(next_weapon,0,foe.boss,foe.phase).range)-0.12
  if absf(foe.x-player.x)>reach: continue
  _ai_cursor=(index+1)%enemies.size()
  if bool(foe.get("phaseCounterPending",false)):
   _begin_phase_counter(foe)
   break
  foe.aiRound+=1
  var tactical_guard: bool=foe.aiRound%2==1 if str(foe.get("tactic",""))=="guard" else foe.type=="guardian" and foe.aiRound%3==1
  if foe.boss and str(foe.get("tactic",""))=="guard": tactical_guard=foe.aiRound%4==2
  if tactical_guard and next_weapon!="burst" and not foe.counterPending:
   _state(foe,"guard",0.85)
   foe.parryUntil=-1.0
   foe.aiCooldown=_enemy_recovery(foe,1.0)
   _ai_gap=_turn_gap(0.45)
   _emit("enemyGuard",{"side":"enemy","sourceId":foe.id,"x":foe.x})
  elif foe.type=="duelist" and not foe.counterPending and foe.aiRound%3==1:
   foe.counterPending=true
   foe.dodgeDirection=-foe.facing
   _state(foe,"dodge",0.34)
   _ai_gap=_turn_gap(0.45)
   _emit("dodge",{"side":"enemy","sourceId":foe.id,"x":foe.x,"direction":foe.dodgeDirection})
  else:
   var heavy: bool=foe.type=="guardian" or (foe.boss and (foe.phase==2 or foe.aiRound%3==0)) or (foe.type=="striker" and foe.aiRound%4==0)
   # Sentience chooses a full weapon kit internally. The legacy phase-two
   # heavy flag otherwise replaces every sword opening with a chain attack.
   _attack(foe,"light" if foe.get("style","")=="sentience" else "heavy" if heavy else "light")
  break

func _turn_gap(seconds: float) -> float:
 return seconds*float(_encounter_rule.get("turnGapScale",1.0))

func _enemy_recovery(foe: Dictionary,seconds: float) -> float:
 var tactic: String=str(foe.get("tactic",""))
 var scale: float=0.82 if tactic=="press" else 0.90 if tactic=="flank" else 1.08 if tactic=="range" else 1.0
 return maxf(0.12,seconds*float(_encounter_rule.get("attackIntervalScale",1.0))*scale)

func _try_pressure_escape(foe: Dictionary) -> bool:
 if _legacy_mode or training or foe.hp<=0.0 or not bool(foe.get("escapePending",false)): return false
 if time<float(foe.get("punishUntil",-1.0)) or time<float(foe.get("escapeReadyAt",0.0)): return false
 # This runs only after hitstun ends: never steal a confirmed three-hit chain
 # or the reward for a successful deflection / posture break.
 foe.escapePending=false
 foe.pressureHits=0
 foe.escapeReadyAt=time+(2.2 if foe.boss else 3.0)
 foe.counterPending=true
 foe.adaptiveCounter=true
 foe.aiCooldown=0.05
 if foe.type=="guardian":
  _state(foe,"guard",0.42)
  foe.parryUntil=-1.0
  _emit("enemyGuard",{"side":"enemy","sourceId":foe.id,"x":foe.x,"counter":true})
 else:
  foe.dodgeDirection=-foe.facing
  _state(foe,"dodge",0.34)
  _emit("dodge",{"side":"enemy","sourceId":foe.id,"x":foe.x,"direction":foe.dodgeDirection,"counter":true})
 return true

func _state(who: Dictionary,state: String,duration: float=0.0) -> void:
 if who.side=="player" and state in ["attack","stagger","dead","dodge","ultimate"]: _clear_buffer()
 if who.side=="player" and state in ["stagger","dead","dodge","ultimate"]: _clear_riposte()
 who.parryOpening=-1.0
 who.state=state
 who.stateTime=0.0
 who.stateDuration=duration
 who.attack={}
 who.combo=0
 who.queuedCombo=false
 who.queuedHeavy=false

func _move(who: Dictionary,amount: float) -> void:
 var next: float=clampf(who.x+amount,-LIMIT,LIMIT)
 var obstacles: Array[Dictionary]=_living_enemies()
 if who.side=="enemy" and player.hp>0.0: obstacles.append(player)
 for other in obstacles:
  if other.id==who.id: continue
  next=minf(next,other.x-GAP) if who.x<=other.x else maxf(next,other.x+GAP)
 who.x=clampf(next,-LIMIT,LIMIT)

func _orient_duel_spawn() -> void:
 # Seeded formations may be mirrored, but a one-on-one opening always puts
 # the player on the left. Preserve its intended spacing; normal movement
 # and multi-enemy flanking formations remain unrestricted after spawning.
 if enemies.size()!=1: return
 var distance:=clampf(absf(float(enemies[0].x)-float(player.x)),GAP,LIMIT*2.0)
 player.x=-distance*0.5
 enemies[0].x=distance*0.5

func _separate_spawns() -> void:
 var ordered: Array[Dictionary]=[player]
 ordered.append_array(enemies)
 ordered.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return a.x<b.x)
 var previous: float=-LIMIT-GAP
 for who in ordered:
  who.x=maxf(clampf(who.x,-LIMIT,LIMIT),previous+GAP)
  previous=who.x
 var overflow: float=maxf(0.0,previous-LIMIT)
 for who in ordered: who.x-=overflow

func _living_enemies() -> Array[Dictionary]:
 var living: Array[Dictionary]=[]
 for foe in enemies:
  if foe.hp>0.0: living.append(foe)
 return living

func _refresh_target() -> void:
 # A successful deflection owns a brief target focus. Otherwise its small
 # push can make a bystander nearer and turn the follow-up to the other side.
 var followup_id: String=""
 var followup_reach: float=3.0
 if _has_riposte() and player.state in ["idle","move","guard"]:
  followup_id=str(player.get("riposteTarget",""))
  followup_reach=float(player.get("riposteReach",3.0))
 elif player.state=="attack":
  followup_id=str(player.attack.get("followupTarget",""))
  followup_reach=float(player.attack.get("followupReach",3.0))
 if not followup_id.is_empty():
  for foe in enemies:
   if foe.id==followup_id and foe.hp>0.0 and absf(foe.x-player.x)<=followup_reach:
    enemy=foe
    return
 var closest: Dictionary={}
 for foe in enemies:
  if foe.hp>0.0 and (closest.is_empty() or absf(foe.x-player.x)<absf(closest.x-player.x)): closest=foe
 if not closest.is_empty(): enemy=closest
 elif not enemies.is_empty(): enemy=enemies[0]
 else:
  enemy=_fighter("enemy",1.65,-1)
  enemy.hp=0.0
  enemy.id=""
  enemy.state="dead"

func _mark_down(foe: Dictionary) -> void:
 if foe.hp>0.0 or foe.downEmitted: return
 foe.downEmitted=true
 foe.hp=0.0
 _state(foe,"dead")
 stats.kills+=1
 _ai_gap=maxf(_ai_gap,0.8 if _legacy_mode else 0.22)
 if not _legacy_mode:
  _gain_energy(player,6.0)
  player.skillCooldown=maxf(0.0,player.skillCooldown-0.35)
 _emit("enemyDown",{"side":"enemy","sourceId":player.id,"targetId":foe.id,"id":foe.id,"x":foe.x,"name":foe.name,"boss":foe.boss})

func _check_boss_phase(foe: Dictionary) -> void:
 var phase_health: float=float(foe.hp)-float(foe.get("practiceDamage",0.0)) if infinite_hp else float(foe.hp)
 if not foe.boss or foe.phase!=1 or foe.hp<=0.0 or phase_health>foe.maxHp*0.5: return
 foe.phase=2
 if training: return
 foe.posture=minf(foe.posture,20.0)
 foe.phaseCounterPending=true
 foe.escapePending=false
 foe.pressureHits=0
 foe.adaptiveCounter=false
 foe.aiCooldown=maxf(foe.aiCooldown,0.9)
 _ai_gap=maxf(_ai_gap,0.8)
 _emit("bossPhase",{"side":"enemy","sourceId":foe.id,"targetId":foe.id,"x":foe.x,"phase":2,"boss":true,"armored":true,"windup":SentienceCombat.attack("burst",0,true,2,true).windup})
 if ultimate.is_empty(): _begin_phase_counter(foe)

func _begin_phase_counter(foe: Dictionary) -> void:
 if training:
  foe.phaseCounterPending=false
  return
 # Crossing half health never consumes an opening earned by perfect defense
 # or a posture break. The pending phase attack starts when that hitstun ends.
 if time<float(foe.get("punishUntil",-1.0)):return
 # The boss takes the attack turn; a future encounter with escorts must not
 # stack an already-running escort strike under the phase-change warning.
 for other in enemies:
  if other.id!=foe.id and other.hp>0.0 and other.state=="attack":
   _state(other,"stagger",0.35)
   other.aiCooldown=maxf(other.aiCooldown,0.8)
 _attack(foe,"heavy",0,true)

func _check_end() -> void:
 for foe in enemies: _mark_down(foe)
 if not ultimate.is_empty() or ended: return
 if player.hp>0.0 and not _living_enemies().is_empty(): return
 ended=true
 winner="player" if player.hp>0.0 else "enemy"
 if player.hp<=0.0: _state(player,"dead")
 _emit("end",{"winner":winner})

func snapshot() -> Dictionary:
 return {"player":player.duplicate(true),"enemy":enemy.duplicate(true),"enemies":enemies.duplicate(true),"enemyId":enemy.id,"time":time,"started":started,"paused":paused,"ended":ended,"winner":winner,"training":training,"infiniteHp":infinite_hp,"ultimate":not ultimate.is_empty(),"ultimateTime":ultimate.get("time",-1.0),"combo":combo_count,"hitStop":hit_stop,"stats":stats.duplicate(true)}

func _emit(kind: String,data: Dictionary={}) -> void:
 var output: Dictionary=data.duplicate()
 output.type=kind
 output.time=time
 var source: Dictionary=player
 # An evade belongs to the evading target; other combat events identify
 # their visual source explicitly (including the defender for a parry).
 var identity: String=str(data.get("targetId", "")) if kind=="evade" else str(data.get("sourceId", ""))
 for foe in enemies:
  if str(foe.id)==identity:
   source=foe
   break
 output.style=source.get("style",player_profile)
 output.characterId=source.get("characterId","fuhua")
 output.stance=source.get("stance","punch")
 if source.get("style","")=="night_squire":
  output.nightBurst=float(source.get("nightBurstRemaining",0.0))>0.0 or bool(source.get("attack",{}).get("nightBurst",false))
  output.nightFocused=bool(source.get("attack",{}).get("nightFocused",false))
  output.hitIndex=int(source.get("attack",{}).get("hitIndex",0))
 if source.side=="enemy": output.weapon=data.get("weapon",source.get("weapon","sword"))
 event.emit(output)
