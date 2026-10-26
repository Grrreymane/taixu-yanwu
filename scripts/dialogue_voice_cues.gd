extends RefCounted
## Automatic mood-to-grunt matching is removed. Only an individually reviewed
## original clip attached to the exact sentence may produce a dialogue cue.
const PLAYER_PROFILES := ["azure_empyrea", "fenghuang", "night_squire"]
var _was_active := false
var _session := 0
var _last_clock := -1.0
var _last_signature := ""
var _last_key := ""
var _emitted := 0

func reset() -> void:
	# Keep the monotonically increasing session: replaying the same scene must
	# receive a fresh key even if the audio player remembers its previous cue.
	_was_active = false
	_last_clock = -1.0
	_last_signature = ""
	_last_key = ""

func next(story: Dictionary, style_id: String = "azure_empyrea") -> Dictionary:
	if not bool(story.get("active", false)):
		reset()
		return {}
	# A line revealed while unfocused starts only when its scene is visible.
	# Already-started audio is paused/resumed by the separate playback owner.
	if not bool(story.get("focused", true)) or bool(story.get("paused", false)):
		return {}
	var cue := resolve(story, style_id)
	if cue.is_empty():
		return {}
	var clock: float = maxf(0.0, float(story.get("time", 0.0)))
	if not _was_active or clock + 0.000001 < _last_clock:
		_session += 1
		_last_signature = ""
	_was_active = true
	_last_clock = clock
	var signature: String = str(cue.signature)
	if signature == _last_signature:
		return {}
	_last_signature = signature
	_last_key = "dialogue:%d:%s" % [_session, signature]
	_emitted += 1
	cue["lineKey"] = _last_key
	cue["key"] = _last_key
	cue["session"] = _session
	return cue

static func resolve(line: Dictionary, style_id: String = "azure_empyrea") -> Dictionary:
	var authored: Variant = line.get("voiceCue", {})
	if not authored is Dictionary or not bool(authored.get("reviewed", false)): return {}
	var clip_id := str(authored.get("clipId", ""))
	var speaker: String = str(line.get("speaker", ""))
	var text: String = str(line.get("text", ""))
	if clip_id.is_empty() or speaker not in ["fuhua", "senti"] or text.strip_edges().is_empty():
		return {}
	var profile: String = "sentience" if speaker == "senti" else style_id if style_id in PLAYER_PROFILES else "azure_empyrea"
	var scene: String = str(line.get("scene", "dialogue"))
	var branch: String = str(line.get("branchId", ""))
	var index: int = int(line.get("index", 0))
	var text_hash: String = text.sha256_text()
	if str(authored.get("textHash", "")) != text_hash: return {}
	# Voice identity is independent of reveal progress, frame time and outfit.
	var signature: String = (JSON.stringify([scene, branch, index, speaker, str(line.get("revision", "")), text_hash, clip_id])).sha256_text()
	return {"type":"dialogue", "profile":profile, "voiceProfile":profile,
		"speaker":speaker, "category":"dialogue", "clipId":clip_id, "reviewed":true,
		"reason":"individually_reviewed_original_clip", "scene":scene, "branchId":branch, "index":index,
		"textHash":text_hash, "signature":signature}

func snapshot() -> Dictionary:
	return {"active":_was_active, "session":_session, "lastLineKey":_last_key, "emitted":_emitted,
		"automatic":false, "policy":"reviewed_exact_line_only"}
