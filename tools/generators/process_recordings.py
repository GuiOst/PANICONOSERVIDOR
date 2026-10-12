#!/usr/bin/env python3
"""Baixa e processa as GRAVAÇÕES REAIS usadas em Pânico no Servidor (Etapa A).

Todas as fontes têm licença verificada arquivo por arquivo (ver
docs/ASSETS_E_LICENCAS.md e assets/audio/CREDITOS_AUDIO.md).

O que o processamento faz (não altera o caráter da gravação):
  - converte para mono 48 kHz;
  - remove ruído subsônico (passa-altas 40-60 Hz);
  - corta o silêncio inicial (o som começa no instante do passo / do evento);
  - iguala a sonoridade entre as variações de um mesmo conjunto;
  - fade-out curto para não haver estalos;
  - para a porta: afinação mais grave e mixagem em camadas (trinco, rangido,
    batida) para dar peso de porta industrial.

Requisitos: Python 3, numpy, scipy, git e ffmpeg no PATH.
Uso:   python tools/generators/process_recordings.py [pasta_cache]
Saída: assets/audio/footsteps, assets/audio/doors, assets/audio/ui
"""
import os
import subprocess
import sys
import tempfile
import numpy as np
from scipy import signal

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio")
SR = 48000
CACHE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(tempfile.gettempdir(), "pns_audio_sources")

# Repositório -> pastas necessárias (checkout esparso, só o que é usado)
REPOS = {
    "cdda": ("https://github.com/Fris0uman/CDDA-Soundpacks.git",
             ["sound/CC-Sounds/plmove", "sound/CC-Sounds/open_door", "sound/CC-Sounds/close_door"]),
    "mtg": ("https://github.com/luanti-org/minetest_game.git",
            ["mods/doors/sounds", "mods/default/sounds"]),
    "kenney": ("https://github.com/iwenzhou/kenney.git",
               ["Audio (295 files)/RPG sounds (50 sounds)", "Audio (295 files)/UI sounds (50 sounds)"]),
    "kimpact": ("https://github.com/latent-spaces/brag.git",
                ["skills/brag/assets/sfx/impact"]),
}


def fetch():
    os.makedirs(CACHE, exist_ok=True)
    for name, (url, paths) in REPOS.items():
        dst = os.path.join(CACHE, name)
        if not os.path.isdir(dst):
            subprocess.run(["git", "clone", "--depth", "1", "--filter=blob:none", "--sparse", "-q", url, dst], check=True)
        subprocess.run(["git", "-C", dst, "sparse-checkout", "set", "--no-cone", "--skip-checks"]
                       + ["/" + p + "/" for p in paths], check=True)
        subprocess.run(["git", "-C", dst, "checkout", "-q", "HEAD"], check=True)


def src(name, rel):
    return os.path.join(CACHE, name, rel)


CDDA = "sound/CC-Sounds"
KRPG = "Audio (295 files)/RPG sounds (50 sounds)"
KUI = "Audio (295 files)/UI sounds (50 sounds)"
KIMP = "skills/brag/assets/sfx/impact"


# ----------------------------------------------------------------- utilidades
def load(path, rate=1.0):
    """Decodifica com ffmpeg. rate<1 deixa mais grave e mais lento (como fita)."""
    af = f"asetrate={int(SR * rate)},aresample={SR}" if rate != 1.0 else f"aresample={SR}"
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-af", af, "-f", "f32le", "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def hp(x, hz):
    sos = signal.butter(2, hz / (SR / 2), "high", output="sos")
    return signal.sosfilt(sos, x)


def lp(x, hz):
    sos = signal.butter(2, hz / (SR / 2), "low", output="sos")
    return signal.sosfilt(sos, x)


def trim(x, thr=0.06, pre_ms=3, tail_db=-55):
    """Corta silêncio inicial (mantém 3 ms antes do ataque) e cauda inaudível."""
    a = np.abs(x)
    peak = a.max() if a.max() > 0 else 1.0
    idx = np.argmax(a > thr * peak)
    x = x[max(0, idx - int(pre_ms * SR / 1000)):]
    env = np.convolve(np.abs(x), np.ones(480) / 480, mode="same")
    above = np.where(env > peak * 10 ** (tail_db / 20))[0]
    if len(above):
        x = x[: min(len(x), above[-1] + int(0.03 * SR))]
    return x


