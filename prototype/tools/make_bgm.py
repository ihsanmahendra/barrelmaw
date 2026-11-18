"""Composes the background music loops into prototype/audio/*.ogg-free WAV files (no dependencies).
A bouncy pirate sea shanty in 6/8: accordion-like chords, a bass line, a tin-whistle melody and
soft percussion. Run: python3 tools/make_bgm.py
  bgm_menu.wav   - relaxed, the main menu and the map
  bgm_battle.wav - faster and busier, during a stage
Both loop seamlessly (the length is a whole number of bars and tails are wrapped around)."""
import math, os, random, struct, wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
random.seed(11)

NOTES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(name):
    """'A4' -> 440.0, 'F#3', 'Bb3'."""
    n = NOTES[name[0]]
    i = 1
    if name[i] == "#":
        n += 1; i += 1
    elif name[i] == "b":
        n -= 1; i += 1
    octave = int(name[i:])
    return 440.0 * 2 ** ((n - 9 + 12 * (octave - 4)) / 12.0)


def render(total, notes):
    """notes: list of (start_sec, dur_sec, freq, kind, vol)."""
    buf = [0.0] * total
    for start, dur, f, kind, vol in notes:
        s0 = int(start * SR)
        n = int(dur * SR)
        ph = 0.0
        ph2 = random.random()
        for i in range(n):
            j = (s0 + i) % total  # wrap so the tail overlaps the loop start
            t = i / SR
            ph += f / SR
            if kind == "accordion":  # two slightly detuned square-ish waves = reedy
                w = (math.sin(2 * math.pi * ph) + 0.5 * math.sin(4 * math.pi * ph) + 0.25 * math.sin(6 * math.pi * ph))
                w += 0.7 * math.sin(2 * math.pi * (ph * 1.004))
                env = min(1.0, t / 0.03) * (1.0 if t < dur - 0.06 else max(0.0, (dur - t) / 0.06))
                w *= 0.35
            elif kind == "whistle":
                vib = 1.0 + 0.012 * math.sin(2 * math.pi * 5.2 * t) * min(1.0, t / 0.2)
                w = math.sin(2 * math.pi * ph * vib) + 0.18 * math.sin(4 * math.pi * ph * vib)
                env = min(1.0, t / 0.04) * (1.0 if t < dur - 0.08 else max(0.0, (dur - t) / 0.08))
                w *= 0.5
            elif kind == "bass":
                w = math.sin(2 * math.pi * ph) + 0.4 * math.sin(4 * math.pi * ph)
                env = min(1.0, t / 0.01) * math.exp(-t * 3.2)
            elif kind == "kick":
                fr = 110.0 * math.exp(-t * 18.0) + 45.0
                ph3 = ph if False else 0.0
                w = math.sin(2 * math.pi * fr * t)
                env = math.exp(-t * 12.0)
            elif kind == "snare":
                w = random.uniform(-1, 1) * 0.8 + math.sin(2 * math.pi * 190 * t) * 0.3
                env = math.exp(-t * 22.0)
            elif kind == "hat":
                w = random.uniform(-1, 1)
                env = math.exp(-t * 55.0)
            else:
                w, env = 0.0, 0.0
            buf[j] += w * env * vol
    return buf


def save(name, buf, gain=0.9):
    peak = max(1e-9, max(abs(x) for x in buf))
    k = min(1.0, 0.8 / peak) * gain
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x * k)) * 32767)) for x in buf))
    print(name, round(len(buf) / SR, 1), "s")


