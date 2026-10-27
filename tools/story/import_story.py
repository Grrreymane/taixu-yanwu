"""Import the user-authored Markdown story without rewriting its wording.

Run from any directory:
    python tools/story/import_story.py
    python tools/story/import_story.py --check

Only numbered story rows and explicitly marked stage directions are imported.
Authoring notes remain in the source document and are never executed.
"""

from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE_PATH = PROJECT_ROOT / "docs" / "story" / "识境演武_剧情重写完整版.md"
OUTPUT_PATH = PROJECT_ROOT / "scripts" / "data" / "sentience_story_scenes.json"
REVISION = "story-rewrite-1"
SCENE_HEADER = re.compile(r"^#{2,3}\s+【([A-J]\d{2}(?:-[PSMH])?)｜(.+)】\s*$")
NUMBERED_ROW = re.compile(r"^([A-J]\d{2}-(?:[PSMH])?\d{2})\s+(.+?)\s*$")
SPEAKERS = {
    "符华": ("fuhua", "dialogue"),
    "小识": ("senti", "dialogue"),
    "符华（心想）": ("fuhua_thought", "thought"),
    "符华（回忆）": ("fuhua", "memory"),
    "程立雪": ("lixue", "dialogue"),
}


def _unbold(text: str) -> str:
    return text[2:-2] if text.startswith("**") and text.endswith("**") else text


def parse_source(source_bytes: bytes, source_path: str) -> dict:
    """Keep the source IDs, punctuation, speakers, and ordering intact."""
    scenes = {}
    scene = None
    ids = set()
    for source_line, raw in enumerate(source_bytes.decode("utf-8-sig").splitlines(), 1):
        value = raw.strip()
        header = SCENE_HEADER.fullmatch(value)
        if header:
            source_scene_id, title = header.groups()
            scene_id = source_scene_id
            if source_scene_id == "I01" and title.startswith("公共续段"):
                scene_id = "I01_CONT"
            if scene_id in scenes:
                raise ValueError(f"Duplicate scene {scene_id} on source line {source_line}")
            scene = {
                "title": title,
                "sourceSceneId": source_scene_id,
                "sourceLine": source_line,
                "lines": [],
                "stageDirections": [],
            }
            scenes[scene_id] = scene
            continue
        if value.startswith("#"):
            scene = None
            continue
        match = NUMBERED_ROW.fullmatch(value)
        if match:
            if scene is None:
                raise ValueError(f"Story row outside a scene on source line {source_line}")
            line_id, body = match.groups()
            expected_prefix = scene["sourceSceneId"]
            expected_prefix += "" if "-" in expected_prefix else "-"
            if not line_id.startswith(expected_prefix):
                raise ValueError(f"Row {line_id} does not belong to {scene['sourceSceneId']}")
            if line_id in ids:
                raise ValueError(f"Duplicate story row {line_id}")
            ids.add(line_id)
            plain = _unbold(body)
            if plain.startswith("（") and plain.endswith("）"):
                speaker, kind, display_name, text = "narrator", "narration", "", plain
            else:
                if "：" not in plain:
                    raise ValueError(f"Missing speaker in {line_id}")
                display_name, text = plain.split("：", 1)
                if display_name not in SPEAKERS:
                    raise ValueError(f"Unknown speaker {display_name!r} in {line_id}")
                speaker, kind = SPEAKERS[display_name]
            scene["lines"].append({
                "id": line_id,
                "speaker": speaker,
                "text": text,
                "kind": kind,
                "displayName": display_name,
                "sourceLine": source_line,
            })
            continue
        if scene is not None and value.startswith("**"):
            plain = _unbold(value)
            if plain.startswith("场景：") or (plain.startswith("（") and plain.endswith("）")):
                scene["stageDirections"].append({
                    "beforeLine": len(scene["lines"]),
                    "text": plain,
                    "sourceLine": source_line,
                })
    if not scenes or any(not entry["lines"] for entry in scenes.values()):
        raise ValueError("Every scene must contain numbered story rows")
    counts = Counter(row["kind"] for entry in scenes.values() for row in entry["lines"])
    return {
        "revision": REVISION,
        "source": {"path": source_path, "sha256": hashlib.sha256(source_bytes).hexdigest()},
        "counts": {
            "scenes": len(scenes),
            "lines": len(ids),
            "kinds": dict(sorted(counts.items())),
            "stageDirections": sum(len(entry["stageDirections"]) for entry in scenes.values()),
        },
        "scenes": scenes,
    }


def render(data: dict) -> str:
    return json.dumps(data, ensure_ascii=False, indent=2) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=SOURCE_PATH)
    parser.add_argument("--output", type=Path, default=OUTPUT_PATH)
    parser.add_argument("--check", action="store_true", help="Verify the checked-in data without writing it.")
    args = parser.parse_args()
    source = args.source.resolve()
    try:
        source_label = source.relative_to(PROJECT_ROOT).as_posix()
    except ValueError:
        source_label = source.name
    data = parse_source(source.read_bytes(), source_label)
    expected = render(data)
    if args.check:
        if not args.output.is_file() or args.output.read_text(encoding="utf-8") != expected:
            raise SystemExit("Story data differs from the source. Run the importer without --check.")
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("w", encoding="utf-8", newline="\n") as stream:
            stream.write(expected)
    print(json.dumps({"ok": True, "checkOnly": args.check, **data["counts"]}, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