def fade(x, out_ms=25, in_ms=1.0):
    n_out = min(len(x) // 3, int(out_ms * SR / 1000))
    n_in = int(in_ms * SR / 1000)
    x = x.copy()
    if n_in:
        x[:n_in] *= np.linspace(0, 1, n_in)
    if n_out:
        x[-n_out:] *= np.linspace(1, 0, n_out) ** 2
    return x


def loudness(x, win_ms=30):
    """Maior energia (RMS) em janelas de 30 ms — mede a força do impacto e
    serve para igualar variações de forma consistente."""
    n = int(win_ms * SR / 1000)
    if len(x) <= n:
        return np.sqrt(np.mean(x ** 2) + 1e-12)
    e = np.convolve(x ** 2, np.ones(n) / n, mode="valid")
    return np.sqrt(e.max() + 1e-12)


def match(x, target_rms, peak_ceiling=0.89):
    x = x * (target_rms / loudness(x))
    pk = np.abs(x).max()
    if pk > peak_ceiling:  # limitador simples: só reduz se passar do teto
        x *= peak_ceiling / pk
    return x


def mix(*layers):
    """layers: (sinal, ganho_db, atraso_s)"""
    n = max(len(s) + int(d * SR) for s, g, d in layers)
    out = np.zeros(n)
    for s, g, d in layers:
        i = int(d * SR)
        out[i:i + len(s)] += s * 10 ** (g / 20)
    return out


def save(x, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = np.clip(x, -1, 1).astype(np.float32).tobytes()
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "6", path], input=pcm, check=True)
    print("  ", rel, f"{len(x) / SR:.2f}s")


def step_set(files, out_prefix, target_db, hp_hz=50, lp_hz=None, rate=1.0):
    target = 10 ** (target_db / 20)
    for i, (repo, rel) in enumerate(files, 1):
        x = hp(load(src(repo, rel), rate), hp_hz)
        if lp_hz:
            x = lp(x, lp_hz)
        x = fade(match(trim(x), target))
        save(x, f"{out_prefix}_{i:02d}.ogg")


# ------------------------------------------------------------------- passos
def footsteps():
    print("Passos:")
    # CONCRETO — caminhada: samulis (CC0) + worthahep88 (CC0)
    step_set([("cdda", f"{CDDA}/plmove/walk_t_rock_floor_{i}.ogg") for i in range(1, 5)]
             + [("mtg", f"mods/default/sounds/default_hard_footstep.{i}.ogg") for i in range(1, 4)],
             "footsteps/concrete/walk", -17)
    # CONCRETO — corrida: botas, Kenney RPG Audio (CC0), passadas mais secas e fortes
    step_set([("kenney", f"{KRPG}/footstep0{i}.ogg") for i in range(10)],
             "footsteps/concrete/run", -14)
    # METAL — caminhada: GiocoSound (CC0)
    step_set([("cdda", f"{CDDA}/plmove/walk_metal/walk_metal_{i}.ogg") for i in range(1, 6)],
             "footsteps/metal/walk", -17, hp_hz=60)
    # METAL — corrida: mypantsfelldown (CC0) + GiocoSound com camada de chapa (Kenney, CC0)
    files = [("mtg", f"mods/default/sounds/default_metal_footstep.{i}.ogg") for i in range(1, 4)]
    step_set(files, "footsteps/metal/run", -14, hp_hz=60)
    plates = [f"{KIMP}/impactPlate_light_00{i}.ogg" for i in range(5)]
    for k, i in enumerate([1, 2, 4, 5], start=4):
        step = trim(hp(load(src("cdda", f"{CDDA}/plmove/walk_metal/walk_metal_{i}.ogg")), 60))
        plate = lp(trim(hp(load(src("kimpact", plates[k % 5]), 0.85), 80)), 3500)
        x = mix((match(step, 0.2), 0, 0), (match(plate, 0.2), -13, 0.004))
        save(fade(match(x, 10 ** (-14 / 20))), f"footsteps/metal/run_{k:02d}.ogg")
    # MOLHADO (poças): nathanaelj83 (CC0) + duckduckpony (CC BY 3.0)
    step_set([("cdda", f"{CDDA}/plmove/walk_t_water_sh_{i}.ogg") for i in range(1, 7)],
             "footsteps/wet/walk", -18)
    # MOLHADO — corrida: os mesmos respingos rasos com uma passada de bota
    # (Kenney RPG, CC0) por baixo, mais forte — a "pisada pesada" na poça.
    for i in range(1, 7):
        splash = trim(hp(load(src("cdda", f"{CDDA}/plmove/walk_t_water_sh_{i}.ogg"), 1.04), 60))
        boot = lp(trim(hp(load(src("kenney", f"{KRPG}/footstep0{(i * 3) % 10}.ogg")), 60)), 2500)
        x = mix((match(splash, 0.2), 0, 0.012), (match(boot, 0.2), -6, 0))
        save(fade(match(x, 10 ** (-15 / 20))), f"footsteps/wet/run_{i:02d}.ogg")


