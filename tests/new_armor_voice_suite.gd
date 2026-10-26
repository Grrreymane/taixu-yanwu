extends SceneTree
const Voice = preload("res://scripts/character_voice.gd")
const Cues = preload("res://scripts/dialogue_voice_cues.gd")
var checks:=0
var failures:Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:
		failures.append(label)
		print("CHECK FAILED: ",label)
func run() -> void:
	var voice:=Voice.new()
	voice.settings_path=""
	root.add_child(voice)
	voice.set_enabled(true,false)
	voice.unlock()
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Voice.CATALOG_PATH))
	check(voice.snapshot().loaded==manifest.clips.size(),"entire expanded voice catalogue loads")
	check(voice.snapshot().catalogErrors.is_empty(),"expanded sources have no missing or invalid stream")
	var played:Array=[]
	for profile:String in ["shadow_knight","hawk_of_the_fog"]:
		for category:String in ["attack","heavy","ability","hurt","dodge","ultimate"]:
			voice.clear("new_armor_test")
			voice.set_context({"phase":"fight","playerProfile":profile,"storyActive":false,"paused":false,"ultimateActive":false})
			var kind:=category if category in ["dodge","ultimate"] else "hit" if category=="hurt" else "attack"
			var data:Dictionary={"type":kind,"side":"player","sourceId":"player","targetSide":"player","targetId":"player","name":"light" if category=="attack" else category,"duration":3.1}
			check(voice.handle_event(data),"new armor plays actual original source: "+profile+" / "+category)
			var current:Array=voice.snapshot().current
			if current.is_empty():continue
			var clip:Dictionary=voice._clips[str(current[0].id)]
			check(current[0].profile==profile and current[0].category==category,"requested armor and event retain ownership")
			check(clip.source.bank=="BK_FUKA_COMMON_VO" and clip.source.language=="zh-CN","new armor never borrows C5/C6 exclusive voice")
			check(not str(clip.source.eventRoute).contains("ANI_C1_DRESS1"),"unselected costume-specific branch is excluded")
			check(clip.stream is AudioStreamOggVorbis and not clip.stream.loop,"original source is a finite one-shot OGG")
			if profile=="shadow_knight" and category=="ultimate":check(clip.source.event=="VO_L_FUK_ANI_B","Shadow Knight Q uses NL_B_Ultra's exact event")
			if profile=="hawk_of_the_fog" and category in ["heavy","ability","ultimate"]:
				var expected:String={"heavy":"VO_L_FUK_C1_ARTIFACT_CHARGEFIN_B","ability":"VO_L_FUK_C1_ARTIFACT_CHARGEFIN_C","ultimate":"VO_L_FUK_C1_ARTIFACT_ULT"}[category]
				check(clip.source.event==expected,"Hawk skill uses the exact C1 Artifact event: "+category)
			played.append({"profile":profile,"category":category,"id":clip.id,"event":clip.source.event,"file":clip.file})
		voice.clear("new_armor_dialogue_test")
		check(Cues.resolve({"speaker":"fuhua","text":"嗯？","mood":"question"},profile).is_empty(),"new armor does not restore automatic dialogue prefixes")
		check(not voice.play_dialogue({"lineKey":profile,"profile":profile,"emotion":"question"}),"raw emotion metadata cannot restore an unreviewed voice")
		check(voice._candidates(profile,"parry","").is_empty(),"no fabricated parry source is introduced")
	voice.clear("test_done")
	await create_timer(.1).timeout
	var report:Dictionary={"suite":"new_armor_voice","checks":checks,"passed":failures.is_empty(),"failures":failures,"loaded":voice.snapshot().loaded,"played":played,"catalogErrors":voice.snapshot().catalogErrors,"gpu":false}
	FileAccess.open("res://build/reports/new-armor-voice.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"loaded":voice.snapshot().loaded}))
	voice.free()
	await create_timer(.08).timeout
	quit(0 if failures.is_empty() else 1)
