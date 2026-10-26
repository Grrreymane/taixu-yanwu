extends SceneTree
## Event/lifecycle regression. Pixel visibility is reviewed with the GPU probe.
const Combat := preload("res://scripts/combat.gd")
const Ink := preload("res://scripts/effects.gd")
const Senti := preload("res://scripts/sentience_effects.gd")
const STEP := 1.0/120.0
var checks := 0
var failures: Array[String] = []
var pinned_textures: Array[Texture2D] = []

class QuietInk extends Ink:
	func _sound(_key: String) -> void: pass

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	# Load unchanged source PNGs even before an editor import, without a GPU.
	for directory: String in ["native","phoenix-native","sentience-native"]:
		for filename: String in DirAccess.get_files_at("res://assets/vfx/"+directory):
			if not filename.ends_with(".png"): continue
			var path := "res://assets/vfx/"+directory+"/"+filename
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			var texture := ImageTexture.create_from_image(image)
			texture.take_over_path(path)
			pinned_textures.append(texture)
	var ink := QuietInk.new()
	var senti := Senti.new()
	root.add_child(ink)
	root.add_child(senti)
	for direction: int in [-1,1]:
		for action: String in ["light","heavy","ability"]:
			var game := Combat.new()
			game.start_encounter({"training":true,"playerX":-0.65*direction,"enemies":[{"id":"foe","x":0.65*direction,"hp":300.0}]})
			game.player.facing=direction
			game.enemy.facing=-direction
			ink.clear()
			ink.update_fighters(game.player,game.enemies)
			game.event.connect(ink.handle_event)
			check(game.action(action),"actual combat accepts "+action)
			var saw_front := false
			var saw_contact := false
			var frozen_checked := false
			for index: int in 200:
				var before := game.time
				game.update(STEP)
				ink.update_fighters(game.player,game.enemies)
				ink.tick(game.time-before)
				for item: Dictionary in ink.active:
					if item.settings.get("role","") in ["attack_ribbon","ability_front"]:
						saw_front = saw_front or (item.node.visible and item.node.position.z>=0.67 and float(item.mat.get_shader_parameter("opacity"))>0.5)
				if game.hit_stop>0.0 and not frozen_checked:
					var frozen: Dictionary=ink.snapshot()
					ink.tick(0.0)
					check(ink.snapshot()==frozen,"actual contact freeze preserves "+action+" VFX")
					frozen_checked=true
					saw_contact=true
			check(saw_contact and saw_front,"actual "+action+" direction "+str(direction)+" emits visible-front ribbon with a contact")
			game.event.disconnect(ink.handle_event)
	for weapon: String in ["sword","spear","chain"]:
		for direction: int in [-1,1]:
			senti.clear()
			senti._swing({"x":0.0,"facing":direction,"id":"foe","weapon":weapon,"motion":"senti_"+weapon+"_1","contactHeight":1.3})
			var front_count := 0
			var dark_count := 0
			for item: Dictionary in senti._active:
				if item.options.get("role","")!="weapon_trail": continue
				if item.node.position.z>0.65 and item.material.get_shader_parameter("opacity")==1.0: front_count+=1
				if not bool(item.material.get_shader_parameter("source_rgb")): dark_count+=1
				if weapon!="spear": check(signf(item.node.scale.x)==direction,"curved "+weapon+" geometry mirrors with facing")
			check(front_count==2 and dark_count==1,weapon+" keeps a native-alpha dark contour under the bright strip")
	senti.clear()
	senti.handle_event({"type":"bossEntrance","x":1.2,"facing":-1.0})
	check(senti._cues.is_empty(),"entrance does not schedule a damaging weapon swing")
	for item: Dictionary in senti._active:
		if item.time<0.0: check(not item.node.visible,"delayed entrance layer stays hidden before first tick")
	var reached: Dictionary={}
	for index: int in 636:
		senti.tick(STEP)
		for item: Dictionary in senti._active:
			if item.node.visible: reached[item.options.get("role","")]=true
	check(reached.has("entrance_gather") and reached.has("entrance_reveal") and reached.has("entrance_calligraphy") and reached.has("entrance_settle"),"all boss entrance phases execute")
	check(senti._active.is_empty(),"boss presentation fully clears before 5.3-second control handoff")
	ink.clear()
	ink.handle_event({"type":"victory","style":"fenghuang"})
	check(ink.active.is_empty(),"phoenix victory cannot emit cloud-empyrea feathers")
	ink.handle_event({"type":"victory","style":"azure_empyrea","x":0.0})
	check(ink.active.size()==22 and ink.native_textures.has("victory_feather") and ink.native_textures.has("victory_glow"),"cloud victory schedules verified native feather and glow textures")
	for item: Dictionary in ink.active:
		if item.time<0.0: check(not item.node.visible,"victory particle delay cannot flash at start")
	for index: int in 420: ink.tick(STEP)
	check(ink.active.is_empty(),"victory particles clear after their presentation tail")
	var hit: Dictionary={"contactHeight":2.15,"contactX":0.4}
	check(is_equal_approx(ink._contact_origin(hit).y,2.15),"combat contactHeight reaches actual impact origin")
	ink.free()
	senti.free()
	var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Headless actual combat events, depth placement, timing, reflection and cleanup. Pixel appearance requires GPU review."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
	FileAccess.open("res://build/reports/native-effect-readability.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("NATIVE EFFECT READABILITY ",checks-failures.size(),"/",checks)
	quit(0 if failures.is_empty() else 1)
