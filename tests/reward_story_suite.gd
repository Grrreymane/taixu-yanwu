extends "res://tests/story_flow_suite.gd"
## Reward-conditioned dialogue and the real reward->story->battle transaction.
const Campaign=preload("res://scripts/campaign.gd")
const GROUPS: Dictionary={"press":["fist","iron","risk","finisher"],"guard":["reflection","riposte","calm","breath"],"flow":["flow","swift","windstep","reservoir"]}
const PAIRS: Dictionary={"mirror_answer":["reflection","riposte"],"bold_breath":["risk","breath"],"flowing_finish":["flow","finisher"],"wind_turn":["windstep","swift"]}
var story_source
var enumerated:=0
var sampled_texts:=0
var routes_seen: Dictionary={}
var branches_seen: Dictionary={}
var evidence: Dictionary={"singleRewards":[],"historyComparisons":[],"mainRewards":[],"endings":[]}

func _run() -> void:
 OS.add_logger(recorder)
 var text_only: bool="--text-only" in OS.get_cmdline_user_args()
 story_source=load("res://scripts/sentience_story.gd")
 check(story_source!=null and story_source.has_method("decision"),"new pure reward decision API is present")
 if story_source!=null and story_source.has_method("decision"):
  _decision_contract()
  _single_and_ordered_responses()
  if not text_only:
   _all_five_card_histories()
   await _reward_main_flow()
 check(completed==(["decision","responses"] if text_only else ["decision","responses","enumeration","main"]),"all intended reward-story validation sections reached completion")
 check(evidence.singleRewards.size()==18 and (text_only or (enumerated==95040 and evidence.mainRewards.size()==5)),"required histories, eighteen cards and real reward transactions executed")
 check(recorder.errors.is_empty(),"no hidden engine or script errors")
 var report: Dictionary={"suite":"reward_story","mode":"text_only" if text_only else "full","checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors,"warnings":recorder.warnings,"completed":completed,"enumeratedHistories":enumerated,"sampledTextScenes":sampled_texts,"routeCoverage":routes_seen,"branchCoverage":branches_seen,"evidence":evidence}
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
 var report_name: String="reward-story-text-suite.json" if text_only else "reward-story-suite.json"
 FileAccess.open("res://build/reports/"+report_name,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 OS.remove_logger(recorder)
 print(JSON.stringify({"suite":"reward_story","checks":checks,"passed":failures.is_empty(),"failures":failures,"errors":recorder.errors.size(),"warnings":recorder.warnings.size(),"enumeratedHistories":enumerated,"sampledTextScenes":sampled_texts}))
 quit(0 if failures.is_empty() else 1)

func _context(history: Array,stage: int=-1) -> Dictionary:
 return {"rewardIds":history.duplicate(),"stageIndex":history.size() if stage<0 else stage,"contractId":"mirror","runNumber":1,"runSeed":42003,"stats":{"parries":2,"dodges":1,"maxCombo":8,"damageTaken":12}}
func _group(id: String) -> String:
 for group: String in GROUPS:
  if id in GROUPS[group]: return group
 return ""
func _signature(lines: Array) -> String:
 var text: PackedStringArray=[]
 for line: Dictionary in lines: text.append(str(line.get("speaker",""))+":"+str(line.get("text","")))
 return "|".join(text)
func _valid_text(scene: String,context: Dictionary) -> Array:
 var lines: Array=story_source.lines(scene,context)
 check(lines.size()>=2,"approved scene sequence contains its complete dialogue: "+scene)
 var speakers: Dictionary={}
 for line: Dictionary in lines:
  var text:=str(line.get("text","")).strip_edges()
  check(not text.is_empty() and line.get("speaker","") in ["senti","fuhua","narrator","fuhua_thought","lixue"],"branch preserves a supported speaker or authored narration")
  check(not str(line.get("lineId","")).is_empty() and not str(line.get("sourceSceneId","")).is_empty(),"every displayed line retains manuscript identity")
  check(not "{reward" in text and not "undefined" in text and not "TODO" in text,"branch never exposes an unresolved placeholder")
  speakers[str(line.get("speaker",""))]=true
 check(speakers.has("fuhua") and speakers.has("senti"),"branch retains the two-character exchange alongside authored narration")
 check(lines==story_source.lines(scene,context),"same reward history replays exactly the same dialogue")
 sampled_texts+=1
 return lines

func _decision_contract() -> void:
 var empty: Dictionary=story_source.decision(_context([]))
 check(empty.choiceCount==0 and empty.latestId=="" and empty.rewardId=="" and empty.previousId=="" and empty.routeId=="balanced","empty build has no stale reward or artificial contract route")
 var malformed: Dictionary={"rewardIds":["fist","unknown",17,"fist","reflection",null,"swift"],"stageIndex":3,"contractId":"flow"}
 var before: Dictionary=malformed.duplicate(true)
 var decision: Dictionary=story_source.decision(malformed)
 check(decision.history==["fist","reflection","swift"] and decision.rewardIds==decision.history and decision.choiceCount==3,"unknown/non-string/duplicate IDs are filtered while preserving first-choice order")
 check(malformed==before,"decision never rewrites caller-owned history")
 decision.history.append("breath")
 check(story_source.decision(malformed).history==["fist","reflection","swift"],"returned history is independent of later callers")
 for history: Array in [["fist"],["fist","iron"],["fist","flow"],["fist","iron","flow","reflection"],["fist","iron","flow","swift","reflection"],["fist","iron","risk","flow","reflection"]]:
  var result: Dictionary=story_source.decision(_context(history))
  var counts: Dictionary={"press":0,"guard":0,"flow":0}
  for id: String in history: counts[_group(id)]+=1
  var maximum: int=maxi(counts.press,maxi(counts.guard,counts.flow))
  var leaders: Array=counts.keys().filter(func(key: String): return counts[key]==maximum)
  var expected: String=leaders[0] if leaders.size()==1 and (history.size()<5 or maximum>=3) else "balanced"
  check(result.routeId==expected and result.counts==counts,"route reflects earned build majority and explicit tie rule")
  check(result.finalChoice==(history.size()>=5),"last-choice marker follows actual encounter stage")
 for combo: String in PAIRS:
  var pair: Array=PAIRS[combo]
  check(story_source.decision(_context(pair)).comboId==combo,"the latest card completes its advertised pair: "+combo)
  var reverse: Array=pair.duplicate()
  reverse.reverse()
  check(story_source.decision(_context(reverse)).comboId==combo,"pair can complete in the other acquisition order: "+combo)
  var after: Array=pair.duplicate()
  var unrelated: String="calm" if not "calm" in pair else "iron"
  after.append(unrelated)
  check(story_source.decision(_context(after)).comboId=="","previous completed pair is not falsely celebrated again on an unrelated latest card")
 completed.append("decision")

func _single_and_ordered_responses() -> void:
 var signatures: Dictionary={}
 for id: String in Campaign.REWARDS:
  var context:=_context([id])
  var lines:=_valid_text("reward",context)
  var signature:=_signature(lines)
  check(not signatures.has(signature),"each of eighteen immediate reward reactions is independently written: "+id)
  signatures[signature]=id
  var first_pair:=_signature(lines.slice(0,2))
  var decision: Dictionary=story_source.decision(context)
  check(decision.latestId==id and decision.rewardId==id and decision.choiceCount==1 and not str(decision.branchId).is_empty(),"immediate scene is keyed to the actually selected card")
  evidence.singleRewards.append({"id":id,"branch":decision.branchId,"firstPair":first_pair,"text":signature})
 check(evidence.singleRewards.map(func(item: Dictionary): return item.firstPair).reduce(func(unique: Dictionary,text: String): unique[text]=true; return unique,{}).size()==18,"the first two lines themselves distinguish every card, rather than only changing a branch label")
 # A second press->guard turn must not negotiate the same outing again.
 var remembered:=_valid_text("reward",_context(["fist","calm","iron","breath"]))
 check(remembered==story_source.lines("reward",_context(["breath"])),"repeated turn returns to the new card's own scene instead of forgetting an earlier agreement")
 # risk->breath was a combination scene, so it cannot consume the outing scene.
 var unseen:=_valid_text("reward",_context(["risk","breath","fist","calm"]))
 check(unseen==story_source.lines("reward",_context(["fist","calm"])),"a combination that took priority does not falsely mark the turn conversation as already seen")
 for pair: Array in PAIRS.values():
  var reverse: Array=pair.duplicate()
  reverse.reverse()
  var forward_text:=_signature(_valid_text("reward",_context(pair)))
  var reverse_text:=_signature(_valid_text("reward",_context(reverse)))
  check(forward_text!=reverse_text,"both acquisition orders have a complete, different combination conversation")
  check(forward_text!=_signature(story_source.lines("reward",_context([pair[-1]]))),"a completed pair changes the conversation itself")
 for contract: String in ["mirror","flow","breaker"]:
  for run: int in [1,2]: _valid_text("intro",{"contractId":contract,"runNumber":run})
 check(story_source.lines("defeat",_context([],0))!=story_source.lines("defeat",_context([],5)),"losing to a phantom is distinguished from losing the final duel")
 var cases: Array=[
  [["reflection","riposte"],["fist","riposte"]],
  [["fist","reflection","swift"],["reflection","fist","swift"]],
  [["fist","iron","risk","finisher","breath"],["flow","swift","windstep","reservoir","breath"]]
 ]
 for histories: Array in cases:
  var first:=_context(histories[0])
  var second:=_context(histories[1])
  var a: Dictionary=story_source.decision(first)
  var b: Dictionary=story_source.decision(second)
  check(a.latestId==b.latestId and a.branchId!=b.branchId,"same latest card can resolve differently from its earlier build/order")
  check(_signature(_valid_text("reward",first))!=_signature(_valid_text("reward",second)),"changed branch changes actual dialogue, not only telemetry")
  evidence.historyComparisons.append({"first":histories[0],"second":histories[1],"firstBranch":a.branchId,"secondBranch":b.branchId})
 var endings: Dictionary={"press":["fist","iron","risk","finisher","breath"],"guard":["reflection","riposte","calm","breath","fist"],"flow":["flow","swift","windstep","reservoir","breath"],"balanced":["fist","iron","reflection","calm","flow"]}
 for scene: String in ["final","victory","defeat"]:
  var variants: Dictionary={}
  for route: String in endings:
   var context:=_context(endings[route],5)
   check(story_source.decision(context).routeId==route,"ending fixture earns its claimed route")
   var text:=_signature(_valid_text(scene,context))
   check(not variants.has(text),"finale outcome reflects distinct build route: "+scene+"/"+route)
   variants[text]=true
   evidence.endings.append({"scene":scene,"route":route,"text":text})
 completed.append("responses")

func _all_five_card_histories() -> void:
 var ids: Array=Campaign.REWARDS.keys().filter(func(key): return key not in Campaign.RewardBuilds.NEW_IDS)
 _enumerate(ids,[],0)
 check(routes_seen.size()==4,"all four build routes occur in valid five-card histories")
 completed.append("enumeration")
func _enumerate(ids: Array,history: Array,mask: int) -> void:
 if history.size()==5:
  var context:=_context(history,5)
  var before: Dictionary=context.duplicate(true)
  var decision: Dictionary=story_source.decision(context)
  var counts: Dictionary={"press":0,"guard":0,"flow":0}
  for id: String in history: counts[_group(id)]+=1
  var expected:="balanced"
  for route: String in counts:
   if counts[route]>=3: expected=route
  var valid: bool=decision.get("history",[])==history and decision.get("rewardIds",[])==history and decision.get("latestId","")==history[4] and decision.get("rewardId","")==history[4] and decision.get("previousId","")==history[3] and decision.get("choiceCount",0)==5 and decision.get("counts",{})==counts and decision.get("routeId","")==expected and decision.get("finalChoice",false) and not str(decision.get("routeTitle","")).is_empty() and not str(decision.get("branchId","")).is_empty()
  check(valid and context==before and decision==story_source.decision(context),"valid five-card history resolves completely, deterministically and without mutation")
  if not valid and failures.size()<15: evidence["invalidHistory%d"%enumerated]=history.duplicate()
  routes_seen[expected]=int(routes_seen.get(expected,0))+1
  var branch: String=str(decision.get("branchId",""))
  branches_seen[branch]=int(branches_seen.get(branch,0))+1
  if enumerated%97==0:
   for scene: String in ["reward","final","victory","defeat"]: _valid_text(scene,context)
  enumerated+=1
  return
 for index in ids.size():
  if mask&(1<<index): continue
  history.append(ids[index])
  _enumerate(ids,history,mask|(1<<index))
  history.pop_back()

func _reward_main_flow() -> void:
 var Main=load("res://scripts/main.gd")
 check(Main!=null and Main.can_instantiate(),"real Main with reward-driven story loads")
 if Main==null or not Main.can_instantiate(): return
 var world=Main.new()
 world.process_mode=Node.PROCESS_MODE_DISABLED
 world.campaign=VolatileCampaign.new()
 world.music._player.free()
 world.music._previous_player.free()
 world.music.free()
 world.music=QuietMusic.new()
 root.add_child(world)
 world._action("start")
 check(world.story.active and world.story.scene_id=="intro","fresh run starts only its intro before a choice is made")
 world._action("story_skip")
 var history: Array=[]
 var picks: Array[String]=["risk","breath","reflection","riposte","fist"]
 for index in 5:
  _finish(world)
  check(world.campaign.phase=="reward" and not world.story.active,"earned reward selection waits for an actual choice")
  # Controlled offer, real choose_reward: this test isolates story routing
  # from the separately tested seeded draft distribution.
  world.campaign.reward_options=[Campaign.REWARDS[picks[index]].duplicate(true)]
  world._action("reward_0")
  history.append(picks[index])
  check(world.campaign.reward_ids==history and world.campaign.boons.size()==index+1,"one accepted click applies exactly one card before story evaluation")
  check(world.story.active and world.story.scene_id=="reward" and world.campaign.stage_index==index+1,"every accepted reward immediately starts its own story after preparing the next battle")
  var choice: Dictionary=world.story.snapshot().get("choice",{})
  var expected: Dictionary=story_source.decision(world.campaign.snapshot(world.game.snapshot()))
  check(choice.get("latestId","")==picks[index] and choice.get("branchId","")==expected.branchId and choice.get("choiceCount",0)==history.size(),"presented decision is computed from the newly committed ordered history")
  var saved_carry: Dictionary=world.campaign.carry.duplicate(true)
  var saved_stats:=_record(world)
  var countdown: float=world.stage_countdown
  var clock: float=world.game.time
  world._action("reward_0")
  world._action("reward_1")
  world._action("light")
  _frames(world,2)
  check(world.campaign.reward_ids==history and world.campaign.carry==saved_carry and _record(world)==saved_stats,"extra reward/fight input during dialogue cannot apply another reward or alter score")
  check(world.game.time==clock and world.stage_countdown==countdown,"reward dialogue freezes the prepared next encounter and countdown")
  if index%2==0: world._action("story_skip")
  else:
   var advances:=0
   while world.story.active and advances<world.story.lines.size()*2+2:
    world._action("story_next")
    advances+=1
   check(advances==world.story.lines.size()*2,"normal reveal/next consumes exactly one reward scene")
  _frames(world,1)
  check(not world.story.active and world.campaign.reward_ids==history and (world.stage_countdown<countdown or world.boss_entrance.active),"skip/next returns to the next fight or its original boss entrance without another story")
  if index==4: check(choice.get("finalChoice",false) and world.campaign.stage_index==5,"last reward includes the final-choice decision instead of adding a second preboss scene")
  evidence.mainRewards.append({"history":history.duplicate(),"branch":choice.get("branchId",""),"latest":choice.get("latestId",""),"stage":world.campaign.stage_index})
 # Finish, replay/skip and defeat/retry must all retain the same build once.
 _finish(world)
 check(world.story.active and world.story.scene_id=="victory" and world.campaign.phase=="cleared","final victory receives the finished build")
 check(world.story.snapshot().get("choice",{}).get("routeId","")=="guard","victory follows the actual three-guard-card route despite the latest press card")
 var won:=_record(world)
 world._action("story_skip")
 _frames(world,2)
 world._action("story_skip")
 check(_record(world)==won and world.campaign.saves==1 and world.victory.visible,"skipping build ending cannot pay rewards or save score twice")
 world._action("menu")
 world._action("start")
 check(world.campaign.reward_ids.is_empty() and world.story.snapshot().get("choice",{}).get("choiceCount",-1)==0,"new opening forgets the previous run's build and reaction")
 world._action("story_skip")
 _finish(world)
 world.campaign.reward_options=[Campaign.REWARDS.flow.duplicate(true)]
 world._action("reward_0")
 world._action("story_skip")
 _finish(world,false)
 check(world.story.active and world.story.scene_id=="defeat" and world.story.snapshot().get("choice",{}).get("latestId","")=="flow","defeat reflects this run's chosen card rather than the earlier winning build")
 var loss_history: Array=world.campaign.reward_ids.duplicate()
 world._action("story_skip")
 world._action("retry")
 check(not world.story.active and world.campaign.reward_ids==loss_history and world.campaign.stage_index==1,"retry preserves learned build without replaying its already-paid reward scene")
 world._action("menu")
 world._action("start")
 world._action("story_skip")
 _finish(world)
 world.campaign.reward_options=[Campaign.REWARDS.iron.duplicate(true)]
 world._action("reward_0")
 check(world.story.active,"menu cancellation fixture reaches a reward scene")
 world._action("menu")
 _frames(world,1)
 check(not world.story.active and world.story_after.is_empty() and world.campaign.phase=="menu","menu cancels an active reward scene without a hidden continuation")
 world._action("practice")
 check(not world.story.active and world.campaign.reward_ids.is_empty() and world.campaign.boons.is_empty(),"practice cannot inherit a trial build or its dialogue")
 world.free()
 await process_frame
 await process_frame
 await create_timer(0.12).timeout
 completed.append("main")
