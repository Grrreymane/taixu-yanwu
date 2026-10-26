"""Original procedural combat Foley. No game audio is sampled; standard Python only."""
import json
import math
import random
import struct
import wave
from pathlib import Path
RATE = 44100
OUT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
DURATIONS = {'swing': .125, 'swing_heavy': .185, 'hit': .145, 'hit_alt': .130,
             'kick': .190, 'heavy': .285, 'block': .130, 'block_heavy': .195,
             'parry': .235, 'ultimate': 1.05}
LAYERS = {
    'swing': 'Short cloth/air swell; no impact transient or bass tail',
    'swing_heavy': 'Broader air swell, still quieter than contact',
    'hit': 'Dry leather transient + short body impulse + filtered friction',
    'hit_alt': 'Brighter palm/smack transient, shorter recovery than first punch',
    'kick': 'Lower body impulse and wider contact transient than a punch',
    'heavy': 'Immediate crack + textured low body impulse; shortened tonal tail',
    'block': 'Damped forearm knock and short cloth friction',
    'block_heavy': 'Heavier guard knock with additional low body layer',
    'parry': 'Immediate catch knock + delayed inharmonic release, not a UI chime',
    'ultimate': 'Unchanged previous cinematic cue',
}

def legacy_make(name, duration):
    rng = random.Random(3109 if name == 'ultimate' else 3103)
    low = mid = top = 0.0
    samples = []
    for n in range(round(RATE * duration)):
        t = n / RATE
        noise = rng.uniform(-1.0, 1.0)
        low += (1 - math.exp(-math.tau * 260 / RATE)) * (noise - low)
        mid += (1 - math.exp(-math.tau * 1350 / RATE)) * (noise - mid)
        top += (1 - math.exp(-math.tau * 5200 / RATE)) * (noise - top)
        air = top - mid
        paper = mid - low
        attack = 1 - math.exp(-t / .0013)
        if name in ('swing', 'swing_heavy'):
            center = .064 if name == 'swing' else .101
            width = .030 if name == 'swing' else .047
            swell = math.exp(-.5 * ((t - center) / width) ** 2)
            signal = swell * (paper * 1.35 + air * .36 + low * .25)
            signal += math.sin(math.tau * (180*t - 155*t*t)) * .025 * swell
        elif name == 'hit':
            body = math.sin(math.tau * (105*t + 80*.022*(1-math.exp(-t/.022))))
            signal = .69*body*math.exp(-t/.054)
            signal += .95*paper*math.exp(-t/.034) + .43*air*math.exp(-t/.009)
            signal += .17*math.sin(math.tau*348*t)*math.exp(-t/.022)
        elif name == 'heavy':
            body = math.sin(math.tau * (52*t + 90*.025*(1-math.exp(-t/.025))))
            signal = .79*body*math.exp(-t/.105)
            signal += .31*math.sin(math.tau*137*t)*math.exp(-t/.053)
            signal += 1.0*paper*math.exp(-t/.051) + .35*air*math.exp(-t/.012)
            signal += .48*low*math.exp(-t/.13)
        elif name == 'block':
            # Hollow forearm/guard knock, without the landed punch's bass tail.
            signal = .42*math.sin(math.tau*238*t)*math.exp(-t/.035)
            signal += .28*math.sin(math.tau*431*t)*math.exp(-t/.049)
            signal += .13*math.sin(math.tau*693*t)*math.exp(-t/.024)
            signal += .9*paper*math.exp(-t/.020) + .25*low*math.exp(-t/.043)
        elif name == 'parry':
            # Bounded metallic catch: inharmonic partials and a short tail.
            signal = sum(amp*math.sin(math.tau*freq*t)*math.exp(-t/tail)
                         for freq,amp,tail in [(835,.36,.070),(1417,.23,.090),
                                              (2173,.13,.045),(3289,.055,.024)])
            signal += .30*paper*math.exp(-t/.009) + .12*air*math.exp(-t/.006)
        else:
            signal = .43*math.sin(math.tau*(56*t+38*t*t))*math.exp(-t/.36)
            signal += .16*math.sin(math.tau*112*t)*math.exp(-t/.27)
            signal += (paper*.55 + air*.12)*math.exp(-t/.20)
        tail = min(1.0, max(0.0, (duration-t)/.018))
        samples.append(math.tanh(signal * 1.2) * attack * tail)
    mean = sum(samples) / len(samples)
    samples = [x - mean for x in samples]
    peak = max(abs(x) for x in samples)
    samples = [x * .76 / peak for x in samples]
    samples[0] = samples[-1] = 0.0
    return samples

