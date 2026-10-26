extends RefCounted
## One authoritative health indicator per enemy. A group keeps its overhead
## layout even after all but one enemy fall; the final survivor never jumps UI.
static func plan(enemies: Array) -> Dictionary:
	var primary:=""
	var mode:="group"
	for foe: Dictionary in enemies:
		if float(foe.get("hp",0.0))>0.0 and bool(foe.get("boss",false)):
			primary=str(foe.get("id","enemy"))
			mode="boss"
			break
	if primary.is_empty() and enemies.size()==1:
		primary=str(enemies[0].get("id","enemy"))
		mode="single"
	var overhead: Array[String]=[]
	for foe: Dictionary in enemies:
		var identity:=str(foe.get("id","enemy"))
		if float(foe.get("hp",0.0))>0.0 and identity!=primary: overhead.append(identity)
	return {"primaryId":primary,"overheadIds":overhead,"mode":mode}