# -------------------------------------------------------------------- porta
def doors():
    print("Porta:")
    t_mech = 10 ** (-12 / 20)
    # 1) Trinco / mecanismo no INÍCIO da abertura
    latch_src = [("kenney", f"{KRPG}/metalLatch.ogg", 0.8), ("mtg", "mods/doors/sounds/doors_steel_door_open.ogg", 0.85),
                 ("kenney", f"{KRPG}/metalLatch.ogg", 0.7)]
    for i, (repo, rel, rate) in enumerate(latch_src, 1):
        x = lp(trim(hp(load(src(repo, rel), rate), 70)), 6000)
        save(fade(match(x, t_mech)), f"doors/unlatch_{i:02d}.ogg")
    # 2) Rangido metálico DURANTE o movimento (dobradiça, afinada para baixo)
    creaks = [f"{KRPG}/creak{i}.ogg" for i in (1, 2, 3)]
    for i, (rel, rate) in enumerate([(creaks[0], 0.55), (creaks[1], 0.5), (creaks[2], 0.45)], 1):
        x = lp(hp(load(src("kenney", rel), rate), 90), 4000)
        x = fade(match(trim(x, thr=0.03), 10 ** (-17 / 20)), out_ms=120, in_ms=30)
        save(x, f"doors/creak_open_{i:02d}.ogg")
    for i, (rel, rate) in enumerate([(creaks[1], 0.42), (creaks[0], 0.47), (creaks[2], 0.4)], 1):
        x = lp(hp(load(src("kenney", rel), rate), 90), 3500)
        x = fade(match(trim(x, thr=0.03), 10 ** (-18 / 20)), out_ms=120, in_ms=30)
        save(x, f"doors/creak_close_{i:02d}.ogg")
    # 3) Batida surda ao chegar TOTALMENTE ABERTA (batente)
    for i, n in enumerate([0, 3, 1], 1):
        x = lp(trim(hp(load(src("kimpact", f"{KIMP}/impactMetal_medium_00{n}.ogg"), 0.75), 60)), 2500)
        save(fade(match(x, 10 ** (-17 / 20)), out_ms=60), f"doors/stop_open_{i:02d}.ogg")
    # 4) BATIDA de fechamento: porta de aço real + chapa pesada para dar massa
    slam_bases = [("mtg", "mods/doors/sounds/doors_steel_door_close.ogg", 0.9),
                  ("cdda", f"{CDDA}/close_door/gun_safe/close_safe.ogg", 0.8),
                  ("mtg", "mods/doors/sounds/doors_steel_door_close.ogg", 0.8)]
    for i, (repo, rel, rate) in enumerate(slam_bases, 1):
        base = trim(hp(load(src(repo, rel), rate), 50))
        plate = lp(trim(hp(load(src("kimpact", f"{KIMP}/impactPlate_heavy_00{i}.ogg"), 0.7), 40)), 1800)
        latch = lp(trim(hp(load(src("kenney", f"{KRPG}/metalLatch.ogg"), 0.9), 200)), 7000)
        x = mix((match(base, 0.25), 0, 0), (match(plate, 0.25), -5, 0.0), (match(latch, 0.25), -14, 0.07))
        save(fade(match(x, 10 ** (-9 / 20)), out_ms=150), f"doors/slam_{i:02d}.ogg")
    # 5) Porta TRANCADA: maçaneta forçada (trinco batendo duas vezes)
    for i, (r1, r2) in enumerate([(0.85, 0.8), (0.75, 0.72)], 1):
        a = trim(hp(load(src("kenney", f"{KRPG}/metalLatch.ogg"), r1), 80))
        b = trim(hp(load(src("kenney", f"{KRPG}/metalClick.ogg"), r2), 80))
        x = mix((match(a, 0.25), 0, 0), (match(b, 0.25), -4, 0.16), (match(a, 0.25), -2, 0.34))
        save(fade(match(x, t_mech)), f"doors/locked_{i:02d}.ogg")


# --------------------------------------------------------------- interface
def ui():
    print("Interface:")
    x = hp(load(src("kenney", f"{KUI}/click3.ogg")), 100)
    save(fade(match(trim(x), 10 ** (-20 / 20))), "ui/click.ogg")
    x = hp(load(src("kenney", f"{KUI}/rollover2.ogg")), 100)
    save(fade(match(trim(x), 10 ** (-26 / 20))), "ui/hover.ogg")


if __name__ == "__main__":
    fetch()
    footsteps()
    doors()
    ui()
    print("Concluído.")
