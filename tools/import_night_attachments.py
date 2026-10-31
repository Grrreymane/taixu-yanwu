"""Preserve ND emitter attachment transforms from the local, read-only export."""
import argparse
import json
import re
import hashlib
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--source-root', type=Path, required=True)
args = parser.parse_args()
source = args.source_root / 'c3-native-vfx/structure'
assets = Path(__file__).resolve().parents[1] / 'assets/vfx/native-burst'
read = lambda p: json.loads(p.read_text(encoding='utf8'))
objects = {(x['cab'].lower(), str(x['pathId'])): x for x in read(source / 'structure.json')}
transforms = {}
materials = {row['name']: row for row in read(source.parent / 'original/materials.json')}
particle_materials = {}
for row in read(source / 'particle-initial-validated.json'):
    if row['node'].split('/')[0] not in ['Avatar_Fuka_ND_Ultra_Follow', 'Avatar_Fuka_ND_Ultra_CostSP']:
        continue
    go = objects[(row['cab'].lower(), str(row['data']['m_GameObject']['m_PathID']))]
    tr = go['fields']['m_Transform']
    transforms[row['node']] = {key: {axis.lower(): value for axis, value in tr['m_Local' + key.capitalize()].items()} for key in ['position', 'rotation', 'scale']}
    if not row['materials']:
        continue
    material = materials[row['materials'][0]['material']]
    props = material['savedProperties']
    floats = {p['Key']: p['Value'] for p in props['m_Floats']}
    colors = {p['Key']: p['Value'] for p in props['m_Colors']}
    main = next((slot for slot in material['textureSlots'] if slot['slot'] == '_MainTex'), None)
    shader_path = args.source_root / 'fk-native-vfx/shader-reference/shaders' / material['shader']['pathId'] / 'source.bin'
    if not main or not shader_path.exists():
        continue
    raw = shader_path.read_bytes()
    names = [s.decode() for s in re.findall(rb'[ -~]{8,200}', raw) if s.startswith(b'miHoYo/')]
    name = names[-1] if names else ''
    particle_materials[row['node']] = {'gain': floats.get('_EmissionScaler', 1), 'tint': colors.get('_TintColor', {'R': .5, 'G': .5, 'B': .5, 'A': .5}), 'additive': 'Additive' in name, 'textureST': [main['scale']['X'],main['scale']['Y'],main['offset']['X'],main['offset']['Y']], 'sourceShader': {'name': name, 'sha256': hashlib.sha256(raw).hexdigest()}}
for filename in ['source-emitters.json']:
    data = read(assets / filename)
    rows = data if isinstance(data, list) else data['night_squire']
    for row in rows:
        row.update(transforms[row['node']])
        row['material'] = particle_materials[row['node']]
    (assets / filename).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
print('Imported native ND activation / follow transforms')
