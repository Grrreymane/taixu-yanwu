extends SceneTree
const Presentation = preload("res://scripts/story_presentation.gd")
const Roster = preload("res://scripts/fighter_roster.gd")
const Dialogue = preload("res://scripts/sentience_dialogue.gd")
const Story = preload("res://scripts/sentience_story.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var presentation := Presentation.new()
	viewport.add_child(presentation)
	presentation.begin("victory",{"rewardIds":["fist","iron","risk","breath","swift"],"stageIndex":5},Roster.resolve("fuhua","azure_empyrea","default"))
	for dimensions: Vector2i in [Vector2i(1440,900),Vector2i(960,540),Vector2i(360,800)]:
		viewport.size=dimensions
		for source_id: String in Dialogue.catalog().scenes:
			presentation.lines=Dialogue.scene_lines(source_id)
			for index: int in presentation.lines.size():
				presentation.index=index
				presentation._refresh_line()
				var line: Dictionary=presentation.lines[index]
				var data:=presentation.snapshot()
				var label: String="%s %s"%[str(dimensions),str(data.lineId)]
				check(presentation._text.text==line.text,label+" preserves full source text")
				var expected_name: String="旁白" if str(line.speaker)=="narrator" else str(line.displayName)
				check(data.displayName==expected_name,label+" preserves the actual speaker")
				var height: float=presentation._text.get_theme_font("font").get_height(26)
				check(float(data.textLineCount)*height<=float(data.textHeight)+1.0,label+" fits all wrapped lines")
				check(presentation._dialog.position.y>=70.0,label+" stays below chapter header")
				check(presentation._backdrop.visible==(str(data.location)!="mountain"),label+" has the matching setting")
				check(str(data.location)==str(line.presentationLocation),label+" uses the authored direction's exact setting")
				for actor in presentation.actors.values():
					check(actor.visible==(str(data.location)=="mountain"),label+" does not stage a diner conversation in the arena")
				if line.speaker=="lixue":
					check(data.location=="memory" and data.displayName=="程立雪（回忆）" and not line.audible,label+" keeps Cheng Lixue in the remembered scene")
				elif line.speaker=="fuhua_thought":
					check("心想" in str(data.displayName),label+" labels internal thought")
				var old_clock:=presentation.clock
				var old_index:=presentation.index
				presentation.advance()
				check(presentation.index==old_index and presentation.revealed and presentation.clock==old_clock,label+" reveal does not skip a line or restart the take")
	presentation.reset()
	check(not presentation.active and not presentation._ui.visible,"return closes all chapter overlays")
	presentation.free()
	viewport.free()
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
	var report: Dictionary={"suite":"story_rewrite_presentation","checks":checks,"passed":failures.is_empty(),"failures":failures}
	FileAccess.open("res://build/reports/story-rewrite-presentation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
