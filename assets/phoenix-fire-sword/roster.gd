extends RefCounted
## Original C4_04_01 (Fire and Sword), not C4_04_01_alter (Sword and Fire).
const TEX := "res://assets/phoenix-fire-sword/"
const APPEARANCE: Dictionary = {
	"id":"fire_and_sword", "styleId":"fenghuang", "name":"火与剑", "playable":true,
	"portraitPath":TEX+"FukaC4_04_01.png",
	"modelPath":TEX+"Avatar_Fuka_C4_04_01.scn", "textureDir":TEX, "rig":"fuhua_c4",
	"visual":{
		"height":2.85, "rootBone":"Bip001", "headBone":"Bip001 Head",
		"facialAnimation":"res://assets/motions/fuhua-face-atlas.json",
		"nativeMaterialProfile":"phoenix_fire_sword", "nativeMaterialCatalog":TEX+"material-profiles.json",
		"ultimateJumpLimit":0.65, "hiddenMeshes":[], "hiddenSurfaces":["body:0"],
		"surfaceNativeRoles":{"body:2":"cloak","nativefistweapon001:0":"weapon","nativefistweapon002:0":"weapon"},
		"surfaceShaderParameters":{"nativefistweapon001:0":{"has_lightmap":false},"nativefistweapon002:0":{"has_lightmap":false}},
		"textures":{
			"bodyColor":TEX+"Avatar_Fuka_C4_04_01_Texture_Body_Color.png",
			"bodyLightmap":TEX+"Avatar_Fuka_C4_04_01_Texture_Body_LightMap.png",
			"hairLightmap":TEX+"Avatar_Fuka_Texture_Hair_LightMap.png",
			"faceColor":TEX+"Avatar_Fuka_Texture_Face_Color.png", "faceMask":TEX+"Avatar_Fuka_FaceMap.png"
		},
		"outlinePixels":{"body":0.92,"hair":1.05,"face":0.38},
		"faceAtlas":{"scale":Vector2(0.25,0.25),"leftEyeOffset":Vector2(0.25,0.75),"otherOffset":Vector2(0.0,0.75)}
	}
}
