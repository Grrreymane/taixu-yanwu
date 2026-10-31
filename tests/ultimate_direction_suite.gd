extends SceneTree
## Real native poses, not placeholder body heights, validate the shot design.
const Actor=preload("res://scripts/actor.gd")
const Roster=preload("res://scripts/fighter_roster.gd")
const Azure=preload("res://scripts/ultimate_camera.gd")
const Fire=preload("res://scripts/fenghuang_camera.gd")
const Night=preload("res://scripts/night_squire_camera.gd")
const Lightning=preload("res://scripts/lightning_camera.gd")
const Battle=preload("res://scripts/battle_camera.gd")
const PROFILES={"azure_empyrea":3.3,"fenghuang":3.8,"night_squire":1.5833333,"shadow_knight":3.116667,"hawk_of_the_fog":2.733333}
var failures:Array[String]=[]
var checks:=0
var bird: Node3D
var rows:Array=[]

func _initialize()->void:call_deferred("_run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message)
func frame(profile:String,time:float,focus:Dictionary)->Dictionary:
	match profile:
		"azure_empyrea":return Azure.sample(time,focus.playerX,focus.targetX,focus.facing,focus.aspect,focus.entry,focus.battle)
		"fenghuang":return Fire.sample(time,focus)
		"night_squire":return Night.sample(time,focus)
	return Lightning.sample(time,focus,profile)
func cuts(profile:String)->Array:
	match profile:
		"azure_empyrea":return Azure.CUTS
		"fenghuang":return Fire.CUTS
		"night_squire":return Night.CUTS
	return Lightning.cuts(profile)
func projection(shot:Dictionary,point:Vector3,aspect:float)->Vector2:
	var eye:=Transform3D(Basis.IDENTITY,shot.position).looking_at(shot.target)
	var local:Vector3=eye.affine_inverse()*point
	var height:float=-local.z*tan(deg_to_rad(float(shot.fov)*.5))
	return Vector2(local.x/(height*aspect),local.y/height)

func _run()->void:
	bird=preload("res://scripts/native_phoenix.gd").new()
	root.add_child(bird)
	for profile:String in PROFILES:
		var actor=Actor.new()
		root.add_child(actor)
		actor.setup(false,Roster.resolve("fuhua",profile,"default"))
		var duration:float=PROFILES[profile]
		var max_face_y:=0.0
		var portrait_samples:=0
		for facing:float in [-1.0,1.0]:
			for aspect:float in [16.0/9.0,0.75]:
				actor.reset_presentation()
				var battle:Dictionary=Battle.frame(0.0,[1.35*facing],aspect)
				var focus:Dictionary={"playerX":0.0,"targetX":1.35*facing,"facing":facing,"aspect":aspect,"battle":battle,"entry":battle}
				for index in int(ceil(duration*60))+1:
					var time:float=minf(duration,index/60.0)
					var pose:Dictionary={"x":0.0,"facing":facing,"side":"player","state":"ultimate","stateTime":time,"stateDuration":duration,"style":profile}
					actor.animate_fighter(pose,1.0/60.0,time,time)
					var shot:Dictionary=frame(profile,time,focus)
					var portrait:bool=shot.get("composition","full")=="portrait"
					if portrait:portrait_samples+=1
					if profile=="fenghuang" and Fire.Flight.active(time):
						bird.begin({"x":0.0,"targetX":1.35*facing})
						bird.tick(time)
						var skeleton: Skeleton3D=bird.model.find_children("*","Skeleton3D",true,false)[0]
						var box: AABB=preload("res://scripts/model_bounds.gd").measure(bird.model,skeleton,[]).bounds
						for corner in 8:
							var point: Vector3=bird.model.global_transform*box.get_endpoint(corner)
							var projected:=projection(shot,point,aspect)
							check(absf(projected.x)<.96 and absf(projected.y)<.96,"native phoenix %.3f corner %d fits aspect %.2f (%s)"%[time,corner,aspect,str(projected)])
						continue
					var names:Array=["Bip001 Head","Bip001 Spine2","Bip001 L Hand","Bip001 R Hand"] if portrait else ["Bip001 Head","Bip001 L Foot","Bip001 R Foot"]
					for name:String in names:
						var bone:int=actor.skeleton.find_bone(name)
						var point:Vector3=actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(bone).origin
						var projected:Vector2=projection(shot,point,aspect)
						check(absf(projected.x)<.96 and absf(projected.y)<.96,"%s %s %.3f facing %.0f aspect %.2f within directed frame (%s)"%[profile,name,time,facing,aspect,str(projected)])
						if name=="Bip001 Head":
							max_face_y=maxf(max_face_y,absf(projected.y))
							var crown:=projection(shot,point+Vector3.UP*.35,aspect)
							check(crown.y<.92,"%s %.3f keeps headwear below the top letterbox"%[profile,time])
				for cut:float in cuts(profile):
					var before:=frame(profile,cut-.00001,focus)
					var after:=frame(profile,cut+.00001,focus)
					check(before.position.distance_to(after.position)>.3,profile+" has a real directed cut")
					check(after.position.z>0.0 and before.position.z>0.0,profile+" cuts retain the combat axis")
		if profile not in ["fenghuang","night_squire"]:check(portrait_samples>10,profile+" contains an intentional native-pose character insert")
		rows.append({"profile":profile,"maxFaceProjectionY":max_face_y,"portraitSamples":portrait_samples,"cuts":cuts(profile)})
		actor.free()
	bird.free()
	var report:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"nativePoseRows":rows}
	DirAccess.make_dir_recursive_absolute("res://build/reports")
	FileAccess.open("res://build/reports/ultimate-direction.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
