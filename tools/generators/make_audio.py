#!/usr/bin/env python3
"""Gera os efeitos sonoros ORIGINAIS do Pânico no Servidor (síntese pura).

Nenhuma gravação de terceiros é usada, então não há licença externa.
Requer: Python 3, numpy, scipy.  Uso: python tools/generators/make_audio.py
Saída: assets/audio/interactions/*.wav e assets/audio/ambience/*.wav (mono, 44.1 kHz, 16 bits)

Os sons de ambiente recebem um bloco "smpl" com pontos de loop. O importador
do Godot (modo de loop "Detect From WAV", o padrão) reconhece e repete o som
sem emendas.
"""
import os
import struct
import numpy as np
from scipy import signal

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX = os.path.join(ROOT, "assets", "audio", "interactions")
AMB = os.path.join(ROOT, "assets", "audio", "ambience")
os.makedirs(SFX, exist_ok=True)
os.makedirs(AMB, exist_ok=True)
rng = np.random.default_rng(2026)


def t_axis(sec):
    return np.arange(int(sec * SR)) / SR


def noise(sec):
    return rng.standard_normal(int(sec * SR))


def lp(x, hz, order=4):
    b, a = signal.butter(order, hz / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def hp(x, hz, order=2):
    b, a = signal.butter(order, hz / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def env_ad(n, attack, decay_tau):
    t = np.arange(n) / SR
    e = np.minimum(t / max(attack, 1e-4), 1.0) * np.exp(-np.maximum(t - attack, 0) / decay_tau)
    return e


def ring(freqs, sec, tau, amps=None):
    t = t_axis(sec)
    out = np.zeros_like(t)
    amps = amps or [1.0] * len(freqs)
    for f, a in zip(freqs, amps):
        out += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / (tau * (300.0 / f) ** 0.3))
    return out


def place(dst, src, at_sec, gain=1.0):
    i = int(at_sec * SR)
    j = min(len(dst), i + len(src))
    dst[i:j] += src[: j - i] * gain


def normalize(x, peak=0.85):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def make_loop(x, fade_sec):
    """Torna o som contínuo: mistura o final com o começo (crossfade)."""
    n = int(fade_sec * SR)
    head, body, tail = x[:n], x[n:-n], x[-n:]
    w = np.linspace(0, 1, n)
    mixed = tail * (1 - w) + head * w
    return np.concatenate([body, mixed])


def write_wav(path, x, loop=False):
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    chunks = b""
    fmt = struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16)
    chunks += b"fmt " + struct.pack("<I", len(fmt)) + fmt
    chunks += b"data" + struct.pack("<I", len(data)) + data
    if loop:
        n = len(x)
        smpl = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, n - 1, 0, 0)  # loop para frente, do início ao fim
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)


# ======================================================== AMBIENTES (loop)
# Ronco subterrâneo: ruído grave + drone de máquinas distantes + rangidos e gotas.
dur = 32.0
t = t_axis(dur + 2.0)
rumble = lp(np.cumsum(noise(dur + 2.0)) * 0.02, 140) * 1.0
rumble = hp(rumble, 18)
drone = (0.35 * np.sin(2 * np.pi * 43.0 * t) + 0.22 * np.sin(2 * np.pi * 61.5 * t + 1.0)
         + 0.10 * np.sin(2 * np.pi * 87.0 * t)) * (0.75 + 0.25 * np.sin(2 * np.pi * 0.07 * t))
air = bp(noise(dur + 2.0), 300, 1500) * 0.05 * (0.6 + 0.4 * np.sin(2 * np.pi * 0.05 * t + 2))
amb = normalize(rumble) * 0.55 + drone * 0.35 + air
for at in (5.5, 17.0, 26.5):  # rangidos metálicos distantes
    sec = rng.uniform(1.8, 3.0)
    tt = t_axis(sec)
    f0 = rng.uniform(140, 260)
    sweep = np.sin(2 * np.pi * np.cumsum(f0 + 40 * np.sin(2 * np.pi * 0.6 * tt)) / SR)
    groan = lp(sweep * bp(noise(sec), 100, 900) * 4, 900) * np.sin(np.pi * tt / sec) ** 2
    place(amb, groan, at, 0.18)
for _ in range(9):  # gotas pingando
    d = ring([rng.uniform(1400, 2400)], 0.25, 0.03) * env_ad(int(0.25 * SR), 0.001, 0.04)
    place(amb, d, rng.uniform(0.5, dur), 0.07)
write_wav(os.path.join(AMB, "underground_ambience.wav"), normalize(make_loop(amb, 2.0), 0.7), loop=True)

