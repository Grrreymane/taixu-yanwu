extends RefCounted
## Character identifies the person; style owns the moveset; appearance owns art.
## Add a style for a new armor's distinct attacks, or an appearance for a skin
## that keeps those attacks. Entries are selectable only after integration.
## Combat profiles are identifiers, not a second copy of combat.gd's balance.

const DEFAULT_CHARACTER := "fuhua"
const DEFAULT_STYLE := "azure_empyrea"
const DEFAULT_APPEARANCE := "default"
const FACIAL_ANIMATION := "res://assets/motions/fuhua-face-atlas.json"
const ShadowKnight := preload("res://assets/shadow-knight/roster.gd")
const HawkOfFog := preload("res://assets/hawk-of-the-fog/roster.gd")
const FireAndSword := preload("res://assets/phoenix-fire-sword/roster.gd")
const NightSquireSkins := preload("res://assets/night-squire-skins/roster.gd")

# Compatibility names allow actor.gd to adopt the catalog without changing its
# public setup(ghost) call or the motion sampler's existing dictionary shape.
const MODEL_PATH := "res://assets/azure/Avatar_Fuka_C5_IN.fbx"
const TEX_DIR := "res://assets/azure/"
const PREFIX := "Avatar_Fuka_Ani_C5_"
const MOTIONS: Dictionary = {
	"idle": {"clip": "StandBy", "end": 2.016667},
	"intro": {"clip": "StandBy", "end": 2.016667},
	"move": {"clip": "Run", "end": 0.65},
	"guard": {"clip": "StandBy", "end": 2.016667},
	"dodge": {"clip": "Evadeforward", "end": 0.55},
	"dodgeBack": {"clip": "EvadeBackward", "end": 0.55},
	"stagger": {"clip": "Hit_L", "end": 1.283333},
	"dead": {"clip": "Die", "end": 1.933333},
	"light1": {"clip": "Attack01", "end": 0.8, "contact": 0.22},
	"light2": {"clip": "Attack02", "end": 0.65, "contact": 0.15},
	"light3": {"clip": "Attack03", "end": 1.12, "contact": 0.95},
	"heavy": {"clip": "Attack_Charge_03", "end": 1.3, "contact": 0.83},
	"ability": {"clip": "Attack04", "end": 1.12, "contact": 0.65},
	"ultimate": {"clip": "Ultra", "end": 3.85}
}
const ATTACK_PACING: Dictionary = {
	"light3": [Vector2(0.40, 0.60), Vector2(0.72, 0.67)],
	"heavy": [Vector2(0.38, 0.51), Vector2(0.72, 0.60)],
	"ability": [Vector2(0.38, 0.48), Vector2(0.72, 0.59)]
}

const PHOENIX_TEX := "res://assets/phoenix/"
const PHOENIX_MOTIONS: Dictionary = {
	"idle": {"clip":"StandBy","end":2.0},
	"intro": {"clip":"Combat","end":2.0},
	"move": {"clip":"Run","end":0.6667},
	"guard": {"clip":"Combat","end":2.0},
	"dodge": {"clip":"EvadeForward","end":0.64},
	"dodgeBack": {"clip":"EvadeBackward","end":0.60},
	"stagger": {"clip":"Hit_L","end":0.9167},
	"dead": {"clip":"Die","end":3.1333},
	"light1": {"clip":"JW_A1","end":0.82,"contact":0.18},
	"light2": {"clip":"JW_C2_1","end":0.95,"contact":0.32},
	"light3": {"clip":"JW_A3","end":0.85,"contact":0.25},
	"kick_light1": {"clip":"JW_B1","end":0.86,"contact":0.30},
	"kick_light2": {"clip":"JW_B2","end":0.85,"contact":0.24},
	"kick_light3": {"clip":"JW_B3","end":0.90,"contact":0.25},
	"heavy": {"clip":"JW_C1_1","end":1.05,"contact":0.25},
	"kick_heavy": {"clip":"JW_A5","end":1.05,"contact":0.45},
	"ability": {"clip":"JW_A4","end":0.90,"contact":0.26},
	"switch_kick": {"clip":"JW_A4","end":0.90,"contact":0.26},
	"switch_punch": {"clip":"JW_C3_1","end":0.90,"contact":0.22},
	"counter_punch": {"clip":"JW_C2_1","end":0.85,"contact":0.32},
	"counter_kick": {"clip":"JW_B2","end":0.85,"contact":0.24},
	"ultimate": {"clip":"JW_Ultra","end":3.4667}
}

