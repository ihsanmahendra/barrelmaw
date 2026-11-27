"""Synthesizes the placeholder sound effects into prototype/audio/*.wav (no dependencies).
Run: python3 tools/make_sfx.py"""
import math, random, struct, wave, os

SR = 44100
random.seed(7)
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")


def env(t, dur, attack=0.005, release=None):
    release = release if release is not None else dur * 0.6
    if t < attack:
        return t / attack
    if t > dur - release:
        return max(0.0, (dur - t) / release)
    return 1.0


def osc(kind, phase):
    if kind == "sine":
        return math.sin(phase)
    if kind == "square":
        return 1.0 if math.sin(phase) >= 0 else -1.0
    if kind == "tri":
        return 2.0 / math.pi * math.asin(math.sin(phase))
    if kind == "saw":
        return 2.0 * ((phase / (2 * math.pi)) % 1.0) - 1.0
    return 0.0


def tone(dur, f0, f1=None, kind="sine", vol=0.5, attack=0.005, release=None, noise=0.0, vibrato=0.0):
    f1 = f0 if f1 is None else f1
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        k = i / max(1, n - 1)
        f = f0 * ((f1 / f0) ** k) if f0 > 0 and f1 > 0 else f0
        if vibrato:
            f *= 1.0 + vibrato * math.sin(2 * math.pi * 6 * t)
        phase += 2 * math.pi * f / SR
        s = osc(kind, phase) * (1.0 - noise) + (random.uniform(-1, 1) * noise)
        out.append(s * env(t, dur, attack, release) * vol)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    return out


def offset(track, secs):
    return [0.0] * int(SR * secs) + track


def lowpass(track, a=0.3):
    out, y = [], 0.0
    for s in track:
        y += a * (s - y)
        out.append(y)
    return out


# These ids are taken from the SoundWeaver pack (see audio/CREDITS.md); do not overwrite them.
PACK_SOUNDS = {"click", "card", "deal", "sparkle", "miss", "win", "lose", "reward"}


def save(name, samples, gain=1.0):
    if name in PACK_SOUNDS:
        return
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = min(1.0, 0.89 / peak) * gain
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))
    print(name, round(len(samples) / SR, 2), "s")


# UI
save("click", tone(0.06, 900, 600, "sine", 0.6, release=0.05))
save("card", mix(tone(0.12, 520, 780, "tri", 0.5, release=0.1), tone(0.12, 1040, 1560, "sine", 0.18, release=0.1)))
save("deal", lowpass(tone(0.09, 400, 200, "sine", 0.5, noise=0.6, release=0.08), 0.25))
save("sparkle", mix(*[offset(tone(0.18, f, f * 1.01, "sine", 0.35, release=0.16), i * 0.045)
                      for i, f in enumerate([1320, 1568, 1976, 2349, 2637])]))
# Combat
save("fire", mix(tone(0.14, 1100, 260, "square", 0.3, release=0.12), tone(0.14, 600, 180, "saw", 0.2, release=0.12)))
save("hit", mix(tone(0.12, 700, 300, "tri", 0.5, release=0.1), lowpass(tone(0.1, 300, 300, "sine", 0.7, noise=1.0, release=0.09), 0.4)))
save("big", mix(tone(0.3, 220, 70, "sine", 0.8, release=0.28), lowpass(tone(0.25, 200, 200, "sine", 0.9, noise=1.0, release=0.24), 0.2),
                offset(tone(0.12, 900, 500, "tri", 0.3, release=0.1), 0.02)))
save("boom", mix(tone(0.6, 140, 38, "sine", 0.95, release=0.55), lowpass(tone(0.5, 150, 150, "sine", 1.0, noise=1.0, release=0.48), 0.12),
                 offset(tone(0.25, 1200, 300, "saw", 0.25, release=0.22), 0.01)))
save("miss", mix(tone(0.22, 180, 110, "saw", 0.45, release=0.2), tone(0.22, 175, 105, "square", 0.25, release=0.2)))
# Results
save("win", mix(*[offset(tone(0.3, f, f, "tri", 0.5, release=0.25), i * 0.1) for i, f in enumerate([523, 659, 784, 1047, 1319])],
                *[offset(tone(0.3, f * 2, f * 2, "sine", 0.15, release=0.25), i * 0.1) for i, f in enumerate([523, 659, 784, 1047, 1319])]))
save("lose", mix(*[offset(tone(0.35, f, f * 0.97, "tri", 0.5, release=0.3), i * 0.18) for i, f in enumerate([392, 349, 311, 262])]))
save("reward", mix(tone(0.25, 880, 880, "sine", 0.5, release=0.22), offset(tone(0.35, 1320, 1320, "sine", 0.5, release=0.3), 0.09)))
# Cannon: low thump with a burst of noise.
save("cannon", mix(tone(0.55, 110, 38, "sine", 0.95, release=0.5), lowpass(tone(0.4, 200, 200, "sine", 1.0, noise=1.0, release=0.38), 0.15),
                   offset(lowpass(tone(0.25, 300, 300, "sine", 0.5, noise=1.0, release=0.22), 0.3), 0.01)))

# ---- Card packs (phase 5). Added at the end so the older sounds above keep the same noise. ----
def chime(freq, dur=0.5, vol=0.4, partials=((1.0, 1.0), (2.0, 0.35), (3.0, 0.15))):
    return mix(*[tone(dur, freq * m, freq * m, "sine", vol * a, attack=0.004, release=dur * 0.95) for m, a in partials])


def run(freqs, step, dur, vol, kind="tri"):
    return mix(*[offset(tone(dur, f, f, kind, vol, release=dur * 0.9), i * step) for i, f in enumerate(freqs)])