# Zumbido elétrico de transformador/painel (60 Hz + harmônicos). 6 s = ciclos inteiros.
dur = 6.0
t = t_axis(dur)
hum = (np.sin(2 * np.pi * 60 * t) * 0.5 + np.sin(2 * np.pi * 120 * t) * 0.8
       + np.sin(2 * np.pi * 180 * t) * 0.35 + np.sin(2 * np.pi * 240 * t) * 0.25
       + np.sin(2 * np.pi * 360 * t) * 0.10)
hum *= 0.85 + 0.15 * np.sin(2 * np.pi * 0.5 * t)
hiss = hp(noise(dur), 3000) * 0.03
write_wav(os.path.join(AMB, "electrical_hum.wav"), normalize(hum + hiss, 0.6), loop=True)

# Zumbido de lâmpada fluorescente: dente de serra 120 Hz filtrado + chiado.
dur = 4.0
t = t_axis(dur)
saw = signal.sawtooth(2 * np.pi * 120 * t) * 0.5
buzz = bp(saw, 200, 4000) + 0.25 * np.sin(2 * np.pi * 120 * t)
buzz *= 0.9 + 0.1 * np.sin(2 * np.pi * 0.25 * t)
crackle = np.zeros_like(t)
for _ in range(10):
    c = hp(noise(0.01), 2000) * env_ad(int(0.01 * SR), 0.0005, 0.003)
    place(crackle, c, rng.uniform(0.1, dur - 0.1), 0.4)
write_wav(os.path.join(AMB, "lamp_buzz.wav"), normalize(buzz + crackle, 0.5), loop=True)

# ======================================================== EFEITOS
def click(sec=0.06, hz=3500, tau=0.006, body=900):
    n = int(sec * SR)
    c = bp(noise(sec), hz * 0.5, min(hz * 2, 18000)) * env_ad(n, 0.0005, tau)
    c += ring([body], sec, 0.01)[:n] * 0.4
    return c


# Lanterna: "clique-claque" de botão emborrachado.
x = np.zeros(int(0.18 * SR))
place(x, click(0.06, 3200, 0.005, 1100), 0.0, 1.0)
place(x, click(0.06, 2400, 0.007, 800), 0.045, 0.7)
write_wav(os.path.join(SFX, "flashlight_on.wav"), normalize(x, 0.6))
x = np.zeros(int(0.18 * SR))
place(x, click(0.06, 2400, 0.007, 800), 0.0, 0.7)
place(x, click(0.06, 2900, 0.005, 950), 0.035, 0.9)
write_wav(os.path.join(SFX, "flashlight_off.wav"), normalize(x, 0.55))


def metal_hit(sec, freqs, tau, thump_hz=90, gain_thump=1.0):
    n = int(sec * SR)
    r = ring(freqs, sec, tau, [1.0 / (i + 1) ** 0.5 for i in range(len(freqs))])
    th = lp(noise(sec), 400) * env_ad(n, 0.001, 0.05) * 3 + np.sin(2 * np.pi * thump_hz * t_axis(sec)) * env_ad(n, 0.001, 0.08)
    tr = hp(noise(sec), 1500) * env_ad(n, 0.0005, 0.01) * 0.6
    return r * 0.5 + th * gain_thump + tr


def creak(sec, f_lo, f_hi):
    tt = t_axis(sec)
    f = f_lo + (f_hi - f_lo) * (0.5 - 0.5 * np.cos(np.pi * tt / sec)) + 25 * np.sin(2 * np.pi * 7 * tt)
    # "stick-slip": pulsos irregulares filtrados por ressonâncias
    phase = np.cumsum(f) / SR
    pulses = (np.sin(2 * np.pi * phase) > 0.92).astype(float) * (0.6 + 0.4 * rng.random(len(tt)))
    s = bp(pulses, 300, 3000) + 0.4 * bp(pulses, 900, 1300, 2)
    return s * np.sin(np.pi * tt / sec) ** 0.7


# (Passos e porta agora usam GRAVAÇÕES REAIS: ver process_recordings.py)

# Disjuntor: alavanca pesada + estalo elétrico + zumbido subindo.
x = np.zeros(int(1.4 * SR))
place(x, metal_hit(0.5, [300, 870, 1900], 0.05, 100, 1.0), 0.0, 1.0)
zap = hp(noise(0.12), 1200) * env_ad(int(0.12 * SR), 0.001, 0.02)
place(x, zap, 0.05, 0.6)
tt = t_axis(1.1)
hum_up = (np.sin(2 * np.pi * 120 * tt) + 0.4 * np.sin(2 * np.pi * 240 * tt)) * np.minimum(tt / 0.4, 1) * np.exp(-tt / 0.6)
place(x, hum_up, 0.15, 0.25)
write_wav(os.path.join(SFX, "breaker_switch.wav"), normalize(x, 0.8))

print("Sons gerados em", SFX, "e", AMB)
