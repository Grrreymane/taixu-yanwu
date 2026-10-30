"""Enrich the existing particle catalog from local, read-only game exports.

Usage: python tools/prepare_native_effect_materials.py --source-root <exports>
No installation paths or original shader binaries are written to the catalog.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--source-root', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
dest = root / 'assets/vfx/remaining-native'
catalog = json.loads((dest / 'emitters.json').read_text(encoding='utf8'))
meshes = json.loads((dest / 'meshes.json').read_text(encoding='utf8'))
for code, material_dir, groups in [
    ('fk', 'original', ['fog_charge', 'fog_impact', 'fog_strike', 'fog_follow']),
    ('c2', 'original-full', ['blood_impact', 'blood_follow','shadow_impact','shadow_follow']),
    ('fk-artifact', 'original', ['fog_release']),
]:
    source = args.source_root / (code + '-native-vfx')
    materials = {m['name']: m for m in json.loads((source / material_dir / 'materials.json').read_text(encoding='utf8'))}
    geometry = json.loads((source / 'geometry/geometry.json').read_text(encoding='utf8'))
    for mesh in geometry:
        key = mesh['name'] + '_' + mesh['pathId']
        if key not in meshes:
            continue
        data = mesh['details']
        for field in ['colors', 'normals']:
            if data.get(field):
                meshes[key][field] = data[field]
    for group in groups:
        for row in catalog.get(group, []):
            material = materials[row['material']]
            shader_id = material['shader']['pathId']
            candidates = [source / 'shader-reference/shaders' / shader_id / 'source.bin', args.source_root / 'c5-native-vfx/original/shaders' / shader_id / 'source.bin', args.source_root / 'fk-native-vfx/shader-reference/shaders' / shader_id / 'source.bin']
            raw = next((p.read_bytes() for p in candidates if p.exists()), b'')
            names = [s.decode() for s in re.findall(rb'[ -~]{8,200}', raw) if s.startswith((b'miHoYo/', b'Particles/', b'Mobile/Particles/'))]
            name = names[-1] if names else ''
            # These are source shader families, not guesses from texture names.
            row['sourceShader'] = {'id': shader_id, 'name': name, 'sha256': hashlib.sha256(raw).hexdigest() if raw else ''}
            row['channelMix'] = 'Channel_Mix' in name or 'Channel Mix' in name
            row['blend'] = 'add' if 'Additive' in name or row['channelMix'] else 'alpha'
            row['propMesh'] = 'Prop_Outline' in name
            if not name:
                raise RuntimeError('Missing source shader: ' + row['material'] + ' / ' + shader_id)
(dest / 'emitters.json').write_text(json.dumps(catalog, ensure_ascii=False, separators=(',', ':')), encoding='utf8')
(dest / 'meshes.json').write_text(json.dumps(meshes, separators=(',', ':')), encoding='utf8')
print('Enriched', sum(map(len, catalog.values())), 'emitters and', len(meshes), 'meshes')
