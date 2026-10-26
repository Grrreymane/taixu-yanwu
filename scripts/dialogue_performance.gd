extends RefCounted
## Complete source clips only. Dialogue wording and speaker changes never
## select body parts, rotate joints, synthesize expressions, or rewind a take.
var _actors: Dictionary = {}

func reset() -> void:
	_actors.clear()

func apply(actor, identity: String, _line: Dictionary, _line_id: int, delta: float, clock: float) -> void:
	if not actor.ready_for_combat: return
	if not _actors.has(identity):
		var clip: String=actor._prefix+str(actor._motions.idle.clip)
		# Use the original take span. C5's imported resource includes trailing
		# FBX padding beyond its 2.016667-second StandBy source take.
		var duration: float=float(actor._motions.idle.end)
		_actors[identity]={"mode":"native_full_clip","sourceClip":clip,"duration":duration,"loopClip":clip,"loopDuration":duration,
			"sourceTime":0.0,"skeletalEdits":0,"facialMode":"source_default","updates":0}
	var state: Dictionary=_actors[identity]
	var sample_clock:=clock
	# C6's original, non-looping Idle is a complete 4.233s idle gesture. Its
	# endpoint matches Standby; play it once, then the original looping stance.
	# Never borrow Victory's arms or facial curves for this sequence.
	if identity=="senti" and actor.animation_player.has_animation("native/Idle") and clock<4.2333336:
		state.sourceClip="native/Idle"
		state.duration=4.2333336
	else:
		state.sourceClip=state.loopClip
		state.duration=state.loopDuration
		if identity=="senti": sample_clock=maxf(0.0,clock-4.2333336)
	actor.animate_native_dialogue(str(state.sourceClip),float(state.duration),clock,
		-1.0 if identity=="fuhua" else 1.0,0.25 if identity=="fuhua" else -0.25,sample_clock)
	state.sourceTime=actor.source_time
	if delta>0.0: state.updates=int(state.updates)+1

func snapshot() -> Dictionary:
	return _actors.duplicate(true)
