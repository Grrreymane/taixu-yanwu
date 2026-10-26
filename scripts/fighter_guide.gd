extends RefCounted
## Player-facing help for the current demo. Appearance never selects a moveset.
const Combat = preload("res://scripts/combat.gd")
const FenghuangCombat = preload("res://scripts/fenghuang_combat.gd")
const LightningCombat = preload("res://scripts/lightning_combat.gd")

static func for_style(style_id: String) -> Dictionary:
	var common := [
		{"key":"L", "title":"格挡 · 极限防御", "body":"按住格挡；在攻击将要命中时按下，可触发极限防御。红色不可防御招式请用闪避。", "detail":"格挡承受攻击会积累架势，满格时会被破防"},
		{"key":"SPACE", "title":"闪避", "body":"配合 A / D 朝指定方向闪避；没有方向输入时向后退。抓住敌人出手的瞬间避开攻击。", "detail":"A / D 或方向键移动 · 触屏可用下方方向按钮"}
	]
	var result: Dictionary
	match style_id:
		"shadow_knight":
			result = {
				"styleId":style_id, "name":"影骑士·月轮", "tag":"月食连打", "summary":"贴身连击积攒 SP，开启月食后接上更强的雷击连段。",
				"cooldown":LightningCombat.cooldown(style_id), "burstDuration":LightningCombat.ECLIPSE_DURATION,
				"moves":[
					{"key":"J", "title":"三段连击", "body":"连续按 J 衔接三段拳脚。月食期间换成爆发连段，命中三次便追加一道雷击。", "detail":"月食：每 3 次命中追加 8 点伤害"},
					{"key":"K", "title":"雷击重拳", "body":"连击后接重击，压制敌人架势。月食期间重击的伤害、破势和距离都更高。", "detail":"敌人破防后，可以继续接 J 或 E"},
					common[0], common[1],
					{"key":"E", "title":"雷霆连击", "body":"向前追击并连续出招，适合接在防反或普通连击之后；月食期间改用爆发连打。", "detail":"基础冷却 %.1f 秒" % LightningCombat.cooldown(style_id)},
					{"key":"Q", "title":"月食", "body":"跃起落地攻击，随后进入月食。趁爆发持续时接连出招，但仍要留意敌人的不可防御攻击。", "detail":"消耗 100 SP · 月食 %.0f 秒 · 受击伤害降低 20%%" % LightningCombat.ECLIPSE_DURATION}
				],
				"chain":"L 极限防御  →  E 连击  →  J  →  J  →  K",
				"tip":"Q 落地后继续进攻，别等月食结束。连续命中可以触发追加雷击；敌人亮出红色预警时先闪避。"
			}
		"hawk_of_the_fog":
			result = {
				"styleId":style_id, "name":"雾都迅羽", "tag":"雷闪追击", "summary":"用雷闪贴近敌人，积攒层数，再以重击消耗层数打破架势。",
				"cooldown":LightningCombat.cooldown(style_id),
				"moves":[
					{"key":"J", "title":"三段连击", "body":"连续按 J 衔接拳脚；第三段命中获得 1 层雷闪，并额外恢复 SP。", "detail":"第三段命中：雷闪 +1，SP +5"},
					{"key":"K", "title":"雷闪重击", "body":"消耗全部雷闪层数强化这一击。层数越多，伤害和破势越高。", "detail":"每层增加 5 点伤害、7 点破势"},
					common[0], common[1],
					{"key":"E", "title":"雷闪连击", "body":"快速向前追击。命中获得 1 层雷闪与 5 点 SP，可接重击，也可继续积攒层数。", "detail":"基础冷却 %.1f 秒 · 雷闪最多 3 层" % LightningCombat.cooldown(style_id)},
					{"key":"Q", "title":"千龙破天", "body":"跃起后落地攻击主目标及其附近的敌人。落地收势后，接雷闪继续追击。", "detail":"消耗 100 SP"}
				],
				"chain":"E 雷闪  →  J  →  J  →  J  →  K 重击",
				"tip":"雷闪层数会显示在血条上方。有 3 层时用 K 打出强化重击；距离拉开了，就用 E 追上。"
			}
		"fenghuang":
			result = {
				"styleId":style_id, "name":"炽翎", "tag":"拳腿换式", "summary":"拳式贴身快攻，腿式拉开距离；用换式衔接下一轮进攻。",
				"cooldown":FenghuangCombat.SWITCH_COOLDOWN,
				"moves":[
					{"key":"J", "title":"三段连击", "body":"连续按 J 衔接三段攻击。拳式出手快，腿式距离更远、收势稍慢。", "detail":"当前姿态决定使用拳式或腿式"},
					{"key":"K", "title":"重击", "body":"拳式重击适合贴身追打；腿式重击距离更远、破势更强。连击命中后可接 K。", "detail":"看准破绽出手，避免被打断"},
					common[0], common[1],
					{"key":"E", "title":"换式", "body":"出招并切换拳式 / 腿式。连击收势时也能换式，调整下一招的距离。", "detail":"基础冷却 %.2f 秒" % FenghuangCombat.SWITCH_COOLDOWN},
					{"key":"Q", "title":"火凤燎原", "body":"消耗 SP 释放火焰必杀，对主目标及其附近的敌人造成两段攻击。", "detail":"消耗 100 SP"}
				],
				"chain":"L 极限防御  →  J 反击  →  J 连击 / K 重击",
				"tip":"防反后的 J 会使用当前姿态的专属反击。平时可先用拳式连打，再按 E 换腿式，用 K 追击。"
			}
		"night_squire":
			result = {
				"styleId":style_id, "name":"白夜执事", "tag":"贴身连打", "summary":"连环腿积攒烈波，拳脚消耗烈波；开启爆发后持续压制。",
				"cooldown":Combat.NIGHT_SKILL_COOLDOWN, "burstDuration":Combat.NIGHT_BURST_DURATION,
				"moves":[
					{"key":"J", "title":"三段连击", "body":"连续按 J 衔接拳击；爆发期间换成更快、更强的踢击。第三段命中可缩短 E 的冷却。", "detail":"第三段命中：E 冷却减少 0.65 秒"},
					{"key":"K", "title":"重击", "body":"拳脚重击压制敌人架势。连击命中后可接 K；爆发期间重击更强、距离更远。", "detail":"有烈波时，J / K 每次出手消耗 1 层强化"},
					common[0], common[1],
					{"key":"E", "title":"连环腿", "body":"近身三连踢，命中后获得 3 层烈波，强化接下来三次 J / K 的伤害和破势。", "detail":"基础冷却 %.1f 秒 · 烈波最多 3 层" % Combat.NIGHT_SKILL_COOLDOWN},
					{"key":"Q", "title":"天极之拳", "body":"开启爆发，强化拳脚连段，补满 3 层烈波并重置 E 冷却。起式后接连击持续进攻。", "detail":"消耗 100 SP · 爆发持续 %.0f 秒" % Combat.NIGHT_BURST_DURATION}
				],
				"chain":"L 极限防御  →  E 连环腿  →  J  →  J  →  K",
				"tip":"E 还在冷却时，防反后直接接 J。想更快再用连环腿，就打完 J 的第三段；Q 起式结束后也可接 E。"
			}
		_:
			result = {
				"styleId":"azure_empyrea", "name":"云墨丹心", "tag":"寸劲破势", "summary":"用连击寻找破绽，寸劲击破架势，再以重击追打。",
				"cooldown":8.0,
				"moves":[
					{"key":"J", "title":"三段连击", "body":"连续按 J 衔接三段拳脚。前两段出手快，第三段收招更重、破势更强。", "detail":"连击过程中可提前输入下一段"},
					{"key":"K", "title":"重击", "body":"蓄势重击，伤害和破势都高于普通连击。连击命中后可接 K，追打敌人的破绽。", "detail":"适合连击收尾或破防后追击"},
					common[0], common[1],
					{"key":"E", "title":"寸劲", "body":"向前打出寸劲，造成较强的架势伤害。极限防御后接 E，更容易抓住敌人的硬直。", "detail":"基础冷却 8 秒"},
					{"key":"Q", "title":"太虚之握", "body":"消耗 SP 释放四段必杀，攻击主目标及其附近的敌人；最后一击造成更高伤害。", "detail":"消耗 100 SP"}
				],
				"chain":"L 极限防御  →  J  →  J  →  K / E",
				"tip":"防反成功就按下下一招，不必等角色完全站定。E 还在冷却时，先用 J 起手，再接重击。"
			}
	result["riposteWindow"] = Combat.RIPOSTE_WINDOW
	result["parryNote"] = "极限防御成功后，%.0f 秒内可接反击；命中停顿中也能提前输入。" % Combat.RIPOSTE_WINDOW
	return result.duplicate(true)
