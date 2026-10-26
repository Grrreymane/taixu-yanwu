extends RefCounted
## Additional audited C3 outfits only. Default and red leaves remain in the main catalog.
const ORDERED_IDS := ["default","autumn_leaves","spring_traveler","xuanyi_sushang","black_butler"]
const APPEARANCES: Dictionary = {
  "spring_traveler": {
    "id": "spring_traveler",
    "styleId": "night_squire",
    "name": "春风之旅",
    "playable": true,
    "modelPath": "res://assets/night-squire-spring-traveler/Avatar_Fuka_C3_04_01.scn",
    "textureDir": "res://assets/night-squire-spring-traveler/",
    "portraitPath": "res://assets/night-squire-skins/portraits/FukaC3_04_01.png",
    "rig": "fuhua_c3",
    "visual": {
      "height": 2.85,
      "rootBone": "Bip001",
      "headBone": "Bip001 Head",
      "hiddenMeshes": [],
      "nativeMaterialProfile": "night_squire_spring_traveler",
      "nativeMaterialCatalog": "res://assets/night-squire-spring-traveler/material-profiles.json",
      "facialAnimation": "res://assets/motions/fuhua-face-atlas.json",
      "textures": {
        "bodyColor": "res://assets/night-squire-spring-traveler/Avatar_Fuka_C3_04_01_Texture_Body_Color.png",
        "bodyLightmap": "res://assets/night-squire-spring-traveler/Avatar_Fuka_C3_04_01_Texture_Body_LightMap.png",
        "hairColor": "res://assets/night-squire-spring-traveler/Avatar_Fuka_C3_04_01_Texture_Hair_Color.png",
        "hairLightmap": "res://assets/night-squire-spring-traveler/Avatar_Fuka_C3_04_01_Texture_Hair_LightMap.png",
        "faceColor": "res://assets/night-squire-spring-traveler/Avatar_Fuka_Texture_Face_Color.png",
        "faceMask": "res://assets/night-squire-spring-traveler/Avatar_Fuka_FaceMap.png"
      },
      "outlinePixels": {
        "body": 0.92,
        "hair": 1.05,
        "face": 0.38
      },
      "faceAtlas": {
        "scale": Vector2(0.25,0.25),
        "leftEyeOffset": Vector2(0.25,0.75),
        "otherOffset": Vector2(0.0,0.75)
      },
      "hiddenSurfaces": [
        "body:1"
      ],
      "surfaceKinds": {},
      "surfaceNativeRoles": {
        "body:0": "body",
        "face:0": "face",
        "hair:0": "hair",
        "nativefistweapon001:0": "weapon",
        "nativefistweapon002:0": "weapon"
      },
      "surfaceTextures": {
        "body:0": {
          "albedo": "res://assets/night-squire-spring-traveler/Avatar_Fuka_C3_04_01_Texture_Body_Color.png",
          "lightmap": "res://assets/night-squire-spring-traveler/Avatar_Fuka_C3_04_01_Texture_Body_LightMap.png"
        },
        "face:0": {
          "albedo": "res://assets/night-squire-spring-traveler/Avatar_Fuka_Texture_Face_Color.png",
          "lightmap": "res://assets/night-squire-spring-traveler/Avatar_Fuka_Texture_Face_LightMap.png",
          "faceMap": "res://assets/night-squire-spring-traveler/Avatar_Fuka_FaceMap.png"
        },
        "hair:0": {
          "albedo": "res://assets/night-squire-spring-traveler/Avatar_Fuka_C3_04_01_Texture_Hair_Color.png",
          "lightmap": "res://assets/night-squire-spring-traveler/Avatar_Fuka_C3_04_01_Texture_Hair_LightMap.png"
        },
        "nativefistweapon001:0": {
          "albedo": "res://assets/night-squire/Weapon_Fist_F1_25_3.png"
        },
        "nativefistweapon002:0": {
          "albedo": "res://assets/night-squire/Weapon_Fist_F1_25_3.png"
        }
      },
      "surfaceShaderParameters": {
        "nativefistweapon001:0": {
          "has_lightmap": false
        },
        "nativefistweapon002:0": {
          "has_lightmap": false
        }
      }
    }
  },
  "xuanyi_sushang": {
    "id": "xuanyi_sushang",
    "styleId": "night_squire",
    "name": "玄衣素裳",
    "playable": true,
    "modelPath": "res://assets/night-squire-xuanyi/Avatar_Fuka_C3_04_02.scn",
    "textureDir": "res://assets/night-squire-xuanyi/",
    "portraitPath": "res://assets/night-squire-skins/portraits/FukaC3_04_02.png",
    "rig": "fuhua_c3",
    "visual": {
      "height": 2.85,
      "rootBone": "Bip001",
      "headBone": "Bip001 Head",
      "hiddenMeshes": [],
      "nativeMaterialProfile": "night_squire_xuanyi_sushang",
      "nativeMaterialCatalog": "res://assets/night-squire-xuanyi/material-profiles.json",
      "facialAnimation": "res://assets/motions/fuhua-face-atlas.json",
      "textures": {
        "bodyColor": "res://assets/night-squire-xuanyi/Avatar_Fuka_C3_04_02_Texture_Body_Color.png",
        "bodyLightmap": "res://assets/night-squire-xuanyi/Avatar_Fuka_C3_04_02_Texture_Body_Lightmap.png",
        "hairColor": "res://assets/night-squire-xuanyi/Avatar_Fuka_C3_04_02_Texture_Hair_Color.png",
        "hairLightmap": "res://assets/night-squire-xuanyi/Avatar_Fuka_C3_04_02_Texture_Hair_LightMap.png",
        "faceColor": "res://assets/night-squire-xuanyi/Avatar_Fuka_Texture_Face_Color.png",
        "faceMask": "res://assets/night-squire-xuanyi/Avatar_Fuka_FaceMap.png"
      },
      "outlinePixels": {
        "body": 0.92,
        "hair": 1.05,
        "face": 0.38
      },
      "faceAtlas": {
        "scale": Vector2(0.25,0.25),
        "leftEyeOffset": Vector2(0.25,0.75),
        "otherOffset": Vector2(0.0,0.75)
      },
      "hiddenSurfaces": [
        "body:1",
        "body:4"
      ],
      "surfaceKinds": {},
      "surfaceNativeRoles": {
        "body:0": "body",
        "body:2": "dualface",
        "body:3": "cutout",
        "face:0": "face",
        "hair_c3_dress02:0": "hair",
        "nativefistweapon001:0": "weapon",
        "nativefistweapon002:0": "weapon"
      },
      "surfaceTextures": {
        "body:0": {
          "albedo": "res://assets/night-squire-xuanyi/Avatar_Fuka_C3_04_02_Texture_Body_Color.png",
          "lightmap": "res://assets/night-squire-xuanyi/Avatar_Fuka_C3_04_02_Texture_Body_Lightmap.png"
        },
        "body:2": {
          "albedo": "res://assets/night-squire-xuanyi/Avatar_Fuka_C3_04_02_Texture_Body_Color.png",
          "lightmap": "res://assets/night-squire-xuanyi/Avatar_Fuka_C3_04_02_Texture_Body_Lightmap.png"
        },
        "body:3": {
          "albedo": "res://assets/night-squire-xuanyi/Avatar_Fuka_C3_04_02_Texture_Body_Color.png",
          "lightmap": "res://assets/night-squire-xuanyi/Avatar_Fuka_C3_04_02_Texture_Body_Lightmap.png"
        },
        "face:0": {
          "albedo": "res://assets/night-squire-xuanyi/Avatar_Fuka_Texture_Face_Color.png",
          "lightmap": "res://assets/night-squire-xuanyi/Avatar_Fuka_Texture_Face_LightMap.png",
          "faceMap": "res://assets/night-squire-xuanyi/Avatar_Fuka_FaceMap.png"
        },
        "hair_c3_dress02:0": {
          "albedo": "res://assets/night-squire-xuanyi/Avatar_Fuka_C3_04_02_Texture_Hair_Color.png",
          "lightmap": "res://assets/night-squire-xuanyi/Avatar_Fuka_C3_04_02_Texture_Hair_LightMap.png"
        },
        "nativefistweapon001:0": {
          "albedo": "res://assets/night-squire/Weapon_Fist_F1_25_3.png"
        },
        "nativefistweapon002:0": {
          "albedo": "res://assets/night-squire/Weapon_Fist_F1_25_3.png"
        }
      },
      "surfaceShaderParameters": {
        "nativefistweapon001:0": {
          "has_lightmap": false
        },
        "nativefistweapon002:0": {
          "has_lightmap": false
        }
      }
    }
  },
  "black_butler": {
    "id": "black_butler",
    "styleId": "night_squire",
    "name": "黑执事",
    "playable": true,
    "modelPath": "res://assets/night-squire-black-butler/Avatar_Fuka_C3_03_01.scn",
    "textureDir": "res://assets/night-squire-black-butler/",
    "portraitPath": "res://assets/night-squire-skins/portraits/FukaC3_03_01.png",
    "rig": "fuhua_c3",
    "visual": {
      "height": 2.85,
      "rootBone": "Bip001",
      "headBone": "Bip001 Head",
      "hiddenMeshes": [],
      "nativeMaterialProfile": "night_squire_black_butler",
      "nativeMaterialCatalog": "res://assets/night-squire-black-butler/material-profiles.json",
      "facialAnimation": "res://assets/motions/fuhua-face-atlas.json",
      "textures": {
        "bodyColor": "res://assets/night-squire-black-butler/Avatar_Fuka_C3_03_01_Body_Color.png",
        "bodyLightmap": "res://assets/night-squire-black-butler/Avatar_Fuka_C3_03_01_Body_LightMap.png",
        "hairColor": "res://assets/night-squire-black-butler/Avatar_Fuka_Texture_Hair_Color.png",
        "hairLightmap": "res://assets/night-squire-black-butler/Avatar_Fuka_Texture_Hair_LightMap.png",
        "faceColor": "res://assets/night-squire-black-butler/Avatar_Fuka_Texture_Face_Color.png",
        "faceMask": "res://assets/night-squire-black-butler/Avatar_Fuka_FaceMap.png"
      },
      "outlinePixels": {
        "body": 0.92,
        "hair": 1.05,
        "face": 0.38
      },
      "faceAtlas": {
        "scale": Vector2(0.25,0.25),
        "leftEyeOffset": Vector2(0.25,0.75),
        "otherOffset": Vector2(0.0,0.75)
      },
      "hiddenSurfaces": [
        "body:1"
      ],
      "surfaceKinds": {
        "hair:1": "body"
      },
      "surfaceNativeRoles": {
        "body:0": "body",
        "face:0": "face",
        "hair:0": "hair",
        "hair:1": "body",
        "nativefistweapon001:0": "weapon",
        "nativefistweapon002:0": "weapon"
      },
      "surfaceTextures": {
        "body:0": {
          "albedo": "res://assets/night-squire-black-butler/Avatar_Fuka_C3_03_01_Body_Color.png",
          "lightmap": "res://assets/night-squire-black-butler/Avatar_Fuka_C3_03_01_Body_LightMap.png"
        },
        "face:0": {
          "albedo": "res://assets/night-squire-black-butler/Avatar_Fuka_Texture_Face_Color.png",
          "lightmap": "res://assets/night-squire-black-butler/Avatar_Fuka_Texture_Face_LightMap.png",
          "faceMap": "res://assets/night-squire-black-butler/Avatar_Fuka_FaceMap.png"
        },
        "hair:0": {
          "albedo": "res://assets/night-squire-black-butler/Avatar_Fuka_Texture_Hair_Color.png",
          "lightmap": "res://assets/night-squire-black-butler/Avatar_Fuka_Texture_Hair_LightMap.png"
        },
        "hair:1": {
          "albedo": "res://assets/night-squire-black-butler/Avatar_Fuka_C3_03_01_Body_Color.png",
          "lightmap": "res://assets/night-squire-black-butler/Avatar_Fuka_C3_03_01_Body_LightMap.png"
        },
        "nativefistweapon001:0": {
          "albedo": "res://assets/night-squire/Weapon_Fist_F1_25_3.png"
        },
        "nativefistweapon002:0": {
          "albedo": "res://assets/night-squire/Weapon_Fist_F1_25_3.png"
        }
      },
      "surfaceShaderParameters": {
        "nativefistweapon001:0": {
          "has_lightmap": false
        },
        "nativefistweapon002:0": {
          "has_lightmap": false
        }
      }
    }
  }
}
