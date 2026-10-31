extends RefCounted
## Seeded combat arrangements. Native motions and health budgets are unchanged.
const RULES := {
 "relay":{"id":"relay","title":"接力追击","description":"幻身换手更快，招式收尾后留意下一人。","attackIntervalScale":1.0,"turnGapScale":0.78},
 "pressure":{"id":"pressure","title":"步步紧逼","description":"敌人收招后更快再次进攻，成功防反可打断压制。","attackIntervalScale":0.80,"turnGapScale":1.0},
 "measure":{"id":"measure","title":"伺机反击","description":"敌人收招间隔较长，留意守势与距离变化。","attackIntervalScale":1.20,"turnGapScale":1.12}
}
const TYPES := {"press":"striker","guard":"guardian","flank":"duelist","range":"striker"}
const NAMES := {"press":"强攻","guard":"守御","flank":"追袭","range":"远枪"}
const BOSS_CYCLES := [["sword","spear","sword","chain"],["spear","sword","chain","sword"],["chain","sword","spear","sword"]]

static func apply(stages: Array,seed_value: int) -> void:
 var random:=RandomNumberGenerator.new()
 random.seed=seed_value+43127
 var previous_rule: String=""
 var previous_pattern: int=-1
 for index in stages.size():
  var stage: Dictionary=stages[index]
  var rule_ids: Array=RULES.keys()
  rule_ids.erase(previous_rule)
  var rule_id: String=rule_ids[random.randi_range(0,rule_ids.size()-1)]
  previous_rule=rule_id
  stage.encounterRule=RULES[rule_id].duplicate(true)
  if stage.enemies.size()==1 and rule_id=="relay":
   stage.encounterRule.title="连势追击"
   stage.encounterRule.description="敌人收招后的衔接更紧，防反可以争取追击机会。"
   stage.encounterRule.attackIntervalScale=0.90
  var pattern:=random.randi_range(0,3)
  if pattern==previous_pattern: pattern=(pattern+1+random.randi_range(0,1))%4
  previous_pattern=pattern
  stage.variant=pattern
  if index==5:
   var cycle_index:=random.randi_range(0,BOSS_CYCLES.size()-1)
   stage.enemies[0].weaponCycle=BOSS_CYCLES[cycle_index].duplicate()
   stage.enemies[0].tactic="guard" if rule_id=="measure" else "press"
   stage.enemies[0].erase("weaponLock")
   stage.arrangementId="boss_%d"%cycle_index
   stage.arrangementTitle=["剑起连斩","长枪先手","链刃开场"][cycle_index]
   stage.encounterRule.description+=" 小识本轮以%s起手，半血后的入梦仍需闪避。"%["剑","枪","链刃"][cycle_index]
  else:
   _arrange(stage,index,pattern)
  if random.randi_range(0,1)==1:
   stage.playerX=-float(stage.playerX)
   for foe: Dictionary in stage.enemies: foe.x=-float(foe.x)
  stage.encounterChallenge=_challenge(index,random.randi_range(0,4))
  stage.brief="%s。%s"%[stage.arrangementTitle,stage.encounterRule.description]

static func _arrange(stage: Dictionary,index: int,pattern: int) -> void:
 var count: int=stage.enemies.size()
 var positions: Array=[]
 var tactics: Array=[]
 var weapons: Array=[]
 var title: String=""
 if count==1:
  stage.playerX=-1.6
  positions=[1.5 if pattern<2 else 2.3]
  tactics=[["press"],["guard"],["range"],["flank"]][pattern]
  weapons=[["sword"],["chain"],["spear"],["sword"]][pattern]
  title=["近身试剑","守势问招","长枪试距","追身连斩"][pattern]
 elif count==2:
  stage.playerX=[0.0,-2.6,0.9,0.0][pattern]
  positions=[[-2.6,2.4],[0.0,2.5],[-2.7,-0.8],[-3.0,2.2]][pattern]
  tactics=[["flank","press"],["guard","range"],["range","press"],["range","flank"]][pattern]
  weapons=[["sword","chain"],["chain","spear"],["spear","sword"],["spear","chain"]][pattern]
  title=["两翼夹击","前盾后枪","追袭接力","枪链错锋"][pattern]
 else:
  stage.playerX=[0.0,-3.4,0.8,0.0][pattern]
  positions=[[-2.5,2.1,4.1],[-1.1,1.0,3.2],[-3.7,-1.8,3.2],[-3.9,-2.0,2.5]][pattern]
  tactics=[["flank","guard","range"],["guard","press","range"],["range","flank","press"],["range","guard","flank"]][pattern]
  weapons=[["sword","chain","spear"],["chain","spear","spear"],["spear","sword","chain"],["spear","chain","sword"]][pattern]
  title=["破围三锋","长阵压境","双翼轮转","守御夹阵"][pattern]
 stage.arrangementId="%d_%d"%[count,pattern]
 stage.arrangementTitle=title
 stage.title="第%s试 · %s"%[["一","二","三","四","五"][index],title]
 for slot in count:
  var foe: Dictionary=stage.enemies[slot]
  foe.x=positions[slot]
  foe.tactic=tactics[slot]
  foe.type=TYPES[foe.tactic]
  foe.weaponLock=weapons[slot]
  foe.name="识律幻身 · "+str(NAMES[foe.tactic])
  foe.speed=2.55 if foe.tactic in ["press","flank"] else 1.85 if foe.tactic=="range" else 1.45

