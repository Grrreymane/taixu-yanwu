extends RefCounted
## Presentation owns its clock; campaign statistics remain frozen after finish.

const DURATION := 4.4
var visible := false
var time := 0.0
var paused := false
var focused := true
var plays := 0

func begin() -> void:
	visible = true
	time = 0.0
	paused = false
	plays += 1

func clear() -> void:
	visible = false
	time = 0.0
	paused = false

func tick(delta: float) -> void:
	if visible and not paused and focused:
		time += maxf(0.0, delta)

func playing() -> bool:
	return visible and time < DURATION

func skip() -> void:
	if visible:
		time = maxf(time, DURATION)
		paused = false

func toggle_pause() -> void:
	if playing():
		paused = not paused

func set_focused(value: bool) -> void:
	focused = value
	if playing() and not value:
		paused = true

func snapshot() -> Dictionary:
	return {"visible":visible,"playing":playing(),"time":time,
		"duration":DURATION,"paused":paused,"focused":focused,"plays":plays}

static func _shot(position: Vector3, target: Vector3, fov: float, label: String) -> Dictionary:
	return {"position":position,"target":target,"fov":fov,"roll":0.0,"shot":label}

static func _blend(a: Dictionary, b: Dictionary, amount: float, label: String) -> Dictionary:
	var progress := smoothstep(0.0, 1.0, clampf(amount, 0.0, 1.0))
	return _shot(Vector3(a.position).lerp(b.position, progress),
		Vector3(a.target).lerp(b.target, progress),lerpf(a.fov,b.fov,progress),label)

static func frame(at: float, aspect: float, profile: String = "azure_empyrea") -> Dictionary:
	if profile == "azure_empyrea": return _azure_frame(at, aspect)
	# Native Victory is framed from the front, separate from the combat axis.
	# The last composition leaves the right half for results and controls.
	var opening := _shot(Vector3(2.5,1.9,5.9),Vector3(0,1.55,0),35.0,"arrival")
	var gesture := _shot(Vector3(1.25,2.05,5.0),Vector3(0,1.85,0),34.0,"salute")
	var portrait := _shot(Vector3(0.25,2.12,4.6),Vector3(0,1.85,0),33.0,"portrait")
	var distance := maxf(6.7,6.7*1.35/maxf(0.6,aspect))
	var offset := distance*tan(deg_to_rad(31.0*0.5))*aspect*0.44
	var result := _shot(Vector3(offset,1.95,distance),Vector3(offset,1.52,0),31.0,"results")
	if at < 1.3:
		return _blend(opening,gesture,at/1.3,"salute")
	if at < 3.55:
		return _blend(gesture,portrait,(at-1.3)/2.25,"portrait")
	return _blend(portrait,result,(at-3.55)/(DURATION-3.55),"reveal" if at < DURATION else "results")

static func _azure_frame(at: float, aspect: float) -> Dictionary:
	# C5 begins facing -Z, turns through -X, and finishes facing +Z/-X.
	# A fixed +Z camera hid the face and umbrella gesture behind her hair.
	# Follow the original turn, without rotating or reposing the character.
	var opening := _shot(Vector3(-0.60,2.25,-6.65),Vector3(0,1.90,0),35.0,"umbrella")
	var turn := _shot(Vector3(-4.25,2.15,-3.75),Vector3(0,1.86,0),34.0,"turn")
	var glance := _shot(Vector3(-4.45,2.18,1.25),Vector3(0,1.96,0),33.0,"glance")
	var portrait := _shot(Vector3(-2.1,2.16,4.1),Vector3(0,1.88,0),33.0,"portrait")
	var distance := maxf(6.7,6.7*1.35/maxf(0.6,aspect))
	var offset := distance*tan(deg_to_rad(31.0*0.5))*aspect*0.44
	var view := Vector3(-0.48,0,0.88).normalized()
	var right := Vector3(view.z,0,-view.x)
	var result := _shot(view*distance+right*offset+Vector3.UP*1.95,right*offset+Vector3.UP*1.52,31.0,"results")
	if at < 1.2: return _blend(opening,turn,at/1.2,"umbrella")
	if at < 2.2: return _blend(turn,glance,(at-1.2),"turn")
	if at < 3.2: return _blend(glance,portrait,(at-2.2),"glance")
	return _blend(portrait,result,(at-3.2)/(DURATION-3.2),"reveal" if at<DURATION else "results")
