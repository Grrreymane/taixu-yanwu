extends SceneTree
## Real Main countdown + repeated/mirrored wave creation; CPU skinning only.
const Bounds = preload("res://scripts/model_bounds.gd")
class VolatileCampaign extends "res://scripts/campaign.gd":
	func _load_record() -> void: pass
	func _save_record() -> void: pass
class ProbeMain extends "res://scripts/main.gd":
	func _load_fighter_choice() -> void:
		fighter=FighterRoster.resolve()
		appearance_choices={"azure_empyrea":"default"}
	func _save_fighter_choice() -> void: pass
	func _notification(_what:int) -> void: pass
var checks:=0
var failures:Array[String]=[]
var samples:Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		print("CHECK FAILED: ",label)
func measure(actor) -> Dictionary:
	var measured:Dictionary=Bounds.measure(actor.model,actor.skeleton,actor._visual.get("hiddenSurfaces",[]))
	var box:AABB=measured.bounds
	return {"floor":(actor.model.global_transform*box.position).y,
		"top":(actor.model.global_transform*(box.position+Vector3.UP*box.size.y)).y}
func run() -> void:
	root.size=Vector2i(1440,900)
	var world:=ProbeMain.new()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	world.campaign=VolatileCampaign.new()
	root.add_child(world)
	world.music.set_enabled(false,false)
	world.voice.set_enabled(false,false)
	world.effects.sounds.clear()
	check(world.ready_to_play,"actual Main and native actor are ready without a GPU")
	var previous_nodes:Array=[]
	for mirrored:int in 2:
		for stage_index:int in 5:
			world.campaign.stage_index=stage_index
			world.campaign.phase="fight"
			world.campaign.mode="trial"
			if mirrored==1:
				world.campaign.stages[stage_index].playerX*=-1.0
				for foe:Dictionary in world.campaign.stages[stage_index].enemies:foe.x*=-1.0
			world._begin_encounter(false)
			check(world.game.time==0.0,"spawn orientation is prepared before any simulation tick")
			if world.game.enemies.size()==1:
				check(world.game.player.x<0.0 and world.game.enemy.x>0.0,"actual single-enemy wave opens with the player left even when its formation is mirrored")
			for foe:Dictionary in world.game.enemies:
				check(int(foe.facing)==(1 if foe.x<=world.game.player.x else -1),"each spawned phantom faces the player immediately")
			await process_frame
			for old_id:int in previous_nodes:check(not is_instance_id_valid(old_id),"previous wave actor is freed without pose reuse")
			previous_nodes.clear()
			for actor in world.enemy_nodes.values():previous_nodes.append(actor.get_instance_id())
			for t:float in [0.0,0.8,1.9]:
				world.stage_countdown=2.1-t
				world._process(0.0)
				check(world.game.time==0.0,"countdown evidence remains independent of Combat._step")
				for foe:Dictionary in world.game.enemies:
					var actor=world.enemy_nodes[str(foe.id)]
					var marker:Dictionary=world.enemy_markers[str(foe.id)]
					var bounds:=measure(actor)
					check(actor.current_motion=="idle" and actor._motions[actor.current_motion].clip=="Standby","ordinary phantom uses native grounded Standby throughout countdown")
					check(bounds.floor>=-0.025 and bounds.floor<0.07,"ordinary native shoe sole stays on arena floor")
					check(signf(actor.rotation.y)==float(foe.facing),"sampled model yaw follows correct spawn facing")
					if marker.holder.visible:
						check(marker.holder.global_position.y-bounds.top>0.08,"visible overhead health bar clears hair and face")
						check(absf(marker.holder.global_position.x-float(foe.x))<0.001,"health marker belongs to its own actor")
					samples.append({"mirrored":mirrored==1,"stage":stage_index,"id":foe.id,"time":t,"facing":foe.facing,"yaw":actor.rotation.y,"motion":actor.current_motion,"floorY":bounds.floor,"topY":bounds.top,"barY":marker.holder.global_position.y,"barVisible":marker.holder.visible})
	world.campaign.stage_index=5
	world._begin_encounter(false)
	world._process(0.0)
	check(world.game.player.x<0.0 and world.game.enemy.x>0.0,"final boss enters opposite a player spawning on the left")
	check(world.boss_entrance.active,"final boss still uses its dedicated entrance")
	world.boss_entrance.time=3.2
	world._process(0.0)
	var boss=world.enemy_nodes[str(world.game.enemy.id)]
	check(boss.current_motion=="intro" and boss._motions.intro.clip=="Standby_2","boss flourish keeps the original floating portrait pose")
	check(not world.enemy_markers[str(world.game.enemy.id)].holder.visible,"boss entrance never overlays an overhead bar on its face")
	var report:Dictionary={"suite":"sentience_spawn","gpu":false,"checks":checks,"passed":failures.is_empty(),"failures":failures,"samples":samples,"bodyBonesEdited":false}
	FileAccess.open("res://build/reports/sentience-spawn.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"sampleCount":samples.size()}))
	world.free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
