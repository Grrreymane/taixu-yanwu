extends SceneTree
## Read-only verification of the shipped source manifest and real OGG streams.
const Voice = preload("res://scripts/character_voice.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("CHECK FAILED: ",label)
func run() -> void:
	var voice := Voice.new()
	voice.settings_path = ""
	root.add_child(voice)
	voice.set_enabled(true,false)
	voice.unlock()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Voice.CATALOG_PATH))
	check(manifest.language == "zh-CN", "voice catalogue explicitly identifies Chinese dubbing")
	check(voice.snapshot().catalogErrors.is_empty(), "every catalogue entry loads without a resource error")
	check(voice.snapshot().loaded == manifest.clips.size(), "all recorded source entries are loaded")
	var profiles: Dictionary = {}
	var unique_files: Dictionary = {}
	for row: Dictionary in manifest.clips:
		var loaded: Dictionary = voice._clips.get(str(row.id),{})
		check(not loaded.is_empty(), "loaded original clip " + str(row.id))
		if loaded.is_empty(): continue
		check(loaded.stream is AudioStreamOggVorbis and not loaded.stream.loop, "voice is a non-looping original OGG " + str(row.id))
		check(absf(float(loaded.duration) - float(row.duration)) < 0.08, "decoded duration matches source manifest " + str(row.id))
		check(str(row.get("source",{}).get("language","")) == "zh-CN", "source language is recorded per clip " + str(row.id))
		check(int(row.get("source",{}).get("packageLanguageId",-1)) == 1, "clip came from Chinese package language entry " + str(row.id))
		unique_files[str(row.file)] = true
		for profile: String in row.profiles:
			if not profiles.has(profile): profiles[profile] = {}
			profiles[profile][str(row.category)] = int(profiles[profile].get(str(row.category),0)) + 1
	for profile: String in ["azure_empyrea","fenghuang","night_squire","sentience"]:
		for category: String in ["attack","hurt","ultimate"]:
			check(int(profiles.get(profile,{}).get(category,0)) > 0, "real " + category + " pool exists for " + profile)
			voice.clear("asset_test")
			voice.set_context({"phase":"fight","paused":false,"storyActive":false,"playerProfile":profile if profile != "sentience" else "azure_empyrea","bossId":"boss" if profile == "sentience" else "","enemyCount":1})
			var data := {"type":"attack" if category == "attack" else "hit" if category == "hurt" else "ultimate",
				"side":"enemy" if profile == "sentience" else "player","sourceId":"boss" if profile == "sentience" else "player",
				"targetSide":"enemy" if profile == "sentience" else "player","targetId":"boss" if profile == "sentience" else "player","name":"light","duration":3.3}
			check(voice.handle_event(data), "real source stream starts for " + profile + " / " + category)
			await process_frame
			var current: Array = voice.snapshot().current
			check(current.size() == 1 and current[0].profile == profile and current[0].category == category, "concrete stream routed to expected actor " + profile + " / " + category)
	voice.clear("entrance_asset_test")
	voice.set_context({"phase":"fight","paused":false,"storyActive":false,"playerProfile":"azure_empyrea","bossId":"boss","enemyCount":1})
	check(voice.handle_event({"type":"bossEntrance","side":"enemy","sourceId":"boss","boss":true}), "boss entrance starts real Chinese ULT_2")
	check(voice.snapshot().current[0].id == "entrance_c6_206160557", "entrance uses the exact original 万象 phrase")
	check(not voice.handle_event({"type":"attack","side":"enemy","sourceId":"boss"}), "ordinary boss effort cannot cut off entrance")
	check(not voice.handle_event({"type":"ultimate","side":"player"}), "player voice does not interrupt a staged entrance")
	voice.tick(4.5)
	check(voice.handle_event({"type":"attack","side":"enemy","sourceId":"boss","weapon":"burst"}), "Senti real burst starts an ultimate voice")
	check(voice.snapshot().current[0].id == "ultimate_c6_162144407", "first burst avoids immediately repeating the entrance recording")
	voice.clear("entrance_skip_test")
	voice.handle_event({"type":"bossEntrance","side":"enemy","sourceId":"boss"})
	voice.stop_entrance()
	check(not voice.snapshot().active, "skip cuts only the entrance voice")
	var dialogue_ids: Array[String] = []
	for row: Dictionary in manifest.clips:
		if str(row.category) != "dialogue": continue
		voice.clear("dialogue_asset_test")
		var profile: String = str(row.profiles[0])
		voice.set_context({"phase":"fight","paused":false,"storyActive":true,"playerProfile":profile if profile != "sentience" else "azure_empyrea","bossId":"","enemyCount":1})
		var mood: String = str(row.moods[0])
		check(voice.play_dialogue({"lineKey":"source:" + str(row.id),"profile":profile,"speaker":"senti" if profile == "sentience" else "fuhua","reviewed":true,"clipId":str(row.id)}), "archived short source can be played only explicitly " + str(row.id))
		await process_frame
		var current: Array = voice.snapshot().current
		check(current.size() == 1 and current[0].category == "dialogue" and current[0].id == str(row.id), "verified dialogue source is used without a combat substitution " + str(row.id))
		dialogue_ids.append(str(row.id))
	for profile: String in ["azure_empyrea","fenghuang","night_squire","sentience"]:
		for mood: String in ["neutral","question"]:
			voice.clear("dialogue_mapping_test")
			check(not voice.play_dialogue({"lineKey":profile + ":" + mood,"profile":profile,"speaker":"senti" if profile == "sentience" else "fuhua","emotion":mood}), "neutral or question no longer triggers an automatic grunt for " + profile + " / " + mood)
			var current: Array = voice.snapshot().current
			check(current.is_empty(), "no fallback dialogue voice for " + profile + " / " + mood)
		for mood: String in ["surprise","displeased"]:
			check(not voice.play_dialogue({"lineKey":profile + ":" + mood,"profile":profile,"speaker":"senti" if profile == "sentience" else "fuhua","emotion":mood}), "unavailable emotion remains silent for " + profile + " / " + mood)
			check(not voice.snapshot().active, "unavailable new emotion also stops the previous prefix for " + profile + " / " + mood)
	voice.clear("test_done")
	await create_timer(0.15).timeout
	var report := {"suite":"character_voice_assets","passed":failures.is_empty(),"checks":checks,"failures":failures,
		"entries":manifest.clips.size(),"uniqueFiles":unique_files.size(),"language":manifest.language,"profiles":profiles,"dialogueSources":dialogue_ids,"catalogErrors":voice.snapshot().catalogErrors}
	FileAccess.open("res://build/reports/character-voice-assets.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	voice.free()
	await process_frame
	await create_timer(0.08).timeout
	quit(0 if failures.is_empty() else 1)
