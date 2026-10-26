"""Check delivered WAV headroom and the intended bass/air contrast."""
import hashlib,json,math,struct,wave
from pathlib import Path
folder=Path(__file__).resolve().parents[1]/'assets'/'audio'
ratios={}
metrics={}
names=['swing','swing_heavy','hit','hit_alt','kick','heavy','block','block_heavy','parry','ultimate']
for name in names:
    with wave.open(str(folder/(name+'.wav')),'rb') as sound:
        assert sound.getnchannels()==1 and sound.getsampwidth()==2
        rate=sound.getframerate()
        pcm=struct.unpack('<'+'h'*sound.getnframes(),sound.readframes(sound.getnframes()))
    x=[v/32768 for v in pcm]
    assert max(abs(v) for v in pcm)<30000, name+' lacks clipping headroom'
    assert pcm[0]==0 and pcm[-1]==0, name+' has a discontinuous file boundary'
    assert abs(sum(x)/len(x))<.001, name+' has excessive DC offset'
    low=0.;low_energy=0.;total=sum(v*v for v in x)
    coefficient=1-math.exp(-math.tau*250/rate)
    for value in x:
        low+=coefficient*(value-low)
        low_energy+=low*low
    ratios[name]=low_energy/total
    first_contact=next((i/rate for i,value in enumerate(x) if abs(value)>.02),len(x)/rate)
    peak_time=max(range(len(x)),key=lambda i:abs(x[i]))/rate
    early_energy=sum(value*value for value in x[:round(rate*.045)])/total
    metrics[name]={'duration':len(x)/rate,'lowFrequencyRatio':round(ratios[name],4),
                   'audibleOnsetMs':round(first_contact*1000,2),'peakMs':round(peak_time*1000,2),
                   'first45msEnergy':round(early_energy,4),'sha256':hashlib.sha256((folder/(name+'.wav')).read_bytes()).hexdigest()}
    if name not in ['swing','swing_heavy','ultimate']:
        assert first_contact<.002,name+' has a delayed impact onset'
        assert peak_time<.025,name+' lacks an early contact peak'
        assert early_energy>.58,name+' smears most energy into its tail'
assert ratios['heavy']>ratios['hit']>ratios['block']>ratios['parry']
assert ratios['heavy']>ratios['swing']*3
assert ratios['kick']>ratios['hit']>ratios['hit_alt']
assert ratios['block_heavy']>ratios['block']
assert len({metrics[name]['sha256'] for name in names})==len(names)
backup=folder.parents[1]/'build/backups/feedback-20261018-impact/audio/ultimate.wav'
if backup.exists():
    assert hashlib.sha256(backup.read_bytes()).hexdigest()==metrics['ultimate']['sha256'],'cinematic sound changed'
report_path=folder.parents[1]/'build/reports/feedback-audio-check.json'
report_path.parent.mkdir(parents=True,exist_ok=True)
report_path.write_text(json.dumps({'passed':True,'sounds':metrics,'limitation':'Signal/routing verification; final loudness and timbre need listening in the real game.'},indent=2),encoding='utf8')
print('PASS: 10 WAV headers, peak headroom, endpoints, DC, immediate contacts, transient energy and distinct low-frequency profiles')
print({k:round(v,3) for k,v in ratios.items()})