const NIGHT_SQUIRE_TEX := "res://assets/night-squire/"
const NIGHT_SQUIRE_AUTUMN_TEX := "res://assets/night-squire-autumn/"
# Original C3_ND clips. Shortened end times only omit long recovery tails;
# every played pose comes from the unmodified source take on its own skeleton.
const NIGHT_SQUIRE_MOTIONS: Dictionary = {
	"idle": {"clip":"StandBy","end":2.0},
	"intro": {"clip":"Combat","end":2.0},
	"move": {"clip":"Run","end":0.6666667},
	"guard": {"clip":"Combat","end":2.0},
	"dodge": {"clip":"EvadeForward","end":0.64},
	"dodgeBack": {"clip":"EvadeBackward","end":0.60},
	"stagger": {"clip":"Hit_L","end":0.916667},
	"dead": {"clip":"Die","end":3.133333},
	"light1": {"clip":"ND_A","end":0.78,"contact":0.40},
	"light2": {"clip":"ND_AA","end":0.86,"contact":0.166667},
	"light3": {"clip":"ND_AAA","end":1.10,"contact":0.416667},
	"kick_light1": {"clip":"ND_B","end":1.08,"contact":0.316667},
	"kick_light2": {"clip":"ND_BB","end":0.86,"contact":0.166667},
	"kick_light3": {"clip":"ND_BBB","end":1.10,"contact":0.266667},
	"heavy": {"clip":"ND_AAB","end":1.10,"contact":0.25},
	"kick_heavy": {"clip":"ND_BBA","end":1.18,"contact":0.733333},
	"ability": {"clip":"ND_BAA","end":1.25,"contact":0.40},
	"counter_punch": {"clip":"ND_AB","end":1.0,"contact":0.60},
	"counter_kick": {"clip":"ND_BA","end":0.85,"contact":0.20},
	"ultimate": {"clip":"ND_Ultra","end":1.5833334}
}

