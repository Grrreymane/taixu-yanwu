extends RefCounted
## Original fan dialogue. Branches use ordered run choices, never random state.
## No source-game dialogue or native story timeline is claimed here.
const SCENES := ["intro","reward","stage_2","stage_4","final","victory","defeat"]
const REWARD_GROUPS := {
 "press":["fist","iron","risk","finisher"],
 "guard":["reflection","riposte","calm","breath"],
 "flow":["flow","swift","windstep","reservoir"]}
const REWARD_TITLES := {
 "fist":"寸心如锋","iron":"破阵之势","risk":"以攻代守","finisher":"三叠归元",
 "reflection":"明镜止水","riposte":"反照","calm":"守一","breath":"生生不息",
 "flow":"行云流水","swift":"招随心转","windstep":"乘风","reservoir":"气贯长虹"}
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
 var titles: Dictionary={"intro":"识境演武","stage_2":"招式之外","stage_4":"胜负之间","final":"这次是本体","victory":"再来一局？","defeat":"胜负未定"}
 var title: String=str(REWARD_TITLES.get(choice.latestId,"下一招")) if scene_id=="reward" else str(titles.get(scene_id,"识境演武"))
 return {"id":scene_id,"title":title,"subtitle":"小识与老古董" if scene_id=="intro" else str(choice.routeTitle),
  "skippable":true,"source":"original-fan-dialogue","revision":Dialogue.REVISION,"routeId":choice.routeId,"branchId":choice.branchId}

static func _rows(rows: Array) -> Array:
 var result: Array=[]
 for row: Array in rows:
  result.append(_line(str(row[0]),str(row[1]),str(row[2])))
 return result

static func _turn_was_shown(choice: Dictionary,turn_key: String) -> bool:
 # A completed pair takes priority over a turn scene. Do not mark a
 # conversation as remembered unless that earlier history actually showed it.
 var history: Array=choice.history
 for count: int in range(2,history.size()):
  var earlier:=decision({"rewardIds":history.slice(0,count),"stageIndex":count})
  var earlier_key: String=str(earlier.previousGroup)+"_"+str(earlier.latestGroup)
  if earlier.turned and str(earlier.comboId).is_empty() and earlier_key==turn_key:
   return true
 return false

static func _final_exchange(route: String) -> Array:
 match route:
  "press": return [_line("senti","好了！接下来可没有幻身了。老古董，拿出真本事来！别打完又跟我说什么「点到为止」啊。","serious"),_line("fuhua","切磋总要有分寸。不过你放心，我会认真应战。请。")]
  "guard": return [_line("senti","看你一路打得这么稳，我就不问你累不累了。接下来换我上，可不会给你那么多时间慢慢想！","confident"),_line("fuhua","好。我也一直在等这一场。")]
  "flow": return [_line("senti","招式搭得挺顺手嘛。来，接下来换我陪你试！","confident"),_line("fuhua","好。不过先说定，打完之后要一起出去走走。")]
 return [_line("senti","前面那几个都打完了吧？那就看着我！我可不会乖乖照你熟悉的套路出招。","confident"),_line("fuhua","我知道。所以我才期待这一场。")]

static func _reward_lines(context: Dictionary) -> Array:
 var choice:=decision(context)
 if not Dialogue.CARDS.has(choice.latestId): return []
 var rows: Array=Dialogue.CARDS[choice.latestId]
 var turn_key: String=str(choice.previousGroup)+"_"+str(choice.latestGroup)
 if not str(choice.comboId).is_empty():
  rows=Dialogue.COMBINATIONS[choice.latestId]
 elif choice.turned and Dialogue.TURNS.has(turn_key) and not _turn_was_shown(choice,turn_key):
  rows=Dialogue.TURNS[turn_key]
 var result:=_rows(rows)
 # Only entering the actual final duel needs an extra beat. Ordinary scenes
 # end on their own conversation, without a stock stage bridge.
 if choice.finalChoice: result.append_array(_final_exchange(str(choice.routeId)))
 return result