# The chest shakes: a low rumble that swells, with a rattle on top.
save("chest_shake", mix(lowpass(tone(0.7, 70, 95, "sine", 0.9, noise=0.55, attack=0.15, release=0.2), 0.12),
                        lowpass(tone(0.7, 180, 260, "tri", 0.25, noise=0.6, attack=0.2, release=0.25, vibrato=0.08), 0.3)))
# The lid creaks open, then a rush of light.
save("chest_open", mix(tone(0.5, 150, 430, "saw", 0.28, attack=0.05, release=0.3, vibrato=0.04),
                       lowpass(tone(0.5, 300, 300, "sine", 0.5, noise=1.0, attack=0.05, release=0.45), 0.2),
                       offset(run([1047, 1319, 1568, 2093], 0.05, 0.35, 0.25, "sine"), 0.3)))
save("flip", mix(lowpass(tone(0.07, 500, 500, "sine", 0.6, noise=1.0, release=0.06), 0.45), offset(tone(0.08, 760, 1180, "sine", 0.3, release=0.07), 0.02)))
# One sting per rarity, each longer and brighter than the last.
save("sting_common", run([523, 659], 0.09, 0.2, 0.45))
save("sting_rare", mix(run([523, 659, 784], 0.08, 0.28, 0.5), offset(chime(1568, 0.4, 0.2), 0.16)))
save("sting_epic", mix(run([523, 659, 784, 1047], 0.08, 0.34, 0.5), run([1047, 1319, 1568, 2093], 0.08, 0.34, 0.16, "sine"), offset(chime(2093, 0.5, 0.22), 0.22)))
save("sting_legendary", mix(run([392, 523, 659, 784, 1047], 0.09, 0.5, 0.5), run([784, 1047, 1319, 1568, 2093], 0.09, 0.5, 0.2, "sine"),
                            offset(chime(2093, 0.8, 0.3), 0.3), offset(chime(2637, 0.7, 0.2), 0.42)))
# Transcended: a long, ethereal rising chord with shimmer.
save("sting_transcended", mix(tone(1.5, 262, 262, "sine", 0.35, attack=0.25, release=1.0, vibrato=0.01), tone(1.5, 392, 392, "sine", 0.3, attack=0.3, release=1.0, vibrato=0.012),
                              tone(1.5, 523, 523, "sine", 0.28, attack=0.35, release=1.0, vibrato=0.014), tone(1.5, 784, 784, "tri", 0.18, attack=0.4, release=1.0),
                              offset(run([1319, 1568, 1976, 2349, 2637, 3136], 0.1, 0.5, 0.22, "sine"), 0.35), offset(chime(3136, 1.0, 0.2), 0.8)))
# Merge: an anvil strike, a ring and a rising shimmer.
save("merge", mix(tone(0.25, 130, 60, "sine", 0.9, release=0.22), lowpass(tone(0.1, 400, 400, "sine", 0.7, noise=1.0, release=0.09), 0.4),
                  chime(988, 0.55, 0.35, ((1.0, 1.0), (2.76, 0.5), (5.4, 0.25))),
                  offset(run([1319, 1568, 1976, 2637], 0.06, 0.3, 0.22, "sine"), 0.12)))
# Pearls clinking.
save("pearl", mix(chime(1760, 0.25, 0.4, ((1.0, 1.0), (2.4, 0.3))), offset(chime(2349, 0.3, 0.35, ((1.0, 1.0), (2.4, 0.3))), 0.07)))

# ---- Next features. Added at the end so the older sounds above keep the same noise. ----
# Drum roll before the Last Shot: fast taps that swell, then one low hit.
save("drumroll", mix(*[offset(lowpass(tone(0.05, 190, 170, "sine", 0.25 + 0.5 * i / 22.0, noise=0.7, release=0.045), 0.3), i * 0.036)
                       for i in range(22)],
                     offset(tone(0.3, 120, 55, "sine", 0.9, release=0.27), 0.82)))
# Crew cheer for a PLUNDER shot: several rising voices with breath noise.
save("crew_cheer", mix(*[offset(lowpass(tone(0.7, f, f * 1.28, "saw", 0.22, attack=0.08, release=0.35, noise=0.18, vibrato=0.025 + 0.004 * i), 0.22), 0.025 * i)
                         for i, f in enumerate([220, 262, 294, 330, 392, 440])]))
# Boss strikes: a ghostly swell, an iron clang with the sea under it, and falling skulls.
save("strike_ghost", mix(tone(0.9, 196, 392, "sine", 0.45, attack=0.25, release=0.4, vibrato=0.05),
                         tone(0.9, 294, 587, "sine", 0.28, attack=0.35, release=0.4, vibrato=0.07),
                         lowpass(tone(0.8, 200, 200, "sine", 0.5, noise=1.0, attack=0.3, release=0.45), 0.08)))
save("strike_armor", mix(tone(0.6, 92, 60, "sine", 0.85, release=0.55), chime(311, 0.7, 0.4, ((1.0, 1.0), (2.76, 0.6), (5.4, 0.35))),
                         offset(chime(233, 0.6, 0.35, ((1.0, 1.0), (2.76, 0.6), (5.4, 0.35))), 0.2),
                         lowpass(tone(0.5, 150, 150, "sine", 0.7, noise=1.0, release=0.45), 0.1)))
save("strike_curse", mix(*[offset(tone(0.32, 900 - 90 * i, 260 - 20 * i, "tri", 0.3, release=0.2), 0.1 * i) for i in range(5)],
                         offset(tone(0.4, 110, 82, "saw", 0.35, release=0.35), 0.45)))
