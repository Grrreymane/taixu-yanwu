extends "res://tests/probes/ultimate_refresh_visual_probe.gd"
## Integration: native attachment, transformation visibility and pause/cleanup.
var failures: Array[String]=[]
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
func run() -> void:
	world=ProbeMain.new()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	world.campaign=VolatileCampaign.new()
	root.add_child(world)
	world.effects.sounds.clear()
	for profile in ["night_squire","fenghuang"]:
		for skin: Dictionary in world.FighterRoster.list_appearances("fuhua",profile):
			world._action("menu")
			world._action("select_style:"+profile)
			world._action("select_appearance:"+str(skin.id))
			world._action("practice")
			world.game.set_training(true)
			world.game.player.x=-0.65
			world.game.enemy.x=0.70
			step(0.3)
			world._action("ultimate")
			if profile=="fenghuang":
				for i in 240:
					step(1.0/120.0)
					var t: float=world.game.ultimate.get("time",-1.0)
					var transformed: bool=world.FenghuangCamera.Flight.active(t)
					check(world.player.visible!=transformed,skin.id+" performer follows transformation phase")
					check(world.effects.native_phoenix.visible==transformed,skin.id+" bird and performer share one clock")
				step(0.12)
				check(world.player.visible and not world.effects.native_phoenix.visible,skin.id+" landing restores native human pose")
			else:
				step(0.65)
				var activation: Array=world.effects.active.filter(func(item):return str(item.settings.get("nativeNode","")).ends_with("CostSP/Smoke01_1 (15)"))
				check(not activation.is_empty() and activation.all(func(item):return item.node.mesh is ArrayMesh),skin.id+" activation retains original smoke geometry")
				step(1.35)
				var smoke: Array=world.effects.active.filter(func(item):return item.settings.get("body_attachment",false))
				check(smoke.size()>10,skin.id+" native burst particles emitted")
				var chest: Vector3=world.player.effect_attachment().chest
				check(chest.y>1.7,skin.id+" attachment is on the torso")
				world.game.player.x-=2.0
				step(0.1)
				for item: Dictionary in world.effects.active:
					if not item.settings.get("body_attachment",false):continue
					var expected: Vector3=world.effects.player_attachment.chest+item.settings.attachment_offset+item.settings.velocity*maxf(0,float(item.time))+Vector3(item.settings.get("source_motion",Vector3.ZERO))
					check(item.node.position.distance_to(expected)<0.001,skin.id+" particles move with the native chest in all axes")
			world._action("pause")
			var transforms: Array=world.effects.active.map(func(item):return item.node.transform)
			var clock: float=world.effects.native_phoenix.clock
			step(0.2)
			check(clock==world.effects.native_phoenix.clock and transforms==world.effects.active.map(func(item):return item.node.transform),skin.id+" pause freezes particle attachments")
			world._action("menu")
			step(0.01)
			check(world.player.visible and not world.effects.native_phoenix.visible and world.effects.active.is_empty(),skin.id+" menu restores performer and clears effects")
	var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures}
	FileAccess.open("res://build/reports/ultimate-placement.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	world.free()
	world=null
	quit(0 if failures.is_empty() else 1)
