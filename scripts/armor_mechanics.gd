extends RefCounted
const Paths=preload("res://scripts/armor_paths.gd")

static func active(p:Dictionary) -> bool:
 return not str(p.get("armorCore","")).is_empty()

static func ability_ready(p:Dictionary,time:float) -> bool:
 if not active(p):return false
 var s:Dictionary=p.armorState
 return (p.style=="azure_empyrea" and int(s.yin)+int(s.yang)==3) or (p.armorCore=="mo_heavy" and time<float(s.chaseUntil) and p.energy>=10.0)

static func ultimate_cost(p:Dictionary,time:float) -> float:
 return 70.0 if active(p) and p.armorCore=="fo_sky" and time<float(p.armorState.skyUntil) else 100.0

static func prepare(g,attack:Dictionary) -> void:
 var p:Dictionary=g.player
 if not active(p):return
 var s:Dictionary=p.armorState
 var kind:String=attack.name
 if p.style=="azure_empyrea" and kind=="ability" and int(s.yin)+int(s.yang)==3:
  attack.inkBranch="yin" if int(s.yin)==3 else "yang" if int(s.yang)==3 else "mixed"
  attack.inkLast="yin" if int(s.yang)>int(s.yin) else "yang"
  s.yin=0;s.yang=0
  if attack.inkBranch=="mixed":attack.push=-0.55
 elif p.style=="fenghuang" and kind=="ability" and p.armorCore=="ph_turn" and int(s.prana)==3:
  attack.pranaSwitch=true
  attack.damage+=24.0;attack.postureDamage+=30.0
  s.prana=1 if Paths.has(p,"ph_refill") else 0
 elif p.style=="shadow_knight":
  if kind=="heavy" and p.armorCore=="mo_heavy" and g.time<float(s.heavyUntil):
   attack.eclipseCrack=true;attack.unblockable=true
   attack.postureDamage+=30.0
   s.heavyUntil=-1.0
  elif kind=="ability" and g.time<float(s.chaseUntil):
   if p.energy>=10.0:g.spend_energy(10.0)
   s.chaseUntil=-1.0
 elif p.style=="hawk_of_the_fog":
  if kind=="light" and g.time<float(s.flashUntil):attack.damage*=1.10
  if kind=="heavy":
   if p.armorCore=="fo_flash" and g.time<float(s.linkUntil):attack.fogLink=true;s.linkUntil=-1.0
   if p.armorCore=="fo_storm" and int(attack.get("fogCharges",0))==3:
    attack.fogStorm=true
    if Paths.has(p,"fo_shatter"):attack.unblockable=true

static func bypass(p:Dictionary,foe:Dictionary,attack:Dictionary,time:float) -> bool:
 return active(p) and p.armorCore=="az_yin" and attack.name=="heavy" and time<float(foe.get("inkUntil",-1.0))

static func posture(p:Dictionary,foe:Dictionary,attack:Dictionary,time:float) -> float:
 if Paths.has(p,"az_fracture") and attack.name=="heavy" and time<float(foe.get("inkUntil",-1.0)) and not foe.get("inkFractured",false):
  foe.inkFractured=true
  return 25.0
 return 0.0

static func _ink(foe:Dictionary,time:float,power:float) -> void:
 foe.inkUntil=time+6.0;foe.inkPower=power;foe.inkFractured=false

