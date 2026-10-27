extends Node3D
## User-approved dialogue over complete native character animation clips.
signal finished
const Actor = preload("res://scripts/actor.gd")
const SentienceProfile = preload("res://scripts/sentience_profile.gd")
const Story = preload("res://scripts/sentience_story.gd")
const DialoguePerformance = preload("res://scripts/dialogue_performance.gd")
const StoryBackdrop = preload("res://scripts/story_backdrop.gd")
const FONT = preload("res://assets/fonts/hi3-sdk-zh-cn.ttf")
var active := false
var scene_id := ""
var index := 0
var clock := 0.0
var line_time := 0.0
var revealed := false
var lines: Array = []
var meta: Dictionary = {}
var decision: Dictionary = {}
var actors: Dictionary = {}
var signature := ""
var _canvas := CanvasLayer.new()
var _ui := Control.new()
var _dialog := Panel.new()
var _chapter := Label.new()
var _speaker := Label.new()
var _text := Label.new()
var _progress := Label.new()
var _next := Button.new()
var _skip := Button.new()
var _backdrop := StoryBackdrop.new()
var _location_title := Label.new()
var _location := "mountain"
var _last_size := Vector2.ZERO
var focused := true
var _performance = DialoguePerformance.new()

func _ready() -> void:
	_canvas.layer=30
	add_child(_canvas)
	_canvas.add_child(_ui)
	_ui.mouse_filter=Control.MOUSE_FILTER_STOP
	_ui.add_child(_backdrop)
	_ui.add_child(_location_title)
	_location_title.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_location_title.add_theme_font_override("font",FONT)
	_location_title.add_theme_font_size_override("font_size",30)
	_location_title.add_theme_color_override("font_color",Color("e8d6ae"))
	_location_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var top:=ColorRect.new()
	top.name="TopShade"
	top.color=Color(0.025,0.035,0.07,0.88)
	top.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_ui.add_child(top)
	_ui.add_child(_chapter)
	_ui.add_child(_dialog)
	var panel:=StyleBoxFlat.new()
	panel.bg_color=Color(0.025,0.05,0.09,0.94)
	panel.border_color=Color("b678c4")
	panel.border_width_top=2
	panel.border_width_left=4
	panel.corner_radius_top_left=4
	panel.corner_radius_top_right=4
	_dialog.add_theme_stylebox_override("panel",panel)
	_dialog.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for label in [_speaker,_text,_progress]:
		_dialog.add_child(label)
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for label in [_chapter,_speaker,_text,_progress]:
		label.add_theme_font_override("font",FONT)
		label.add_theme_color_override("font_color",Color("f1ecf4"))
	_chapter.add_theme_font_size_override("font_size",21)
	_chapter.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	_speaker.add_theme_font_size_override("font_size",24)
	_speaker.add_theme_color_override("font_color",Color("efb8d4"))
	_text.add_theme_font_size_override("font_size",26)
	_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_progress.add_theme_font_size_override("font_size",13)
	_progress.add_theme_color_override("font_color",Color("aebaca"))
	for button in [_next,_skip]:
		_ui.add_child(button)
		button.add_theme_font_override("font",FONT)
		button.add_theme_font_size_override("font_size",17)
		button.focus_mode=Control.FOCUS_NONE
		button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		var style:=StyleBoxFlat.new()
		style.bg_color=Color("233649")
		style.border_color=Color("93b7c9")
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		button.add_theme_stylebox_override("normal",style)
		var hover:=style.duplicate()
		hover.bg_color=Color("426078")
		button.add_theme_stylebox_override("hover",hover)
	_next.text="继续  ENTER"
	_skip.text="跳过剧情  ESC"
	_next.pressed.connect(advance)
	_skip.pressed.connect(skip)
	_ui.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT: advance()
		elif event is InputEventScreenTouch and event.pressed: advance())
	_layout()
	_ui.hide()
	hide()

