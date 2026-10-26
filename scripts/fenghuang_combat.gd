extends RefCounted
## Side-view adaptation: fists trade reach for recovery; kicks control distance.
## Timings and damage are this demo's balance, not the original game's values.
const SWITCH_COOLDOWN := 1.35
const PUNCHES := [
	{"duration":0.42,"windup":0.14,"damage":6.0,"postureDamage":11.0,"range":1.65,"push":0.10,"stun":0.30},
	{"duration":0.45,"windup":0.17,"damage":7.0,"postureDamage":14.0,"range":1.80,"push":0.13,"stun":0.34},
	{"duration":0.68,"windup":0.34,"damage":11.0,"postureDamage":23.0,"range":1.95,"push":0.40,"stun":0.47}
]
const KICKS := [
	{"duration":0.60,"windup":0.25,"damage":7.0,"postureDamage":14.0,"range":2.25,"push":0.20,"stun":0.36},
	{"duration":0.65,"windup":0.29,"damage":9.0,"postureDamage":17.0,"range":2.45,"push":0.24,"stun":0.40},
	{"duration":0.88,"windup":0.47,"damage":13.0,"postureDamage":28.0,"range":2.65,"push":0.65,"stun":0.53}
]

static func attack(kind: String, index: int, stance: String, counter: bool = false) -> Dictionary:
	var kick := stance == "kick"
	var data: Dictionary
	if counter:
		data={"name":"heavy","duration":0.72,"windup":0.19,"damage":16.0,"postureDamage":35.0,"range":2.35 if kick else 2.05,"push":0.55,"stun":0.65,"motion":"counter_"+stance}
	elif kind == "ability":
		data={"name":"ability","duration":0.56,"windup":0.24,"damage":5.0,"postureDamage":18.0,"range":2.30 if kick else 1.95,"push":0.18,"stun":0.38,"motion":"switch_"+stance}
	elif kind == "heavy":
		data={"name":"heavy","duration":1.02 if kick else 0.78,"windup":0.61 if kick else 0.43,"damage":19.0 if kick else 15.0,"postureDamage":42.0 if kick else 34.0,"range":2.75 if kick else 2.0,"push":0.80 if kick else 0.48,"stun":0.59 if kick else 0.51}
	else:
		data=(KICKS[index] if kick else PUNCHES[index]).duplicate(true)
		data.name="light"
	data.comboIndex=index
	data.active=0.12
	data.stance=stance
	return data
