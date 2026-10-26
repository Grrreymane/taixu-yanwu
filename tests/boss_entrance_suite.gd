extends SceneTree
const Entrance := preload("res://scripts/boss_entrance.gd")
const BattleCamera := preload("res://scripts/battle_camera.gd")
var failures: Array[String] = []
var checks := 0
class VolatileCampaign extends "res://scripts/campaign.gd":
	func _load_record() -> void: pass
	func _save_record() -> void: pass

func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label);push_error(label)

func run() -> void:
	root.size=Vector2i(1440,900)
	var world=load("res://scripts/main.gd").new()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	world.campaign=VolatileCampaign.new()
	root.add_child(world)
	world.campaign.begin_trial("mirror",104)
	world.campaign.stage_index=5
	world.campaign.reward_ids.assign(["fist","reflection","flow","swift","riposte"])
	world._begin_encounter(false)
	check(world.boss_entrance.pending,"final stage queues the entrance")
	world._begin_story("reward")
	world._process(0.05)
	check(not world.boss_entrance.active and world.boss_entrance.pending,"reward dialogue must finish before entrance starts")
	world.story.skip()
	world._process(0.05)
	check(world.boss_entrance.active,"entrance starts after final reward dialogue")
	var before=world.game.snapshot()
	var countdown: float=world.stage_countdown
	var received:=0
	for index in 74:
		world._action("light")
		world._action("ultimate")
		world._action("reward_0")
		world._process(0.05)
		check(world.game.time==before.time,"simulation stays frozen throughout entrance")
		check(world.game.player.hp==before.player.hp and world.game.player.energy==before.player.energy,"entrance combat inputs cannot change health or energy")
		check(world.stage_countdown==countdown,"entrance does not consume countdown")
		var shown=world.enemy_nodes[str(world.game.enemy.id)]
		var head: Vector3=shown.skeleton.global_transform*shown.skeleton.get_bone_global_pose(shown.skeleton.find_bone("Bip001 Head")).origin
		var screen: Vector2=world.camera.unproject_position(head)
		check(screen.y>900*0.10 and screen.y<900*0.8,"boss face stays inside letterbox-safe framing")
		if world.boss_entrance.time<0.8 and world.boss_entrance.time>0.4:
			var actor=world.enemy_nodes[str(world.game.enemy.id)]
			if actor.presentation_snapshot().weapon=="sword": received+=1
	check(received>0,"original sword remains visible during native entrance flourish")
	check(not world.hud.visible,"combat controls hidden during presentation")
	var camera_before: Dictionary=world.boss_entrance.frame(1.6)
	world.boss_entrance.skip(1.6)
	var camera_after: Dictionary=world.boss_entrance.frame(1.6)
	check(Vector3(camera_before.position).distance_to(camera_after.position)<0.00001,"skip starts a continuous camera return")
	world.boss_entrance.focused=false
	var frozen: float=world.boss_entrance.time
	world._process(0.05)
	check(world.boss_entrance.time==frozen,"focus loss freezes entrance")
	world.boss_entrance.focused=true
	for index in 23: world._process(0.05)
	check(not world.boss_entrance.active,"entrance returns control")
	check(world.stage_countdown>0.0,"brief ready count protects player on return")
	check(world.hud.visible,"combat controls restored after entrance")
	check(world.touch_move==0.0 and not world.touch_guard,"queued inputs cleared on return")
	for index in 22: world._process(0.05)
	check(world.game.time>before.time,"boss fight runs after countdown")
	world._action("menu")
	check(not world.boss_entrance.active and not world.boss_entrance.pending,"menu cleans entrance")
	world._action("practice")
	world._process(0.05)
	check(not world.boss_entrance.pending and not world.boss_entrance.active,"practice does not replay final boss presentation")
	world.free()
	await process_frame
	await process_frame
	await create_timer(0.15).timeout
	print("BOSS ENTRANCE ",checks," checks; failures ",failures.size())
	quit(0 if failures.is_empty() else 1)
