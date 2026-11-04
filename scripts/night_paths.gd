extends RefCounted
## White Night trial rules. Only gameplay data; native motions/VFX stay shared.
const CORES := {
 "counter":{"id":"counter","title":"防反破阵","description":"极限防御后接 K，将对手击退；撞到后排时造成一次碰撞打击。","hint":"L 防反 → K 击退破阵","rewards":["night_shock","night_chase"]},
 "dodge":{"id":"dodge","title":"闪避续招","description":"成功闪过攻击后，1.6 秒内按 J 可续接中断的下一段；未连招时从第二段起手。","hint":"连击 → 空格闪过攻击 → J 续招","rewards":["night_turn","night_step"]},
 "chain":{"id":"chain","title":"连势快攻","description":"J 第三段命中后，可无视冷却接 E，再接 J。一串连击只触发一次，断连后恢复。","hint":"J → J → J 命中 → E → J","rewards":["night_open","night_finish"]}
}
const REWARDS := {
 "night_shock":{"id":"night_shock","title":"隔山打牛","description":"防反 K 的碰撞可再传向下一名敌人，最多撞击两名后排。","core":"counter"},
 "night_chase":{"id":"night_chase","title":"追身寸劲","description":"防反 K 命中后，1.6 秒内可无视冷却接一次 E，沿原招式追身。","core":"counter"},
 "night_turn":{"id":"night_turn","title":"回身破守","description":"闪避续招也可用 K 收尾；这次重击可穿过格挡，命中仍需在招式范围内。","core":"dodge"},
 "night_step":{"id":"night_step","title":"踏风连步","description":"成功闪避后立即恢复一次闪避，续招窗口延长至 2.4 秒。每 2 秒触发一次。","core":"dodge"},
 "night_open":{"id":"night_open","title":"寸劲开门","description":"连势 E 的末段若被格挡，直接击破该敌人的架势。","core":"chain"},
 "night_finish":{"id":"night_finish","title":"拳脚相续","description":"连势 E 后，J 从第二段继续；也可接 K 收尾。","core":"chain"}
}
const BOSS := {
 "sword":{"title":"剑 · 连斩后撤","description":"剑连斩结束后会后撤。留意收招，追上去再反击。","cycle":["sword","sword","spear","chain"]},
 "spear":{"title":"枪 · 长距突刺","description":"长枪控制距离，突刺落空后有较长破绽；半血后接第二刺。","cycle":["spear","sword","spear","chain"]},
 "chain":{"title":"链 · 两段横扫","description":"链刃横扫后还有第二段红光。闪过第二段，再近身反击。","cycle":["chain","sword","chain","spear"]}
}

static func options() -> Array:
 var result:Array=[]
 for core:Dictionary in CORES.values():result.append(core.duplicate(true))
 return result

static func configure_boss(stages:Array,seed_value:int) -> void:
 var rng:=RandomNumberGenerator.new()
 rng.seed=seed_value+73019
 var id:String=BOSS.keys()[rng.randi_range(0,2)]
 var kit:Dictionary=BOSS[id]
 var stage:Dictionary=stages[5]
 var foe:Dictionary=stage.enemies[0]
 foe.bossPattern=id
 foe.weaponCycle=kit.cycle.duplicate()
 foe.tactic="range" if id=="spear" else "press"
 stage.arrangementTitle=kit.title
 stage.brief=kit.title+"。"+kit.description
 stage.encounterRule.description=kit.description+" 半血后仍会入梦，留意必杀红光。"

static func setup(player:Dictionary,core:String,ids:Array) -> void:
 player.nightCore=core if player.style=="night_squire" and CORES.has(core) else ""
 player.nightPerks={}
 if not player.nightCore.is_empty():
  for id:String in ids:
   if REWARDS.has(id) and REWARDS[id].core==core:player.nightPerks[id]=true
 player.nightResume=-1
 player.nightResumeUntil=-1.0
 player.nightDodgeIndex=1
 player.nightStepReadyAt=0.0
 player.nightFlowUntil=-1.0
 player.nightFlowUsed=false
 player.nightChaseUntil=-1.0

static func has(player:Dictionary,perk:String) -> bool:
 return player.get("nightPerks",{}).has(perk)

static func hint(player:Dictionary,time:float) -> String:
 match str(player.get("nightCore","")):
  "counter":return "E 追身" if time<float(player.get("nightChaseUntil",-1.0)) else "防反 → K 破阵"
  "dodge":return "K 破守 / J 续招" if time<float(player.get("nightResumeUntil",-1.0)) and has(player,"night_turn") else "J 续招" if time<float(player.get("nightResumeUntil",-1.0)) else "闪避续招"
  "chain":return "E 连势" if time<float(player.get("nightFlowUntil",-1.0)) else "连势已用 · 断连恢复" if player.get("nightFlowUsed",false) else "三连命中 → E"
 return ""
