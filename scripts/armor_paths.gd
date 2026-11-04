extends RefCounted
## Side-view adaptations of each armor's resource loop, separate from native animation/VFX.
const Night=preload("res://scripts/night_paths.gd")
const STYLES := {"azure_empyrea":"云墨丹心","fenghuang":"炽翎","shadow_knight":"影骑士·月轮","hawk_of_the_fog":"雾都迅羽","night_squire":"白夜执事"}
const BASICS := {
 "azure_empyrea":"J 命中积阳，K 命中积阴，上限三层。三层时 E 消耗印记，忽略冷却：三阳回 18 SP，三阴附加 6 秒易伤，混色牵引敌人。",
 "fenghuang":"K 或 J 第三段命中积攒神通，须与上次的拳 / 腿式不同；最多三格。E 切换拳腿。分支命中附加 6 秒离火，后续 J 追加 2 点伤害，每 0.7 秒一次。",
 "shadow_knight":"Q 开启 10 秒月食，切换原有爆发连段。月食中每三次命中追加雷击。",
 "hawk_of_the_fog":"E 或 J 第三段命中积一层蓄雷，K 消耗蓄雷强化重击。E 末击或 Q 结束开启 9 秒雷闪，J 伤害提高 10%。"
}
const CORES := {
 "az_balance":{"id":"az_balance","style":"azure_empyrea","title":"阴阳相生","description":"J / K 积满三层混色印记，E 聚拢敌人并留下一层异色。","hint":"J + K 积三层 → E","rewards":["az_echo","az_bind"]},
 "az_yang":{"id":"az_yang","style":"azure_empyrea","title":"三阳回气","description":"J 积三阳，再用 E 命中恢复 30 SP，加快 Q 循环。","hint":"J 积三阳 → E 回能 → Q","rewards":["az_cycle","az_return"]},
 "az_yin":{"id":"az_yin","style":"azure_empyrea","title":"三阴破阵","description":"K 积三阴，E 标记 25% 易伤；K 可穿过标记敌人的格挡。","hint":"K 积三阴 → E 标记 → K","rewards":["az_fracture","az_spread"]},
 "ph_turn":{"id":"ph_turn","style":"fenghuang","title":"神通流转","description":"K 命中后用 E 换拳腿积神通；满三格时，E 消耗神通打出强力换式。","hint":"K → E 换式 → K；三格时 E","rewards":["ph_refill","ph_rekindle"]},
 "ph_fire":{"id":"ph_fire","style":"fenghuang","title":"离火相续","description":"J 引燃离火的伤害翻倍；K 消耗离火引爆，E 重新挂火。","hint":"分支挂火 → J 引燃 / K 引爆","rewards":["ph_spread","ph_fuel"]},
 "ph_prana":{"id":"ph_prana","style":"fenghuang","title":"丹心蓄势","description":"保留神通到 Q，每格提高本次必杀 15% 伤害，随后消耗。","hint":"交替拳腿攒神通 → Q","rewards":["ph_reserve","ph_wings"]},
 "mo_eclipse":{"id":"mo_eclipse","style":"shadow_knight","title":"月食续战","description":"月食中 E 末击消耗 15 SP，延长月食 2 秒，每次最多续 6 秒。","hint":"Q → E 连打续月食","rewards":["mo_long","mo_return"]},
 "mo_discharge":{"id":"mo_discharge","style":"shadow_knight","title":"断海鸣雷","description":"E 末击开启 6 秒引雷；期间 J / K 每三次命中追加雷击。","hint":"E 引雷 → J / K 触发雷击","rewards":["mo_arc","mo_charge"]},
 "mo_heavy":{"id":"mo_heavy","style":"shadow_knight","title":"裂空破军","description":"月食中 E 末击强化下一次 K：穿过格挡，追加 30 架势伤害。","hint":"Q → E 末击 → K 破守","rewards":["mo_open","mo_follow"]},
 "fo_flash":{"id":"fo_flash","style":"hawk_of_the_fog","title":"雷闪疾行","description":"E 末击后 3 秒内，带蓄雷的 K 命中消耗 10 SP，重置 E。","hint":"E → K → E 循环追击","rewards":["fo_step","fo_breath"]},
 "fo_storm":{"id":"fo_storm","style":"hawk_of_the_fog","title":"霹雳连环","description":"攒满三层蓄雷再按 K，命中时对附近敌人追加雷击。","hint":"E / J 三连积蓄雷 → 满层 K","rewards":["fo_shatter","fo_relay"]},
 "fo_sky":{"id":"fo_sky","style":"hawk_of_the_fog","title":"惊雷破空","description":"成功闪避后 3 秒内，Q 只需 70 SP；保留能量抓住爆发机会。","hint":"成功闪避 → Q","rewards":["fo_window","fo_return"]}
}
const REWARDS := {
 "az_echo":{"id":"az_echo","core":"az_balance","title":"阴阳回环","description":"混色 E 命中后，留下阴、阳各一层。"},
 "az_bind":{"id":"az_bind","core":"az_balance","title":"墨阵留形","description":"混色 E 使敌人多露出 0.6 秒破绽；首领为 0.25 秒。"},
 "az_cycle":{"id":"az_cycle","core":"az_yang","title":"阳生不息","description":"三阳 E 命中后，下一次 J 命中额外积一层阳。"},
 "az_return":{"id":"az_return","core":"az_yang","title":"归元养气","description":"三阳 E 命中后的下一次 Q，结束返还 20 SP。"},
 "az_fracture":{"id":"az_fracture","core":"az_yin","title":"寸阴断势","description":"K 命中三阴标记，追加 25 架势伤害；每个标记一次。"},
 "az_spread":{"id":"az_spread","core":"az_yin","title":"墨痕相染","description":"击破带三阴标记敌人的架势，将标记传给附近敌人。"},
 "ph_refill":{"id":"ph_refill","core":"ph_turn","title":"余火归心","description":"满神通 E 消耗后保留一格神通。"},
 "ph_rekindle":{"id":"ph_rekindle","core":"ph_turn","title":"转式生焰","description":"满神通 E 命中后，下一次 K 命中额外补一格神通。"},
 "ph_spread":{"id":"ph_spread","core":"ph_fire","title":"离火燎原","description":"K 引爆离火时，将离火传给附近敌人。"},
 "ph_fuel":{"id":"ph_fuel","core":"ph_fire","title":"薪火相续","description":"J 第三段命中带离火的敌人，将离火刷新至 9 秒。"},
 "ph_reserve":{"id":"ph_reserve","core":"ph_prana","title":"丹心留火","description":"Q 消耗神通后保留一格；命中敌人附加离火。"},
 "ph_wings":{"id":"ph_wings","core":"ph_prana","title":"赤羽归息","description":"满神通时，K 命中额外恢复 10 SP，每招一次。"},
 "mo_long":{"id":"mo_long","core":"mo_eclipse","title":"长夜未央","description":"每次月食可延长的上限由 6 秒提高到 10 秒。"},
 "mo_return":{"id":"mo_return","core":"mo_eclipse","title":"退月回流","description":"月食结束时恢复 20 SP，并重置 E 冷却。"},
 "mo_arc":{"id":"mo_arc","core":"mo_discharge","title":"雷鸣相逐","description":"引雷触发的雷击会传向附近另一名敌人，造成 6 点伤害。"},
 "mo_charge":{"id":"mo_charge","core":"mo_discharge","title":"重拳引雷","description":"引雷期间，K 命中按两次计算雷击积数。"},
 "mo_open":{"id":"mo_open","core":"mo_heavy","title":"裂空回响","description":"强化 K 命中时返还 10 SP，每招一次。"},
 "mo_follow":{"id":"mo_follow","core":"mo_heavy","title":"崩拳追月","description":"强化 K 命中后 3 秒内，可消耗 10 SP 无视冷却接 E。"},
 "fo_step":{"id":"fo_step","core":"fo_flash","title":"游雷无隙","description":"E 后接 K 重置 E，不再消耗 SP。"},
 "fo_breath":{"id":"fo_breath","core":"fo_flash","title":"回风聚雷","description":"E 后接 K 命中，若消耗至少两层蓄雷，返还一层。"},
 "fo_shatter":{"id":"fo_shatter","core":"fo_storm","title":"霹雳破壁","description":"三层蓄雷的 K 可穿过格挡，确保雷击打出。"},
 "fo_relay":{"id":"fo_relay","core":"fo_storm","title":"群雷归流","description":"满层 K 每雷击一名额外敌人，返还 6 SP，最多 12 SP。"},
 "fo_window":{"id":"fo_window","core":"fo_sky","title":"惊雷留隙","description":"闪避后低消耗 Q 的窗口延长至 5 秒，并立即恢复 10 SP。"},
 "fo_return":{"id":"fo_return","core":"fo_sky","title":"千龙回身","description":"低消耗 Q 结束时，补满三层蓄雷并重置 E。"}
}

