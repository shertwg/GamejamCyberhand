from pathlib import Path
import sys
import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt

RATE = 22050
OUT = Path("assets/last_light/audio")
OUT.mkdir(parents=True, exist_ok=True)
SCORES = [
    ("01_orbit", 60, 50, "major"), ("02_fall", 91, 42, "phrygian"),
    ("03_emergency", 74, 45, "minor"), ("04_pressure", 64, 46, "minor"),
    ("05_cold_water", 72, 53, "minor"), ("06_workbench", 86, 48, "dorian"),
    ("07_greenhouse", 68, 55, "major"), ("08_reactor", 100, 42, "phrygian"),
    ("09_static", 76, 49, "minor"), ("10_threshold", 81, 47, "minor"),
    ("11_ravine", 94, 43, "phrygian"), ("12_crystal", 63, 51, "dorian"),
    ("13_relay", 105, 46, "phrygian"), ("14_answer", 70, 54, "major"),
    ("15_home", 66, 57, "major"),
]
MODES = {
    "major": (0, 2, 4, 5, 7, 9, 11), "minor": (0, 2, 3, 5, 7, 8, 10),
    "dorian": (0, 2, 3, 5, 7, 9, 10), "phrygian": (0, 1, 3, 5, 7, 8, 10),
}
TAU = 2 * np.pi

