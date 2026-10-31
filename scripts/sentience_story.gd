extends RefCounted
## Approved manuscript. Routes use earned choices; revisit uses a stable run seed.
## No source-game dialogue or native story timeline is claimed here.
const SCENES := ["intro","reward","stage_2","stage_4","final","victory","defeat"]
const REWARD_GROUPS := {
 "press":["fist","iron","risk","finisher","chainflow","crack"],
 "guard":["reflection","riposte","calm","breath","focus","sustain"],
 "flow":["flow","swift","windstep","reservoir","crosswind","afterglow"]}
const REWARD_TITLES := {
 "fist":"寸心如锋","iron":"破阵之势","risk":"以攻代守","finisher":"三叠归元",
 "reflection":"明镜止水","riposte":"反照","calm":"守一","breath":"生生不息",
 "flow":"行云流水","swift":"招随心转","windstep":"乘风","reservoir":"气贯长虹",
 "crosswind":"乘隙而入","chainflow":"百川归海","afterglow":"余焰不息","crack":"摧锋","focus":"借势回锋","sustain":"决胜气"}
const ROUTE_TITLES := {"press":"破阵之路","guard":"守心之路","flow":"流转之路","balanced":"融会之路"}
const COMBOS := {
 "mirror_answer":["reflection","riposte"],
 "bold_breath":["risk","breath"],
 "flowing_finish":["flow","finisher"],
 "wind_turn":["windstep","swift"]}
const Dialogue = preload("res://scripts/sentience_dialogue.gd")

static func _line(speaker: String,text: String,mood: String="calm",pose: String="idle") -> Dictionary:
 return {"speaker":speaker,"text":text,"mood":mood,"expression":mood,"pose":pose,"portrait":speaker}

static func _contract(context: Dictionary) -> String:
 var selection=context.get("contractId",context.get("contract","mirror"))
 if selection is Dictionary: return str(selection.get("id","mirror"))
 return str(selection)

static func _group(reward_id: String) -> String:
 for group: String in REWARD_GROUPS:
  if reward_id in REWARD_GROUPS[group]: return group
 return ""

static func decision(context: Dictionary={}) -> Dictionary:
 # Invalid or repeated IDs cannot fabricate another reward or retrigger a pair.
 var history: Array[String]=[]
 var raw=context.get("rewardIds",[])
 if raw is Array or raw is PackedStringArray:
  for value in raw:
   if value is String and REWARD_TITLES.has(value) and not history.has(value): history.append(value)
 var latest: String=history[-1] if not history.is_empty() else ""
 var previous: String=history[-2] if history.size()>1 else ""
 var counts: Dictionary={"press":0,"guard":0,"flow":0}
 for reward: String in history: counts[_group(reward)]+=1
 var most:=0
 var leaders: Array[String]=[]
 for group: String in REWARD_GROUPS:
  var count: int=int(counts[group])
  if count>most:
   most=count
   leaders=[group]
  elif count==most and count>0: leaders.append(group)
 var route: String=leaders[0] if leaders.size()==1 else "balanced"
 if history.size()>=5 and most<3: route="balanced"
 var combo:=""
 for id: String in COMBOS:
  var pair: Array=COMBOS[id]
  if latest in pair:
   var other: String=str(pair[1] if latest==pair[0] else pair[0])
   if history.has(other):
    combo=id
    break
 var latest_group:=_group(latest)
 var previous_group:=_group(previous)
 var turned:=not previous.is_empty() and previous_group!=latest_group
 var stage:=maxi(0,int(context.get("stageIndex",history.size())))
 var turn_id:=previous_group+"_to_"+latest_group if turned else "steady"
 var branch:="%s.%s.%s.%s.s%d"%[latest if not latest.is_empty() else "none",route,combo if not combo.is_empty() else "solo",turn_id,stage]
 return {"rewardId":latest,"latestId":latest,"latestTitle":str(REWARD_TITLES.get(latest,"")),"previousId":previous,
  "history":history.duplicate(),"rewardIds":history.duplicate(),"choiceCount":history.size(),
  "counts":counts,"routeId":route,"routeTitle":str(ROUTE_TITLES[route]),
  "latestGroup":latest_group,"previousGroup":previous_group,"turned":turned,
  "comboId":combo,"branchId":branch,"stageIndex":stage,"finalChoice":stage>=5}