func _ensure_actors(selection: Dictionary) -> void:
	var next_signature:=str(selection.get("styleId",""))+":"+str(selection.get("appearanceId",""))
	if signature==next_signature and actors.size()==2: return
	for actor in actors.values(): actor.free()
	actors.clear()
	for identity in ["fuhua","senti"]:
		var config: Dictionary=selection if identity=="fuhua" else SentienceProfile.selection()
		if config.is_empty(): continue
		var actor:=Node3D.new()
		actor.set_script(Actor)
		add_child(actor)
		actor.setup(false,config)
		actors[identity]=actor
	signature=next_signature

func begin(key: String, context: Dictionary, selection: Dictionary) -> void:
	lines=Story.lines(key,context)
	if lines.is_empty(): return
	_ensure_actors(selection)
	scene_id=key
	meta=Story.metadata(key,context)
	decision=Story.decision(context)
	index=0
	clock=0.0
	line_time=0.0
	revealed=false
	_performance.reset()
	active=true
	show()
	_ui.show()
	_refresh_line()

func _refresh_line() -> void:
	line_time=0.0
	revealed=false
	var line: Dictionary=lines[index]
	var identity := str(line.get("speaker",""))
	var kind := str(line.get("kind","dialogue"))
	var default_name := str({"senti":"识之律者","fuhua":"符华","fuhua_thought":"符华（心想）","lixue":"程立雪","narrator":"旁白"}.get(identity,"旁白"))
	_speaker.text=str(line.get("displayName",default_name))
	if _speaker.text.is_empty(): _speaker.text=default_name
	var tint := Color("efb8d4") if identity=="senti" else Color("9adaed")
	if kind in ["narration","direction"]: tint=Color("c4c2bb")
	elif identity=="lixue" or kind=="memory": tint=Color("e0c89b")
	elif identity=="fuhua_thought": tint=Color("b1b8d5")
	_speaker.add_theme_color_override("font_color",tint)
	_text.text=str(line.get("text",""))
	_text.visible_characters=0
	_text.add_theme_color_override("font_color",Color("d1cbc1") if kind in ["narration","direction"] else Color("f1ecf4"))
	var chapter_title:=str(line.get("sceneTitle",meta.get("title","一场切磋")))
	_chapter.text="识境演武  /  "+("小识与老古董" if chapter_title=="识境演武" else chapter_title)
	_location=_line_location(line)
	_backdrop.set_location(_location)
	_location_title.text=str({"street":"暮色 · 街边","noodle_shop":"一碗云吞面","memory":"旧时 · 炉火","mountain":""}.get(_location,""))
	_location_title.visible=_location!="mountain"
	for actor in actors.values(): actor.visible=_location=="mountain"
	_progress.text="%02d / %02d   ·   点击对话继续" % [index+1,lines.size()]
	_next.text="继续  ENTER" if index<lines.size()-1 else "继续旅程  ENTER"
	if scene_id=="reward":
		_progress.text="领悟 %02d / 05   ·   对话 %02d / %02d   ·   点击继续" % [int(decision.get("choiceCount",1)),index+1,lines.size()]
		if index==lines.size()-1:
			_next.text="与小识交手  ENTER" if bool(decision.get("finalChoice",false)) else "继续演武  ENTER"
	elif scene_id=="victory" and index==lines.size()-1: _next.text="查看结算  ENTER"
	elif scene_id=="defeat" and index==lines.size()-1: _next.text="查看战况  ENTER"
	_layout()

func _line_location(line: Dictionary) -> String:
	var authored := str(line.get("presentationLocation",""))
	if not authored.is_empty(): return authored
	var source := str(line.get("sourceSceneId",""))
	if source=="I02":
		var kind := str(line.get("kind",""))
		var identity := str(line.get("speaker",""))
		if kind=="memory" or identity=="lixue" or str(line.get("text","")).begins_with("（短暂闪回"): return "memory"
		if str(line.get("text","")).begins_with("（镜头短暂切回识境"): return "mountain"
		return "noodle_shop"
	if source.begins_with("I01"):
		var id := str(line.get("lineId",line.get("id","")))
		if source=="I01" and id.begins_with("I01-") and id.trim_prefix("I01-").is_valid_int() and int(id.trim_prefix("I01-"))<8: return "street"
		return "noodle_shop"
	return "mountain"