const CHARACTERS: Dictionary = {
	"fuhua": {
		"id": "fuhua", "name": "符华", "playable": true,
		"defaultStyle": "azure_empyrea", "styles": ["azure_empyrea", "fenghuang", "night_squire", "shadow_knight", "hawk_of_the_fog"]
	}
}
const STYLES: Dictionary = {
	"shadow_knight": ShadowKnight.STYLE,
	"hawk_of_the_fog": HawkOfFog.STYLE,
	"night_squire": {
		"id":"night_squire", "characterId":"fuhua", "name":"白夜执事", "playable":true,
		"portraitPath":"res://assets/ui/portraits/FukaC3.png", "roleTag":"贴身连打",
		"combatProfile":"night_squire", "description":"贴身拳脚连打。E 接连击，Q 开启爆发；爆发期间追击更快、更有力。",
		"defaultAppearance":"default", "appearances":NightSquireSkins.ORDERED_IDS,
		"abilityName":"连环腿", "ultimateName":"天极之拳", "hasStances":false,
		"prefix":"Avatar_Fuka_Ani_", "motions":NIGHT_SQUIRE_MOTIONS, "attackPacing":{},
		"defense":{"libraryPath":"", "source":"native", "targetRig":"fuhua_c3",
			"fullGrounding":true,"guardClip":"Combat", "holdTime":0.18,
			"blockClip":"Hit_H", "blockStart":0.035,"blockEnd":0.14,"heavyBlockEnd":0.23,
			"parryClip":"EvadeBackward", "parryStart":0.0,"parryEnd":0.32},
		"victory":{"libraryPath":"", "source":"native", "clip":"Victory", "idleClip":"Victory_idle",
			"clipDuration":4.316667, "idleDuration":2.0, "presentationDuration":4.4, "fallbackMotion":"idle"}
	},
	"azure_empyrea": {
		"id": "azure_empyrea", "characterId": "fuhua", "name": "云墨丹心",
		"portraitPath":"res://assets/ui/portraits/FukaC5.png", "roleTag":"寸劲破势",
		"playable": true, "combatProfile": "azure_empyrea",
		"description": "近身拳脚连击，以寸劲破势，极限防御后反击，聚墨释放太虚之力。",
		"defaultAppearance": "default", "appearances": ["default", "taixu_memory"],
		"abilityName": "寸劲", "ultimateName": "太虚之握", "hasStances": false,
		"prefix": PREFIX, "motions": MOTIONS, "attackPacing": ATTACK_PACING,
		"defense": {
			"libraryPath": "res://assets/motions/lighter-defense.res",
			"source": "lighter_retargeted", "targetRig": "fuhua_c5",
			"guardClip": "Attack_ParryAid_H", "blockClip": "Attack_ParryAid_H",
			"parryClip": "Attack_ParryAid_L", "parryEnd": 0.32
		},
		"victory": {
			"libraryPath": "res://assets/motions/azure-victory.res", "source": "native",
			"clip": "Victory", "idleClip": "VictoryIdle",
			"leadInSkip": 0.60,
			"clipDuration": 3.8, "idleDuration": 2.016667, "presentationDuration": 4.4,
			"fallbackMotion": "idle"
		}
	},
	"fenghuang": {
		"id":"fenghuang", "characterId":"fuhua", "name":"炽翎", "playable":true,
		"portraitPath":"res://assets/ui/portraits/FukaC4.png", "roleTag":"拳腿换式",
		"combatProfile":"fenghuang", "description":"拳式近身快攻，腿式远击破势。E 换式，极限防御后 J 追击。",
		"defaultAppearance":"default", "appearances":["default","fire_and_sword"],
		"abilityName":"换式", "ultimateName":"火凤燎原", "hasStances":true,
		"prefix":"Avatar_Fuka_Ani_", "motions":PHOENIX_MOTIONS, "attackPacing":{},
		"defense": {"libraryPath":"res://assets/motions/phoenix-defense.res", "source":"lighter_retargeted", "targetRig":"fuhua_c4",
			"fullGrounding":true,"guardClip":"Attack_ParryAid_H", "blockClip":"Attack_ParryAid_H", "parryClip":"Attack_ParryAid_L", "parryEnd":0.32},
		"victory": {"libraryPath":"", "source":"native", "clip":"Victory", "idleClip":"Victory_idle",
			"clipDuration":4.316667, "idleDuration":2.0, "presentationDuration":4.4, "fallbackMotion":"idle"}
	}
}
# Appearance IDs are scoped to their style: several armors may each have a
# "default" look without accidentally sharing a model or material profile.
const APPEARANCES: Dictionary = {
	"shadow_knight": ShadowKnight.APPEARANCES,
	"hawk_of_the_fog": HawkOfFog.APPEARANCES,
	"night_squire": {
		"spring_traveler": NightSquireSkins.APPEARANCES.spring_traveler,
		"xuanyi_sushang": NightSquireSkins.APPEARANCES.xuanyi_sushang,
		"black_butler": NightSquireSkins.APPEARANCES.black_butler,
		"autumn_leaves":{"id":"autumn_leaves", "styleId":"night_squire", "name":"红叶知秋", "playable":true,
			"modelPath":NIGHT_SQUIRE_AUTUMN_TEX+"Avatar_Fuka_C3_04_03.scn", "textureDir":NIGHT_SQUIRE_AUTUMN_TEX, "rig":"fuhua_c3",
			"visual":{"height":2.85,"rootBone":"Bip001","headBone":"Bip001 Head","hiddenMeshes":[],
				"nativeMaterialProfile":"night_squire_autumn", "nativeMaterialCatalog":NIGHT_SQUIRE_AUTUMN_TEX+"material-profiles.json",
				# Original 04_03 skeleton, cloth/bag bones and Skin matrices retained.
				# CommonEmpty is native invisible hand geometry replaced by equipped gauntlets.
				"hiddenSurfaces":["body:1"],"surfaceKinds":{},
				"surfaceNativeRoles":{"nativefistweapon001:0":"weapon","nativefistweapon002:0":"weapon"},
				"surfaceShaderParameters":{"nativefistweapon001:0":{"has_lightmap":false},"nativefistweapon002:0":{"has_lightmap":false}},
				"textures":{"bodyColor":NIGHT_SQUIRE_AUTUMN_TEX+"Avatar_Fuka_C3_04_03_Texture_Body_Color.png",
					"bodyLightmap":NIGHT_SQUIRE_AUTUMN_TEX+"Avatar_Fuka_C3_04_03_Texture_Body_LightMap.png",
					"hairColor":NIGHT_SQUIRE_AUTUMN_TEX+"Avatar_Fuka_Texture_Hair_Color.png",
					"hairLightmap":NIGHT_SQUIRE_AUTUMN_TEX+"Avatar_Fuka_Texture_Hair_LightMap.png",
					"faceColor":NIGHT_SQUIRE_AUTUMN_TEX+"Avatar_Fuka_Texture_Face_Color.png",
					"faceMask":NIGHT_SQUIRE_AUTUMN_TEX+"Avatar_Fuka_FaceMap.png"},
				"outlinePixels":{"body":0.92,"hair":1.05,"face":0.38},
				"faceAtlas":{"scale":Vector2(0.25,0.25),"leftEyeOffset":Vector2(0.25,0.75),"otherOffset":Vector2(0.0,0.75)}
			}
		},
		"default":{"id":"default", "styleId":"night_squire", "name":"原装", "playable":true,
			"modelPath":NIGHT_SQUIRE_TEX+"Avatar_Fuka_C3_ND.scn", "textureDir":NIGHT_SQUIRE_TEX, "rig":"fuhua_c3",
			"visual":{"height":2.85,"rootBone":"Bip001","headBone":"Bip001 Head","hiddenMeshes":[],
				"nativeMaterialProfile":"night_squire", "nativeMaterialCatalog":NIGHT_SQUIRE_TEX+"material-profiles.json",
				# Body:1 is originally CommonEmpty / miHoYo_Special/Misc/Invisible.
				"hiddenSurfaces":["body:1"],"surfaceKinds":{"hair:1":"body"},
				"surfaceNativeRoles":{"nativefistweapon001:0":"weapon","nativefistweapon002:0":"weapon"},
				"surfaceShaderParameters":{"nativefistweapon001:0":{"has_lightmap":false},"nativefistweapon002:0":{"has_lightmap":false}},
				"textures":{"bodyColor":NIGHT_SQUIRE_TEX+"Avatar_Fuka_C3_Texture_Body_Color.png",
					"bodyLightmap":NIGHT_SQUIRE_TEX+"Avatar_Fuka_C3_Texture_Body_Lightmap.png",
					"hairColor":NIGHT_SQUIRE_TEX+"Avatar_Fuka_Texture_Hair_Color.png",
					"hairLightmap":NIGHT_SQUIRE_TEX+"Avatar_Fuka_Texture_Hair_LightMap.png",
					"faceColor":NIGHT_SQUIRE_TEX+"Avatar_Fuka_Texture_Face_Color.png",
					"faceMask":NIGHT_SQUIRE_TEX+"Avatar_Fuka_FaceMap.png"},
				"outlinePixels":{"body":0.92,"hair":1.05,"face":0.38},
				"faceAtlas":{"scale":Vector2(0.25,0.25),"leftEyeOffset":Vector2(0.25,0.75),"otherOffset":Vector2(0.0,0.75)}
			}
		}
	},
	"fenghuang": {
		"fire_and_sword": FireAndSword.APPEARANCE,
		"default": {"id":"default", "styleId":"fenghuang", "name":"原装", "playable":true,
			"modelPath":PHOENIX_TEX+"Avatar_Fuka_C4_JW.scn", "textureDir":PHOENIX_TEX, "rig":"fuhua_c4",
			"visual": {"height":2.85,"rootBone":"Bip001","headBone":"Bip001 Head", "hiddenMeshes":[],
				"facialAnimation":FACIAL_ANIMATION,
				"nativeMaterialProfile":"phoenix",
				"ultimateJumpLimit":0.65,
				"hiddenSurfaces":[],"surfaceKinds":{"hair:1":"body","hair:2":"body"},
				"bodyShadowTint":Vector3(0.9373,0.7647,0.7804),
				"textures": {"bodyColor":PHOENIX_TEX+"Avatar_Fuka_C4_Texture_Body_Color.png","bodyLightmap":PHOENIX_TEX+"Avatar_Fuka_C4_Texture_Body_LightMap.png",
					"hairLightmap":PHOENIX_TEX+"Avatar_Fuka_Texture_Hair_LightMap.png",
					"faceColor":PHOENIX_TEX+"Avatar_Fuka_Texture_Face_Color.png", "faceMask":PHOENIX_TEX+"Avatar_Fuka_FaceMap.png"},
				"outlinePixels":{"body":0.92,"hair":1.05,"face":0.38}, "hairShadowTint":Vector3(0.7419,0.6661,0.8088),
				"faceAtlas":{"scale":Vector2(0.25,0.25),"leftEyeOffset":Vector2(0.25,0.75),"otherOffset":Vector2(0.0,0.75)}
			}
		}
	},
	"azure_empyrea": {
		"default": {
			"id": "default", "styleId": "azure_empyrea", "name": "原装", "playable": true,
			"modelPath": MODEL_PATH, "textureDir": TEX_DIR, "rig": "fuhua_c5",
			"visual": {
				"height": 2.85, "rootBone": "Bip001", "headBone": "Bip001 Head",
				"facialAnimation":FACIAL_ANIMATION,
				"nativeMaterialProfile":"azure_default",
				"hiddenMeshes": ["umbrella_s", "body_effect"],
				"textures": {
					"bodyColor": TEX_DIR + "Avatar_Fuka_C5_Body_Color.png",
					"bodyLightmap": TEX_DIR + "Avatar_Fuka_C5_Body_Lightmap.png",
					"hairColor": TEX_DIR + "Avatar_Fuka_C5_Hair_Color.png",
					"hairLightmap": TEX_DIR + "Avatar_Fuka_C5_Hair_LightMap.png",
					"faceColor": TEX_DIR + "Avatar_Fuka_Texture_Face_Color.png",
					"faceMask": TEX_DIR + "Avatar_Fuka_C5_Face_LightMap.png"
				},
				"outlinePixels": {"body": 0.92, "hair": 1.05, "face": 0.38},
				"hairShadowTint": Vector3(0.7418865, 0.66608995, 0.8088235),
				"faceAtlas": {"scale": Vector2(0.25, 0.25),
					"leftEyeOffset": Vector2(0.25, 0.75), "otherOffset": Vector2(0.0, 0.75)}
			}
		},
		"taixu_memory": {
			"id": "taixu_memory", "styleId": "azure_empyrea", "name": "太虚仙忆", "playable": true,
			"modelPath": "res://assets/azure-skin/Avatar_Fuka_C5_04_02.scn", "textureDir": "res://assets/azure-skin/", "rig": "fuhua_c5",
			"visual": {
				"height": 2.85, "rootBone": "Bip001", "headBone": "Bip001 Head",
				"secondaryMotion": "taixu_memory",
				"facialAnimation":FACIAL_ANIMATION,
				"nativeMaterialProfile":"taixu_memory",
				"nativeBodyMesh":"res://assets/azure-skin/native-body-uv2.res",
				"hiddenMeshes": ["umbrella_s"],
				"textures": {
					"bodyLightmap": "res://assets/azure-skin/Avatar_Fuka_C5_04_02_Body_LightMap.png",
					"hairLightmap": "res://assets/azure-skin/Avatar_Fuka_C5_04_02_Hair_LightMap.png",
					"faceColor": "res://assets/azure-skin/Avatar_Fuka_Texture_Face_Color.png",
					"faceMask": "res://assets/azure-skin/Avatar_Fuka_FaceMap.png"
				},
				"outlinePixels": {"body": 0.92, "hair": 1.05, "face": 0.38},
				"hairShadowTint": Vector3(0.8112024, 0.8185606, 0.9117647),
				"faceAtlas": {"scale": Vector2(0.25, 0.25),
					"leftEyeOffset": Vector2(0.25, 0.75), "otherOffset": Vector2(0.0, 0.75)}
			}
		}
	}
}

