extends "res://tests/probes/skin_menu_triangle_audit.gd"
## Skin real triangles on CPU: the bug was the original trousers penetrating
## the front coat panel, not a bone-tip/capsule overlap or an outline effect.
var failures:Array[String]=[]
var checks:=0
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func front_leg_crossings(actor) -> int:
	var triangles:=_triangles(actor)
	var skirt:Array=[];var legs:Array=[]
	for tri:Dictionary in triangles:
		if str(tri.group).ends_with("Skirt_F"):skirt.append(tri)
		elif tri.group=="leg":legs.append(tri)
	var count:=0
	for a:Dictionary in skirt:
		for b:Dictionary in legs:
			if a.box.grow(0.00001).intersects(b.box) and _crossing(a,b)!=null:count+=1
	return count
func _run() -> void:
	var rows:Array=[]
	for mode:String in ["legacy_menu","fitted_menu","native_dialogue"]:
		var actor=Actor.new();root.add_child(actor);actor.setup(false,Roster.resolve("fuhua","azure_empyrea","taixu_memory"))
		if mode=="legacy_menu":
			for capsule:Dictionary in actor._secondary._colliders:
				if capsule.kind=="leg":capsule.radius=0.070 if "Thigh" in actor.skeleton.get_bone_name(capsule.from) else 0.052
		else:
			var fitted:Dictionary=actor._secondary.snapshot()
			check(fitted.colliderSource=="native_trouser_bind_vertices" and fitted.fittedLegColliders.size()==4,mode+" fits all four native trouser envelopes once at setup")
		var initial:Array=[]
		for bone in actor.skeleton.get_bone_count():initial.append(actor.skeleton.get_bone_pose(bone))
		var max_extent:=0.0
		var samples:Array=[]
		for frame in 527:
			var at:=float(frame)/60.0
			if mode=="native_dialogue":actor.animate_native_dialogue("Avatar_Fuka_Ani_C5_StandBy",2.016667,at,1.9,-0.2)
			else:actor.animate_fighter({"state":"idle","stateTime":at,"x":1.9,"facing":1.0,"presentationYaw":-0.20},1.0/60.0,at)
			for entry:Dictionary in actor._secondary._bones:
				var id:=int(entry.id)
				var pose:Transform3D=actor.skeleton.get_bone_pose(id)
				check(pose.origin.is_equal_approx(initial[id].origin) and pose.basis.get_scale().is_equal_approx(initial[id].basis.get_scale()),mode+" keeps original attachment bone length and scale")
				var point:Vector3=actor.skeleton.get_bone_global_pose(id).origin
				check(point.is_finite(),mode+" attachment coordinates remain finite")
				max_extent=maxf(max_extent,point.length())
			if frame in [30,60,90,120,300,526]:
				var crossings:=front_leg_crossings(actor)
				samples.append({"time":at,"frontSkirtLegCrossings":crossings})
				if mode=="legacy_menu" and frame==30:check(crossings>40,"legacy radius reproduces the original visible trouser penetration")
				if mode!="legacy_menu":check(crossings==0,mode+" actual front skirt/leg triangles do not cross at "+str(at))
		check(max_extent<2.1,mode+" cloth positions remain bounded across complete idle loops")
		rows.append({"mode":mode,"samples":samples,"maxSkeletonLocalExtent":max_extent,"secondary":actor._secondary.snapshot()})
		actor.free()
	var report:={"checks":checks,"passed":failures.is_empty(),"failures":failures,"observations":rows}
	FileAccess.open("res://build/reports/taixu-cloth-contact-suite.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
