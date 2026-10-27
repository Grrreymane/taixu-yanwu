extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var actor := Node3D.new()
	actor.set_script(load("res://scripts/actor.gd"))
	root.add_child(actor)
	actor.setup(false)
	if not actor.ready_for_combat:
		quit(2)
		return
	var fighter := {"state": "idle", "stateTime": 0.2, "x": -2.0, "facing": 1.0}
	actor.animate_fighter(fighter, 0.016, 0.2)
	fighter = {"state": "attack", "stateTime": 0.0, "stateDuration": 0.66, "attack": {"name": "light", "comboIndex": 0, "duration": 0.66, "windup": 0.18}, "x": -2.0, "facing": 1.0}
	actor.animate_fighter(fighter, 0.0, 0.2)
	fighter["stateTime"] = 0.18
	actor.animate_fighter(fighter, 0.18, 0.38)
	assert(absf(actor.source_time - 0.22) < 0.00001, "Contact timing changed")
	var before: Transform3D = actor.skeleton.get_bone_pose(15)
	actor.animate_fighter(fighter, 0.04, 0.38)
	var after: Transform3D = actor.skeleton.get_bone_pose(15)
	assert(before.is_equal_approx(after), "Hit stop advanced the actor pose")
	fighter["facing"] = -1.0
	actor.animate_fighter(fighter, 0.0, 0.38)
	assert(actor.scale.x > 0.0 and actor.rotation.y < 0.0, "Facing must rotate, never mirror skin")
	print("ACTOR_CHECK_OK clips=", actor.animation_player.get_animation_list().size(), " bones=", actor.skeleton.get_bone_count(), " materials=", actor.materials.size(), " contact=", actor.source_time)
	actor.queue_free()
	quit()
