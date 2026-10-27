extends "res://tests/story_flow_suite.gd"
## Authored scene routing and exactly-once campaign continuations.
const Story = preload("res://scripts/sentience_story.gd")
const Dialogue = preload("res://scripts/sentience_dialogue.gd")
const Campaign = preload("res://scripts/campaign.gd")
const ROUTES := {
 "press":["fist","iron","risk","finisher","breath"],
 "guard":["reflection","riposte","calm","breath","fist"],
 "flow":["flow","swift","windstep","reservoir","breath"],
 "balanced":["fist","iron","reflection","calm","flow"]}
var evidence: Dictionary={"routeSequences":{},"midpoint":[],"epilogue":[],"revisits":0}

func _run() -> void:
 OS.add_logger(recorder)
 _source_fidelity()
 _routing()
 if not "--text-only" in OS.get_cmdline_user_args(): await _main_flow()
 check(recorder.errors.is_empty(),"no engine or script errors during story integration")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
 var report: Dictionary={"suite":"story_rewrite","checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors,"evidence":evidence}
 FileAccess.open("res://build/reports/story-rewrite-suite.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 OS.remove_logger(recorder)
 print(JSON.stringify({"suite":"story_rewrite","checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors.size()}))
 quit(0 if failures.is_empty() else 1)

func _source_fidelity() -> void:
 var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Dialogue.DATA_PATH))
 check(source.revision==Dialogue.REVISION,"runtime revision matches the approved v3 manuscript")
 var total_lines:=0
 var total_directions:=0
 var all_ids: Dictionary={}
 for scene_id: String in source.scenes:
  var scene: Dictionary=source.scenes[scene_id]
  var displayed:=Dialogue.scene_lines(scene_id)
  var expected_ids: Array[String]=[]
  for source_index: int in range(scene.lines.size()+1):
   for direction_index: int in scene.stageDirections.size():
    var direction: Dictionary=scene.stageDirections[direction_index]
    if int(direction.beforeLine)!=source_index: continue
    var id: String="%s-direction-%02d"%[scene_id,direction_index+1]
    expected_ids.append(id)
    var line: Dictionary=displayed[expected_ids.size()-1]
    check(str(line.text)==str(direction.text) and int(line.sourceLine)==int(direction.sourceLine),id+" preserves the authored direction exactly")
    check(line.kind=="direction" and not line.audible,id+" remains unvoiced stage narration")
    total_directions+=1
   if source_index<scene.lines.size():
    var original: Dictionary=scene.lines[source_index]
    expected_ids.append(str(original.id))
    var line: Dictionary=displayed[expected_ids.size()-1]
    for field: String in ["id","text","speaker","kind","displayName","sourceLine"]:
     check(line[field]==original[field],str(original.id)+" preserves source "+field)
    total_lines+=1
  check(displayed.size()==expected_ids.size(),scene_id+" contains exactly the authored lines and directions")
  check(displayed.map(func(line: Dictionary): return str(line.lineId))==expected_ids,scene_id+" preserves direction placement and manuscript order")
  for line: Dictionary in displayed:
   check(not all_ids.has(line.lineId),str(line.lineId)+" is unique across all scenes")
   all_ids[line.lineId]=true
 check(total_lines==int(source.counts.lines),"every imported numbered line is playable")
 check(total_directions==int(source.counts.stageDirections),"every imported stage direction is playable")
 evidence.source={"revision":source.revision,"lines":total_lines,"directions":total_directions,"scenes":source.scenes.size()}

func _routing() -> void:
 check(Story.scene_ids("intro",{"runNumber":1})==["A01","A03"],"first visit starts with A01 and the selected single rule")
 check(Story.scene_ids("intro",{"runNumber":2})==["A02","A03"],"uncleared repeat uses A02 without special revisit")
 for pair: Array in [["mirror","A03"],["flow","A04"],["breaker","A05"]]:
  check(Story.scene_ids("intro",{"contractId":pair[0]})==["A01",pair[1]],"each actual rule uses its manuscript ending")
 var multiple: Dictionary={"runNumber":3,"completedRuns":1,"selectedContractIds":["mirror","breaker"]}
 check(Story.scene_ids("intro",multiple)==["A02","A06"],"multiple unlocked rules select A06")
 multiple.completedRuns=0
 check(Story.scene_ids("intro",multiple)==["A02","A03"],"multi-rule opening never appears before a clear")
 multiple.completedRuns=1
 multiple.selectedContractIds=["mirror","mirror","invalid"]
 check(Story.scene_ids("intro",multiple)==["A02","A03"],"duplicate and unknown rules do not fabricate multi-rule dialogue")
 for seed: int in 100:
  var context: Dictionary={"runNumber":4,"runSeed":seed,"completedRuns":1}
  var first:=Story.scene_ids("intro",context)
  check(first==Story.scene_ids("intro",context),"revisit is stable for the same run")
  if first[0]=="A07": evidence.revisits+=1
  context.completedRuns=0
  check(Story.scene_ids("intro",context)[0]=="A02","special revisit requires a previous clear")
 check(evidence.revisits==20,"special revisits occupy one fifth of the stable seed range")
 for triple: Array in [["reflection","riposte","C01"],["riposte","reflection","C02"],["risk","breath","C03"],["breath","risk","C04"],["flow","finisher","C05"],["finisher","flow","C06"],["windstep","swift","C07"],["swift","windstep","C08"]]:
  check(Story.scene_ids("reward",{"rewardIds":triple.slice(0,2)})==[triple[2]],"ordered pair resolves to its exact combination scene")
 check(Story.scene_ids("reward",{"rewardIds":["reflection","fist","riposte"]})==["C01","J01"],"nonadjacent combination takes priority, followed by mandatory third-clear midpoint")
 check(Story.scene_ids("reward",{"rewardIds":["fist","calm","iron","breath"]})==["B08"],"already played turn is not repeated")
 check(Story.scene_ids("reward",{"rewardIds":["risk","breath","fist","calm"]})==["D01"],"combination did not consume an unseen turn")
 for count: int in range(1,6):
  var history: Array=["fist","calm","flow","iron","reflection"].slice(0,count)
  var sequence:=Story.scene_ids("reward",{"rewardIds":history,"stageIndex":count})
  check(sequence.has("J01")== (count==3),"midpoint occurs at precisely the third paid reward")
  check(str(sequence[-1]).begins_with("E")== (count==5),"final duel scene occurs only after the fifth reward")
 var index:=0
 for route: String in ROUTES:
  var context: Dictionary={"rewardIds":ROUTES[route],"stageIndex":5}
  var letter: String=["P","S","M","H"][index]
  var expected: Array[String]=["F%02d"%[index+1],"I00","I01","I01-"+letter,"I01_CONT","I02"]
  check(Story.scene_ids("victory",context)==expected,"victory joins only its own route and the complete common epilogue")
  check(Story.scene_ids("defeat",context)==["G02","G%02d"%[index+3]],"final defeat never enters the victory epilogue")
  context.stageIndex=3
  check(Story.scene_ids("defeat",context)==["G01","G%02d"%[index+3]],"phantom defeat has its separate prefix")
  evidence.routeSequences[route]=expected
  index+=1
 var street_ids: Array[String]=["I01-direction-01","I01-01","I01-02","I01-03","I01-04","I01-05"]
 for scene_id: String in ["I01","I01-P","I01-S","I01-M","I01-H","I01_CONT"]:
  for line: Dictionary in Dialogue.scene_lines(scene_id):
   var expected: String="street" if line.lineId in street_ids else "noodle_shop_waiting"
   check(line.presentationLocation==expected,str(line.lineId)+" moves indoors only at seating and does not serve the noodles early")
 var memory:=Dialogue.scene_lines("I02")
 var flashback_ids: Array[String]=["I02-direction-03","I02-02","I02-direction-04"]
 for line: Dictionary in memory:
  var expected: String="memory" if line.lineId in flashback_ids else "noodle_shop"
  check(line.presentationLocation==expected,str(line.lineId)+" switches settings at the exact authored direction")
  if line.lineId in flashback_ids: check(not line.audible,"memory never borrows either live character's voice")
  if line.lineId=="I02-02": check(line.kind=="memory" and line.speaker=="lixue" and line.displayName=="程立雪（回忆）","Lixue retains her authored memory identity")
  if line.lineId=="I02-03": check(line.speaker=="senti" and line.kind=="dialogue" and line.audible,"the present-day prompt is spoken by Senti")
  if line.lineId=="I02-04": check(line.speaker=="fuhua" and line.audible,"Fu Hua replies in the present rather than the old flashback range")
 check(memory[-1].kind=="direction" and memory[-1].presentationLocation=="noodle_shop","the closing fade stays at the restaurant window")
 check(Story.lines("unknown").is_empty(),"unknown scene cannot start a blocking placeholder")

func _main_flow() -> void:
 var Main=load("res://scripts/main.gd")
 if Main==null or not Main.can_instantiate():
  check(false,"real game main loads for story integration")
  return
 var world=Main.new()
 world.process_mode=Node.PROCESS_MODE_DISABLED
 world.campaign=VolatileCampaign.new()
 world.music._player.free()
 world.music._previous_player.free()
 world.music.free()
 world.music=QuietMusic.new()
 root.add_child(world)
 world._action("start")
 world._action("story_skip")
 var choices: Array[String]=["fist","calm","flow","iron","reflection"]
 for step: int in 5:
  _finish(world)
  world.campaign.reward_options=[Campaign.REWARDS[choices[step]].duplicate(true)]
  world._action("reward_0")
  check(world.story.active and world.campaign.reward_ids.size()==step+1,"reward commits once before any new manuscript scene")
  var transcript: Array=world.story.lines.duplicate(true)
  var midpoint_count:=0
  for line: Dictionary in transcript:
   if line.sourceSceneId=="J01": midpoint_count+=1
  check((midpoint_count>0)==(step==2),"real campaign reaches J01 exactly after third victory")
  if step==2: evidence.midpoint=transcript.map(func(line: Dictionary):return line.lineId)
  var before:=_record(world)
  var countdown: float=world.stage_countdown
  var game_time: float=world.game.time
  world._action("reward_0")
  world._action("light")
  _frames(world,2)
  check(_record(world)==before and world.game.time==game_time and world.stage_countdown==countdown,"extra inputs during manuscript dialogue cannot progress combat or pay twice")
  if step==2:
   var advances:=0
   while world.story.active and advances<transcript.size()*2+2:
    world._action("story_next")
    advances+=1
   check(not world.story.active,"third-reward scene plus midpoint finishes naturally as one continuation")
   _finish(world,false)
   world._action("story_skip")
   world._action("retry")
   check(not world.story.active and world.campaign.reward_ids.size()==3 and world.campaign.stage_index==3,"retry after midpoint keeps choices and does not replay the paid midpoint")
  else: world._action("story_skip")
 _finish(world)
 check(world.story.active and world.story.scene_id=="victory" and world.campaign.completed_runs==1,"one final win begins the complete epilogue after recording one clear")
 var won:=_record(world)
 var all_lines: Array=world.story.lines.duplicate(true)
 evidence.epilogue=all_lines.map(func(line: Dictionary):return line.lineId)
 check(evidence.epilogue.has("I02-02") and evidence.epilogue.has("I02-27"),"real victory includes Lixue and the end of the v3 restaurant scene")
 var plays: int=world.victory.plays
 var advances:=0
 while world.story.active and advances<all_lines.size()*2+2:
  world._action("story_next")
  advances+=1
 evidence.tailState={"storyActive":world.story.active,"index":world.story.index,"count":all_lines.size(),"advances":advances,"bossActive":world.boss_entrance.active,"bossPending":world.boss_entrance.pending,"ko":world.knockout.active,"plays":world.victory.plays,"previousPlays":plays,"storyAfter":world.story_after}
 check(not world.story.active and world.victory.visible and world.victory.plays==plays+1,"finishing the final fade starts MVP once")
 world._action("story_skip")
 check(_record(world)==won and world.campaign.saves==1 and world.victory.plays==plays+1,"extra skip cannot duplicate the recorded clear or MVP")
 world._action("menu")
 world._action("start")
 world._action("story_skip")
 _finish(world,false)
 var failed_lines: Array=world.story.lines
 check(failed_lines.all(func(line: Dictionary):return str(line.sourceSceneId).begins_with("G")),"actual failure contains only the applicable G scenes")
 world._action("menu")
 check(world.campaign.phase=="menu" and not world.story.active and world.story_after.is_empty(),"returning to menu cancels the full manuscript continuation")
 world.free()
 await process_frame
 await process_frame
 await create_timer(0.12).timeout