static func lines(scene_id: String,context: Dictionary={}) -> Array:
 var contract:=_contract(context)
 var choice:=decision(context)
 var route: String=str(choice.routeId)
 var repeat_run:=int(context.get("runNumber",1))>1
 match scene_id:
  "intro":
   var opening: String={
    "mirror":"来，先让我看看你能接下几招。光挡住可不够啊，我留的破绽，你得自己抓。",
    "flow":"那你可得跟紧点。这帮家伙可不会乖乖站着等你出招，一不留神就追上来了！",
    "breaker":"这回给你安排了几个难啃的。一个个守得可牢了，怎么把它们打出破绽，就看你的本事喽。"
   }.get(contract,"好！规矩就这么定了。来，让我看看你有多少本事！")
   if repeat_run:
    return [_line("senti","哟，老古董，又来了？怎么，上回还没打过瘾？","question"),_line("fuhua","上次还有几种变化没试过。这回想再看看。"),_line("senti","行啊，奉陪到底！不过规矩照旧，还是六场。打完就跟我出去转转，可别又赖在山上不走了。","confident"),_line("fuhua","知道了。这次听你的。"),_line("senti",opening,"confident")]
   return [_line("fuhua","你说有东西要给我看……就是这儿？","question"),_line("senti","怎么样？是不是有点太虚山那味儿了？不过你可别急着挑毛病，这回我可是好好改过的。","confident"),_line("fuhua","嗯，确实不太一样。院子宽敞了不少，只是……这些对手，怎么都是你？","question"),_line("senti","嘿嘿，这你就别管了。来，陪我打六场！前五场打完，你都能挑点新花样试试。至于最后一场嘛……当然是我亲自上！说好了啊，打完就陪我出去逛逛，不许反悔！","confident"),_line("fuhua","好，六场。不过既然是切磋，我可不会手下留情。"),_line("senti",opening,"confident")]
  "reward": return _reward_lines(context)
  "stage_2":
   # Compatibility for standalone presentation. Campaign uses choice scenes.
   return [_line("fuhua","这庭院跟从前不太一样。你还改了些什么？","question"),_line("senti","现在就告诉你，那还有什么惊喜？打完了我带你慢慢看！","confident"),_line("fuhua","好。那我就当是来了个新地方。"),_line("senti","本来就是！像太虚山，又不代表什么都得跟你记忆里一样。","confident")]
  "stage_4":
   return [_line("senti","还剩两场！说好了啊，待会儿出去，去哪儿得由我定。","confident"),_line("fuhua","好。想去哪里？","question"),_line("senti","暂时保密！反正不爬山了。难得出来一趟，咱们干点别的去。","calm"),_line("fuhua","好。那我跟着你。")]
  "final":
   var result: Array=[_line("senti","行了行了，都退下吧！接下来用不着你们了。","confident"),_line("fuhua","终于轮到你了。准备好了？","question")]
   result.append_array(_final_exchange(route))
   return result
  "victory":
   match route:
    "press": return [_line("senti","……行吧，这场算你赢。哎，对了！演武的名字我还没定呢。","serious"),_line("fuhua","你花了这么多心思，当然该由你起名。想好方向了吗？"),_line("senti","得一听就知道是我的！还要响亮，最好念着也顺口。你帮我想想。","calm"),_line("fuhua","你更想让大家记住这场演武，还是记住你？","question"),_line("senti","就不能两个都记住吗？","question"),_line("fuhua","当然可以。那我们路上慢慢想。")]
    "guard": return [_line("senti","行行行，今天就算你赢了。再打下去，饭都要吃不上了！","calm"),_line("fuhua","那走吧。你想去哪家？","question"),_line("senti","跟我来就知道了。还有啊，今天先吃饭，茶留到饭后再喝！","confident"),_line("fuhua","好，都听你的。反正今天不赶时间。"),_line("senti","那还等什么？走！对了，刚才那一场，我可还有话要跟你说……","calm")]
    "flow": return [_line("fuhua","结束了。还好吗？","question"),_line("senti","好得很！怎么，这就想走了？我还有几个地方没带你看呢。","confident"),_line("fuhua","好啊。正好我也有些好奇。"),_line("senti","那跟紧了！这回可不许抢着带路。有些地方，你肯定认不出来。","confident"),_line("fuhua","好。今天听你安排。")]
   return [_line("senti","我决定了，下次得找个观众来！就咱俩在这儿打，打完连个评头论足的人都没有。","calm"),_line("fuhua","你想叫苍玄之书？","question"),_line("senti","她倒是合适。不过得先讲好，来看打架就专心看，可别看一半又开始讲故事。","serious"),_line("fuhua","可她看完以后，说不定又会有新故事了。"),_line("senti","那也得先听我讲！今天这场，我能说的可多着呢！","confident")]
  "defeat":
   var challenge: String="怎么样，老古董？这回见识到我的厉害了吧！" if int(choice.stageIndex)>=5 else "哎，打算就这么停了？我可还在最后一场等你呢。"
   match route:
    "press": return [_line("senti",challenge,"confident"),_line("fuhua","我想再试一次。刚才有些操之过急了。"),_line("senti","行啊。不过输一场而已，也不用连刚才那些招都不敢使了吧？","calm"),_line("fuhua","不会。我再想想怎么出招。"),_line("senti","好，你慢慢想。我等着！","calm")]
    "guard": return [_line("senti",challenge,"confident"),_line("fuhua","先休息一下吧。我想再回想一下刚才那场。"),_line("senti","行，不过别想得忘了时间啊。说好了还要出去玩的！","calm"),_line("fuhua","放心，我记得。"),_line("senti","那就好！等想明白了，也跟我说说你发现了什么。","calm")]
    "flow": return [_line("senti",challenge,"confident"),_line("fuhua","我还想再来一次。你愿意陪我吗？","question"),_line("senti","哟，难得你这么来劲！奉陪到底！不过出去了可得全听我的。","confident"),_line("fuhua","好。去哪里都由你决定。"),_line("senti","一言为定！来，先把这场打痛快了！","confident")]
   return [_line("senti",challenge,"confident"),_line("fuhua","我想再想想。刚才选的几招，似乎还有更好的搭配。"),_line("senti","那你就慢慢琢磨呗。反正你不急，我也不急。","calm"),_line("fuhua","谢谢。没想到这场演武，比我预想的还要有趣。"),_line("senti","现在才知道啊？那下次我叫你来，可别又一脸疑惑地问我要干什么！","confident")]
 return []
