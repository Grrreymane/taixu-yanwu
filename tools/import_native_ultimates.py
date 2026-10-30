"""Rebuild native ultimate catalogs from local exports; game installs are read-only."""
import argparse,os,json,struct,hashlib,shutil,re
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('--source-root',type=Path,required=True)
parser.add_argument('--suit',choices=['fog','shadow'],default='fog')
args=parser.parse_args()
r=args.source_root.resolve()/('fk-artifact-native-vfx' if args.suit=='fog' else 'c2-native-vfx')
material_dir='original' if args.suit=='fog' else 'original-full'
prefixes={'fog_release':'Avatar_Fuka_FK_AF01_Ultra/'} if args.suit=='fog' else {'shadow_impact':'Avatar_Fuka_NL_Attack_UltraThunder/','shadow_follow':'Avatar_Fuka_NL_Ultra_Follow/'}
os.chdir(Path(__file__).resolve().parents[1])
dest=Path('assets/vfx/remaining-native')
def read(path):return json.loads(path.read_text(encoding='utf8'))
initial=read(r/'structure/particle-initial-validated.json');modules={x['pathId']:x['data'] for x in read(r/'structure/particle-through-velocity-validated.json')}
objects={(x['cab'].lower(),int(x['pathId'])):x for x in read(r/'structure/structure.json')};files={x['cab'].lower():x for x in read(r/'structure/serialized-files.json')}
links={x['node']:x for x in read(r/'structure/renderer-material-links.json')};materials={m['name']:m for m in read(r/material_dir/'materials.json')};textures={x['name']:x for x in read(r/material_dir/'textures.json')}
meshes={(x['cab'].lower(),int(x['pathId'])):x for x in read(r/'geometry/geometry.json') if x['kind']=='Mesh'}
catalog=read(dest/'emitters.json');meshout=read(dest/'meshes.json');groups={key:[] for key in prefixes}
def copy_texture(slot):
 t=textures[slot['texture']['name']];raw=Path(t['files'][0]['path']).read_bytes();sha=hashlib.sha256(raw).hexdigest();path=dest/(('af01_' if args.suit=='fog' else 'nl_')+sha[:12]+'.png');path.write_bytes(raw);return 'res://'+path.as_posix(),sha
for x in initial:
 group=next((key for key,prefix in prefixes.items() if x['node'].startswith(prefix)),None)
 if not group:continue
 material=next((materials[m['material']] for m in x['materials'] if any(s['slot'] in ['_MainTex','_MainSmokeTexture'] and s['texture'] for s in materials[m['material']]['textureSlots'])),None)
 if not material:continue
 main=next(s for s in material['textureSlots'] if s['slot'] in ['_MainTex','_MainSmokeTexture'] and s['texture'])
 texture,sha=copy_texture(main)
 d=modules[x['particlePathId']];l=links[x['node']];ob=objects[(l['cab'].lower(),int(l['rendererPathId']))];b=(r/'structure'/ob['rawFile']).read_bytes();ext=files[ob['cab'].lower()]['externals'];mc=struct.unpack_from('<i',b,64)[0];o=120+12*mc
 mode=struct.unpack_from('<H',b,o)[0];assert mode in range(5)
 renderer={'mode':mode,'alignment':struct.unpack_from('<i',b,o+32)[0],'lengthScale':struct.unpack_from('<f',b,o+20)[0],'velocityScale':struct.unpack_from('<f',b,o+16)[0],'meshes':[]}
 if mode==4:
  for i in range(len(b)-68,len(b)-20,12):
   f,pid=struct.unpack_from('<iq',b,i);cab=ob['cab'].lower() if f==0 else ext[f-1]['fileName'].lower() if 0<f<=len(ext) else '?';m=meshes.get((cab,pid))
   if m:
    key=m['name']+'_'+m['pathId'];renderer['meshes'].append(key);detail=m['details'];meshout[key]={'name':m['name'],'sha256':m['rawSHA256'],**{k:detail[k] for k in ['vertices','uv0','indices','colors','normals'] if detail.get(k)}}
  if not renderer['meshes']:renderer['builtinPlane']=True
 go=objects[(l['cab'].lower(),int(l['gameObjectPathId']))];tr=go['fields']['m_Transform'];chain=[]
 while tr:
  chain.append({'position':tr['m_LocalPosition'],'rotation':tr['m_LocalRotation'],'scale':tr['m_LocalScale']})
  parent=objects.get((l['cab'].lower(),int(tr['m_Father']['pathId'])));tr=parent['fields'] if parent and parent['type']=='Transform' else None
 floats={p['Key']:p['Value'] for p in material['savedProperties']['m_Floats']};colors={p['Key']:p['Value'] for p in material['savedProperties']['m_Colors']}
 pid=material['shader']['pathId'];candidates=[r/'shader-reference/shaders'/pid/'source.bin',args.source_root/'c5-native-vfx/original/shaders'/pid/'source.bin',args.source_root/'fk-native-vfx/shader-reference/shaders'/pid/'source.bin'];raw=next(p.read_bytes() for p in candidates if p.exists());names=[s.decode() for s in re.findall(rb'[ -~]{8,200}',raw) if s.startswith((b'miHoYo/',b'Mobile/Particles/',b'Particles/'))];name=names[-1] if names else pid
 channel_mix='Channel_Mix' in name or 'Channel Mix' in name
 row={'node':x['node'],'prefab':x['prefab'],'texture':texture,'sha256':sha,'material':material['name'],'emissionScale':floats.get('_EmissionScaler',floats.get('_SmokeBrightness',1)),'tint':colors.get('_TintColor',{'R':1,'G':1,'B':1,'A':1}),'data':d,'renderer':renderer,'transforms':list(reversed(chain)),'textureST':[main['scale']['X'],main['scale']['Y'],main['offset']['X'],main['offset']['Y']],'materialColors':colors,'materialFloats':floats,'sourceShader':{'id':pid,'name':name,'sha256':hashlib.sha256(raw).hexdigest()},'blend':'add' if 'Additive' in name or channel_mix else 'alpha','channelMix':channel_mix,'propMesh':False}
 for slot in material['textureSlots']:
  if slot['slot']=='_MaskTex' and floats.get('_UseMaskTex',0)>0 and slot['texture']:
   row['maskTexture']=copy_texture(slot)[0]
  if slot['slot']=='_DisTexture' and 'DLCSmoke' in name and slot['texture']:
   row['smokeTexture']=copy_texture(slot)[0]
   row['smokeST']=[slot['scale']['X'],slot['scale']['Y'],slot['offset']['X'],slot['offset']['Y']]
 groups[group].append(row)
 print(x['node'].split('/')[-1],renderer['mode'],renderer['meshes'],name)
# AF01 is the augmented suit. The previous FK groups belong to base Valkyrie
# Accipiter, including an unrelated QYHY costume follow effect.
for key in list(catalog):
 if key.startswith(args.suit+'_'):del catalog[key]
catalog.update(groups)
used={key for rows in catalog.values() for row in rows for key in row['renderer']['meshes']}
meshout={key:mesh for key,mesh in meshout.items() if key in used}
(dest/'emitters.json').write_text(json.dumps(catalog,ensure_ascii=False,separators=(',',':')),encoding='utf8');(dest/'meshes.json').write_text(json.dumps(meshout,separators=(',',':')),encoding='utf8')
print({key:len(rows) for key,rows in groups.items()},'total meshes',len(meshout))