func advance() -> void:
	if not active: return
	if not revealed:
		revealed=true
		_text.visible_characters=-1
		return
	index+=1
	if index>=lines.size(): skip()
	else: _refresh_line()

func skip() -> void:
	if not active: return
	active=false
	hide()
	_ui.hide()
	finished.emit()

func reset() -> void:
	# Leaving a run discards its dialogue memory without firing continuation.
	active=false
	scene_id=""
	index=0
	clock=0.0
	line_time=0.0
	revealed=false
	lines.clear()
	meta.clear()
	decision.clear()
	_performance.reset()
	hide()
	_ui.hide()

func tick(delta: float) -> void:
	if not active: return
	if get_viewport().get_visible_rect().size!=_last_size: _layout()
	if not focused: return
	var step:=maxf(0.0,delta)
	clock+=step
	line_time+=step
	if not revealed:
		_text.visible_characters=int(line_time*28.0)
		if _text.visible_characters>=_text.text.length():
			revealed=true
			_text.visible_characters=-1
	var line: Dictionary=lines[index]
	for identity in actors:
		var actor: Node3D=actors[identity]
		_performance.apply(actor,identity,line,index,step,clock)

func frame(aspect: float) -> Dictionary:
	# Keep both speakers in one composition. Main applies this frame directly,
	# so even a small speaker-dependent offset would visibly jump on each click.
	var z: float=maxf(5.9,3.45/(2.0*tan(deg_to_rad(29.0*0.5))*maxf(aspect,0.65)))
	return {"position":Vector3(0,2.08,z),"target":Vector3(0,1.95,0),"fov":29.0,"roll":0.0,"shot":"dialogue_two_shot"}

func snapshot() -> Dictionary:
	var line: Dictionary=lines[index] if active and index<lines.size() else {}
	return {"active":active,"scene":scene_id,"index":index,"total":lines.size(),"time":clock,"lineTime":line_time,
		"speaker":line.get("speaker",""),"text":line.get("text",""),"revealed":revealed,"title":meta.get("title",""),"actors":actors.size(),"focused":focused,
		"lineId":line.get("lineId",line.get("id","")),"sourceSceneId":line.get("sourceSceneId",""),"kind":line.get("kind","dialogue"),"displayName":_speaker.text,"location":_location,
		"textHeight":_text.size.y,"textLineCount":_text.get_line_count(),"fontSize":_text.get_theme_font_size("font_size"),"textWidth":_text.size.x,
		"choice":decision.duplicate(true),"branchId":str(decision.get("branchId","")),"revision":meta.get("revision",""),"performance":_performance.snapshot()}

func _layout() -> void:
	_last_size=get_viewport().get_visible_rect().size
	var factor: float=clampf(minf(_last_size.x/1280.0,_last_size.y/800.0),0.40,1.8)
	_ui.scale=Vector2.ONE*factor
	_ui.size=_last_size/factor
	var w: float=_ui.size.x
	var h: float=_ui.size.y
	_backdrop.size=Vector2(w,h)
	_location_title.position=Vector2(40,110)
	_location_title.size=Vector2(w-80,45)
	_ui.get_node("TopShade").size=Vector2(w,70)
	_chapter.position=Vector2(40,22)
	_chapter.size=Vector2(w-320,40)
	_skip.position=Vector2(w-224,15)
	_skip.size=Vector2(185,41)
	var text_width := w-150.0
	var measured_width := FONT.get_string_size(_text.text,HORIZONTAL_ALIGNMENT_LEFT,-1,26).x
	var rows := ceili(measured_width/maxf(text_width,1.0))+1
	var text_height := maxf(88.0,float(rows)*34.0)
	var panel_height := text_height+116.0
	_dialog.position=Vector2(40,h-panel_height-22)
	_dialog.size=Vector2(w-80,panel_height)
	_speaker.position=Vector2(30,15)
	_speaker.size=Vector2(400,34)
	_text.position=Vector2(30,60)
	_text.size=Vector2(text_width,text_height)
	_progress.position=Vector2(30,panel_height-38)
	_progress.size=Vector2(420,22)
	_next.position=Vector2(w-269,h-68)
	_next.size=Vector2(195,35)
