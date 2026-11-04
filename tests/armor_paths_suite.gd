extends SceneTree
const Combat=preload("res://scripts/combat.gd")
const Paths=preload("res://scripts/armor_paths.gd")
const Rules=preload("res://scripts/armor_mechanics.gd")
const Campaign=preload("res://scripts/campaign.gd")
const Story=preload("res://scripts/sentience_story.gd")
class Volatile extends "res://scripts/campaign.gd":
 func _load_record() -> void:pass
var checks:=0
var failures:Array=[]
var exercised:Dictionary={}

func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures.append(label);push_error(label)

func game(core:String,perks:Array=[],count:int=3):
 var g=Combat.new();g.set_player_profile(Paths.CORES[core].style)
 var foes:Array=[]
 for i in count:foes.append({"id":"foe%d"%i,"hp":2000.0,"x":0.3+i*1.1})
 g.start_encounter({"playerX":-1.0,"training":true,"enemies":foes},{"hp":1000.0,"maxHp":1000.0,"energy":0.0,"armorCore":core,"armorPerkIds":perks})
 return g

func strike(g,kind:String,index:int=0,target:Dictionary={},final:bool=false) -> Dictionary:
 g._state(g.player,"idle")
 g._attack(g.player,kind,index)
 var a:Dictionary=g.player.attack
 if final and a.has("hitWindows"):a.hitIndex=a.hitWindows.size()-1;a.damage=a.hitDamages[-1]
 g._receive(g.player,g.enemy if target.is_empty() else target,a)
 return a

func mark_perk(id:String) -> void:exercised[id]=true

