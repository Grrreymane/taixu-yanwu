extends SceneTree
## Headless temporal/layout contract. Final pixel review belongs to the GPU owner.
const Knockout=preload("res://scripts/knockout_presentation.gd")
var checks:=0
var failures:Array[String]=[]
var completed:=0
func _initialize() -> void:call_deferred("_run")
func _check(condition:bool,label:String) -> void:
	checks+=1
	if not condition:failures.append(label);push_error(label)
func _close(a:float,b:float) -> bool:return absf(a-b)<0.00001
func _run() -> void:
	var ko=Knockout.new();root.add_child(ko)
	ko.finished.connect(func():completed+=1)
	_check(not ko.visible and not ko.active,"New module starts hidden")
	_check(ko._canvas.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Overlay does not capture combat or UI input")
	ko.begin({"final":false,"count":1,"total":3})
	_check(not ko.active and ko.snapshot().badgeActive,"An intermediate enemy only creates a badge")
	_check(ko.snapshot().timeScale==1.0 and ko.snapshot().cameraPulse==0.0,"Ordinary defeats do not request slow motion or camera shake")
	_check(ko.snapshot().count==1 and ko.snapshot().total==3,"Badge retains actual defeat counts")
	ko.tick(0.1)
	var before:=ko.snapshot()
	ko.tick(1.0,true)
	_check(_close(ko.snapshot().badgeTime,before.badgeTime),"Pause freezes intermediate badge as well")
	ko.tick(0.5)
	_check(not ko.visible and completed==0,"Minor badge expires without signalling round completion")
	ko.begin({"final":true,"winner":"player","count":3,"total":3})
	_check(ko.active and ko.visible and ko.snapshot().result=="victory","Final enemy starts the victory treatment")
	_check(ko.snapshot().timeScale==0.0 and ko.snapshot().cameraPulse==1.0,"The finishing contact requests its opening freeze and impact pulse")
	ko.tick(0.089)
	_check(ko.snapshot().timeScale==0.0,"Freeze lasts until90ms")
	ko.tick(0.001)
	_check(ko.snapshot().timeScale==0.25,"After90ms time resumes in slow motion")
	ko.tick(0.249)
	_check(ko.snapshot().timeScale==0.25,"Slow motion lasts through339ms")
	ko.tick(0.001)
	_check(ko.snapshot().timeScale==1.0,"Normal playback returns at340ms")
	var preserved_time:float=ko.time
	var preserved_count:int=ko.count
	ko.begin({"final":false,"count":99,"total":99})
	_check(_close(ko.time,preserved_time) and ko.count==preserved_count,"A late ordinary defeat cannot reset the final sequence")
	ko.tick(0.1,true)
	_check(_close(ko.time,preserved_time),"Paused finish holds its exact time")
	ko.set_focused(false);ko.tick(1.0)
	_check(_close(ko.time,preserved_time),"Focus loss holds the sequence")
	ko.set_focused(true);ko.tick(-1.0);ko.tick(NAN);ko.tick(INF)
	_check(_close(ko.time,preserved_time),"Invalid or negative deltas cannot corrupt timing")
	ko.tick(2.0)
	_check(not ko.active and not ko.visible and completed==1,"Oversized delta completes the sequence once")
	ko.tick(2.0)
	_check(completed==1 and ko.snapshot().timeScale==1.0,"Finished overlay cannot leave slow motion behind or emit twice")
	ko.begin({"final":true,"winner":"enemy"})
	_check(ko.snapshot().result=="defeat" and ko.snapshot().label=="K.O.","Player defeat gets its separate red-white KO treatment")
	ko.clear()
	_check(not ko.visible and ko.time==0.0 and ko.count==0 and ko.snapshot().cameraPulse==0.0,"Clear removes every presentation request")
	_check(completed==1,"Clear is not round completion")
	var frame_rates:Array=[]
	for fps in [30,60,120,144]:
		ko.begin({"final":true,"winner":"player"})
		var wall:=0.0
		while ko.active and wall<2.0:
			ko.tick(1.0/float(fps));wall+=1.0/float(fps)
		frame_rates.append({"fps":fps,"completionWallTime":wall})
		_check(wall>=Knockout.DURATION-0.00001 and wall<=Knockout.DURATION+1.0/float(fps)+0.00001,"Finish timing is stable at%d fps" % fps)
	var max_flash:=0.0
	for sample in 136:
		var frame:=Knockout.timing(float(sample)/100.0)
		for key in ["opacity","entry","ending","flash","rays","caption","cameraPulse"]:
			_check(is_finite(frame[key]) and frame[key]>=0.0 and frame[key]<=1.0,"Normalized temporal envelope %s at%d" % [key,sample])
		max_flash=maxf(max_flash,frame.flash)
		if sample>=24:_check(frame.cameraPulse==0.0,"Camera impulse ends before the hold at%d" % sample)
		if sample>=18:_check(frame.flash==0.0,"No repeated flashes during hold at%d" % sample)
	_check(max_flash<=0.24 and Knockout.DURATION<=1.6,"Presentation stays brief and flash is bounded")
	var layouts:Array=[]
	for viewport:Vector2 in [Vector2(960,540),Vector2(1440,900),Vector2(1920,1080),Vector2(540,960)]:
		var g:=Knockout.layout(viewport)
		var text:Rect2=g.textBounds
		# Cover the maximum1.34 entrance scale, italic slant and shadow edges.
		var extent:=Vector2(text.size.x*1.34*0.5+text.size.y*0.20*1.34*0.5+28*g.unit,text.size.y*1.34*0.5+20*g.unit)
		var safety:=Rect2(g.center-extent,extent*2)
		_check(Rect2(Vector2.ZERO,viewport).encloses(safety),"Title including entry zoom and skew fits%s" % viewport)
		_check(Rect2(Vector2.ZERO,viewport).encloses(g.badge),"Ordinary defeat badge fits%s" % viewport)
		layouts.append({"width":viewport.x,"height":viewport.y,"fontSize":g.fontSize,"textWidth":text.size.x,"textHeight":text.size.y})
	ko.free()
	var report={"suite":"knockout_presentation","passed":failures.is_empty(),"checks":checks,"failures":failures,"frameRates":frame_rates,"layouts":layouts,"duration":Knockout.DURATION,"gpuUsed":false}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/reports"))
	FileAccess.open("res://build/reports/knockout-presentation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
