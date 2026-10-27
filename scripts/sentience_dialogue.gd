extends RefCounted
## Verbatim imported manuscript. Scene selection belongs to SentienceStory.
const REVISION := "story-voice-v3"
const DATA_PATH := "res://scripts/data/sentience_story_scenes.json"
const CARD_SCENES := {
 "fist":"B01","iron":"B02","risk":"B03","finisher":"B04",
 "reflection":"B05","riposte":"B06","calm":"B07","breath":"B08",
 "flow":"B09","swift":"B10","windstep":"B11","reservoir":"B12"}
const COMBINATION_SCENES := {
 "riposte":"C01","reflection":"C02","breath":"C03","risk":"C04",
 "finisher":"C05","flow":"C06","swift":"C07","windstep":"C08"}
const TURN_SCENES := {
 "press_guard":"D01","press_flow":"D02","guard_press":"D03",
 "guard_flow":"D04","flow_press":"D05","flow_guard":"D06"}
static var _catalog: Dictionary = {}

static func catalog() -> Dictionary:
 if _catalog.is_empty():
  var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
  if parsed is Dictionary and parsed.get("revision","")==REVISION and parsed.get("scenes",{}) is Dictionary:
   _catalog=parsed
  else:
   push_error("The approved story manuscript data is missing or invalid: "+DATA_PATH)
 return _catalog.duplicate(true)

static func _scenes() -> Dictionary:
 if _catalog.is_empty(): catalog()
 return _catalog.get("scenes",{})

static func initial_location(scene_id: String) -> String:
 if scene_id=="I01": return "street"
 if scene_id.begins_with("I01"): return "noodle_shop_waiting"
 if scene_id=="I02": return "noodle_shop"
 return "mountain"

static func _location(source: Dictionary, scene_id: String, previous: String) -> String:
 # Directions sharing beforeLine are separate beats: stop at the table, then
 # flash back; remember the old kitchen, then return to the present table.
 var kind:=str(source.get("kind","dialogue"))
 var text:=str(source.get("text",""))
 if scene_id=="I01" and kind=="direction" and text.begins_with("两人在靠窗的桌边坐下"):
  return "noodle_shop_waiting"
 if scene_id=="I02":
  if kind=="direction" and text.begins_with("短暂闪回："): return "memory"
  if kind=="direction" and text.begins_with("回到现实。"): return "noodle_shop"
  if kind=="memory": return "memory"
 return previous

static func _decorate(source: Dictionary, scene_id: String, scene: Dictionary, location: String) -> Dictionary:
 var line:=source.duplicate(true)
 line["lineId"]=str(source.id)
 line["sourceSceneId"]=scene_id
 line["manuscriptSceneId"]=str(scene.get("sourceSceneId",scene_id))
 line["sceneTitle"]=str(scene.get("title",scene_id))
 line["presentationLocation"]=location
 line["audible"]=str(line.kind)=="dialogue" and str(line.speaker) in ["fuhua","senti"]
 line["mood"]="calm"
 line["expression"]="calm"
 line["pose"]="idle"
 line["portrait"]=str(line.speaker) if bool(line.audible) else ""
 return line

static func scene_lines(scene_id: String) -> Array:
 var scenes:=_scenes()
 if not scenes.has(scene_id): return []
 var scene: Dictionary=scenes[scene_id]
 var source_lines: Array=scene.get("lines",[])
 var directions: Array=scene.get("stageDirections",[])
 var result: Array=[]
 var location:=initial_location(scene_id)
 for source_index: int in range(source_lines.size()+1):
  for direction_index: int in directions.size():
   var direction: Dictionary=directions[direction_index]
   if int(direction.beforeLine)!=source_index: continue
   var direction_line: Dictionary={"id":"%s-direction-%02d"%[scene_id,direction_index+1],
    "speaker":"narrator","kind":"direction","displayName":"旁白",
    "text":str(direction.text),"sourceLine":int(direction.sourceLine)}
   location=_location(direction_line,scene_id,location)
   result.append(_decorate(direction_line,scene_id,scene,location))
  if source_index<source_lines.size():
   location=_location(source_lines[source_index],scene_id,location)
   result.append(_decorate(source_lines[source_index],scene_id,scene,location))
 return result

static func scene_title(scene_id: String) -> String:
 return str(_scenes().get(scene_id,{}).get("title",scene_id))

# Compatibility for inspection tools. Gameplay retains IDs and directions.
static func _legacy_table(mapping: Dictionary) -> Dictionary:
 var result: Dictionary={}
 for key: String in mapping:
  var rows: Array=[]
  for line: Dictionary in scene_lines(str(mapping[key])):
   if str(line.kind)=="dialogue": rows.append([line.speaker,line.text,line.mood])
  result[key]=rows
 return result

static var CARDS: Dictionary = _legacy_table(CARD_SCENES)
static var COMBINATIONS: Dictionary = _legacy_table(COMBINATION_SCENES)
static var TURNS: Dictionary = _legacy_table(TURN_SCENES)
