"""Synthesized ambience for the game: no recordings, just math.

    python tools/sounds.py

Writes 16-bit mono WAVs into godot/sounds/. Loops are built so their ends meet.
"""
import os
import wave

import numpy as np
from scipy import signal

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "godot", "sounds")
rng = np.random.default_rng(22)


def t_axis(sec):
    return np.arange(int(RATE * sec)) / RATE


def lowpass(x, hz, order=2):
    b, a = signal.butter(order, hz / (RATE / 2), "low")
    return signal.lfilter(b, a, x)


def highpass(x, hz, order=2):
    b, a = signal.butter(order, hz / (RATE / 2), "high")
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (RATE / 2), hi / (RATE / 2)], "band")
    return signal.lfilter(b, a, x)


def noise(sec):
    return rng.standard_normal(int(RATE * sec))


def brown(sec):
    w = noise(sec)
    b = np.cumsum(w)
    b = highpass(b, 8)
    return b / (np.abs(b).max() + 1e-9)


def env_ad(n, attack, decay):
    t = np.arange(n) / RATE
    return np.minimum(1.0, t / max(attack, 1e-4)) * np.exp(-np.maximum(0, t - attack) / max(decay, 1e-4))


def place(buf, clip, at):
    i = int(at * RATE) % len(buf)
    n = len(clip)
    end = i + n
    if end <= len(buf):
        buf[i:end] += clip
    else:
        k = len(buf) - i
        buf[i:] += clip[:k]
        buf[:n - k] += clip[k:]


def seamless(x, fade=1.0):
    """Crossfade the tail into the head so the loop has no click."""
    n = int(fade * RATE)
    head = x[:n].copy()
    tail = x[-n:]
    w = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = tail * (1 - w) + head * w
    return x


def write(name, x, gain=0.8):
    os.makedirs(OUT, exist_ok=True)
    x = x / (np.abs(x).max() + 1e-9) * gain
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print("wrote", name, "%.1fs" % (len(x) / RATE))


def clank(freq=900.0, dur=1.2):
    t = t_axis(dur)
    partials = [1.0, 2.76, 5.4, 8.9]
    s = sum(np.sin(2 * np.pi * freq * p * t + rng.random() * 6) * (0.6 ** k) for k, p in enumerate(partials))
    return s * env_ad(len(t), 0.002, 0.25)


def hiss(dur, lo=2000, hi=7000):
    x = bandpass(noise(dur), lo, hi)
    return x * env_ad(len(x), 0.05, dur * 0.5)


def yard():
    sec = 41.0
    x = brown(sec) * 0.35
    x += lowpass(noise(sec), 180) * 0.25          # the city across the river
    # the engine at rest: the air pump's slow double beat and a steady simmer
    pump = np.zeros(int(RATE * sec))
    beat = lowpass(noise(0.25), 220) * env_ad(int(RATE * 0.25), 0.01, 0.08)
    p = 0.0
    while p < sec:
        place(pump, beat * 0.9, p)
        place(pump, beat * 0.6, p + 0.35)
        p += 1.6 + rng.uniform(-0.05, 0.05)
    x += pump * 0.5
    x += bandpass(noise(sec), 3000, 8000) * 0.05
    for k in range(5):
        place(x, hiss(rng.uniform(1.5, 3.0)) * 0.35, rng.uniform(0, sec))
    for k in range(7):
        place(x, clank(rng.uniform(500, 1400)) * rng.uniform(0.08, 0.2), rng.uniform(0, sec))
    write("yard", seamless(x))


def train():
    sec = 33.0
    x = brown(sec) * 0.5 + lowpass(noise(sec), 90) * 0.5
    clack = bandpass(noise(0.12), 400, 2500) * env_ad(int(RATE * 0.12), 0.002, 0.03)
    thud = lowpass(noise(0.12), 160) * env_ad(int(RATE * 0.12), 0.003, 0.05)
    period = 1.1  # a 39-foot rail at about 25 miles an hour
    p = 0.0
    while p < sec:
        for off in (0.0, 0.16, 0.62, 0.78):
            place(x, clack * 0.7 + thud * 0.9, p + off)
        p += period
    for k in range(6):
        c = np.sin(2 * np.pi * rng.uniform(180, 320) * t_axis(0.4)) * env_ad(int(RATE * 0.4), 0.05, 0.15)
        place(x, c * 0.05, rng.uniform(0, sec))
    write("train", seamless(x), 0.7)


def fire():
    sec = 30.0
    x = lowpass(brown(sec), 400) * 0.6
    x += bandpass(noise(sec), 300, 1500) * 0.08
    for k in range(260):
        pop = highpass(noise(0.02), 1500) * env_ad(int(RATE * 0.02), 0.0005, 0.006)
        place(x, pop * rng.uniform(0.2, 1.0), rng.uniform(0, sec))
    write("fire", seamless(x), 0.6)


def marsh():
    sec = 36.0
    x = lowpass(brown(sec), 600) * 0.6
    lap = lowpass(noise(sec), 300) * (0.5 + 0.5 * np.sin(2 * np.pi * t_axis(sec) / 3.1))
    x += lap * 0.2
    for k in range(9):
        n = int(RATE * 0.35)
        t = np.arange(n) / RATE
        f0 = rng.uniform(1800, 3200)
        chirp = np.sin(2 * np.pi * (f0 + 900 * np.sin(2 * np.pi * 14 * t)) * t) * env_ad(n, 0.01, 0.12)
        place(x, chirp * 0.08, rng.uniform(0, sec))
    write("marsh", seamless(x), 0.55)


def crickets():
    sec = 32.0
    x = lowpass(brown(sec), 300) * 0.25
    for c in range(9):
        f = rng.uniform(3800, 5200)
        rate = rng.uniform(2.2, 3.6)
        amp = rng.uniform(0.05, 0.14)
        p = rng.uniform(0, 1)
        n = int(RATE * 0.12)
        t = np.arange(n) / RATE
        chirp = np.sin(2 * np.pi * f * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 60 * t)) * env_ad(n, 0.01, 0.05)
        while p < sec:
            place(x, chirp * amp, p)
            p += 1.0 / rate
    for k in range(14):
        n = int(RATE * 0.3)
        t = np.arange(n) / RATE
        f = rng.uniform(140, 260)
        croak = signal.sawtooth(2 * np.pi * f * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 30 * t)) * env_ad(n, 0.02, 0.1)
        place(x, lowpass(croak, 900) * 0.12, rng.uniform(0, sec))
    write("crickets", seamless(x), 0.5)


def room():
    sec = 24.0
    x = lowpass(brown(sec), 200) * 0.25
    tick = highpass(noise(0.015), 2000) * env_ad(int(RATE * 0.015), 0.0005, 0.004)
    p = 0.0
    k = 0
    while p < sec:
        place(x, tick * (0.35 if k % 2 == 0 else 0.25), p)
        p += 1.0
        k += 1
    write("room", seamless(x, 0.5), 0.35)


def whistle():
    sec = 3.2
    t = t_axis(sec)
    envv = np.minimum(1, t / 0.18) * np.minimum(1, (sec - t) / 0.6)
    tones = [(262.0, 1.0), (330.0, 0.8), (392.0, 0.7), (466.0, 0.35)]
    s = sum(a * np.sin(2 * np.pi * f * t * (1 + 0.004 * np.sin(2 * np.pi * 5 * t))) for f, a in tones)
    s += bandpass(noise(sec), 250, 1400) * 0.9
    write("whistle", s * envv, 0.9)


if __name__ == "__main__":
    yard()
    train()
    fire()
    marsh()
    crickets()
    room()
    whistle()
