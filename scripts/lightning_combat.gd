extends RefCounted
## Original C1 augmented / C2 motions; combat timing and damage fit this arena.
const PROFILES := ["shadow_knight", "hawk_of_the_fog"]
const ECLIPSE_DURATION := 10.0
const SHADOW_ULTIMATE := 3.116667
const FOG_ULTIMATE := 2.733333

static func supported(profile: String) -> bool:
 return profile in PROFILES

static func cooldown(profile: String) -> float:
 return 6.0 if profile=="shadow_knight" else 4.5

static func ultimate_duration(profile: String) -> float:
 return SHADOW_ULTIMATE if profile=="shadow_knight" else FOG_ULTIMATE

static func ultimate_cues(profile: String) -> Array:
 return [1.233333] if profile=="shadow_knight" else [0.47]

static func ultimate_damage(profile: String, index: int) -> float:
 return 46.0 if profile=="shadow_knight" else 54.0

static func attack(profile: String, kind: String, index: int, burst: bool=false) -> Dictionary:
 var step:=clampi(index,0,2)
 var result: Dictionary
 if profile=="shadow_knight":
  if kind=="ability":
   result={"duration":1.15,"windup":0.30,"damage":7.0,"postureDamage":15.0,"range":2.25,"push":0.07,"stun":0.42,"drive":1.15,
    "hitWindows":[0.30,0.50,0.76],"hitDamages":[7.0,7.0,10.0],"hitIndex":0,"motion":"burst_ability" if burst else "ability"}
   if burst:
    result.hitDamages=[9.0,9.0,14.0]
    result.postureDamage=20.0
  elif kind=="heavy":
   result={"duration":1.02 if burst else 0.95,"windup":0.44 if burst else 0.48,"damage":23.0 if burst else 17.0,"postureDamage":48.0 if burst else 38.0,"range":2.65 if burst else 2.30,"push":0.50,"stun":0.60,"motion":"burst_heavy" if burst else "heavy"}
  else:
   result={"duration":[0.62,0.64,0.86][step],"windup":[0.20,0.22,0.34][step],"damage":[7.0,8.0,12.0][step],"postureDamage":[14.0,16.0,26.0][step],"range":[1.85,2.00,2.20][step],"push":0.10 if step<2 else 0.42,"stun":0.36 if step<2 else 0.50,"motion":("burst_light" if burst else "light")+str(step+1)}
   if burst:
    result.damage*=1.20
    result.postureDamage*=1.15
 else:
  if kind=="ability":
   result={"duration":1.05,"windup":0.27,"damage":5.0,"postureDamage":12.0,"range":2.65,"push":0.07,"stun":0.42,"drive":2.2,"motion":"ability","hitWindows":[0.27,0.40,0.60],"hitDamages":[5.0,5.0,8.0],"hitIndex":0}
  elif kind=="heavy":
   result={"duration":0.92,"windup":0.36,"damage":15.0,"postureDamage":34.0,"range":2.35,"push":0.45,"stun":0.60,"motion":"heavy"}
  else:
   result={"duration":[0.48,0.52,0.76][step],"windup":[0.16,0.19,0.30][step],"damage":[5.0,7.0,11.0][step],"postureDamage":[10.0,13.0,24.0][step],"range":[1.72,1.86,2.05][step],"push":0.08 if step<2 else 0.35,"stun":0.33 if step<2 else 0.48,"motion":"light"+str(step+1)}
 result.name=kind
 result.comboIndex=step
 result.active=0.10
 result.eclipse=burst
 return result
