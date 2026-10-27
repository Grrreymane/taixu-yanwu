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
        self.assertEqual(len(rows), 367)
        self.assertEqual({row["id"] for row in rows}, set(source_rows))
        for row in rows:
            with self.subTest(line=row["id"]):
                original = source_rows[row["id"]]
                reconstructed = "**" + row["text"] + "**" if row["kind"] == "narration" else row["displayName"] + "：" + row["text"]
                self.assertEqual(reconstructed, original)

    def test_shared_epilogue_halves_do_not_overwrite_each_other(self):
        self.assertEqual([row["id"] for row in self.scenes["I01"]["lines"]], [f"I01-{n:02d}" for n in range(1, 13)])
        self.assertEqual([row["id"] for row in self.scenes["I01_CONT"]["lines"]], [f"I01-{n:02d}" for n in range(13, 20)])
        for route in "PSMH":
            self.assertTrue(self.scenes[f"I01-{route}"]["lines"])
            self.assertTrue(all(row["id"].startswith(f"I01-{route}") for row in self.scenes[f"I01-{route}"]["lines"]))

    def test_revised_memory_has_correct_speaker_and_returns_to_conversation(self):
        rows = {row["id"]: row for row in self.scenes["I02"]["lines"]}
        self.assertEqual(rows["I02-02"]["speaker"], "lixue")
        self.assertEqual(rows["I02-02"]["kind"], "memory")
        self.assertEqual(rows["I02-02"]["displayName"], "程立雪（回忆）")
        self.assertEqual(rows["I02-03"]["speaker"], "senti")
        self.assertEqual(rows["I02-03"]["kind"], "dialogue")
        self.assertEqual(len(rows), 27)

    def test_unnumbered_stage_directions_keep_their_positions(self):
        for scene in self.scenes.values():
            for direction in scene["stageDirections"]:
                with self.subTest(sourceLine=direction["sourceLine"]):
                    self.assertEqual("*" + direction["text"] + "*", self.source_lines[direction["sourceLine"] - 1].strip())
                    self.assertGreaterEqual(direction["beforeLine"], 0)
                    self.assertLessEqual(direction["beforeLine"], len(scene["lines"]))
                    preceding = sum(row["sourceLine"] < direction["sourceLine"] for row in scene["lines"])
                    self.assertEqual(direction["beforeLine"], preceding)
        self.assertEqual(sum(len(scene["stageDirections"]) for scene in self.scenes.values()), 34)
        flashback = self.scenes["I02"]["stageDirections"]
        self.assertTrue(any(item["beforeLine"] == 1 and item["text"].startswith("短暂闪回") for item in flashback))
        self.assertTrue(any(item["beforeLine"] == 2 and item["text"].startswith("回到现实") for item in flashback))
        self.assertTrue(any(item["beforeLine"] == 27 and "淡出" in item["text"] for item in flashback))
        self.assertEqual([item["sourceLine"] for item in flashback], sorted(item["sourceLine"] for item in flashback))

    def test_editorial_notes_and_preamble_stay_out_of_the_game(self):
        body = json.dumps(self.scenes, ensure_ascii=False)
        self.assertNotIn("若与 E 段相连", body)
        self.assertNotIn("此组是选卡后的短对白", body)
        self.assertNotIn("演出与文本校对备注", body)
        sample = "## 编辑说明\n*外部备注。*\n## 【A01｜测试】\n*人物坐下。*\nA01-01 符华：原句。\n**（旧格式兼容。）**\n"
        parsed = importer.parse_source(sample.encode("utf-8"), "sample.md")
        directions = parsed["scenes"]["A01"]["stageDirections"]
        self.assertEqual([(d["beforeLine"], d["text"]) for d in directions], [(0, "人物坐下。"), (1, "（旧格式兼容。）")])

    def test_duplicate_ids_are_rejected(self):
        sample = "## 【A01｜测试】\nA01-01 符华：原句。\nA01-01 小识：第二句。\n"
        with self.assertRaisesRegex(ValueError, "Duplicate story row"):
            importer.parse_source(sample.encode("utf-8"), "sample.md")


if __name__ == "__main__":
    unittest.main()
