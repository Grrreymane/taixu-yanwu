extends RefCounted
## Extracted Fx_FukaC5_Ultra_Sphere_01 keyframe values; coordinates adapted in effects.gd.
const DURATION := 1.1666666
const ROTATION := [Vector2(0,0), Vector2(0.16666667,0), Vector2(0.6666667,180), Vector2(1.1666666,180)]
const POSITION := [Vector2(0,0), Vector2(0.033333335,0), Vector2(0.06666667,0), Vector2(0.1,0), Vector2(0.13333334,0), Vector2(0.16666667,0), Vector2(0.2,0), Vector2(0.23333333,0), Vector2(0.26666668,0), Vector2(0.3,0), Vector2(0.33333334,0), Vector2(0.36666667,0), Vector2(0.4,0), Vector2(0.43333334,0), Vector2(0.46666667,0), Vector2(0.5,0), Vector2(0.53333336,-0.14916785), Vector2(0.56666666,-0.55259585), Vector2(0.6,-1.1441737), Vector2(0.6333333,-1.8577876), Vector2(0.6666667,-2.627328), Vector2(0.7,-3.3866808), Vector2(0.73333335,-4.0697374), Vector2(0.76666665,-4.610383), Vector2(0.8,-4.942508), Vector2(0.8333333,-5), Vector2(0.8666667,13), Vector2(0.9,6), Vector2(0.93333334,11), Vector2(0.96666664,9), Vector2(1,9), Vector2(1.0333333,9), Vector2(1.0666667,9), Vector2(1.1,9), Vector2(1.1333333,9), Vector2(1.1666666,9), Vector2(1.2,9)]
const SCALE_X := [Vector2(0.16666667,2), Vector2(0.8333333,1.75)]
const SCALE_Y := [Vector2(0.16666667,2), Vector2(0.8333333,1.75)]
const SCALE_Z := [Vector2(0.16666667,2), Vector2(0.8333333,7)]
const MORPH := [Vector2(0,0), Vector2(0.033333335,0), Vector2(0.06666667,0), Vector2(0.1,0), Vector2(0.13333334,0), Vector2(0.16666667,0), Vector2(0.2,0.012746792), Vector2(0.23333333,0.04860984), Vector2(0.26666668,0.10402768), Vector2(0.3,0.17396898), Vector2(0.33333334,0.25493114), Vector2(0.36666667,0.3438655), Vector2(0.4,0.4377235), Vector2(0.43333334,0.53345642), Vector2(0.46666667,0.62801567), Vector2(0.5,0.7183526), Vector2(0.53333336,0.8014186), Vector2(0.56666666,0.8741649), Vector2(0.6,0.9335431), Vector2(0.6333333,0.9765042), Vector2(0.6666667,1), Vector2(0.7,1), Vector2(0.73333335,1), Vector2(0.76666665,1), Vector2(0.8,1), Vector2(0.8333333,1), Vector2(0.8666667,1), Vector2(0.9,1), Vector2(0.93333334,1), Vector2(0.96666664,1), Vector2(1,1), Vector2(1.0333333,1), Vector2(1.0666667,1), Vector2(1.1,1), Vector2(1.1333333,1), Vector2(1.1666666,1), Vector2(1.2,1)]
const ALPHA := [Vector2(0,0.0627451), Vector2(0.033333335,0.06360435), Vector2(0.06666667,0.06624694), Vector2(0.1,0.070770144), Vector2(0.13333334,0.07727124), Vector2(0.16666667,0.0858475), Vector2(0.2,0.0965962), Vector2(0.23333333,0.109614596), Vector2(0.26666668,0.125), Vector2(0.3,0.15243012), Vector2(0.33333334,0.19645905), Vector2(0.36666667,0.24949864), Vector2(0.4,0.30396074), Vector2(0.43333334,0.3522571), Vector2(0.46666667,0.3867996), Vector2(0.5,0.4), Vector2(0.53333336,0.4), Vector2(0.56666666,0.4), Vector2(0.6,0.4), Vector2(0.6333333,0.4), Vector2(0.6666667,0.4), Vector2(0.7,0.4), Vector2(0.73333335,0.4), Vector2(0.76666665,0.4), Vector2(0.8,0.4), Vector2(0.8333333,0.4), Vector2(0.8666667,0.4), Vector2(0.9,0.4), Vector2(0.93333334,0.4), Vector2(0.96666664,0.4), Vector2(1,0.4), Vector2(1.0333333,0.4), Vector2(1.0666667,0.4), Vector2(1.1,0.4), Vector2(1.1333333,0.4), Vector2(1.1666666,0.4), Vector2(1.2,0.4)]

static func sample(keys: Array, time: float) -> float:
	if time<=keys[0].x: return keys[0].y
	for i: int in range(1,keys.size()):
		if time<=keys[i].x:
			return lerpf(keys[i-1].y,keys[i].y,inverse_lerp(keys[i-1].x,keys[i].x,time))
	return keys[-1].y