static func contact(g,attack:Dictionary,foe:Dictionary) -> float:
 var p:Dictionary=g.player
 if not active(p):return 0.0
 var s:Dictionary=p.armorState
 var first:bool=not attack.get("armorPaid",false)
 var kind:String=attack.name
 var last:bool=int(attack.get("hitIndex",0))>=attack.get("hitWindows",[0]).size()-1
 var bonus:=0.0
 if p.style=="azure_empyrea":
  if g.time<float(foe.get("inkUntil",-1.0)):bonus+=float(attack.damage)*float(foe.get("inkPower",0.15))
  if kind in ["light","heavy"] and first:
   var key:String="yang" if kind=="light" else "yin"
   var count:int=2 if key=="yang" and s.yangNext else 1
   if key=="yang":s.yangNext=false
   s[key]=int(s[key])+mini(count,3-int(s.yin)-int(s.yang))
  var branch:String=attack.get("inkBranch","")
  if branch=="yin":_ink(foe,g.time,0.25 if p.armorCore=="az_yin" else 0.15)
  elif branch=="yang" and first:
   g._gain_energy(p,30.0 if p.armorCore=="az_yang" else 18.0)
   if Paths.has(p,"az_cycle"):s.yangNext=true
   if Paths.has(p,"az_return"):s.yangRefund=true
  elif branch=="mixed":
   if first:
    for other:Dictionary in g.enemies:
     if other.hp>0 and other.id!=foe.id and absf(other.x-foe.x)<=3.2:
      other.pushRemaining=signf(foe.x-other.x)*minf(0.9,maxf(0.0,absf(other.x-foe.x)-0.85))
    if p.armorCore=="az_balance":
     if Paths.has(p,"az_echo"):s.yin=1;s.yang=1
     else:s[str(attack.inkLast)]=1
   if Paths.has(p,"az_bind"):foe.punishUntil=maxf(float(foe.get("punishUntil",-1)),g.time+float(attack.stun)+(0.25 if foe.boss else 0.6))
 elif p.style=="fenghuang":
  var burning:bool=g.time<float(foe.get("lihuoUntil",-1.0))
  if burning and kind=="light" and g.time>=float(foe.get("lihuoNext",-1.0)):
   bonus+=4.0 if p.armorCore=="ph_fire" else 2.0
   foe.lihuoNext=g.time+0.7
  if p.armorCore=="ph_fire" and burning:
   if kind=="heavy":
    bonus+=12.0;foe.lihuoUntil=-1.0
    if Paths.has(p,"ph_spread"):
     for other:Dictionary in g.enemies:
      if other.id!=foe.id and other.hp>0 and absf(other.x-foe.x)<=2.6:other.lihuoUntil=g.time+6.0
  var branch:bool=kind=="heavy" or (kind=="light" and int(attack.comboIndex)==2)
  if branch:
   if first:
    if str(s.branch)!=str(p.stance):s.prana=mini(3,int(s.prana)+1);s.branch=p.stance
    if kind=="heavy" and s.rekindle:s.prana=mini(3,int(s.prana)+1);s.rekindle=false
    if kind=="heavy" and int(s.prana)==3 and Paths.has(p,"ph_wings"):g._gain_energy(p,10.0)
   if not (p.armorCore=="ph_fire" and burning and kind=="heavy"):foe.lihuoUntil=g.time+6.0
   if kind=="light" and burning and Paths.has(p,"ph_fuel"):foe.lihuoUntil=g.time+9.0
  if kind=="ability":
   if p.armorCore=="ph_fire":foe.lihuoUntil=g.time+6.0
   if attack.get("pranaSwitch",false) and first and Paths.has(p,"ph_rekindle"):s.rekindle=true
 elif p.style=="shadow_knight":
  if kind=="ability" and last and not attack.get("armorFinalPaid",false):
   attack.armorFinalPaid=true
   match str(p.armorCore):
    "mo_eclipse":
     var limit:=10.0 if Paths.has(p,"mo_long") else 6.0
     if p.eclipseRemaining>0 and p.energy>=15.0 and float(s.eclipseAdded)<limit:
      g.spend_energy(15.0);p.eclipseRemaining+=2.0;s.eclipseAdded+=2.0
    "mo_discharge":s.conductUntil=g.time+6.0
    "mo_heavy":
     if p.eclipseRemaining>0:s.heavyUntil=g.time+6.0
  if p.armorCore=="mo_discharge" and g.time<float(s.conductUntil) and kind in ["light","heavy"]:
   s.conductHits+=2 if kind=="heavy" and Paths.has(p,"mo_charge") else 1
   if int(s.conductHits)>=3:
    s.conductHits-=3;bonus+=8.0
    g._emit("lightningDischarge",{"sourceId":p.id,"targetId":foe.id,"x":foe.x,"damage":8.0})
    if Paths.has(p,"mo_arc"):
     for other:Dictionary in g.enemies:
      if other.id!=foe.id and other.hp>0 and absf(other.x-foe.x)<=2.5:
       _arc(g,other,6.0);break
  if attack.get("eclipseCrack",false) and first:
   if Paths.has(p,"mo_open"):g._gain_energy(p,10.0)
   if Paths.has(p,"mo_follow"):s.chaseUntil=g.time+3.0
 elif p.style=="hawk_of_the_fog":
  if kind=="ability" and last and not attack.get("armorFinalPaid",false):
   attack.armorFinalPaid=true;s.flashUntil=g.time+9.0
   if p.armorCore=="fo_flash":s.linkUntil=g.time+3.0
  if attack.get("fogLink",false) and first and int(attack.get("fogCharges",0))>0:
   var cost:=0.0 if Paths.has(p,"fo_step") else 10.0
   if p.energy>=cost:g.spend_energy(cost);p.skillCooldown=0.0
   if Paths.has(p,"fo_breath") and int(attack.fogCharges)>=2:p.fogCharges=mini(3,int(p.fogCharges)+1)
  if attack.get("fogStorm",false) and first:
   var count:=0
   for other:Dictionary in g.enemies:
    if other.id!=foe.id and other.hp>0 and absf(other.x-foe.x)<=2.6:
     _arc(g,other,12.0);count+=1
     if count==2:break
   if Paths.has(p,"fo_relay"):g._gain_energy(p,6.0*count)
 attack.armorPaid=true
 return bonus