static func metadata(scene_id: String,context: Dictionary={}) -> Dictionary:
 var choice:=decision(context)
 var titles: Dictionary={"intro":"识境演武","stage_2":"招式之外","stage_4":"胜负之间","midpoint":"还没修完的路","final":"这次是本体","victory":"下次再来","defeat":"胜负未定"}
 var title: String=str(REWARD_TITLES.get(choice.latestId,"下一招")) if scene_id=="reward" else str(titles.get(scene_id,"识境演武"))
 return {"id":scene_id,"title":title,"subtitle":"小识与老古董" if scene_id=="intro" else str(choice.routeTitle),
  "skippable":true,"source":"user-authored-manuscript","revision":Dialogue.REVISION,
  "routeId":choice.routeId,"branchId":choice.branchId,"sourceSceneIds":scene_ids(scene_id,context)}

static func _turn_was_shown(choice: Dictionary,turn_key: String) -> bool:
 # A combination takes priority without consuming an unseen turn scene.
 var history: Array=choice.history
 for count: int in range(2,history.size()):
  var earlier:=decision({"rewardIds":history.slice(0,count),"stageIndex":count})
  var earlier_key: String=str(earlier.previousGroup)+"_"+str(earlier.latestGroup)
  if earlier.turned and str(earlier.comboId).is_empty() and earlier_key==turn_key:
   return true
 return false

static func _route_scene(prefix: String,route: String,first: int=1) -> String:
 return "%s%02d"%[prefix,first+int({"press":0,"guard":1,"flow":2,"balanced":3}.get(route,3))]

static func _reward_scene_id(choice: Dictionary) -> String:
 if not str(choice.comboId).is_empty(): return str(Dialogue.COMBINATION_SCENES[choice.latestId])
 var turn_key: String=str(choice.previousGroup)+"_"+str(choice.latestGroup)
 if choice.turned and Dialogue.TURN_SCENES.has(turn_key) and not _turn_was_shown(choice,turn_key):
  return str(Dialogue.TURN_SCENES[turn_key])
 return str(Dialogue.CARD_SCENES.get(choice.latestId,""))

static func _contract_scene(context: Dictionary) -> String:
 var selected: Array[String]=[]
 var raw: Variant=context.get("selectedContractIds",[])
 if raw is Array or raw is PackedStringArray:
  for value: Variant in raw:
   if value is String and value in ["mirror","flow","breaker"] and not selected.has(value): selected.append(value)
 if int(context.get("completedRuns",0))>0 and selected.size()>1: return "A06"
 return str({"mirror":"A03","flow":"A04","breaker":"A05"}.get(_contract(context),"H04"))

static func _opening_scene(context: Dictionary) -> String:
 var run_number:=int(context.get("runNumber",1))
 if run_number<=1: return "A01"
 # One in five seeded revisits after a clear; rerender/retry cannot reroll it.
 if int(context.get("completedRuns",0))>0 and context.has("runSeed"):
  if absi(int(context.runSeed)+run_number*17)%5==0: return "A07"
 return "A02"

static func scene_ids(scene_id: String,context: Dictionary={}) -> Array[String]:
 var choice:=decision(context)
 var route: String=str(choice.routeId)
 match scene_id:
  "intro": return [_opening_scene(context),_contract_scene(context)]
  "reward":
   var reaction:=_reward_scene_id(choice)
   var result: Array[String]=[]
   if not reaction.is_empty(): result.append(reaction)
   if int(choice.stageIndex)==3 and int(choice.choiceCount)==3: result.append("J01")
   if bool(choice.finalChoice): result.append(_route_scene("E",route))
   return result
  "midpoint": return ["J01"]
  "stage_2": return ["H01"]
  "stage_4": return ["H02"]
  "final": return ["H03",_route_scene("E",route)]
  "victory":
   var branch: String=str({"press":"P","guard":"S","flow":"M","balanced":"H"}.get(route,"H"))
   return [_route_scene("F",route),"I00","I01","I01-"+branch,"I01_CONT","I02"]
  "defeat": return ["G02" if int(choice.stageIndex)>=5 else "G01",_route_scene("G",route,3)]
 return []

static func _final_exchange(route: String) -> Array:
 return Dialogue.scene_lines(_route_scene("E",route))

static func _reward_lines(context: Dictionary) -> Array:
 return lines("reward",context)

static func lines(scene_id: String,context: Dictionary={}) -> Array:
 var result: Array=[]
 for source_scene: String in scene_ids(scene_id,context): result.append_array(Dialogue.scene_lines(source_scene))
 return result