static func options(style:String) -> Array:
 if style=="night_squire":return Night.options()
 var rows:Array=[]
 for core:Dictionary in CORES.values():
  if core.style==style:rows.append(core.duplicate(true))
 return rows

static func valid(style:String,id:String) -> bool:
 return Night.CORES.has(id) if style=="night_squire" else CORES.has(id) and CORES[id].style==style

static func setup(p:Dictionary,id:String,ids:Array) -> void:
 p.armorCore=id if CORES.has(id) and CORES[id].style==p.style else ""
 p.armorPerks={}
 p.armorState={}
 if p.armorCore.is_empty():return
 if not p.armorCore.is_empty():
  for perk:String in ids:
   if REWARDS.has(perk) and REWARDS[perk].core==id:p.armorPerks[perk]=true
 p.armorState={"yin":0,"yang":0,"prana":0,"branch":"","flashUntil":-1.0,"linkUntil":-1.0,"skyUntil":-1.0,"conductUntil":-1.0,"conductHits":0,"eclipseAdded":0.0,"heavyUntil":-1.0,"chaseUntil":-1.0,"yangNext":false,"yangRefund":false,"rekindle":false}

static func has(p:Dictionary,id:String) -> bool:
 return p.get("armorPerks",{}).has(id)

static func readout(p:Dictionary,time:float) -> String:
 if p.get("armorCore","").is_empty():return ""
 var s:Dictionary=p.armorState
 match str(p.style):
  "azure_empyrea":return "阳 %d  阴 %d"%[s.yang,s.yin]
  "fenghuang":return "%s · 神通 %d/3"%["拳" if p.stance=="punch" else "腿",s.prana]
  "shadow_knight":
   if time<float(s.chaseUntil):return "E 追月"
   if time<float(s.heavyUntil):return "K 裂空"
   if p.armorCore=="mo_discharge" and time<float(s.conductUntil):return "引雷 %d/3"%s.conductHits
   return "月食 %ds"%ceili(float(p.eclipseRemaining)) if p.eclipseRemaining>0 else "月食待机"
  "hawk_of_the_fog":
   if time<float(s.skyUntil):return "Q · 70 SP"
   return "蓄雷 %d/3%s"%[p.fogCharges," · 雷闪" if time<float(s.flashUntil) else ""]
 return ""
