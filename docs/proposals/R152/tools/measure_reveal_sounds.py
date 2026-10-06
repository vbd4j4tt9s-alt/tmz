"""R152: loudness of the owner's 17 pull-reveal uploads (RarePullSounds), measured from the files the owner uploaded.
Usage: python3 measure_reveal_sounds.py <dir with the owner's .mp3 uploads> [out.luau]
For every slot: the momentary loudness (ITU-R BS.1770 K-weighting, 400 ms window, LUFS) every 50 ms of the file, its maximum inside the
part the game plays (Start .. end, or the PlaybackRegion) and the sample peak (dBFS) there. Writes a Luau table (tests/sound_levels.luau)
that the R152 suite uses to add up what is really heard at every frame of every reveal (gain = Sound.Volume x Effects group, in dB)."""
import sys, os, glob, json, math, subprocess
import numpy as np

# slot -> (file name part, the asset id in RarePullSounds)
FILES = {
 'Riser': ('popular-riser-metallic', 126242461105018), 'SuckIn': ('backwards-whoosh', 115669680103388),
 'Impact': ('cinematic-impact-hit', 133616032782359), 'GroundImpact': ('ground-impact', 130581466623902),
 'TitleSlam': ('punch-impact-hit', 100663216159686), 'Sparkle': ('shimmering-object', 103090716252123),
 'PackShake': ('pill-shake', 104885054288395), 'PackBurst': ('splat2ogg', 120422004598250),
 'KingChoir': ('angel-choir', 71607900050825), 'KingFanfare': ('medieval-fanfare', 77199097157197),
 'KingBell': ('single-church-bell', 110440649150958), 'CosmicPad': ('leap-motiv', 120548831466483),
 'CosmicWhoosh': ('deep-strange-whoosh', 119158277815268), 'CosmicBoom': ('large-underwater-explosion', 75435110351652),
 'CosmicStar': ('shine-1', 100732233406279), 'SecretGlitch': ('glitch-sound-effect-hd', 84688488729958),
 'SecretVault': ('heavy-door-unlocking', 102739931931289),
}
RATE = 48000; STEP = .05

def decode(path):
    raw = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', path, '-f', 'f32le', '-ac', '2', '-ar', str(RATE), '-'], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype='<f4').reshape(-1, 2).astype(np.float64)

def biquad(x, b, a):
    y = np.zeros_like(x); x1 = x2 = y1 = y2 = 0.0
    b0, b1, b2 = b; a1, a2 = a[1], a[2]
    for i in range(len(x)):
        xi = x[i]; yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, xi, y1, yi; y[i] = yi
    return y

# BS.1770 K-weighting at 48 kHz: high shelf (stage 1) and high pass (stage 2)
SHELF = ((1.53512485958697, -2.69169618940638, 1.19839281085285), (1.0, -1.69065929318241, 0.73248077421585))
HIPASS = ((1.0, -2.0, 1.0), (1.0, -1.99004745483398, 0.99007225036621))

def kweight(ch):
    return biquad(biquad(ch, *SHELF), *HIPASS)

