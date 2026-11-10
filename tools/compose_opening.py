"""Render the opening's original stereo mix from its in-game timeline.

Run from the repo root on Windows with numpy, scipy, soundfile and the
Microsoft Pavel and Irina Desktop Russian voices installed.
"""
from ast import literal_eval
import json
from math import gcd
from pathlib import Path
import subprocess

import numpy as np
from scipy.signal import butter, resample_poly, sosfilt
import soundfile as sf

RATE = 32000
TAU = 2 * np.pi
OUTPUT = Path("assets/last_light/audio/opening_mix.ogg")
WORK = Path("work/opening")


def read_timeline():
    source = Path("game/ui/opening_timeline.gd").read_text(encoding="utf-8")
    def array(name):
        return literal_eval(source.split(f"const {name} := ", 1)[1].split("\nconst ", 1)[0].strip())
    return array("TIMECODES"), array("VOICE_CUES")


def record_voice(cues):
    WORK.mkdir(parents=True, exist_ok=True)
    request = WORK / "voice.json"
    request.write_text(json.dumps([
        {"file": str((WORK / f"{key}.wav").resolve()), "text": line.split(": ", 1)[1],
         "voice": "Microsoft Pavel" if line.startswith("Рейнджер:") else "Microsoft Irina Desktop"}
        for _, _, key, line in cues
    ], ensure_ascii=False), encoding="utf-8")
    subprocess.run(["pwsh", "-NoProfile", "-File", "tools/voice_opening.ps1",
                    str(request.resolve())], check=True)


def mix_opening(cuts, cues):
    length = round(cuts[-1] * RATE)
    t = np.arange(length, dtype=np.float64) / RATE
    rng = np.random.default_rng(9468)
    output = np.zeros((length, 2))
    duck = np.ones(length)

    def fade(start, end):
        x = np.clip((t - start) / (end - start), 0, 1)
        return x * x * (3 - 2 * x)

    def band(low, high, samples):
        return sosfilt(butter(2, [low, high], fs=RATE, btype="bandpass", output="sos"), samples)

    def layer(samples, pan=0.0):
        output[:, 0] += samples * (1 - pan) ** 0.5
        output[:, 1] += samples * (1 + pan) ** 0.5

    def hit(when, decay, low, high, gain, pan):
        u = np.maximum(t - when, 0)
        env = np.minimum(u * 420, 1) * np.exp(-u * decay)
        layer(band(low, high, rng.normal(size=length)) * env * gain, pan)

    fail, fall, pov, impact, aftermath = cuts[2:7]
    for start, end, _, _ in cues:
        duck -= 0.28 * (fade(start - .14, start + .07) - fade(end - .05, end + .32))
    power = (fade(0, .75) - fade(fail + .12, fail + 1.28)) * duck
    engine = .058 * np.sin(TAU * (43*t + .6*np.sin(t*.85)))
    engine += .021 * np.sin(TAU * (86.15*t + .9*np.sin(t*.65)))
    engine += .026 * band(54, 360, rng.normal(size=length))
    layer(power * engine)
    for pitch, pan, offset in [(110,-.5,0),(164.81,.3,.8),(220,.65,1.4),(277.18,-.4,2.2)]:
        cloud = (fade(offset, offset+2.0) - fade(fail-.15, fail+1.18)) * duck
        layer(.018 * np.sin(TAU*(pitch*t + .17*np.sin(t*1.6))) * cloud, pan)

    # The relay snaps once, then the drive tone falls away.
    hit(fail+.04, 14.0, 250, 6400, .52, .53)
    hit(fail+.20, 19.0, 210, 2700, .24, .23)
    u = np.maximum(0, t - fail)
    layer(.072 * np.sin(TAU*(67*u-10*u*u)) * np.minimum(u*32,1) * np.exp(-u*1.85), -.18)
    for when, pitch in [(fail+1.32, 480), (fall+1.7, 392), (pov+.42, 330)]:
        u = np.maximum(t - when, 0)
        envelope = np.minimum(u*28,1)*np.exp(-u*4.8)
        layer(.052*np.sin(TAU*(pitch*u-28*u*u))*envelope, .24)

    # Widen and brighten the rush of atmosphere as the ship banks.
    entry = (fade(fail+.9, fall+1.9) - fade(impact+.02, impact+.24)) * duck
    swell = .62 + .38 * fade(fall+1.0, impact-.12)
    for pan in [-.57,.59]:
        wind = band(125, 2500, rng.normal(size=length))
        layer(wind * entry * swell * .13 * (1+.18*np.sin(t*(3.7+pan))), pan)
    layer(.061 * np.sin(TAU*(38*t+.8*np.sin(t*4))) * entry * swell)
    for offset, pan in [(-2.0,.63),(-1.1,-.61),(-.45,.2)]:
        hit(impact+offset, 9.5, 120, 1700, .24, pan)

    # Ground contact: low weight, a short steel shear and falling fragments.
    strike = impact + .17
    u = np.maximum(t - strike, 0)
    layer(.30 * np.sin(TAU*(49*u-4*u*u))*np.minimum(u*52,1)*np.exp(-u*4.5))
    hit(strike, 5.8, 70, 770, .59, -.16)
    hit(strike+.065, 11.5, 330, 3300, .45, .30)
    for offset, gain, pan in [(0.30,.23,.68),(.51,.16,-.44),(.85,.08,.36),(1.30,.05,-.72)]:
        hit(strike+offset, 12, 190, 2400, gain, pan)
    distant = fade(strike+1.7, strike+2.5) - fade(aftermath-.12, aftermath+.55)
    layer(.027 * band(82, 510, rng.normal(size=length)) * distant, -.36)
    silence_to_cabin = (fade(aftermath-.25, aftermath+.82) - fade(cuts[-1]-.7, cuts[-1]))
    layer((.014*np.sin(TAU*54*t)+.028*band(125,1240,rng.normal(size=length)))*silence_to_cabin, -.23)
    hit(aftermath+.17, 4.6, 230, 1470, .11, .30)

    for start, end, key, _ in cues:
        voice, sr = sf.read(WORK / f"{key}.wav", always_2d=True)
        voice = voice.mean(axis=1)
        active = np.flatnonzero(np.abs(voice) > .004)
        if active.size == 0:
            raise ValueError(f"No speech in {key}")
        voice = voice[max(0,active[0]-sr//35):min(len(voice),active[-1]+sr//16)]
        divisor = gcd(RATE, sr)
        voice = resample_poly(voice, RATE//divisor, sr//divisor)
        budget = round((end-start-.10)*RATE)
        if len(voice) > budget:
            voice = np.interp(np.linspace(0,len(voice)-1,budget),np.arange(len(voice)),voice)
        voice = band(120 if key in ("orbit","manual","alive") else 250, 4200, voice)
        voice *= .34 / max(.12, np.max(np.abs(voice)))
        index = round(start * RATE)
        output[index:index+len(voice)] += voice[:,None]

    output = np.tanh(output * 1.19)
    with sf.SoundFile(OUTPUT,"w",RATE,2,subtype="VORBIS") as stream:
        for start in range(0,length,16384):
            stream.write(output[start:start+16384])
    print(f"{OUTPUT}: {length/RATE:.2f} s, {len(cues)} timed lines, peak {np.max(np.abs(output)):.3f}")


if __name__ == "__main__":
    timecodes, voice_cues = read_timeline()
    record_voice(voice_cues)
    mix_opening(timecodes, voice_cues)
