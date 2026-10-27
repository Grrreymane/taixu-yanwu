"""Validate source fidelity and the easily lost epilogue/narrator branches."""

import hashlib
import importlib.util
import json
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("import_story", ROOT / "tools/story/import_story.py")
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)


class StorySourceImportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source_bytes = importer.SOURCE_PATH.read_bytes()
        cls.source_lines = cls.source_bytes.decode("utf-8-sig").splitlines()
        cls.data = json.loads(importer.OUTPUT_PATH.read_text(encoding="utf-8"))
        cls.scenes = cls.data["scenes"]

    def test_checked_in_data_is_reproducible(self):
        generated = importer.parse_source(self.source_bytes, self.data["source"]["path"])
        self.assertEqual(self.data, generated)
        self.assertEqual(self.data["source"]["sha256"], hashlib.sha256(self.source_bytes).hexdigest())

    def test_every_source_row_and_character_is_preserved(self):
        source_rows = {}
        for line in self.source_lines:
            match = re.match(r"^([A-J]\d{2}-(?:[PSMH])?\d{2})\s+(.+)$", line)
            if match:
                self.assertNotIn(match[1], source_rows)
                source_rows[match[1]] = match[2]
        rows = [row for scene in self.scenes.values() for row in scene["lines"]]
        self.assertEqual(len(self.scenes), 60)
        self.assertEqual(len(rows), 435)
        self.assertEqual({row["id"] for row in rows}, set(source_rows))
        for row in rows:
            with self.subTest(line=row["id"]):
                original = source_rows[row["id"]]
                reconstructed = "**" + row["text"] + "**" if row["kind"] == "narration" else row["displayName"] + "：" + row["text"]
                self.assertEqual(reconstructed, original)

    def test_shared_epilogue_halves_do_not_overwrite_each_other(self):
        self.assertEqual([row["id"] for row in self.scenes["I01"]["lines"]], [f"I01-{n:02d}" for n in range(1, 13)])
        self.assertEqual([row["id"] for row in self.scenes["I01_CONT"]["lines"]], [f"I01-{n:02d}" for n in range(13, 23)])
        for route in "PSMH":
            self.assertTrue(self.scenes[f"I01-{route}"]["lines"])
            self.assertTrue(all(row["id"].startswith(f"I01-{route}") for row in self.scenes[f"I01-{route}"]["lines"]))

    def test_memory_has_separate_speakers_and_thought(self):
        rows = {row["id"]: row for row in self.scenes["I02"]["lines"]}
        self.assertEqual(rows["I02-03"]["speaker"], "fuhua_thought")
        self.assertEqual(rows["I02-03"]["kind"], "thought")
        for line_id in ["I02-04", "I02-06", "I02-08"]:
            self.assertEqual(rows[line_id]["speaker"], "lixue")
            self.assertEqual(rows[line_id]["displayName"], "程立雪")
        for line_id in ["I02-05", "I02-07"]:
            self.assertEqual(rows[line_id]["kind"], "memory")
            self.assertEqual(rows[line_id]["displayName"], "符华（回忆）")

    def test_unnumbered_stage_directions_keep_their_positions(self):
        for scene in self.scenes.values():
            for direction in scene["stageDirections"]:
                with self.subTest(sourceLine=direction["sourceLine"]):
                    self.assertEqual("**" + direction["text"] + "**", self.source_lines[direction["sourceLine"] - 1].strip())
                    self.assertGreaterEqual(direction["beforeLine"], 0)
                    self.assertLessEqual(direction["beforeLine"], len(scene["lines"]))
        flashback = self.scenes["I02"]["stageDirections"]
        self.assertTrue(any(item["beforeLine"] == 3 and "程立雪" in item["text"] for item in flashback))
        self.assertTrue(any(item["beforeLine"] == 8 and "闪回很短" in item["text"] for item in flashback))
        self.assertTrue(any(item["beforeLine"] == 42 and "画面淡出" in item["text"] for item in flashback))

    def test_duplicate_ids_are_rejected(self):
        sample = "## 【A01｜测试】\nA01-01 符华：原句。\nA01-01 小识：第二句。\n"
        with self.assertRaisesRegex(ValueError, "Duplicate story row"):
            importer.parse_source(sample.encode("utf-8"), "sample.md")


if __name__ == "__main__":
    unittest.main()
