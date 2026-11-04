"""Rebuild the small web UI subset from the existing, attributed in-game font.

Needs fontTools[woff]; never changes the full native font.
"""
from pathlib import Path
import hashlib
import json
from fontTools import subset
from fontTools.ttLib import TTFont

root=Path(__file__).resolve().parents[2]
inputs=['web-shell.html','web/choices.js','scripts/armor_paths.gd','scripts/night_paths.gd','scripts/campaign.gd','scripts/reward_builds.gd','scripts/fighter_roster.gd']
text=''.join((root/p).read_text(encoding='utf-8') for p in inputs)
points=set(range(32,127))|{ord(c) for c in text if ord(c)>127}
source=root/'assets/fonts/hi3-sdk-zh-cn.ttf'
font=TTFont(source)
missing=sorted(points-set(font.getBestCmap()))
if missing:raise SystemExit('Missing source glyphs: '+repr(''.join(map(chr,missing))))
options=subset.Options();options.flavor='woff2';options.desubroutinize=True
subsetter=subset.Subsetter(options=options);subsetter.populate(unicodes=points);subsetter.subset(font)
font.flavor='woff2';output=root/'assets/fonts/loading-ui.woff2';font.save(output)
meta=root/'assets/fonts/loading-ui-source.json'
record=json.loads(meta.read_text(encoding='utf-8'))
record.update(purpose='Web loading and choice UI subset; complete in-game font unchanged.',
 selectionRule='Printable ASCII and all non-ASCII codepoints in listed source files.',inputFiles=inputs,
 requestedCodepointCount=len(points),subsetCodepointCount=len(font.getBestCmap()),missingCodepoints=[],
 nonAsciiCharacters=''.join(chr(x) for x in sorted(points) if x>127),
 outputSha256=hashlib.sha256(output.read_bytes()).hexdigest(),outputBytes=output.stat().st_size,
 rebuildNote='Run tools/publishing/subset-choice-font.py after choice or shell copy changes.')
with meta.open('w',encoding='utf-8',newline='\n') as f:json.dump(record,f,ensure_ascii=False,indent=2);f.write('\n')
print('Choice font:',output.stat().st_size,'bytes;',len(points),'codepoints')