static func add_mastery(stages: Array,seed_value: int,challenge: int) -> void:
 # Separate seed stream preserves the established formations and old saves.
 var random:=RandomNumberGenerator.new()
 random.seed=seed_value+99371
 var traits: Array=["brace","pursuit","linked"]
 var names: Dictionary={"brace":"坚守：蓄势招式需用 K / E 或防反打断","pursuit":"追身：连打后会闪身反击，留意黄光","linked":"连锋：枪与链刃会接第二段，别急着抢招"}
 var previous: String=""
 for index in stages.size():
  var stage: Dictionary=stages[index]
  stage.pressureLevel=mini(4,[0,1,1,2,3,3][index]+challenge)
  if index<2: continue
  var pool:=traits.duplicate()
  pool.erase(previous)
  var combat_trait: String=pool[random.randi_range(0,pool.size()-1)]
  previous=combat_trait
  var elite_slot:=0
  for slot in stage.enemies.size():
   var foe: Dictionary=stage.enemies[slot]
   if bool(foe.elite) or bool(foe.boss):
    foe.combatTrait="boss" if bool(foe.boss) else combat_trait if elite_slot==0 else traits[(traits.find(combat_trait)+1)%traits.size()]
    elite_slot+=1
    # Damage increases gradually; every native warning and punish is retained.
    foe.damageScale=float(foe.damageScale)*[1.0,1.0,1.10,1.15,1.20,1.20][index]
  var detail: String="小识交替蓄势与连段；黄光用 K / E 或防反打断，半血入梦需闪避。" if index==5 else str(names[combat_trait])+"。"
  if elite_slot>1: detail+="另一幻身擅长%s。"%str(names[traits[(traits.find(combat_trait)+1)%traits.size()]]).split("：")[0]
  stage.mastery=combat_trait if index!=5 else "boss"
  stage.encounterRule.description+=" "+detail
  stage.brief=stage.arrangementTitle+"。"+detail

static func _challenge(index: int,choice: int) -> Dictionary:
 var goal: Dictionary
 match choice:
  0: goal={"id":"deflect","title":"接招还礼","description":"本场完成 %d 次极限防御。"%(1 if index==0 else 2),"stat":"parries","kind":"minimum","target":1.0 if index==0 else 2.0}
  1: goal={"id":"evade","title":"寸步不沾","description":"本场成功闪避 %d 次攻击。"%(1 if index==0 else 2),"stat":"dodges","kind":"minimum","target":1.0 if index==0 else 2.0}
  2: goal={"id":"combo","title":"一气贯通","description":"本场打出 %d 连击。"%(5 if index==0 else 8),"stat":"maxCombo","kind":"minimum","target":5.0 if index==0 else 8.0}
  3: goal={"id":"swift","title":"速战速决","description":"在 %d 秒内赢下本场。"%[30,42,48,60,55,85][index],"stat":"elapsed","kind":"maximum","target":float([30,42,48,60,55,85][index])}
  _: goal={"id":"untouched","title":"从容应战","description":"赢下本场，受到的伤害不超过 %d。"%[12,18,20,24,24,32][index],"stat":"damageTaken","kind":"maximum","target":float([12,18,20,24,24,32][index])}
 goal.bonusSp=8.0
 goal.score=75
 return goal

static func objective(challenge: Dictionary,live: Dictionary,won: bool=false) -> Dictionary:
 if challenge.is_empty(): return {}
 var result:=challenge.duplicate(true)
 var value:=maxf(0.0,float(live.get(result.stat,0.0)))
 var limited: bool=result.kind=="maximum"
 var failed: bool=limited and value>float(result.target)
 result.progress=value if limited else minf(value,float(result.target))
 result.complete=(won and not failed) if limited else value>=float(result.target)
 result.failed=failed
 result.awarded=won and bool(result.complete)
 result.progressLabel=("已超出" if failed else "剩余 %d 秒"%maxi(0,int(result.target-value)) if result.stat=="elapsed" else "受伤 %d / %d"%[ceili(value),int(result.target)]) if limited else "%d / %d"%[int(result.progress),int(result.target)]
 result.bonus="获胜并达成：额外 8 SP，加 75 分"
 return result
