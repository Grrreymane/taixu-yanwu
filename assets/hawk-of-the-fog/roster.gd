extends RefCounted
## Original C1_05_01 augmented Fu Hua. Attack contact times below are measured
## pose peaks for the side-view adaptation, not recovered native damage events.
const TEX := "res://assets/hawk-of-the-fog/"
const MOTIONS: Dictionary = {
	"idle":{"clip":"StandBy","end":2.0},
	"intro":{"clip":"Combat","end":2.0},
	"move":{"clip":"Run","end":0.6666667},
	"guard":{"clip":"Combat","end":2.0},
	"dodge":{"clip":"EvadeForward","end":0.64},
	"dodgeBack":{"clip":"EvadeBackward","end":0.60},
	"stagger":{"clip":"Hit_L","end":0.9166667},
	"dead":{"clip":"Die","end":3.1333334},
	"light1":{"clip":"A1","end":0.68,"contact":0.10},
	"light2":{"clip":"A2","end":0.62,"contact":0.10},
	"light3":{"clip":"A3","end":0.90,"contact":0.2333333},
	"heavy":{"clip":"FK_Artifact_ATK_C1","end":1.05,"contact":0.3333333},
	"ability":{"clip":"FK_Artifact_ATK_C2","end":1.20,"contact":0.45,"contacts":[0.45,0.55,0.75]},
	"counter_punch":{"clip":"FK_Artifact_ATK_B1_02","end":0.95,"contact":0.2333333},
	"counter_kick":{"clip":"FK_Artifact_ATK_B2","end":0.90,"contact":0.25},
	"ultimate":{"clip":"FK_Artifact_Ultra_AS","end":2.7333336}
}
const STYLE: Dictionary = {
	"id":"hawk_of_the_fog","characterId":"fuhua","name":"雾都迅羽","playable":true,
	"portraitPath":TEX+"FukaC1_05_01.png","roleTag":"雷闪追击",
	"combatProfile":"hawk_of_the_fog","description":"拳脚蓄势，雷闪追击。连击命中积蓄雷电，千龙破天震退对手。",
	"defaultAppearance":"default","appearances":["default"],
	"abilityName":"雷闪连击","ultimateName":"千龙破天","hasStances":false,
	"prefix":"Avatar_Fuka_Ani_","motions":MOTIONS,"attackPacing":{},
	"defense":{"libraryPath":"","source":"native","targetRig":"fuhua_c1",
		"fullGrounding":true,"guardClip":"Combat","holdTime":0.18,
		"blockClip":"Hit_H","blockStart":0.035,"blockEnd":0.14,"heavyBlockEnd":0.23,
		"parryClip":"EvadeBackward","parryStart":0.0,"parryEnd":0.32},
	"victory":{"libraryPath":"","source":"native","clip":"Victory_FK_AF01","idleClip":"Victory_idle",
		"clipDuration":4.316667,"idleDuration":2.0,"presentationDuration":4.4,"fallbackMotion":"idle"}
}
const APPEARANCES: Dictionary = {
	"default":{"id":"default","styleId":"hawk_of_the_fog","name":"原装","playable":true,
		"modelPath":TEX+"Avatar_Fuka_C1_05_01.scn","textureDir":TEX,"rig":"fuhua_c1",
		"visual":{"height":2.85,"rootBone":"Bip001","headBone":"Bip001 Head","hiddenMeshes":[],
			"nativeMaterialProfile":"hawk_of_the_fog","nativeMaterialCatalog":TEX+"material-profiles.json",
			"facialAnimation":"res://assets/motions/fuhua-face-atlas.json","ultimateJumpLimit":0.70,
			"hiddenSurfaces":["body:1"],"surfaceKinds":{},
			"surfaceNativeRoles":{"body:2":"alpha","glass:1":"alpha","nativefistweapon001:0":"weapon","nativefistweapon002:0":"weapon"},
			"surfaceShaderParameters":{"nativefistweapon001:0":{"has_lightmap":false},"nativefistweapon002:0":{"has_lightmap":false}},
			"textures":{"bodyColor":TEX+"Avatar_Fuka_C1_05_01_Body_Color.png",
				"bodyLightmap":TEX+"Avatar_Fuka_C1_05_01_Body_LightMap.png",
				"hairColor":TEX+"Avatar_Fuka_C1_05_01_Hair_Color.png",
				"hairLightmap":TEX+"Avatar_Fuka_C1_05_01_Hair_LightMap.png",
				"faceColor":TEX+"Avatar_Fuka_Texture_Face_Color.png","faceMask":TEX+"Avatar_Fuka_FaceMap.png"},
			"outlinePixels":{"body":0.92,"hair":1.05,"face":0.38},
			"faceAtlas":{"scale":Vector2(0.25,0.25),"leftEyeOffset":Vector2(0.25,0.75),"otherOffset":Vector2(0.0,0.75)}
		}
	}
}
