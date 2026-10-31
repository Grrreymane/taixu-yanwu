extends "res://tests/probes/ultimate_refresh_visual_probe.gd"
func run() -> void:
	root.size=Vector2i(1440,900)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	world=ProbeMain.new()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	world.campaign=VolatileCampaign.new()
	root.add_child(world)
	world.effects.sounds.clear()
	for profile in ["fenghuang","night_squire"]:
		world._action("menu")
		world._action("select_style:"+profile)
		world._action("select_appearance:default")
		world._action("practice")
		world.game.set_training(true)
		world.game.player.x=-0.65
		world.game.enemy.x=0.70
		world.game.enemy.hp=500.0
		world.game.enemy.maxHp=500.0
		step(0.3)
		world._action("ultimate")
		var previous:=0.0
		var times: Array=[0.15,0.50,0.80,1.20,1.65,1.90,2.12,2.85] if profile=="fenghuang" else [0.20,0.55,1.35,2.0,2.50]
		for keyframe: float in times:
			step(keyframe-previous)
			await shot("placement-"+profile+"-"+str(roundi(keyframe*100)))
			previous=keyframe
		if profile=="night_squire":
			world._action("light")
			step(0.20)
			await shot("placement-night-punch")
		step(4.2-previous)
	world.free()
	world=null
	await process_frame
	print("ULTIMATE_PLACEMENT_VISUAL_PASS")
	quit()