def compose(bpm, melody_bars, battle):
    """6/8 shanty in A minor. A bar = 6 eighth notes; BAR is one bar in seconds."""
    eighth = 60.0 / bpm / 2.0
    bar = eighth * 6
    chords = [("A3", "C4", "E4"), ("A3", "C4", "E4"), ("D3", "F3", "A3"), ("E3", "G#3", "B3")] * 2
    chords = [("A3", "C4", "E4"), ("D4", "F4", "A4"), ("A3", "C4", "E4"), ("E4", "G#4", "B4"),
              ("A3", "C4", "E4"), ("D4", "F4", "A4"), ("E4", "G#4", "B4"), ("A3", "C4", "E4")]
    roots = ["A2", "D3", "A2", "E3", "A2", "D3", "E3", "A2"]
    n_bars = len(chords)
    total = int(bar * n_bars * SR)
    notes = []
    for b in range(n_bars):
        t0 = b * bar
        # Oom-pah-pah: bass on 1 and 4, chord stabs on 3 and 6 (eighth positions 0 and 3 / 2 and 5).
        notes.append((t0, eighth * 1.6, hz(roots[b]), "bass", 0.8))
        fifth = hz(roots[b]) * 1.5
        notes.append((t0 + 3 * eighth, eighth * 1.6, fifth, "bass", 0.65))
        for pos in (1, 2, 4, 5):
            for c in chords[b]:
                notes.append((t0 + pos * eighth, eighth * 0.8, hz(c), "accordion", 0.16 if battle else 0.13))
        # Drums.
        notes.append((t0, 0.25, 1, "kick", 0.9 if battle else 0.55))
        notes.append((t0 + 3 * eighth, 0.2, 1, "snare", 0.35 if battle else 0.18))
        if battle:
            for pos in range(6):
                notes.append((t0 + pos * eighth, 0.06, 1, "hat", 0.12))
            notes.append((t0 + 4.5 * eighth, 0.2, 1, "snare", 0.18))
    # Melody: (bar, position in eighths, length in eighths, note)
    mel = melody_bars
    for b, pos, ln, nt in mel:
        notes.append((b * bar + pos * eighth, ln * eighth * 0.95, hz(nt), "whistle", 0.55 if battle else 0.5))
        if battle:  # an octave-lower doubling for body
            notes.append((b * bar + pos * eighth, ln * eighth * 0.95, hz(nt) / 2.0, "accordion", 0.08))
    return render(total, notes)


# Tune: eight bars over Am / Dm / Am / E / Am / Dm / E / Am.
MELODY = [
    (0, 0, 2, "E5"), (0, 2, 1, "E5"), (0, 3, 1, "D5"), (0, 4, 1, "C5"), (0, 5, 1, "D5"),
    (1, 0, 3, "F5"), (1, 3, 1, "E5"), (1, 4, 2, "D5"),
    (2, 0, 2, "C5"), (2, 2, 1, "C5"), (2, 3, 1, "B4"), (2, 4, 1, "A4"), (2, 5, 1, "B4"),
    (3, 0, 4, "G#4"), (3, 4, 2, "B4"),
    (4, 0, 2, "E5"), (4, 2, 1, "E5"), (4, 3, 1, "F5"), (4, 4, 1, "G5"), (4, 5, 1, "F5"),
    (5, 0, 3, "E5"), (5, 3, 1, "D5"), (5, 4, 2, "F5"),
    (6, 0, 2, "E5"), (6, 2, 1, "D5"), (6, 3, 1, "B4"), (6, 4, 2, "G#4"),
    (7, 0, 6, "A4"),
]

def compose_night():
    """Night stages: a slow, dark D-minor tune. Long soft chords, a low bass, a sparse whistle melody and a
    quiet high chime; no snare or hats."""
    bpm = 74
    eighth = 60.0 / bpm / 2.0
    bar = eighth * 6
    chords = [("D4", "F4", "A4"), ("Bb3", "D4", "F4"), ("G3", "Bb3", "D4"), ("A3", "C#4", "E4")] * 2
    roots = ["D3", "Bb2", "G2", "A2"] * 2
    total = int(bar * 8 * SR)
    notes = []
    for b in range(8):
        t0 = b * bar
        notes.append((t0, eighth * 3.0, hz(roots[b]), "bass", 0.8))
        notes.append((t0 + 3 * eighth, eighth * 2.0, hz(roots[b]) * 1.5, "bass", 0.5))
        for c in chords[b]:
            notes.append((t0, eighth * 5.5, hz(c), "accordion", 0.075))
        if b % 2 == 0:
            notes.append((t0, 0.3, 1, "kick", 0.35))
    mel = [
        (0, 0, 3, "A4"), (0, 3, 3, "F4"), (1, 0, 4, "D4"), (1, 4, 2, "F4"),
        (2, 0, 3, "G4"), (2, 3, 3, "Bb4"), (3, 0, 6, "A4"),
        (4, 0, 3, "A4"), (4, 3, 3, "D5"), (5, 0, 4, "C5"), (5, 4, 2, "Bb4"),
        (6, 0, 3, "G4"), (6, 3, 3, "Bb4"), (7, 0, 6, "A4"),
    ]
    for b, pos, ln, nt in mel:
        notes.append((b * bar + pos * eighth, ln * eighth * 0.95, hz(nt), "whistle", 0.36))
    for b, pos, nt in [(1, 3, "F5"), (3, 3, "A5"), (5, 3, "D5"), (7, 3, "E5")]:  # quiet high chimes
        notes.append((b * bar + pos * eighth, eighth * 2.0, hz(nt), "whistle", 0.14))
    return render(total, notes)


save("bgm_menu", compose(96, MELODY, False))
save("bgm_battle", compose(124, MELODY, True))
save("bgm_night", compose_night())
