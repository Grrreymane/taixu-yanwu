"""Compare deterministic before/after combat probe captures, excluding timings."""
import json
import sys
from pathlib import Path

before, after = (json.loads(Path(p).read_text(encoding="utf-8")) for p in sys.argv[1:3])
assert len(before) == len(after) and before, "capture count differs"
max_delta = 0.0
for old, new in zip(before, after):
    assert (old["style"], old["frame"]) == (new["style"], new["frame"])
    assert old["sim"] == new["sim"], "combat state, damage or timing changed"
    assert old["fx"] == new["fx"], "effect count changed"
    assert len(old["poses"]) == len(new["poses"])
    for old_pose, new_pose in zip(old["poses"], new["poses"]):
        assert len(old_pose) == len(new_pose)
        max_delta = max(max_delta, max(abs(a-b) for a, b in zip(old_pose, new_pose)))
assert max_delta < 0.00001, f"native bone pose changed: {max_delta}"
print(f"COMBAT_EQUIVALENCE_PASS: {len(before)} frames, max bone delta {max_delta}; identical simulation and effect counts")