func _initialize() -> void:
 _campaigns();_azure();_phoenix();_moon();_fog();_isolation()
 check(exercised.size()==24,"all 24 exclusive upgrades have behavioral assertions")
 print("ARMOR_PATHS ",checks," checks; ",failures.size()," failures; perks ",exercised.size())
 FileAccess.open("res://build/armor-paths-tests.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"perks":exercised.keys()}))
 quit(0 if failures.is_empty() else 1)

func _campaigns() -> void:
 for core:String in Paths.CORES:
  var fighter:Dictionary={"characterId":"fuhua","styleId":Paths.CORES[core].style,"appearanceId":"default"}
  for seed_value in 8:
   var c=Volatile.new();c.begin_trial("mirror",seed_value,fighter,core)
   check(c.armor_core==core and c.run_rules_version==Campaign.ARMOR_RULES_VERSION,"versioned armor core "+core)
   check(c.combat_carry().armorCore==core,"combat receives selected core")
   var patterns:Array=c.stages.duplicate(true)
   for stage in 5:
    c.finish({"winner":"player","player":{"hp":100.0,"maxHp":120.0,"energy":30.0},"stats":{}})
    check(c.reward_options.size()==3,"three distinct choices")
    if stage==0:
     var previous:Array=c.reward_options.map(func(row):return row.id)
     check(c.reroll_rewards(),"reroll allowed")
     for row:Dictionary in c.reward_options:check(row.id not in previous,"reroll replaces cards")
    var chosen:=0;var special:=false
    for i in c.reward_options.size():
     var id:String=c.reward_options[i].id
     check(not Campaign.NightPaths.REWARDS.has(id),"no white-night card on another armor")
     if Paths.REWARDS.has(id):
      check(Paths.REWARDS[id].core==core,"no foreign exclusive")
      chosen=i;special=true
    if stage<2:check(special,"each of first two clears has an unclaimed exclusive")
    check(c.save_checkpoint(fighter),"checkpoint saved")
    var resumed=Volatile.new();resumed.resume_data=c.resume_data.duplicate(true)
    check(not resumed.resume_trial().is_empty(),"new armor run resumes")
    check(resumed.armor_core==core and resumed.stages==patterns and resumed.reward_options==c.reward_options,"resume preserves core, encounter and draft")
    check(c.choose_reward(chosen),"card applies")
   check(Story.decision(c.snapshot({})).choiceCount==5,"exclusive cards count toward existing story ending")
   for id:String in Paths.CORES[core].rewards:check(id in c.reward_ids,"both compatible cards acquired")
   c.save_checkpoint(fighter)
   var bad:Dictionary=c.resume_data.duplicate(true);bad.armorCore="az_fake"
   check(not Campaign._valid_resume(bad),"unknown core rejected")
   bad=c.resume_data.duplicate(true);bad.fighter.styleId="night_squire"
   check(not Campaign._valid_resume(bad),"wrong armor resume rejected")
   bad=c.resume_data.duplicate(true);bad.rewardIds[0]="night_shock"
   check(not Campaign._valid_resume(bad),"foreign card resume rejected")
 var old=Volatile.new();old.begin_trial("mirror",8)
 for row:Dictionary in old._roll_rewards():check(not Paths.REWARDS.has(row.id),"legacy/generic run never sees armor exclusives")

func _azure() -> void:
 for core:String in ["az_balance","az_yang","az_yin"]:
  var g=game(core)
  g._attack(g.player,"light")
  check(g.player.armorState.yang==0,"whiff earns no mark")
  strike(g,"light");strike(g,"light");strike(g,"light");strike(g,"heavy")
  check(g.player.armorState.yang==3 and g.player.armorState.yin==0,"three-mark cap and separate resources")
  g.player.energy=0;g.player.skillCooldown=9;g._state(g.player,"idle")
  check(g.action("ability"),"full marks bypass E cooldown")
  check(g.player.armorState.yang==0,"branch consumes marks at startup even on whiff")
  var a:Dictionary=g.player.attack
  g._receive(g.player,g.enemy,a)
  check(g.player.energy==(37.0 if core=="az_yang" else 25.0),"three-yang energy paid once")
  var before:float=g.player.energy;g._receive(g.player,g.enemies[1],a)
  check(g.player.energy-before==7.0,"second enemy does not duplicate branch refund")
 for perk:String in ["az_echo","az_bind"]:
  var g=game("az_balance",[perk]);strike(g,"light");strike(g,"heavy");strike(g,"light")
  var a:=strike(g,"ability")
  check(a.inkBranch=="mixed" and g.enemies[1].pushRemaining<0,"mixed branch pulls nearby enemies")
  if perk=="az_echo":check(g.player.armorState.yang==1 and g.player.armorState.yin==1,"echo returns both marks")
  else:check(g.enemy.punishUntil>=g.time+float(a.stun)+0.59,"bind extends opening")
  mark_perk(perk)
 var y=game("az_yang",["az_cycle","az_return"])
 for i in 3:strike(y,"light")
 strike(y,"ability");strike(y,"light")
 check(y.player.armorState.yang==2,"extra yang on next J");mark_perk("az_cycle")
 y.player.energy=100;y._state(y.player,"idle");y.action("ultimate")
 for i in 600:y.update(1.0/120.0)
 check(y.player.energy==20.0 and not y.player.armorState.yangRefund,"Q refund consumed once");mark_perk("az_return")
 var n=game("az_yin",["az_fracture","az_spread"])
 for i in 3:strike(n,"heavy")
 strike(n,"ability")
 n._state(n.enemy,"guard");n.enemy.parryUntil=-1;n.enemy.posture=0
 strike(n,"heavy")
 check(n.enemy.state=="stagger" and n.enemy.posture==30.0,"yin K bypasses guard and consumes fracture")
 strike(n,"heavy");check(n.enemy.posture==35.0,"fracture cannot repeat on same mark");mark_perk("az_fracture")
 n._break_posture(n.enemy)
 check(n.enemies[1].inkUntil>n.time and n.enemies[2].inkUntil>n.time,"ink spreads on actual posture break");mark_perk("az_spread")

func _phoenix() -> void:
 var g=game("ph_turn",["ph_refill","ph_rekindle"])
 strike(g,"heavy");strike(g,"heavy")
 check(g.player.armorState.prana==1,"repeating same stance cannot farm prana")
 g.player.stance="kick";strike(g,"light",2);g.player.stance="punch";strike(g,"heavy")
 var a:=strike(g,"ability")
 check(a.pranaSwitch and a.damage==29 and g.player.armorState.prana==1,"full prana empowers existing switch and retains one");mark_perk("ph_refill")
 strike(g,"heavy")
 check(g.player.armorState.prana==2 and not g.player.armorState.rekindle,"next K restores exactly one extra prana");mark_perk("ph_rekindle")
 var f=game("ph_fire",["ph_spread","ph_fuel"])
 strike(f,"heavy");strike(f,"light",2)
 check(f.enemy.lihuoUntil==f.time+9.0,"J finisher refreshes fire");mark_perk("ph_fuel")
 var hp:float=f.enemy.hp;strike(f,"heavy")
 check(hp-f.enemy.hp==27.0 and f.enemy.lihuoUntil<0 and f.enemies[1].lihuoUntil>f.time,"K consumes fire, detonates and spreads");mark_perk("ph_spread")
 var q=game("ph_prana",["ph_reserve","ph_wings"])
 for stance:String in ["punch","kick","punch"]:q.player.stance=stance;strike(q,"heavy")
 q.player.energy=0;strike(q,"heavy")
 check(q.player.energy==17.0,"full-prana K gains bonus SP once");mark_perk("ph_wings")
 q.player.energy=100;q._state(q.player,"idle");q.action("ultimate")
 check(is_equal_approx(q.player.armorState.ultBonus,0.45) and q.player.armorState.prana==1,"Q snapshots prana damage, keeps reserve")
 for i in 650:q.update(1.0/120.0)
 check(q.enemy.get("lihuoUntil",-1)>q.time,"Q applies fire");mark_perk("ph_reserve")
 var before_hp:float=q.enemy.hp
 strike(q,"light")
 check(is_equal_approx(before_hp-q.enemy.hp,8.0),"reserve fire has a real follow-up damage effect")

func _moon() -> void:
 for perks:Array in [[],["mo_long","mo_return"]]:
  var g=game("mo_eclipse",perks);g.player.eclipseRemaining=10.0
  for i in 9:g.player.energy=100;strike(g,"ability",0,{},true)
  check(g.player.armorState.eclipseAdded==(10.0 if not perks.is_empty() else 6.0),"extension is bounded per eclipse")
  if not perks.is_empty():
   mark_perk("mo_long");g.player.energy=0;g.player.skillCooldown=9;g.player.eclipseRemaining=0.01
   for i in 30:g.update(1.0/120.0)
   check(g.player.energy==20 and g.player.skillCooldown==0,"natural eclipse expiry refunds once");mark_perk("mo_return")
 var d=game("mo_discharge",["mo_arc","mo_charge"])
 strike(d,"ability",0,{},false)
 check(d.player.armorState.conductUntil<0,"first E hit cannot start conduction")
 strike(d,"ability",0,{},true);strike(d,"heavy")
 check(d.player.armorState.conductHits==2,"K counts twice");mark_perk("mo_charge")
 var hp:float=d.enemies[1].hp;strike(d,"light")
 check(d.enemies[1].hp==hp-6 and d.player.armorState.conductHits==0,"third contact arcs to one nearby foe");mark_perk("mo_arc")
 var h=game("mo_heavy",["mo_open","mo_follow"]);h.player.eclipseRemaining=10
 strike(h,"ability",0,{},true);h.player.energy=0;h.enemy.posture=0;h._state(h.enemy,"guard");h.enemy.parryUntil=-1
 var a:=strike(h,"heavy")
 check(a.eclipseCrack and a.unblockable and h.enemy.posture>=70,"native burst K breaks through guard with bonus posture")
 check(h.player.energy==17,"crack K returns 10 SP");mark_perk("mo_open")
 h.player.skillCooldown=8;h._state(h.player,"idle")
 check(h.action("ability") and h.player.energy==7 and h.player.armorState.chaseUntil<0,"follow E spends SP and consumes ticket");mark_perk("mo_follow")

func _fog() -> void:
 for perks:Array in [[],["fo_step","fo_breath"]]:
  var g=game("fo_flash",perks);strike(g,"ability",0,{},true)
  g.player.fogCharges=2;g.player.skillCooldown=8;g.player.energy=0
  strike(g,"heavy")
  check((g.player.skillCooldown==0)==not perks.is_empty(),"loop needs energy unless upgraded")
  if not perks.is_empty():check(g.player.fogCharges==1,"two-charge K returns one charge");mark_perk("fo_step");mark_perk("fo_breath")
 var storm=game("fo_storm",["fo_shatter","fo_relay"]);storm.player.fogCharges=3
 storm._state(storm.enemy,"guard");storm.enemy.parryUntil=-1
 var hp:float=storm.enemies[1].hp;var a:=strike(storm,"heavy")
 check(a.unblockable and storm.enemies[1].hp==hp-12,"full K bypasses block and splashes");mark_perk("fo_shatter")
 check(storm.player.energy==19,"two extra targets refund capped 12 SP");mark_perk("fo_relay")
 var sky=game("fo_sky",["fo_window","fo_return"]);sky.player.energy=60
 sky.action("dodge")
 var hit:Dictionary={"name":"light","comboIndex":0,"damage":5,"postureDamage":5,"push":0,"stun":0.2}
 sky._receive(sky.enemy,sky.player,hit)
 check(sky.player.energy==70 and sky.player.armorState.skyUntil==sky.time+5.0,"actual evade opens extended ticket and grants SP")
 sky._receive(sky.enemies[1],sky.player,hit)
 check(sky.player.energy==70,"same dodge cannot refund overlapping hitboxes twice");mark_perk("fo_window")
 sky._state(sky.player,"idle");check(sky.action("ultimate"),"Q accepts 70 SP during ticket")
 check(sky.player.energy==0 and sky.player.armorState.skyUntil<0,"low-cost Q consumes ticket")
 for i in 500:sky.update(1.0/120.0)
 check(sky.player.fogCharges==3 and sky.player.skillCooldown==0,"low-cost Q reloads charges and E");mark_perk("fo_return")
 var no_ticket=game("fo_sky");no_ticket.player.energy=70
 check(not no_ticket.action("ultimate"),"70 SP Q rejected without successful dodge")

func _isolation() -> void:
 for core:String in Paths.CORES:
  var g=game(core,Paths.REWARDS.keys())
  check(g.player.armorPerks.size()==2,"foreign perks cannot leak into selected core")
  var baseline=Combat.new();baseline.set_player_profile(g.player.style)
  for kind:String in ["light","heavy","ability"]:
   for index in (3 if kind=="light" else 1):
    g._attack(g.player,kind,index);baseline._attack(baseline.player,kind,index)
    for key:String in ["motion","windup","duration","hitWindows","hitDamages","range"]:
     check(g.player.attack.get(key)==baseline.player.attack.get(key),"native motion/contact schedule retained: "+core+" / "+kind+" / "+key)
  check(not Rules.active(baseline.player),"old/practice mechanics remain opt-in")