static func list_characters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in CHARACTERS.values():
		if bool(entry.get("playable", false)):
			result.append(entry.duplicate(true))
	return result

static func list_styles(character_id: String = DEFAULT_CHARACTER) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var character: Dictionary = CHARACTERS.get(character_id, {})
	if not bool(character.get("playable", false)):
		return result
	for style_id: String in character.get("styles", []):
		var style: Dictionary = STYLES.get(style_id, {})
		if bool(style.get("playable", false)) and str(style.get("characterId", "")) == character_id:
			result.append(style.duplicate(true))
	return result

static func list_appearances(character_id: String = DEFAULT_CHARACTER, style_id: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var style := _style_for(character_id, style_id)
	if style.is_empty():
		return result
	var skins: Dictionary = APPEARANCES.get(str(style.id), {})
	for skin_id: String in style.get("appearances", []):
		var skin: Dictionary = skins.get(skin_id, {})
		if bool(skin.get("playable", false)) and str(skin.get("styleId", "")) == str(style.id):
			result.append(skin.duplicate(true))
	return result

## Empty style/appearance means that parent's default. A supplied invalid ID
## stays invalid; never silently turn a future or stale selection into Fu Hua.
static func resolve(character_id: String = DEFAULT_CHARACTER, style_id: String = "", appearance_id: String = "") -> Dictionary:
	var style := _style_for(character_id, style_id)
	if style.is_empty():
		return {}
	var chosen_skin := str(style.defaultAppearance) if appearance_id.is_empty() else appearance_id
	var skins: Dictionary = APPEARANCES.get(str(style.id), {})
	var skin: Dictionary = skins.get(chosen_skin, {})
	if not chosen_skin in style.appearances or not bool(skin.get("playable", false)) or str(skin.get("styleId", "")) != str(style.id):
		return {}
	return {
		"characterId": character_id, "styleId": str(style.id), "appearanceId": chosen_skin,
		"character": CHARACTERS[character_id].duplicate(true),
		"style": style.duplicate(true), "appearance": skin.duplicate(true),
		"actor": {
			"modelPath": skin.modelPath, "textureDir": skin.textureDir,
			"prefix": style.prefix, "motions": style.motions.duplicate(true),
			"attackPacing": style.attackPacing.duplicate(true), "visual": skin.visual.duplicate(true),
			"defense": style.defense.duplicate(true), "victory": style.victory.duplicate(true),
			"combatProfile": style.combatProfile, "rig": skin.rig
		}
	}

static func actor_config(character_id: String = DEFAULT_CHARACTER, style_id: String = "", appearance_id: String = "") -> Dictionary:
	var selection := resolve(character_id, style_id, appearance_id)
	return selection.get("actor", {})

static func presentation_identity(character_id: String = DEFAULT_CHARACTER, style_id: String = "", appearance_id: String = "") -> Dictionary:
	var selection := resolve(character_id, style_id, appearance_id)
	if selection.is_empty():
		return {}
	return {
		"characterId": selection.characterId, "styleId": selection.styleId, "appearanceId": selection.appearanceId,
		"characterName": selection.character.name, "styleName": selection.style.name,
		"skinName": selection.appearance.name, "description": selection.style.description,
		"abilityName": selection.style.get("abilityName","寸劲"),
		"ultimateName": selection.style.get("ultimateName","太虚之握"),
		"hasStances": selection.style.get("hasStances",false)
	}

static func _style_for(character_id: String, style_id: String) -> Dictionary:
	var character: Dictionary = CHARACTERS.get(character_id, {})
	if not bool(character.get("playable", false)):
		return {}
	var chosen_style := str(character.defaultStyle) if style_id.is_empty() else style_id
	var style: Dictionary = STYLES.get(chosen_style, {})
	if not chosen_style in character.styles or not bool(style.get("playable", false)) or str(style.get("characterId", "")) != character_id:
		return {}
	return style