def note(root, scale, degree):
    return 440 * 2 ** ((root + scale[degree % 7] + degree // 7 * 12 - 69) / 12)

def add(out, seconds, duration, hz, gain, timbre, rng):
    start = int(seconds * RATE)
    end = min(len(out), start + int(duration * RATE))
    if end <= start:
        return
    t = np.arange(end - start, dtype=np.float32) / RATE
    phase = TAU * hz * t + rng.uniform(0, TAU)
    if timbre == "pad":
        env = np.minimum(1, t / 1.3) * np.minimum(1, (duration-t) / 1.5)
        tone = .68*np.sin(phase) + .22*np.sin(phase*1.003) + .1*np.sin(phase*2.0)
        tone *= .85 + .15*np.sin(TAU*.21*t)
    elif timbre == "bass":
        env = np.minimum(1, t*24) * np.exp(-t*2.4)
        tone = .8*np.sin(phase) + .2*np.sin(2*phase)
    elif timbre == "drum":
        env = np.minimum(1, t*200) * np.exp(-t*13)
        tone = np.sin(TAU*(hz*t + 14*(1-np.exp(-t*27))))
    else:
        env = np.minimum(1, t*55) * np.exp(-t*3.4)
        tone = .65*np.sin(phase + .46*np.exp(-t*8)*np.sin(phase*2.01)) + .15*np.sin(phase*3)
    out[start:end] += tone * np.maximum(0, env) * gain

def write_score(i, name, bpm, root, mode):
    rng = np.random.default_rng(17771+i)
    beat = 60/bpm
    bars = round((190 + i % 5 * 5)/(4*beat))
    duration = bars*beat*4
    buf = np.zeros(int(duration*RATE), dtype=np.float32)
    scale = MODES[mode]
    seqs = ((0,5,3,4),(0,1,5,1),(0,3,5,4),(0,5,6,3),(0,2,5,3))
    seq = seqs[i % len(seqs)]
    motif = (0, 2+i%3, 4, 6, 4+i%2, 2, 1, 4)
    tense = mode == "phrygian" or i in (2, 8, 9)
    for bar in range(bars):
        section = min(4, bar * 5 // bars)
        start = bar*beat*4
        chord = seq[(bar//2 + (section == 2)) % 4]
        if bar % 2 == 0:
            for interval in (0, 4, 9, 11 if section in (2, 3) else 7):
                add(buf,start,beat*9,note(root,scale,chord+interval),.043,"pad",rng)
        if section > 0:
            for b in (0, 2 if not tense else 2.5):
                add(buf,start+b*beat,beat*1.6,note(root-12,scale,chord),.105 if tense else .071,"bass",rng)
        if tense and section in (1, 2, 3):
            for b in (0, 1.5, 3 if section == 2 else 2.5):
                add(buf,start+b*beat,.31,43+i%9,.066,"drum",rng)
        if section in (1,2,3) or bar % 3 == 0:
            offsets = (0.5,1.5,2.5,3.5) if section in (2,3) else (0.75,2.75)
            for j, b in enumerate(offsets):
                degree = chord+7+motif[(bar*2+j+section) % len(motif)]
                add(buf,start+b*beat,beat*2.9,note(root,scale,degree),.064 if tense else .075,"bell",rng)
    stereo = np.empty((len(buf),2), dtype=np.float32)
    stereo[:,0] = buf
    stereo[:,1] = buf
    for delay, left, right in ((0.18,.12,.17),(.32,.14,.08),(.56,.07,.10),(.91,.045,.031)):
        delay_n = int(delay*RATE)
        stereo[delay_n:,0] += buf[:-delay_n]*left
        stereo[delay_n:,1] += buf[:-delay_n]*right
    fade = RATE*3
    stereo[:fade] *= np.linspace(0,1,fade)[:,None]
    stereo[-fade:] *= np.linspace(1,0,fade)[:,None]
    with sf.SoundFile(OUT/(name+".ogg"),"w",RATE,2,subtype="VORBIS") as stream:
        for start in range(0,len(stereo),16384):
            stream.write(np.tanh(stereo[start:start+16384]*1.2))
    print(name, round(duration,1), flush=True)

def effects():
    rng = np.random.default_rng(308)
    recipes = {
        "step": (.14,85,.26,920), "hatch": (.50,89,.42,540),
        "pickup": (.30,740,.12,2400), "craft": (.41,460,.28,1900),
        "click": (.08,390,.23,2800), "warning": (.75,195,.16,860),
        "success": (.62,440,.06,2100), "servo": (.25,148,.15,1200),
        "air": (6.0,44,.20,550), "storm": (6.0,31,.36,810),
        "cave": (6.0,58,.10,410), "impact": (1.25,40,.64,500),
    }
    for name,(seconds,hz,noise,cutoff) in recipes.items():
        t = np.arange(int(seconds*RATE))/RATE
        raw = sosfilt(butter(2,cutoff,fs=RATE,output="sos"),rng.normal(size=len(t)))
        phase = TAU*(hz*t + hz*.13*np.sin(t*3))
        x = .32*np.sin(phase) + noise*raw + .08*np.sin(phase*2.01)
        if name in ("air","storm","cave"):
            x *= .46 + .18*np.cos(TAU*t/seconds)
            edge = RATE//6
            x[:edge] *= np.linspace(0,1,edge)
            x[-edge:] *= np.linspace(1,0,edge)
        else:
            x *= np.minimum(t*180,1)*np.exp(-t*(5 if seconds>.35 else 16))
        sf.write(OUT/(name+".wav"),x.astype(np.float32),RATE,subtype="PCM_16")

def footsteps():
    """Separate heel, sole and surface tails. No steady carrier tone."""
    surfaces = {
        "metal": (0.22, 112, 0.43, 1850, (493, 781, 1187), .065),
        "wet": (0.24, 94, 0.44, 1450, (267, 412), .037),
        "gravel": (0.22, 89, 0.52, 2740, (), 0),
        "stone": (0.20, 103, 0.35, 2220, (334, 577), .028),
    }
    for surface_id, (surface, settings) in enumerate(surfaces.items()):
        seconds, heel_hz, scuff_level, scuff_hz, partials, ring = settings
        for variant in range(1, 5):
            rng = np.random.default_rng(711 + surface_id * 51 + variant)
            t = np.arange(int(seconds * RATE)) / RATE
            white = rng.normal(size=len(t))
            impact = sosfilt(butter(2, (55, 390), "bandpass", fs=RATE, output="sos"), white)
            heel = (np.sin(TAU * heel_hz * rng.uniform(.91, 1.09) * t) * .30
                    + impact * 1.55) * np.minimum(t * 560, 1) * np.exp(-t * 49)
            delay = rng.uniform(.036, .052)
            sole = np.maximum(0, t - delay)
            grit = sosfilt(butter(2, (340, scuff_hz), "bandpass", fs=RATE, output="sos"), white)
            scuff = grit * np.minimum(sole * 160, 1) * np.exp(-sole * 32) * scuff_level
            if surface == "gravel":
                for offset in rng.uniform(.034, .092, size=4):
                    grain = np.maximum(0, t - offset)
                    scuff += grit * np.minimum(grain * 900, 1) * np.exp(-grain * 230) * .24
            elif surface == "wet":
                splash = np.maximum(0, t - .026)
                scuff += grit * np.minimum(splash * 210, 1) * np.exp(-splash * 21) * .18
            resonant = np.zeros_like(t)
            for frequency in partials:
                resonant += np.sin(TAU * frequency * rng.uniform(.96, 1.04) * t)
            resonant *= np.minimum(t * 500, 1) * np.exp(-t * 27) * ring
            sample = heel + scuff + resonant
            sample *= np.minimum(1, (seconds - t) * 65)
            sample *= .58 / max(.58, np.max(np.abs(sample)))
            sf.write(OUT / f"foot_{surface}_{variant}.wav", sample, RATE, subtype="PCM_16")

if __name__ == "__main__":
    footsteps()
    if "--footsteps" not in sys.argv:
        effects()
        for i, score in enumerate(SCORES):
            write_score(i, *score)
