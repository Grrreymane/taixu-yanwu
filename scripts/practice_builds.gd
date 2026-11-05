extends RefCounted

const Paths=preload("res://scripts/armor_paths.gd")
const Night=preload("res://scripts/night_paths.gd")
var saved: Dictionary={}
var style: String=""
var draft: Dictionary={"core":"","perks":[]}
var infinite_energy:bool=false
var enemy_pattern:String="sword"
var draft_enemy:String="sword"

func restore_settings(value:Variant) -> void:
 infinite_energy=false;enemy_pattern="sword"
 if not value is Dictionary:return
 if value.get("infiniteEnergy") is bool:infinite_energy=value.infiniteEnergy
 var pattern:String=str(value.get("enemyPattern","sword"))
 if Night.BOSS.has(pattern):enemy_pattern=pattern

func settings() -> Dictionary:
 return {"infiniteEnergy":infinite_energy,"enemyPattern":enemy_pattern}

# Practice preferences never enter campaign rewards, checkpoints or rankings.
func clean(style_id:String,value:Variant) -> Dictionary:
 var result:Dictionary={"core":"","perks":[]}
 if not value is Dictionary:return result
 var core:String=str(value.get("core",""))
 if not Paths.valid(style_id,core):return result
 result.core=core
 var candidates:Variant=value.get("perks",[])
 if candidates is Array:
  for row in perk_options(style_id,core):
   if row.id in candidates:result.perks.append(row.id)
 return result

func restore(value:Variant) -> void:
 saved.clear()
 if not value is Dictionary:return
 for key in Paths.STYLES:
  if value.has(key):saved[key]=clean(key,value[key])

func selection(style_id:String) -> Dictionary:
 return clean(style_id,saved.get(style_id,{}))

func begin(style_id:String) -> void:
 style=style_id
 draft=selection(style)
 draft_enemy=enemy_pattern

func choose_enemy(pattern:String) -> void:
 if Night.BOSS.has(pattern):draft_enemy=pattern

func choose(core:String) -> void:
 if core!="" and not Paths.valid(style,core):return
 if core==draft.core:return
 draft={"core":core,"perks":[]}

func toggle(id:String) -> void:
 for row in perk_options(style,str(draft.core)):
  if row.id!=id:continue
  if id in draft.perks:draft.perks.erase(id)
  else:draft.perks.append(id)
  return

func commit() -> void:
 saved[style]=clean(style,draft)
 enemy_pattern=draft_enemy

func apply(player:Dictionary,style_id:String) -> void:
 var loadout:Dictionary=selection(style_id)
 Night.setup(player,str(loadout.core),loadout.perks)
 Paths.setup(player,str(loadout.core),loadout.perks)

func snapshot() -> Dictionary:
 return {"style":style,"core":draft.core,"selectedPerks":draft.perks.duplicate(),
  "options":Paths.options(style),"perks":perk_options(style,str(draft.core)),
  "basics":Paths.BASICS.get(style,""),"enemyPattern":draft_enemy,"enemyOptions":enemy_options()}

static func enemy_options() -> Array:
 var result:Array=[]
 for id in Night.BOSS:
  result.append({"id":id,"title":Night.BOSS[id].title,"description":Night.BOSS[id].description})
 return result

static func perk_options(style_id:String,core:String) -> Array:
 var rows:Array=[]
 if not Paths.valid(style_id,core):return rows
 var registry:Dictionary=Night.REWARDS if style_id=="night_squire" else Paths.REWARDS
 for row in Paths.options(style_id):
  if row.id!=core:continue
  for id in row.rewards:
   rows.append(registry[id].duplicate(true))
 return rows