def make(name, duration):
    if name == 'ultimate':
        return legacy_make(name, duration)
    rng = random.Random(91031 + list(DURATIONS).index(name))
    low = mid = top = dc = 0.0
    samples = []
    def impulse(t, base, drop, glide, tail):
        return math.sin(math.tau*(base*t+drop*glide*(1-math.exp(-t/glide))))*math.exp(-t/tail)
    for n in range(round(RATE*duration)):
        t = n/RATE
        noise = rng.uniform(-1,1)
        low += (1-math.exp(-math.tau*230/RATE))*(noise-low)
        mid += (1-math.exp(-math.tau*1650/RATE))*(noise-mid)
        top += (1-math.exp(-math.tau*7800/RATE))*(noise-top)
        leather = mid-low
        crack = top-mid
        if name in ('swing','swing_heavy'):
            center,width = (.038,.022) if name=='swing' else (.067,.032)
            swell = math.exp(-.5*((t-center)/width)**2)
            signal = swell*(leather*.9+crack*.55+low*.12)
        elif name=='hit':
            signal = .40*impulse(t,91,105,.013,.026)
            signal += 1.7*leather*math.exp(-t/.016) + .70*crack*math.exp(-t/.0038)
            signal += .13*impulse(t,280,38,.005,.012)
        elif name=='hit_alt':
            signal = .27*impulse(t,129,150,.009,.019)
            signal += 2.0*leather*math.exp(-t/.013) + 1.0*crack*math.exp(-t/.005)
            signal += .14*impulse(t,405,100,.006,.010)
        elif name=='kick':
            signal = .54*impulse(t,73,130,.017,.041)
            signal += 1.25*leather*math.exp(-t/.022) + .75*crack*math.exp(-t/.0045)
            signal += .24*low*math.exp(-t/.045)
        elif name=='heavy':
            signal = .65*impulse(t,53,119,.016,.061)
            signal += .17*impulse(t,137,33,.011,.024)
            signal += 1.35*leather*math.exp(-t/.023) + .80*crack*math.exp(-t/.004)
            signal += 1.15*low*math.exp(-t/.052)
        elif name in ('block','block_heavy'):
            strong = name=='block_heavy'
            signal = .34*impulse(t,170 if strong else 214,42,.008,.024 if strong else .015)
            signal += .18*impulse(t,390,80,.007,.011)
            signal += 1.65*leather*math.exp(-t/(.018 if strong else .011))
            signal += .34*crack*math.exp(-t/.004)
            if strong: signal += .25*impulse(t,90,55,.008,.029)
        else: # Perfect parry: catch is immediate; the short bright release follows it.
            signal = .32*impulse(t,237,50,.007,.012)
            signal += 1.25*leather*math.exp(-t/.008)+.58*crack*math.exp(-t/.0025)
            metal_t = max(0,t-.003)
            metal_attack = 1-math.exp(-metal_t/.0018)
            signal += metal_attack*sum(amp*math.sin(math.tau*freq*metal_t)*math.exp(-metal_t/tail)
                for freq,amp,tail in [(619,.10,.023),(1547,.19,.052),(2473,.08,.034),(3811,.028,.017)])
        attack = 1-math.exp(-t/(.00038 if name not in ('swing','swing_heavy') else .0015))
        release = min(1,max(0,(duration-t)/.012))
        signal = math.tanh(signal*1.15)*attack*release
        # Causal 24 Hz DC blocker; keep the bass impulse without an offset click.
        dc += (1-math.exp(-math.tau*24/RATE))*(signal-dc)
        samples.append((signal-dc)*release)
    mean=sum(samples)/len(samples)
    samples=[x-mean for x in samples]
    gain=.74/max(abs(x) for x in samples)
    samples=[x*gain for x in samples]
    samples[0]=samples[-1]=0.0
    return samples

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    report = {'source': 'Original procedural synthesis, not extracted game audio',
              'version': 2, 'sampleRate': RATE, 'sounds': {},
              'import': 'Short combat clips use uncompressed PCM with no trimming, normalization or looping; existing ultimate import is unchanged.',
              'routing': 'Only actual hit/block/parry events select contact sounds; attack cues select air only. Stance and combo distinguish light contacts.',
              'voicePolicy': '8 voices; free voice first, then oldest lowest priority. Air cannot replace a contact or parry. Deterministic small pitch variation; parry/ultimate pitch is fixed.'}
    for name,duration in DURATIONS.items():
        samples = make(name,duration)
        pcm = [round(x * 32767) for x in samples]
        with wave.open(str(OUT / (name+'.wav')), 'wb') as target:
            target.setnchannels(1)
            target.setsampwidth(2)
            target.setframerate(RATE)
            target.writeframes(struct.pack('<'+'h'*len(pcm),*pcm))
        rms = math.sqrt(sum(x*x for x in samples) / len(samples))
        report['sounds'][name] = {'seconds': len(samples)/RATE,
                                  'layers': LAYERS[name],
                                  'peak': max(abs(x) for x in samples),
                                  'rmsDbFS': round(20*math.log10(rms),2),
                                  'clippedSamples': sum(abs(x)>=32767 for x in pcm)}
    (OUT/'synthesis-report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print(json.dumps(report,indent=2))
if __name__ == '__main__':
    main()
