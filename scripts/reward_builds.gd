extends RefCounted
## Derived bonuses: never write a set bonus back into the saved base carry.
const GROUPS := {
 "counter":{"title":"守中反击","ids":["reflection","riposte","calm","focus"],"two":"极限防御额外回复 5 SP","three":"防反追击伤害再提高 15%"},
 "dodge":{"title":"游身逐风","ids":["swift","windstep","crosswind"],"two":"成功闪避额外回复 6 SP","three":"闪避后下一招伤害再提高 20%"},
 "combo":{"title":"寸劲连环","ids":["fist","iron","finisher","chainflow","crack"],"two":"J 三连末段额外造成 12 点架势伤害","three":"J 三连末段额外缩短 E 冷却 0.6 秒"},
 "burst":{"title":"气贯长虹","ids":["flow","reservoir","risk","afterglow"],"two":"必杀结束时返还 12 SP","three":"必杀结束后 6 秒，J / K / E 伤害提高 15%"}
}
const NEW_IDS := ["crosswind","chainflow","afterglow","crack","focus","sustain"]

static func family(id: String) -> String:
 for key: String in GROUPS:
  if id in GROUPS[key].ids: return key
 return ""

static func count(ids: Array,key: String) -> int:
 var total:=0
 for id: String in ids:
  if id in GROUPS[key].ids: total+=1
 return total

static func preview(ids: Array,id: String) -> String:
 var key:=family(id)
 if key.is_empty(): return "调息补给\n独立生效，可搭配任意招式"
 var group: Dictionary=GROUPS[key]
 var current:=count(ids,key)
 var next:=current+1
 var bonus: String=group.two if next<=2 else group.three
 return "%s · %d → %d 招\n%s：%s"%[group.title,current,next,"凑齐 2 招" if next<2 else "激活 2 招" if next==2 else "激活 3 招" if next==3 else "3 招效果已生效",bonus]

static func summary(ids: Array) -> String:
 var parts: PackedStringArray=[]
 for key: String in GROUPS:
  var amount:=count(ids,key)
  if amount>0: parts.append("%s %d/3%s"%[GROUPS[key].title,mini(3,amount)," · 已成势" if amount>=2 else ""])
 return "  /  ".join(parts)

static func carry(base: Dictionary,ids: Array) -> Dictionary:
 var result:=base.duplicate(true)
 result.merge({"dodgeStrike":0.0,"finisherRefund":0.0,"afterglowBonus":0.0,"breakBonus":0.0,"riposteRefund":0.0,"killHeal":0.0,"killEnergy":0.0,"parryEnergy":0.0,"dodgeEnergy":0.0,"finisherPosture":0.0,"ultimateRefund":0.0},true)
 if "crosswind" in ids: result.dodgeStrike+=0.45
 if "chainflow" in ids: result.finisherRefund+=1.2
 if "afterglow" in ids: result.afterglowBonus+=0.25
 if "crack" in ids: result.breakBonus+=0.25
 if "focus" in ids: result.riposteRefund+=2.0
 if "sustain" in ids: result.killHeal+=4.0; result.killEnergy+=8.0
 if count(ids,"counter")>=2: result.parryEnergy+=5.0
 if count(ids,"counter")>=3: result.riposteBonus+=0.15
 if count(ids,"dodge")>=2: result.dodgeEnergy+=6.0
 if count(ids,"dodge")>=3: result.dodgeStrike+=0.20
 if count(ids,"combo")>=2: result.finisherPosture+=12.0
 if count(ids,"combo")>=3: result.finisherRefund+=0.6
 if count(ids,"burst")>=2: result.ultimateRefund+=12.0
 if count(ids,"burst")>=3: result.afterglowBonus+=0.15
 return result
