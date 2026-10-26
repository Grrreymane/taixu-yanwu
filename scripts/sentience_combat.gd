extends RefCounted
## Horizontal encounters authored around the original C6 weapon motions.
## Source clip times live in presentation.json; these are playable warning windows.
const WEAPONS := ["sword", "spear", "chain"]
const LABELS := {"sword":"剑 · 连斩", "spear":"枪 · 突刺", "chain":"链 · 横扫", "burst":"识之律者 · 入梦"}

static func weapon_for(who: Dictionary, round_index: int) -> String:
	var fixed := str(who.get("weaponLock", ""))
	if fixed in WEAPONS: return fixed
	if bool(who.get("boss", false)):
		# A separate fifth turn owns the burst; it never consumes a sword turn.
		var cycle := 5 if int(who.get("phase", 1)) == 2 else 4
		var turn := posmod(maxi(0, round_index-1), cycle)
		return ["sword", "spear", "sword", "chain", "burst"][turn]
	var offset := 1 if who.get("type", "") == "duelist" else 2 if who.get("type", "") == "guardian" else 0
	return WEAPONS[posmod(maxi(0, round_index - 1) + offset, WEAPONS.size())]

static func attack(weapon: String, index: int, boss: bool, phase: int, phase_entry: bool = false) -> Dictionary:
	var step := clampi(index, 0, 2)
	var result := {"name":"light", "comboIndex":step, "duration":1.0, "windup":0.48, "active":0.12,
		"damage":6.5, "postureDamage":15.0, "range":2.1, "push":0.16, "stun":0.22,
		"weapon":weapon, "motion":"senti_sword_1", "nativeNext":-1, "unblockable":false,
		"armored":false, "phaseTransition":phase_entry, "drive":0.55, "recovery":0.85}
	match weapon:
		"sword":
			result.motion="senti_sword_%d" % (step + 1)
			result.windup=[0.48,0.34,0.58][step]
			result.duration=[0.91,0.82,1.22][step]
			result.damage=[6.5,7.0,10.0][step]
			result.range=[2.1,2.2,2.4][step]
			result.push=[0.12,0.16,0.48][step]
			result.nativeNext=step+1 if step<(2 if boss and phase==2 else 1) else -1
			result.stun=0.18
		"spear":
			step=mini(step,1)
			result.comboIndex=step
			result.motion="senti_spear_%d" % (step + 1)
			result.windup=0.72 if step==0 else 0.48
			result.duration=1.26 if step==0 else 1.12
			result.range=4.2 if step==0 else 3.8
			result.damage=9.0 if step==0 else 10.0
			result.push=0.34
			result.drive=0.9
			result.nativeNext=1 if step==0 and boss else -1
		"chain":
			step=mini(step,1)
			result.comboIndex=step
			result.name="heavy"
			result.motion="senti_chain_%d" % (step + 1)
			result.windup=0.88 if step==0 else 0.74
			result.duration=1.5 if step==0 else 1.48
			result.range=3.0 if step==0 else 2.8
			result.contactHeight=2.15 if step==0 else 1.3
			result.damage=11.0 if step==0 else 13.0
			result.postureDamage=34.0
			result.push=0.52
			result.stun=0.36
			result.drive=0.15
			result.nativeNext=1 if step==0 and boss and phase==2 else -1
			result.unblockable=step==1
			result.recovery=1.1
		"burst":
			result.name="heavy"
			result.motion="senti_burst"
			result.windup=1.5 if phase_entry else 1.15
			result.duration=result.windup+0.85
			result.range=3.6
			result.damage=17.0
			result.postureDamage=65.0
			result.push=0.75
			result.stun=0.42
			result.unblockable=true
			result.armored=true
			result.drive=0.0
			result.recovery=1.35
	if boss: result.damage*=1.1 if phase==2 else 1.0
	result.label=LABELS.get(weapon,LABELS.sword)
	return result

static func pressure_counter(source: Dictionary,full_chain: bool=false,continuation: bool=false) -> Dictionary:
	var result:=source.duplicate(true)
	var added: float=0.0 if continuation else maxf(0.0,0.64-float(result.windup))
	result.windup+=added
	result.duration+=added
	if not full_chain: result.nativeNext=-1
	result.counter=true
	result.pressureChain=full_chain
	result.armored=true
	result.heavyBreaksArmor=true
	result.recovery=1.05
	return result