static func _arc(g,foe:Dictionary,amount:float) -> void:
 var damage:=minf(float(foe.hp),amount*float(g.player.damageMultiplier))
 g._take_health(foe,damage);g.stats.damageDealt+=damage
 g._emit("lightningDischarge",{"sourceId":g.player.id,"targetId":foe.id,"x":foe.x,"damage":damage})
 if foe.hp<=0:g._state(foe,"dead")
 g._mark_down(foe);g._check_boss_phase(foe)

static func evaded(g) -> void:
 var p:Dictionary=g.player
 if not active(p) or p.armorCore!="fo_sky":return
 # One ticket per actual dodge, even when several hitboxes overlap.
 if is_equal_approx(float(p.armorState.get("skyDodge",-10.0)),float(p.nextDodgeAt)):return
 p.armorState.skyDodge=p.nextDodgeAt
 p.armorState.skyUntil=g.time+(5.0 if Paths.has(p,"fo_window") else 3.0)
 if Paths.has(p,"fo_window"):g._gain_energy(p,10.0)

static func broken(g,foe:Dictionary) -> void:
 if not Paths.has(g.player,"az_spread") or g.time>=float(foe.get("inkUntil",-1.0)):return
 for other:Dictionary in g.enemies:
  if other.id!=foe.id and other.hp>0 and absf(other.x-foe.x)<=3.0:_ink(other,g.time,0.25)

static func ultimate_begin(g) -> void:
 var p:Dictionary=g.player
 if not active(p):return
 var s:Dictionary=p.armorState
 s.ultBonus=0.0;s.ultRefund=0.0;s.ultSky=false
 if p.armorCore=="ph_prana":
  s.ultBonus=0.15*int(s.prana)
  s.prana=mini(1,int(s.prana)) if Paths.has(p,"ph_reserve") else 0
 if s.yangRefund:s.ultRefund=20.0;s.yangRefund=false
 if p.armorCore=="fo_sky":s.ultSky=g.time<float(s.skyUntil);s.skyUntil=-1.0

static func ultimate_multiplier(p:Dictionary,foe:Dictionary,time:float) -> float:
 if not active(p):return 1.0
 if p.armorCore=="ph_prana" and Paths.has(p,"ph_reserve"):foe.lihuoUntil=time+6.0
 return 1.0+float(p.armorState.get("ultBonus",0.0))+(float(foe.get("inkPower",0.15)) if time<float(foe.get("inkUntil",-1.0)) else 0.0)

static func ultimate_end(g) -> void:
 var p:Dictionary=g.player
 if not active(p):return
 var s:Dictionary=p.armorState
 g._gain_energy(p,float(s.get("ultRefund",0.0)));s.ultRefund=0.0;s.ultBonus=0.0
 if p.style=="shadow_knight":s.eclipseAdded=0.0
 if p.style=="hawk_of_the_fog":
  s.flashUntil=g.time+9.0
  if s.get("ultSky",false) and Paths.has(p,"fo_return"):p.fogCharges=3;p.skillCooldown=0.0

static func eclipse_end(g) -> void:
 if Paths.has(g.player,"mo_return"):g._gain_energy(g.player,20.0);g.player.skillCooldown=0.0
