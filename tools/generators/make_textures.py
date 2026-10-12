#!/usr/bin/env python3
"""Gera as texturas procedurais ORIGINAIS do Pânico no Servidor.

Todas são criadas do zero (ruído matemático), portanto não há licença de
terceiros envolvida. Requer: Python 3, numpy, scipy, Pillow.
Uso:  python tools/generators/make_textures.py
Saída: assets/textures/*.png   (todas repetíveis/"tileable")
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "textures")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1337)


def fbm(n, beta=2.0, seed=None):
    """Ruído fractal tileável via espectro 1/f^beta (FFT é periódica)."""
    r = np.random.default_rng(seed) if seed is not None else rng
    w = r.standard_normal((n, n))
    f = np.fft.fft2(w)
    fx = np.fft.fftfreq(n)[:, None]
    fy = np.fft.fftfreq(n)[None, :]
    k = np.sqrt(fx * fx + fy * fy)
    k[0, 0] = 1.0
    f *= 1.0 / k ** (beta / 2.0)
    f[0, 0] = 0
    out = np.real(np.fft.ifft2(f))
    out -= out.min()
    out /= out.max()
    return out


def blur(a, s):
    return ndimage.gaussian_filter(a, s, mode="wrap")


def norm01(a):
    a = a - a.min()
    return a / max(a.max(), 1e-6)


def to_img(rgb):
    return Image.fromarray(np.clip(rgb * 255.0, 0, 255).astype(np.uint8))


def save_rgb(name, rgb):
    to_img(rgb).save(os.path.join(OUT, name))


def save_gray(name, g):
    Image.fromarray(np.clip(g * 255.0, 0, 255).astype(np.uint8), "L").save(os.path.join(OUT, name))


def normal_from_height(h, strength=4.0):
    """Mapa de normais no padrão OpenGL (Y+), que é o usado pelo Godot."""
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * strength
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * strength
    nx, ny, nz = -dx, dy, np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / l * 0.5 + 0.5, ny / l * 0.5 + 0.5, nz / l * 0.5 + 0.5], axis=-1)


def tint(g, c0, c1):
    c0 = np.array(c0)[None, None, :]
    c1 = np.array(c1)[None, None, :]
    return c0 + (c1 - c0) * g[..., None]


def vertical_streaks(n, count, seed):
    """Escorridos verticais de umidade/ferrugem (tileável no eixo X e Y)."""
    r = np.random.default_rng(seed)
    s = np.zeros((n, n))
    for _ in range(count):
        x = r.integers(0, n)
        y0 = r.integers(0, n)
        length = r.integers(n // 6, n // 1.5)
        width = r.uniform(1.5, 6.0)
        strength = r.uniform(0.3, 1.0)
        ys = (y0 + np.arange(length)) % n
        fade = np.linspace(1.0, 0.0, length) ** 1.5 * strength
        s[ys, x] += fade
    s = ndimage.gaussian_filter1d(s, 2.5, axis=1, mode="wrap")
    s = ndimage.gaussian_filter1d(s, 1.0, axis=0, mode="wrap")
    return norm01(s)


N = 1024

# ---------------------------------------------------------------- concreto
base = fbm(N, 2.2, 1)
fine = fbm(N, 1.0, 2)
pores = (fbm(N, 0.6, 3) > 0.78).astype(float)
pores = blur(pores, 0.7)
stains = norm01(blur(fbm(N, 2.6, 4), 6)) ** 2.2
streaks = vertical_streaks(N, 70, 5)
g = 0.55 + 0.25 * (base - 0.5) + 0.12 * (fine - 0.5) - 0.25 * pores
g -= 0.35 * stains + 0.22 * streaks
g = np.clip(g, 0, 1)
albedo = tint(g, (0.10, 0.10, 0.10), (0.62, 0.61, 0.58))
# leve esverdeado/marrom de umidade nas manchas
albedo[..., 1] += 0.015 * stains
albedo[..., 2] -= 0.03 * stains
save_rgb("concrete_wall_albedo.png", albedo)
h = 0.6 * base + 0.25 * fine - 0.5 * pores
save_rgb("concrete_wall_normal.png", normal_from_height(blur(h, 0.8), 6.0))
save_gray("concrete_wall_rough.png", np.clip(0.82 + 0.15 * fine - 0.25 * streaks, 0, 1))

# ------------------------------------------------------------- piso (concreto selado + juntas)
base = fbm(N, 2.0, 11)
fine = fbm(N, 0.9, 12)
scuff = norm01(blur(fbm(N, 1.4, 13), 1.5))
dirt = norm01(blur(fbm(N, 2.4, 14), 10)) ** 2.0
yy, xx = np.mgrid[0:N, 0:N]
# junta de dilatação a cada meia textura (textura cobre 4 m -> placas de 2 m)
joint = np.zeros((N, N))
for p in (0, N // 2):
    joint = np.maximum(joint, np.exp(-((np.minimum(np.abs(xx - p), N - np.abs(xx - p))) ** 2) / 6.0))
    joint = np.maximum(joint, np.exp(-((np.minimum(np.abs(yy - p), N - np.abs(yy - p))) ** 2) / 6.0))
g = 0.42 + 0.18 * (base - 0.5) + 0.08 * (fine - 0.5) - 0.28 * dirt + 0.08 * (scuff > 0.7)
g = np.clip(g - 0.3 * joint, 0, 1)
albedo = tint(g, (0.05, 0.05, 0.05), (0.50, 0.50, 0.48))
save_rgb("floor_concrete_albedo.png", albedo)
save_rgb("floor_concrete_normal.png", normal_from_height(blur(0.4 * base + 0.2 * fine - 1.2 * joint, 0.8), 5.0))
# piso selado: mais liso (brilho) onde não há sujeira -> reflexos sutis das luzes
save_gray("floor_concrete_rough.png", np.clip(0.45 + 0.4 * dirt + 0.15 * fine, 0, 1))

# ---------------------------------------------------------- metal pintado descascado
n2 = 512
base = fbm(n2, 2.0, 21)
fine = fbm(n2, 0.8, 22)
chip_noise = norm01(blur(fbm(n2, 1.6, 23), 1.0))
chips = (chip_noise > 0.72).astype(float)
chips = blur(chips, 0.6)
rust = norm01(blur(fbm(n2, 2.0, 24), 3))
streaks = vertical_streaks(n2, 40, 25)
paint = 0.75 + 0.12 * (base - 0.5) + 0.05 * (fine - 0.5)
paint_rgb = tint(np.clip(paint, 0, 1), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))  # branco: a cor vem do material
rust_rgb = tint(rust, (0.16, 0.07, 0.03), (0.42, 0.20, 0.08))
m = np.clip(chips + 0.6 * streaks * (rust > 0.4), 0, 1)[..., None]
albedo = paint_rgb * (1 - m) + rust_rgb * m
albedo *= (1 - 0.35 * streaks)[..., None]
save_rgb("metal_painted_albedo.png", albedo)
save_rgb("metal_painted_normal.png", normal_from_height(blur(0.3 * fine - 0.8 * chips, 0.7), 4.0))
save_gray("metal_painted_rough.png", np.clip(0.55 + 0.35 * m[..., 0] + 0.1 * fine, 0, 1))

# ------------------------------------------------------------ metal enferrujado (canos)
base = fbm(n2, 1.8, 31)
fine = fbm(n2, 0.7, 32)
spots = norm01(blur(fbm(n2, 2.2, 33), 2))
g = np.clip(0.3 + 0.4 * base + 0.15 * fine, 0, 1)
steel = tint(g, (0.18, 0.18, 0.19), (0.45, 0.45, 0.46))
rust_rgb = tint(fine, (0.20, 0.08, 0.03), (0.50, 0.25, 0.10))
m = np.clip((spots - 0.45) * 3.0, 0, 1)[..., None]
save_rgb("metal_rusty_albedo.png", steel * (1 - m) + rust_rgb * m)
save_rgb("metal_rusty_normal.png", normal_from_height(blur(0.5 * fine + 0.4 * m[..., 0], 0.8), 3.0))
save_gray("metal_rusty_rough.png", np.clip(0.4 + 0.5 * m[..., 0] + 0.1 * fine, 0, 1))

# ------------------------------------------------------------ chapa xadrez (diamond plate)
n3 = 512
yy, xx = np.mgrid[0:n3, 0:n3] / n3
cell = 8
u = (xx * cell) % 1.0
v = (yy * cell) % 1.0
# losangos alternados em diagonal
d1 = np.abs((u - 0.25) + (v - 0.25)) + np.abs((u - 0.25) - (v - 0.25)) * 3.0
d2 = np.abs((u - 0.75) - (v - 0.75)) + np.abs((u - 0.75) + (v - 0.75)) * 3.0
bumps = np.clip(1.0 - d1 / 0.5, 0, 1) + np.clip(1.0 - d2 / 0.5, 0, 1)
bumps = np.clip(bumps * 2.0, 0, 1)
wear = fbm(n3, 1.5, 41)
dirt = norm01(blur(fbm(n3, 2.4, 42), 5)) ** 2
g = np.clip(0.35 + 0.2 * wear + 0.15 * bumps - 0.3 * dirt, 0, 1)
save_rgb("metal_plate_albedo.png", tint(g, (0.05, 0.05, 0.055), (0.62, 0.62, 0.64)))
save_rgb("metal_plate_normal.png", normal_from_height(blur(bumps, 1.0), 6.0))
save_gray("metal_plate_rough.png", np.clip(0.35 + 0.45 * dirt - 0.15 * bumps + 0.1 * wear, 0, 1))

# ------------------------------------------------------------ faixa de perigo amarela/preta
n4 = 512
yy, xx = np.mgrid[0:n4, 0:n4]
stripe = (((xx + yy) // (n4 // 8)) % 2).astype(float)
stripe = blur(stripe, 0.8)
wear = norm01(blur(fbm(n4, 1.7, 51), 1.0))
worn = (wear > 0.68).astype(float)
worn = blur(worn, 0.8)
dirt = norm01(blur(fbm(n4, 2.4, 52), 6))
yellow = np.array([0.80, 0.58, 0.05])
black = np.array([0.04, 0.04, 0.04])
rgb = yellow[None, None, :] * stripe[..., None] + black[None, None, :] * (1 - stripe[..., None])
under = tint(fbm(n4, 1.0, 53), (0.25, 0.24, 0.22), (0.40, 0.39, 0.36))
rgb = rgb * (1 - worn[..., None]) + under * worn[..., None]
rgb *= (1 - 0.45 * dirt)[..., None]
save_rgb("hazard_stripes_albedo.png", rgb)

# ------------------------------------------------------------ madeira de caixote
n5 = 512
yy, xx = np.mgrid[0:n5, 0:n5]
grain = fbm(n5, 1.2, 61)
grain = ndimage.gaussian_filter1d(grain, 10, axis=0, mode="wrap")  # veios alongados
planks = ((yy // (n5 // 4)) % 2).astype(float)
gaps = np.exp(-(((yy % (n5 // 4)) - 0) ** 2) / 4.0)
g = np.clip(0.45 + 0.35 * (norm01(grain) - 0.5) + 0.06 * planks - 0.5 * gaps, 0, 1)
dirt = norm01(blur(fbm(n5, 2.4, 62), 6)) ** 1.5
wood = tint(g, (0.12, 0.08, 0.04), (0.55, 0.40, 0.24)) * (1 - 0.4 * dirt)[..., None]
save_rgb("wood_crate_albedo.png", wood)
save_rgb("wood_crate_normal.png", normal_from_height(blur(0.3 * grain - gaps, 0.8), 3.0))

# ------------------------------------------------------------ decalques de sujeira (RGBA)
def stain_decal(name, seed, color, size=512, streak=False):
    r = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:size, 0:size] / size
    cx, cy = 0.5, 0.42 if streak else 0.5
    dist = np.sqrt((xx - cx) ** 2 + ((yy - cy) * (0.6 if streak else 1.0)) ** 2)
    n = fbm(size, 1.8, seed)
    mask = np.clip((0.42 - dist + 0.18 * (n - 0.5)) * 4.0, 0, 1)
    if streak:
        s = vertical_streaks(size, 25, seed + 1)
        s[: int(size * 0.3)] *= 0.2
        mask = np.clip(mask + s * (np.abs(xx - 0.5) < 0.3), 0, 1)
    mask *= 0.55 + 0.45 * fbm(size, 0.8, seed + 2)
    # borda zerada para não aparecer o retângulo do decal
    edge = np.clip(np.minimum.reduce([xx, 1 - xx, yy, 1 - yy]) * 12.0, 0, 1)
    a = np.clip(mask * edge, 0, 1)
    rgb = np.ones((size, size, 3)) * np.array(color)[None, None, :]
    rgba = np.dstack([rgb, a])
    Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name))


stain_decal("decal_grime.png", 71, (0.05, 0.045, 0.035))
stain_decal("decal_leak.png", 72, (0.10, 0.06, 0.03), streak=True)
stain_decal("decal_oil.png", 73, (0.02, 0.02, 0.025))

# ------------------------------------------------------------ "cookie" da lanterna
# Padrão projetado pela lanterna: centro quente, anel do refletor e bordas
# irregulares (sujeira na lente). Escala de cinza.
n6 = 256
yy, xx = np.mgrid[0:n6, 0:n6] / (n6 - 1) * 2 - 1
r = np.sqrt(xx ** 2 + yy ** 2)
hot = np.exp(-(r / 0.28) ** 2) * 0.55
body = np.clip(1.0 - (r / 0.95) ** 3, 0, 1) * 0.55
ring_ = np.exp(-((r - 0.62) / 0.05) ** 2) * 0.18
dirt = 0.9 + 0.1 * fbm(n6, 1.5, 81)
cookie = np.clip((hot + body + ring_) * dirt, 0, 1) * (r < 1.0)
save_gray("flashlight_cookie.png", cookie)

# ------------------------------------------------------------ poça d'água (decal)
n7 = 512
yy, xx = np.mgrid[0:n7, 0:n7] / (n7 - 1) * 2 - 1
shape_noise = blur(fbm(n7, 2.2, 91), 3)
r = np.sqrt((xx * 1.0) ** 2 + (yy * 1.25) ** 2) + 0.35 * (shape_noise - 0.5)
mask = np.clip((0.78 - r) * 6.0, 0, 1)
edge = np.clip(np.minimum.reduce([xx + 1, 1 - xx, yy + 1, 1 - yy]) * 8.0, 0, 1)
alpha = mask * edge
rgb = np.ones((n7, n7, 3)) * np.array([0.035, 0.04, 0.045])[None, None, :]
Image.fromarray((np.dstack([rgb, alpha * 0.92]) * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "decal_puddle_albedo.png"))
# ORM: R = oclusão (1), G = rugosidade (bem lisa no centro), B = metal (0)
rough = np.clip(0.05 + 0.5 * (1 - mask) + 0.05 * fbm(n7, 1.0, 92), 0, 1)
orm = np.dstack([np.ones_like(rough), rough, np.zeros_like(rough)])
Image.fromarray((orm * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, "decal_puddle_orm.png"))

print("Texturas geradas em", OUT)