def measure(path):
    pcm = decode(path)
    k = np.stack([kweight(pcm[:, 0]), kweight(pcm[:, 1])], axis=1)
    sq = (k ** 2).sum(axis=1)
    cs = np.concatenate([[0.0], np.cumsum(sq)])
    n = len(sq); dur = n / RATE; half = int(.2 * RATE)
    env = []; peaks = []
    t = 0.0
    while t <= dur + 1e-9:
        c = int(t * RATE); lo = max(0, c - half); hi = min(n, c + half)
        ms = (cs[hi] - cs[lo]) / (2 * half)  # silence outside the file counts as silence
        env.append(round(-0.691 + 10 * math.log10(ms) if ms > 1e-12 else -99.0, 2))
        a0 = max(0, c - int(.025 * RATE)); a1 = min(n, c + int(.025 * RATE))
        pk = float(np.abs(pcm[a0:a1]).max()) if a1 > a0 else 0.0
        peaks.append(round(20 * math.log10(pk) if pk > 1e-9 else -99.0, 1))
        t += STEP
    # the audible hit: a 20 ms window every 5 ms; Onset = first moment within 35 dB of the loudest 20 ms of the first 2.5 s,
    # Hit = first moment within 6 dB of it (where a hit / punch / clunk is heard: what has to land on the picture's beat)
    w = int(.02 * RATE); step = int(.005 * RATE)
    lev = np.array([10 * math.log10(max(1e-12, (cs[min(n, i + w)] - cs[i]) / w)) for i in range(0, n, step)])
    tt = np.arange(len(lev)) * .005; top = lev[tt < 2.5].max()
    onset = float(tt[np.argmax(lev > top - 35)]); hit = float(tt[np.argmax(lev > top - 6)])
    peak = float(tt[np.argmax(np.where(tt < 2.5, lev, -1e9))])  # the loudest 20 ms of the first 2.5 s (a whoosh's swell)
    return pcm, env, dur, onset, hit, peak, peaks

def main():
    folder = sys.argv[1]; out = sys.argv[2] if len(sys.argv) > 2 else None
    here = os.path.dirname(os.path.abspath(__file__))
    slots_src = open(os.path.join(here, '../../../../src/ReplicatedStorage/RarePullSounds.lua'), encoding='utf-8').read()
    rows = {}
    for slot, (part, aid) in FILES.items():
        hits = sorted(glob.glob(os.path.join(folder, '*%s*.mp3' % part)))
        assert hits, 'no upload for %s (%s)' % (slot, part)
        assert str(aid) in slots_src, '%s: asset %d is not in RarePullSounds' % (slot, aid)
        pcm, env, dur, onset, hit, peak, peaks = measure(hits[0])
        rows[slot] = {'File': os.path.basename(hits[0]).split('-', 1)[1], 'Id': aid, 'Duration': round(dur, 3), 'Env': env, 'Peaks': peaks,
                      'Peak': round(20 * math.log10(max(1e-9, float(np.abs(pcm).max()))), 2), 'Onset': round(onset, 3), 'Hit': round(hit, 3), 'Swell': round(peak, 3)}
        print('%-13s %6.2f s  peak %6.1f dBFS  M max %6.1f LUFS  onset %.3f  hit %.3f  swell %.3f  %s' % (slot, dur, rows[slot]['Peak'], max(env), onset, hit, peak, rows[slot]['File']))
    if out:
        lines = ['--!nocheck', '-- R152: momentary loudness (LUFS, BS.1770, 400 ms) every %.2f s of each owner upload; Peak = sample peak (dBFS);' % STEP,
                 '-- Onset / Hit = seconds into the file where it starts / where its hit is heard (20 ms windows: 35 / 6 dB under its loudest moment);',
                 '-- Swell = its loudest 20 ms (the top of a whoosh); Peaks = the sample peak (dBFS) within 25 ms of each Env point.',
                 '-- Generated by docs/proposals/R152/tools/measure_reveal_sounds.py from the owner\'s files; do not edit by hand.', 'return {Step=%.2f,Slots={' % STEP]
        for slot, r in rows.items():
            lines.append(' %s={File=%s,Id=%d,Duration=%.3f,Peak=%.2f,Onset=%.3f,Hit=%.3f,Swell=%.3f,Env={%s},Peaks={%s}},' % (slot, json.dumps(r['File']), r['Id'], r['Duration'], r['Peak'], r['Onset'], r['Hit'], r['Swell'], ','.join('%g' % v for v in r['Env']), ','.join('%g' % v for v in r['Peaks'])))
        lines.append('}}')
        open(out, 'w').write('\n'.join(lines) + '\n')
        print('wrote', out)

if __name__ == '__main__':
    main()
