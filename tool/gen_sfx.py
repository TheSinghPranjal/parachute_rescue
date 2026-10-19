#!/usr/bin/env python3
"""Synthesizes the game's original sound effects and music loop.

Pure standard library, deterministic (seeded). Re-run to regenerate:
    python3 tool/gen_sfx.py assets/audio
"""
import math
import random
import struct
import sys
import wave
from pathlib import Path

RATE = 22050
rng = random.Random(42)


def env(i, n, attack=0.01, release=0.3):
    t = i / RATE
    dur = n / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = min(1.0, (dur - t) / release) if release > 0 else 1.0
    return max(0.0, a * r)


def tone(freq_fn, dur, wave_fn=math.sin, vol=0.6, attack=0.01, release=None):
    n = int(dur * RATE)
    release = dur * 0.6 if release is None else release
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        phase += 2 * math.pi * freq_fn(t) / RATE
        out.append(wave_fn(phase) * vol * env(i, n, attack, release))
    return out


def noise(dur, vol=0.5, attack=0.005, release=None, lowpass=0.3):
    n = int(dur * RATE)
    release = dur * 0.8 if release is None else release
    out, last = [], 0.0
    for i in range(n):
        last += (rng.uniform(-1, 1) - last) * lowpass
        out.append(last * vol * env(i, n, attack, release))
    return out


def square(p):
    return 1.0 if math.sin(p) >= 0 else -1.0


def tri(p):
    return 2 / math.pi * math.asin(math.sin(p))


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def concat(*tracks):
    out = []
    for t in tracks:
        out.extend(t)
    return out


def silence(dur):
    return [0.0] * int(dur * RATE)


def write(path, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = 0.9 / peak if peak > 0.9 else 1.0
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(
            struct.pack('<h', int(max(-1, min(1, s * scale)) * 32767)) for s in samples))


def note(n):
    return 440 * 2 ** ((n - 69) / 12)


def build():
    s = {}
    s['plane'] = mix(tone(lambda t: 110 + 8 * math.sin(t * 30), 0.9, square, 0.15, 0.2, 0.5),
                     noise(0.9, 0.2, 0.2, 0.5, 0.08))
    s['release'] = tone(lambda t: 900 - 600 * t / 0.25, 0.25, tri, 0.4)
    s['chute'] = concat(noise(0.08, 0.6, 0.002, 0.05, 0.6),
                        mix(noise(0.22, 0.35, 0.01, 0.2, 0.15),
                            tone(lambda t: 260 + 200 * t, 0.22, tri, 0.25)))
    s['wind'] = noise(0.6, 0.5, 0.12, 0.4, 0.05)
    s['rescue'] = concat(tone(lambda t: note(76), 0.09, tri, 0.5, 0.005, 0.05),
                         tone(lambda t: note(79), 0.09, tri, 0.5, 0.005, 0.05),
                         tone(lambda t: note(84), 0.22, tri, 0.5, 0.005, 0.18))
    s['splash'] = mix(noise(0.5, 0.7, 0.002, 0.45, 0.5),
                      tone(lambda t: 300 - 200 * t, 0.3, math.sin, 0.3))
    s['thud'] = mix(tone(lambda t: 90 - 40 * t, 0.25, math.sin, 0.9, 0.002, 0.2),
                    noise(0.2, 0.3, 0.002, 0.18, 0.2))
    s['bite'] = concat(noise(0.05, 0.8, 0.001, 0.03, 0.7), silence(0.04),
                       noise(0.06, 0.8, 0.001, 0.04, 0.7))
    s['heliHit'] = mix(tone(lambda t: 520 - 300 * t, 0.12, square, 0.35, 0.001, 0.1),
                       noise(0.1, 0.4, 0.001, 0.08, 0.6))
    s['explosion'] = mix(noise(0.8, 0.9, 0.002, 0.75, 0.12),
                         tone(lambda t: 70 - 30 * t, 0.6, math.sin, 0.7, 0.002, 0.5))
    s['zap'] = mix(noise(0.35, 0.8, 0.001, 0.3, 0.9),
                   tone(lambda t: 1400 - 1200 * t, 0.3, square, 0.25, 0.001, 0.25))
    s['beam'] = tone(lambda t: 300 + 120 * math.sin(t * 40) + 200 * t, 0.6, math.sin, 0.35, 0.05, 0.3)
    s['lifeLost'] = concat(tone(lambda t: note(67), 0.12, square, 0.25, 0.005, 0.08),
                           tone(lambda t: note(63), 0.12, square, 0.25, 0.005, 0.08),
                           tone(lambda t: note(60), 0.28, square, 0.25, 0.005, 0.24))
    s['button'] = tone(lambda t: 700, 0.06, tri, 0.4, 0.002, 0.05)
    s['gameOver'] = concat(*[tone(lambda t, n=n: note(n), d, tri, 0.45, 0.005, d * 0.7)
                             for n, d in [(72, 0.18), (67, 0.18), (64, 0.18), (60, 0.5)]])
    s['newBest'] = concat(*[tone(lambda t, n=n: note(n), d, tri, 0.45, 0.005, d * 0.6)
                            for n, d in [(72, 0.1), (76, 0.1), (79, 0.1), (84, 0.1), (88, 0.35)]])
    return s


def music():
    """A light, bouncy 16-bar loop (original composition)."""
    bpm = 132
    beat = 60 / bpm
    prog = [(60, 64, 67), (57, 60, 64), (53, 57, 60), (55, 59, 62)]  # C Am F G
    melody = [76, 79, 81, 79, 76, 74, 72, 74, 76, 76, 74, 72, 74, 79, 76, None,
              72, 74, 76, 72, 81, 79, 76, 74, 72, 74, 76, 79, 77, 76, 74, None]
    bars = 8
    total = int(bars * 4 * beat * RATE)
    out = [0.0] * total

    def add(start, samples):
        i0 = int(start * RATE)
        for i, v in enumerate(samples):
            if i0 + i < total:
                out[i0 + i] += v

    for bar in range(bars):
        chord = prog[bar % 4]
        t0 = bar * 4 * beat
        # Bass "oom-pah".
        for b in range(4):
            root = chord[0] - 24 if b % 2 == 0 else chord[2] - 24
            add(t0 + b * beat, tone(lambda t, f=note(root): f, beat * 0.45, tri, 0.35, 0.005, beat * 0.3))
            if b % 2 == 1:
                for n in chord:
                    add(t0 + b * beat, tone(lambda t, f=note(n): f, beat * 0.3, tri, 0.1, 0.005, beat * 0.2))
        # Melody, two eighth notes per beat.
        for k in range(4):
            n = melody[(bar * 4 + k) % len(melody)]
            if n is not None:
                add(t0 + k * beat, tone(lambda t, f=note(n): f * (1 + 0.004 * math.sin(t * 30)),
                                        beat * 0.85, tri, 0.22, 0.01, beat * 0.5))
        # Shaker.
        for e in range(8):
            add(t0 + e * beat / 2, noise(0.04, 0.06 if e % 2 else 0.1, 0.001, 0.03, 0.9))
    return out


if __name__ == '__main__':
    target = Path(sys.argv[1] if len(sys.argv) > 1 else 'assets/audio')
    target.mkdir(parents=True, exist_ok=True)
    for name, samples in build().items():
        write(target / f'{name}.wav', samples)
    write(target / 'music.wav', music())
    print('wrote', len(list(target.glob('*.wav'))), 'files to', target)
