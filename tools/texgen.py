"""Procedural, tileable PBR textures for The Jekyll Island Club.

Every texture here is painted from math, so there are no outside downloads and no
licensing to track. Each material writes three files into godot/textures/:

    <name>_albedo.jpg   color (sRGB)
    <name>_normal.jpg   OpenGL-style normal map (green points up)
    <name>_orm.jpg      R = ambient occlusion, G = roughness, B = metallic

Run it with any Python that has numpy, scipy and Pillow:

    python tools/texgen.py              # everything
    python tools/texgen.py brick plaster # just these

All noise is periodic on the tile, so every texture repeats without a seam.
"""
import os
import sys
import time

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.spatial import cKDTree

N = 1024
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "godot", "textures")


# ---------------------------------------------------------------- helpers
def rng(seed):
    return np.random.default_rng(seed)


def norm01(a, lo=0.5, hi=99.5):
    a0, a1 = np.percentile(a, [lo, hi])
    return np.clip((a - a0) / max(a1 - a0, 1e-9), 0.0, 1.0)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def lerp(a, b, t):
    t = np.asarray(t, dtype=np.float64)
    if t.ndim == 2 and (np.ndim(a) in (1, 3) or np.ndim(b) in (1, 3)):
        t = t[..., None]
    return a + (b - a) * t


def col(hexs):
    h = hexs.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def grid(n=N):
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    return x / n, y / n


def vnoise(freq_x, freq_y=None, seed=0, n=N, order=3):
    """Periodic value noise with freq_x cells across and freq_y cells down."""
    freq_y = freq_y or freq_x
    g = rng(seed).random((freq_y, freq_x))
    z = ndimage.zoom(g, (n / freq_y, n / freq_x), order=order, mode="grid-wrap", grid_mode=True)
    return z[:n, :n]


def fbm(freq, octaves=5, seed=0, gain=0.5, lac=2, aniso=1.0, n=N):
    """Fractal value noise. aniso > 1 stretches features along x (grain)."""
    out = np.zeros((n, n))
    amp = 1.0
    total = 0.0
    f = freq
    for i in range(octaves):
        fx = min(n, max(1, int(round(f / aniso))))
        fy = min(n, max(1, int(round(f))))
        if f / aniso > n * 2 and f > n * 2:
            break
        out += vnoise(fx, fy, seed + i * 101, n) * amp
        total += amp
        amp *= gain
        f *= lac
    return out / total


def spectral(beta=2.0, seed=0, fmin=1.0, fmax=None, n=N):
    """1/f^beta noise from filtered white noise. Periodic by construction."""
    w = rng(seed).standard_normal((n, n))
    F = np.fft.fft2(w)
    k = np.fft.fftfreq(n) * n
    f = np.sqrt(k[:, None] ** 2 + k[None, :] ** 2)
    f[0, 0] = 1.0
    amp = f ** (-beta / 2.0)
    amp[f < fmin] = 0.0
    if fmax:
        amp[f > fmax] = 0.0
    return norm01(np.real(np.fft.ifft2(F * amp)))


def worley(count, seed=0, n=N, jitter_pts=None, k=2):
    """Periodic cellular noise. Returns (F1, F2, cell_id) with distances in tile units."""
    pts = rng(seed).random((count, 2)) if jitter_pts is None else jitter_pts
    tree = cKDTree(pts * n, boxsize=n)
    y, x = np.mgrid[0:n, 0:n]
    q = np.stack([x.ravel() + 0.5, y.ravel() + 0.5], axis=1)
    d, idx = tree.query(q, k=k)
    d = d / n
    return d[:, 0].reshape(n, n), d[:, 1].reshape(n, n), idx[:, 0].reshape(n, n)


def warp(img, dx, dy):
    """Sample img at (x + dx, y + dy) in pixels, wrapping around."""
    n = img.shape[0]
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    if img.ndim == 3:
        return np.stack([ndimage.map_coordinates(img[..., c], [y + dy, x + dx], order=1, mode="grid-wrap") for c in range(img.shape[2])], axis=-1)
    return ndimage.map_coordinates(img, [y + dy, x + dx], order=1, mode="grid-wrap")


def blur(a, s):
    return ndimage.gaussian_filter(a, s, mode="wrap")


def cavity_ao(h, radius=6.0, strength=2.5):
    """Darken what sits below its neighborhood."""
    d = blur(h, radius) - h
    return np.clip(1.0 - np.clip(d, 0, None) * strength, 0.0, 1.0)


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * h.shape[0] / 256.0
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * h.shape[0] / 256.0
    nx = -dx * strength
    ny = dy * strength
    nz = np.ones_like(h)
    L = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / L, ny / L, nz / L], axis=-1)


def per_cell(ids, count, seed, lo=0.0, hi=1.0):
    return rng(seed).uniform(lo, hi, count)[ids]


def scratches(count, seed, length=(0.02, 0.12), width=1.2, n=N, angle=None):
    """Thin random lines, periodic. Returns 0..1 mask."""
    r = rng(seed)
    img = Image.new("L", (n * 3, n * 3), 0)
    from PIL import ImageDraw
    d = ImageDraw.Draw(img)
    for _ in range(count):
        x, y = r.random() * n, r.random() * n
        a = r.random() * np.pi if angle is None else angle + r.normal(0, 0.15)
        L = r.uniform(*length) * n
        v = int(r.uniform(80, 255))
        for ox in (0, n, 2 * n):
            for oy in (0, n, 2 * n):
                d.line([(x + ox, y + oy), (x + ox + np.cos(a) * L, y + oy + np.sin(a) * L)], fill=v, width=max(1, int(width)))
    a = np.asarray(img, dtype=np.float64) / 255.0
    a = a[n:2 * n, n:2 * n]
    return blur(a, 0.6)


def save(name, albedo, height, rough, ao=None, metal=None, nstrength=4.0, normal=None, size=N):
    os.makedirs(OUT, exist_ok=True)
    if ao is None:
        ao = cavity_ao(height)
    if metal is None:
        metal = np.zeros_like(height)
    if normal is None:
        normal = normal_from_height(height, nstrength)

    def to_img(a, mode, px):
        a = np.clip(a, 0.0, 1.0)
        img = Image.fromarray((a * 255.0 + 0.5).astype(np.uint8), mode)
        if px != a.shape[0]:
            img = img.resize((px, px), Image.LANCZOS)
        return img

    # color keeps full size; bumps and roughness read fine at half size and weigh a quarter
    to_img(np.clip(albedo, 0, 1), "RGB", size).save(os.path.join(OUT, name + "_albedo.jpg"), quality=88, subsampling=0)
    to_img(normal * 0.5 + 0.5, "RGB", size // 2).save(os.path.join(OUT, name + "_normal.jpg"), quality=88, subsampling=0)
    orm = np.stack([ao, np.clip(rough, 0.03, 1.0), metal], axis=-1)
    to_img(orm, "RGB", size // 2).save(os.path.join(OUT, name + "_orm.jpg"), quality=85, subsampling=0)


def tint_var(base_hex, amount, noise):
    """Color that wanders around base by amount, driven by a 0..1 noise field."""
    c = col(base_hex)
    v = (noise - 0.5) * 2.0 * amount
    return np.clip(c[None, None, :] * (1.0 + v[..., None]), 0, 1)


def hue_jitter(rgb, seed, amount=0.04, freq=6):
    r = [fbm(freq, 4, seed + i * 7) - 0.5 for i in range(3)]
    return np.clip(rgb + np.stack(r, axis=-1) * amount * 2.0, 0, 1)


def rows_layout(n_rows, seed, min_len, max_len, stagger=True):
    """Board / block layout in tile units. Returns (row_id, cell_id, u_in_cell, v_in_cell, cell_w, cell_count)."""
    x, y = grid()
    r = rng(seed)
    row = np.minimum((y * n_rows).astype(int), n_rows - 1)
    v = y * n_rows - row
    cell_ids = np.zeros_like(row)
    u_in = np.zeros_like(x)
    w_cell = np.zeros_like(x)
    cid = 0
    for ri in range(n_rows):
        # random widths that sum to exactly one tile, then a random rotation for stagger
        widths = []
        while sum(widths) < 1.0 - 1e-9:
            widths.append(r.uniform(min_len, max_len))
        widths[-1] -= sum(widths) - 1.0
        if widths[-1] < min_len * 0.5 and len(widths) > 1:
            widths[-2] += widths[-1]
            widths.pop()
        off = r.random() if stagger else 0.0
        edges = np.concatenate([[0.0], np.cumsum(widths)])
        m = row == ri
        xs = (x[m] - off) % 1.0
        k = np.searchsorted(edges, xs, side="right") - 1
        k = np.clip(k, 0, len(widths) - 1)
        u_in[m] = (xs - edges[k]) / np.array(widths)[k]
        w_cell[m] = np.array(widths)[k]
        cell_ids[m] = cid + k
        cid += len(widths)
    return row, cell_ids, u_in, v, w_cell, cid


def edge_dist(u, v, w_cell, n_rows, bevel_u, bevel_v):
    """Distance to the cell border, normalised by bevel width (0 at edge, 1 inside)."""
    du = np.minimum(u, 1 - u) * w_cell  # in tile units
    dv = np.minimum(v, 1 - v) / n_rows
    return np.minimum(du / bevel_u, dv / bevel_v)


# ---------------------------------------------------------------- wood
def wood_grain(seed, rings=26.0, fiber=1.0, n=N):
    """Grain running along x. Returns (tone 0..1, fiber 0..1)."""
    x, y = grid(n)
    w1 = fbm(3, 4, seed, aniso=6.0, n=n)
    w2 = fbm(8, 3, seed + 5, aniso=4.0, n=n)
    ring = y * rings + (w1 - 0.5) * 7.0 + (w2 - 0.5) * 1.2
    r = 0.5 + 0.5 * np.sin(ring * 2 * np.pi)
    r = r ** 2.2
    fib = fbm(64, 4, seed + 9, aniso=24.0, n=n)
    fine = fbm(256, 2, seed + 13, aniso=30.0, n=n)
    tone = r * 0.55 + fib * 0.3 * fiber + fine * 0.15 * fiber
    knots_f1, _, _ = worley(5, seed + 21, n)
    knot = smooth(0.035, 0.0, knots_f1)
    tone = np.clip(tone * (1 - knot * 0.5) + knot * 0.05, 0, 1)
    return norm01(tone), fib


def wood_planks(name, seed, base, dark, n_rows=8, min_len=0.35, max_len=1.0, gap_dark=0.12, rough=(0.55, 0.8), wear=0.5, nstr=5.0):
    row, cid, u, v, w, count = rows_layout(n_rows, seed, min_len, max_len)
    tone, fib = wood_grain(seed + 3)
    # each board samples the grain at its own offset so neighbors don't match
    offx = per_cell(cid, count, seed + 1, 0, N)
    offy = per_cell(cid, count, seed + 2, 0, N)
    tone_b = warp(tone, offx, offy)
    fib_b = warp(fib, offx, offy)
    board_tint = per_cell(cid, count, seed + 4, -1, 1)
    e = edge_dist(u, v, w, n_rows, 0.004, 0.006)
    bevel = smooth(0.0, 1.0, e)
    gap = 1.0 - smooth(0.0, 0.35, e)
    wear_n = fbm(6, 4, seed + 30)
    scr = scratches(260, seed + 31, (0.01, 0.06), 1.0)
    c_light = col(base)
    c_dark = col(dark)
    alb = lerp(c_dark[None, None, :], c_light[None, None, :], tone_b)
    alb *= (1.0 + board_tint[..., None] * 0.12)
    worn = smooth(0.55, 0.8, wear_n) * wear
    alb = lerp(alb, alb * 1.18 + 0.03, worn * (1 - gap))
    alb = lerp(alb, np.ones(3) * gap_dark * c_dark, gap * 0.85)
    alb = lerp(alb, alb * 0.72, scr * 0.5)
    alb = hue_jitter(alb, seed + 40, 0.015)
    h = bevel * 0.7 + tone_b * 0.08 + fib_b * 0.12 - scr * 0.05 + fbm(16, 4, seed + 41) * 0.06
    ro = lerp(np.full_like(h, rough[0]), np.full_like(h, rough[1]), np.clip(fib_b * 0.6 + gap * 0.8 - worn * 0.3, 0, 1))
    ao = cavity_ao(h, 4, 3.0) * (1 - gap * 0.6)
    save(name, alb, h, ro, ao, nstrength=nstr)


def wood_solid(name, seed, base, dark, rings=22.0, rough=(0.45, 0.7), nstr=2.5):
    tone, fib = wood_grain(seed, rings)
    alb = lerp(col(dark)[None, None, :], col(base)[None, None, :], tone)
    alb = hue_jitter(alb, seed + 1, 0.012)
    scr = scratches(160, seed + 2, (0.01, 0.05), 1.0)
    alb = lerp(alb, alb * 1.25, scr * 0.35)
    h = tone * 0.15 + fib * 0.2 - scr * 0.05
    ro = rough[0] + (rough[1] - rough[0]) * np.clip(fib * 0.7 + scr * 0.4, 0, 1)
    save(name, alb, h, ro, cavity_ao(h, 3, 1.0), nstrength=nstr)


def parquet(name, seed):
    """Herringbone parquet, worn along a traffic path."""
    x, y = grid()
    s = 8.0  # 8 herringbone repeats per tile
    X = x * s
    Y = y * s
    a = (X + Y)
    b = (Y - X)
    # blocks: alternate orientation in a checker of 45 degree stripes
    ia = np.floor(a).astype(int)
    ib = np.floor(b * 2.0).astype(int)
    fa = a - ia
    fb = b * 2.0 - ib
    orient = (ia + ib) % 2
    cid = (ia * 131 + ib * 71) % 997
    tone, fib = wood_grain(seed + 7, 30.0)
    tone2, fib2 = wood_grain(seed + 8, 30.0)
    t_rot = np.rot90(tone2)
    offx = per_cell(cid, 997, seed + 1, 0, N)
    t1 = warp(tone, offx, offx * 0.37)
    t2 = warp(t_rot, offx * 0.61, offx)
    t = np.where(orient == 0, t1, t2)
    e = np.minimum(np.minimum(fa, 1 - fa) * 1.0, np.minimum(fb, 1 - fb) * 0.5) * N / s
    gap = 1.0 - smooth(0.0, 2.5, e)
    tint = per_cell(cid, 997, seed + 3, -1, 1)
    c1, c0 = col("#a8743f"), col("#4a2a14")
    alb = lerp(c0[None, None, :], c1[None, None, :], t)
    alb *= 1.0 + tint[..., None] * 0.1
    wear = smooth(0.5, 0.85, fbm(4, 4, seed + 9))
    alb = lerp(alb, alb * 1.12 + 0.02, wear * 0.6)
    alb = lerp(alb, np.array([0.05, 0.03, 0.02]), gap * 0.8)
    h = (1 - gap) * 0.6 + t * 0.1
    ro = 0.35 + 0.35 * np.clip(gap + (1 - wear) * 0.3 + fib * 0.2, 0, 1)
    save(name, alb, h, ro, cavity_ao(h, 3, 3.0), nstrength=4.0)


def siding(name, seed):
    """Painted lap siding, weathered, paint worn to grey wood in places."""
    x, y = grid()
    rows = 10
    v = (y * rows) % 1.0
    ridx = np.floor(y * rows).astype(int)
    lap = v ** 0.8
    shadow = smooth(0.0, 0.08, v)
    tone, fib = wood_grain(seed, 18.0)
    tone = warp(tone, per_cell(ridx, rows, seed + 1, 0, N), 0)
    paint_n = fbm(24, 5, seed + 2, aniso=3.0)
    edge_bias = smooth(0.35, 0.0, v) * 0.18  # paint goes first along the drip edge
    peel = smooth(0.86, 0.9, paint_n + fib * 0.1 + edge_bias)
    paint = np.array([0.86, 0.85, 0.8])
    wood = lerp(np.array([0.22, 0.2, 0.18]), np.array([0.46, 0.43, 0.39]), tone)
    alb = lerp(paint[None, None, :] * (0.92 + 0.08 * fbm(30, 3, seed + 3))[..., None], wood, peel)
    grime = smooth(0.3, 1.0, fbm(3, 4, seed + 4, aniso=0.25))  # vertical streaks
    alb *= (1 - grime * 0.22)[..., None]
    alb *= (0.55 + 0.45 * shadow)[..., None]
    h = lap * 0.8 + fib * 0.05 * (1 + peel) - peel * 0.04
    ro = 0.55 + 0.35 * peel
    save(name, alb, h, ro, cavity_ao(h, 6, 1.5) * (0.6 + 0.4 * shadow), nstrength=6.0)


def painted_wood(name, seed, base="#e8e2d4"):
    tone, fib = wood_grain(seed, 20.0)
    brush = fbm(40, 3, seed + 1, aniso=10.0)
    chip_n = fbm(28, 5, seed + 2)
    chip = smooth(0.8, 0.83, chip_n)
    wood = lerp(np.array([0.2, 0.15, 0.1]), np.array([0.45, 0.35, 0.25]), tone)
    alb = lerp(col(base)[None, None, :] * (0.93 + 0.07 * brush)[..., None], wood, chip)
    alb *= (1 - 0.18 * smooth(0.4, 1.0, fbm(4, 4, seed + 3)))[..., None]
    h = brush * 0.05 + (1 - chip) * 0.25 + fib * chip * 0.08
    ro = 0.5 + 0.3 * chip + brush * 0.08
    save(name, alb, h, ro, nstrength=3.0)


def rough_timber(name, seed):
    """Old rough-sawn boards: crates, sheds, beams."""
    tone, fib = wood_grain(seed, 12.0, 1.6)
    saw = 0.5 + 0.5 * np.sin(grid()[0] * 2 * np.pi * 90 + fbm(8, 3, seed + 1) * 6)
    alb = lerp(col("#2f261d"), col("#8a7560"), tone)
    weather = smooth(0.3, 0.9, fbm(5, 5, seed + 2))
    grey = np.array([0.42, 0.4, 0.37])
    alb = lerp(alb, grey * (0.7 + 0.3 * tone[..., None]), weather * 0.6)
    h = fib * 0.3 + tone * 0.15 + saw * 0.03
    ro = 0.75 + 0.2 * fib
    save(name, alb, h, ro, nstrength=5.0)


# ---------------------------------------------------------------- masonry
def masonry(name, seed, n_rows, min_len, max_len, stone_hex, stone_dark, mortar_hex, mortar_w=0.004, chip=0.6, rough=0.85, stagger=True, pit=0.3, nstr=7.0, tint_amt=0.18, moss=0.0):
    row, cid, u, v, w, count = rows_layout(n_rows, seed, min_len, max_len, stagger)
    e = edge_dist(u, v, w, n_rows, mortar_w * 3.0, mortar_w * 3.0)
    # chipped, uneven edges
    ce = e + (fbm(24, 4, seed + 1) - 0.5) * chip
    body = smooth(0.25, 0.75, ce)
    dome = smooth(0.0, 3.5, ce) * 0.25
    surf = fbm(12, 6, seed + 2)
    pits = smooth(0.62, 0.72, fbm(80, 3, seed + 3)) * pit
    tint = per_cell(cid, count, seed + 4, -1, 1)
    tone = per_cell(cid, count, seed + 5, 0, 1)
    c = lerp(col(stone_dark)[None, None, :], col(stone_hex)[None, None, :], np.clip(surf * 0.6 + tone * 0.4, 0, 1))
    c = c * (1.0 + tint[..., None] * tint_amt)
    c = hue_jitter(c, seed + 6, 0.02, 8)
    mort = col(mortar_hex)[None, None, :] * (0.85 + 0.3 * fbm(60, 3, seed + 7))[..., None]
    alb = lerp(mort, c, body)
    alb *= (1 - pits * 0.5)[..., None]
    dirt = smooth(0.35, 1.0, fbm(4, 5, seed + 8, aniso=0.3))
    alb *= (1 - dirt * 0.25)[..., None]
    if moss > 0:
        mm = smooth(0.55, 0.75, fbm(10, 5, seed + 9)) * (1 - body * 0.6) * moss
        alb = lerp(alb, col("#3b4a22")[None, None, :] * (0.7 + 0.5 * fbm(90, 2, seed + 10))[..., None], mm)
    h = body * 0.55 + dome + surf * 0.18 - pits * 0.08
    ro = np.clip(rough - 0.1 * body * surf + (1 - body) * 0.1, 0, 1)
    save(name, alb, h, ro, cavity_ao(h, 5, 2.5), nstrength=nstr)


def cobblestone(name, seed, count=110):
    f1, f2, ids = worley(count, seed)
    edge = (f2 - f1) * np.sqrt(count)
    stone = smooth(0.02, 0.35, edge + (fbm(20, 3, seed + 1) - 0.5) * 0.1)
    dome = np.sqrt(np.clip(edge, 0, 1)) * 0.5
    surf = fbm(24, 5, seed + 2)
    tint = per_cell(ids, count, seed + 3, -1, 1)
    tone = per_cell(ids, count, seed + 4, 0, 1)
    c = lerp(col("#3a3833")[None, None, :], col("#8b857a")[None, None, :], np.clip(surf * 0.5 + tone * 0.5, 0, 1))
    c *= (1 + tint[..., None] * 0.12)
    dirt = col("#2c241b")[None, None, :] * (0.8 + 0.4 * fbm(50, 3, seed + 5))[..., None]
    alb = lerp(dirt, c, stone)
    wet = smooth(0.5, 0.9, fbm(3, 4, seed + 6))
    alb *= (1 - wet * 0.25)[..., None]
    moss = smooth(0.55, 0.8, fbm(12, 4, seed + 7)) * (1 - stone)
    alb = lerp(alb, col("#34401e")[None, None, :], moss * 0.8)
    h = stone * 0.4 + dome * stone + surf * 0.1
    ro = np.clip(0.8 - stone * 0.25 * (1 - surf) - wet * 0.3, 0.15, 1)
    save(name, alb, h, ro, cavity_ao(h, 4, 3.0), nstrength=7.0)


def gravel(name, seed):
    layers = []
    alb = np.zeros((N, N, 3))
    h = np.zeros((N, N))
    base = col("#2a2622")
    alb[:] = base
    for i, (cnt, s) in enumerate([(900, 1.0), (2600, 0.6), (6000, 0.35)]):
        f1, f2, ids = worley(cnt, seed + i * 10)
        e = (f2 - f1) * np.sqrt(cnt)
        st = smooth(0.05, 0.3, e + (fbm(40, 2, seed + i) - 0.5) * 0.15)
        tone = per_cell(ids, cnt, seed + i * 10 + 1, 0.25, 1.0)
        c = np.stack([tone * 0.62, tone * 0.6, tone * 0.56], axis=-1)
        c *= (1 + per_cell(ids, cnt, seed + i * 10 + 2, -0.15, 0.15))[..., None]
        hh = st * (0.3 + np.sqrt(np.clip(e, 0, 1)) * 0.5) * s
        top = hh > h
        alb = np.where(top[..., None], c, alb)
        h = np.maximum(h, hh)
    rust = smooth(0.6, 0.85, fbm(6, 4, seed + 50))
    alb = lerp(alb, alb * np.array([1.2, 0.85, 0.6]), rust * 0.5)
    save(name, alb, h, 0.85 - h * 0.2, cavity_ao(h, 3, 4.0), nstrength=6.0)


def plaster(name, seed, base="#d9d0bd", cracks=0.6, stains=0.5):
    x, y = grid()
    low = fbm(6, 6, seed)
    fine = fbm(128, 3, seed + 1)
    f1, f2, _ = worley(60, seed + 2)
    ce = (f2 - f1)
    ce = warp(ce, (fbm(20, 3, seed + 3) - 0.5) * 30, (fbm(20, 3, seed + 4) - 0.5) * 30)
    crack = (1 - smooth(0.0, 0.004, ce)) * smooth(0.55, 0.7, fbm(5, 4, seed + 5)) * cracks
    stain = smooth(0.45, 0.95, fbm(3, 5, seed + 6, aniso=0.35)) * stains
    c = col(base)[None, None, :] * (0.9 + 0.12 * low + 0.05 * fine)[..., None]
    c = lerp(c, c * np.array([0.78, 0.72, 0.6]), stain)
    c = lerp(c, c * 0.45, crack)
    c = hue_jitter(c, seed + 7, 0.012, 4)
    h = low * 0.25 + fine * 0.08 - crack * 0.15
    save(name, c, h, 0.8 + fine * 0.1, cavity_ao(h, 6, 2.0), nstrength=4.0)


def wallpaper(name, seed, base="#2a4232", figure="#6d8a5e"):
    """Faded Victorian wallpaper: stripes and a small repeating medallion, stained and lifting."""
    x, y = grid()
    s = 8.0
    X = (x * s) % 1.0 - 0.5
    Y = (y * s) % 1.0 - 0.5
    r = np.sqrt(X * X + Y * Y)
    th = np.arctan2(Y, X)
    petal = smooth(0.02, 0.0, np.abs(r - (0.2 + 0.08 * np.cos(th * 4))) - 0.025)
    dot = smooth(0.09, 0.06, r)
    stripe = smooth(0.012, 0.0, np.abs(((x * s * 2) % 1.0) - 0.5) - 0.47)
    fig = np.clip(petal + dot + stripe * 0.8, 0, 1)
    c = lerp(col(base)[None, None, :], col(figure)[None, None, :], fig * 0.8)
    fade = fbm(4, 5, seed)
    c = lerp(c, c * 1.25 + 0.04, smooth(0.5, 1.0, fade) * 0.5)
    stain = smooth(0.5, 1.0, fbm(3, 5, seed + 1, aniso=0.3))
    c = lerp(c, c * np.array([0.7, 0.62, 0.45]), stain * 0.6)
    seam = smooth(0.004, 0.0, np.abs(((x * 2) % 1.0) - 0.5) - 0.497)
    c *= (1 - seam * 0.5)[..., None]
    fine = fbm(200, 2, seed + 2)
    c *= (0.95 + 0.08 * fine)[..., None]
    h = fig * 0.05 + fine * 0.05 + fade * 0.1
    save(name, c, h, 0.75 + fig * 0.08, nstrength=2.0)


def concrete(name, seed, base="#8a857c"):
    low = fbm(5, 6, seed)
    fine = fbm(160, 3, seed + 1)
    pores = smooth(0.7, 0.8, fbm(200, 2, seed + 2))
    f1, f2, _ = worley(25, seed + 3)
    crack = (1 - smooth(0.0, 0.003, warp(f2 - f1, (fbm(16, 3, seed + 4) - 0.5) * 40, 0))) * smooth(0.6, 0.7, fbm(4, 4, seed + 5))
    c = col(base)[None, None, :] * (0.8 + 0.3 * low + 0.1 * fine)[..., None]
    c = lerp(c, c * 0.6, smooth(0.5, 1.0, fbm(3, 5, seed + 6)) * 0.6)
    c *= (1 - pores * 0.3 - crack * 0.5)[..., None]
    h = low * 0.2 + fine * 0.08 - pores * 0.05 - crack * 0.2
    save(name, c, h, 0.85 + fine * 0.1, nstrength=4.0)


def slate_roof(name, seed):
    n_rows = 16
    row, cid, u, v, w, count = rows_layout(n_rows, seed, 0.06, 0.1)
    edge_bottom = smooth(0.0, 0.08, 1 - v + (fbm(40, 3, seed + 1) - 0.5) * 0.15)
    side = smooth(0.0, 0.02, np.minimum(u, 1 - u) * w)
    lap = (1 - v) * 0.5 + 0.5
    tone = per_cell(cid, count, seed + 2, 0, 1)
    c = lerp(col("#1c2024")[None, None, :], col("#4b525a")[None, None, :], np.clip(tone * 0.6 + fbm(30, 4, seed + 3) * 0.4, 0, 1))
    lichen = smooth(0.72, 0.8, fbm(20, 5, seed + 4))
    c = lerp(c, col("#6f7250")[None, None, :], lichen * 0.35)
    c *= (0.5 + 0.5 * edge_bottom * side)[..., None]
    h = lap * edge_bottom * side + fbm(60, 3, seed + 5) * 0.05
    save(name, c, h, 0.65 + lichen * 0.2, cavity_ao(h, 4, 2.0), nstrength=6.0)


def tin_roof(name, seed):
    x, y = grid()
    corr = 0.5 + 0.5 * np.sin(x * 2 * np.pi * 24)
    rust = smooth(0.45, 0.75, fbm(6, 6, seed) + (1 - y) * 0.0)
    streak = smooth(0.3, 1.0, fbm(24, 4, seed + 1, aniso=0.1)) * rust
    base = lerp(np.array([0.42, 0.44, 0.45]), np.array([0.3, 0.31, 0.32]), fbm(16, 4, seed + 2))
    rc = lerp(col("#5a2d14")[None, None, :], col("#9a5226")[None, None, :], fbm(50, 3, seed + 3))
    c = lerp(base, rc, np.clip(rust * 0.8 + streak * 0.5, 0, 1))
    h = corr * 0.6 + rust * 0.05
    metal = 1 - np.clip(rust * 1.2, 0, 1)
    save(name, c, h, 0.45 + rust * 0.45, metal=metal * 0.8, nstrength=8.0)


# ---------------------------------------------------------------- metal
def iron(name, seed, rust_amt=0.5):
    base = fbm(20, 5, seed)
    pits = smooth(0.66, 0.74, fbm(120, 3, seed + 1))
    rust = smooth(0.78 - 0.3 * rust_amt, 0.9 - 0.3 * rust_amt, fbm(8, 6, seed + 2))
    c_iron = lerp(np.array([0.08, 0.08, 0.085]), np.array([0.2, 0.2, 0.21]), base)
    c_rust = lerp(col("#2a140a")[None, None, :], col("#6a3818")[None, None, :], fbm(60, 3, seed + 3))
    c = lerp(c_iron, c_rust, rust)
    c *= (1 - pits * 0.3)[..., None]
    h = base * 0.1 + rust * 0.12 - pits * 0.1
    metal = (1 - rust) * 0.9
    save(name, c, h, 0.45 + rust * 0.45 + pits * 0.1, metal=metal, nstrength=4.0)


def painted_metal(name, seed, rivets=True):
    """Train car and machinery panels: painted steel with seams, rivets, chips and grime."""
    x, y = grid()
    c = np.full((N, N, 3), 0.8)
    paint = 0.82 + 0.1 * fbm(20, 4, seed)
    seam_v = smooth(0.003, 0.0, np.abs(((x * 2) % 1.0) - 0.5) - 0.497)
    seam_h = smooth(0.003, 0.0, np.abs(((y * 2) % 1.0) - 0.5) - 0.497)
    seam = np.maximum(seam_v, seam_h)
    riv = np.zeros_like(x)
    if rivets:
        for axis, sx in ((x, y), (y, x)):
            d_line = np.abs(((axis * 2) % 1.0) - 0.5) - 0.47
            along = (sx * 32) % 1.0 - 0.5
            dd = np.sqrt(np.clip(np.abs(d_line) * 32, 0, None) ** 2 + (along) ** 2)
            riv = np.maximum(riv, smooth(0.28, 0.16, dd))
    chips = smooth(0.84, 0.87, fbm(30, 5, seed + 1) + seam * 0.12)
    grime = smooth(0.3, 1.0, fbm(5, 5, seed + 2, aniso=0.2))
    c = c * paint[..., None]
    c = lerp(c, np.array([0.12, 0.11, 0.1]), chips)
    c = lerp(c, c * np.array([0.55, 0.5, 0.42]), grime * 0.5)
    c *= (1 - seam * 0.5)[..., None]
    h = riv * 0.6 - seam * 0.2 - chips * 0.05 + fbm(80, 2, seed + 3) * 0.02
    save(name, c, h, 0.4 + chips * 0.4 + grime * 0.2, metal=chips * 0.6, nstrength=6.0)


def brass(name, seed):
    base = fbm(24, 5, seed)
    tarn = smooth(0.55, 0.85, fbm(6, 6, seed + 1))
    rub = smooth(0.6, 0.9, fbm(4, 4, seed + 2))
    c = lerp(col("#7a5a26")[None, None, :], col("#c9a45a")[None, None, :], base * 0.5 + rub * 0.5)
    c = lerp(c, col("#2e2a18")[None, None, :], tarn * (1 - rub) * 0.8)
    scr = scratches(200, seed + 3, (0.01, 0.04))
    h = base * 0.05 - scr * 0.03
    save(name, c, h, 0.28 + tarn * 0.45 + scr * 0.1, metal=np.full_like(h, 0.95), nstrength=2.0)


# ---------------------------------------------------------------- cloth, leather, paper, skin
def weave(name, seed, base, threads=160, twill=False, flecks=0.0, fleck_cols=(), fuzz=0.3, rough=0.9, nstr=3.0, slub=0.0):
    x, y = grid()
    if twill:
        warp_t = 0.5 + 0.5 * np.sin((x + y) * 2 * np.pi * threads * 0.5)
        weft_t = 0.5 + 0.5 * np.sin((x - y * 0.2) * 2 * np.pi * threads)
    else:
        warp_t = 0.5 + 0.5 * np.sin(x * 2 * np.pi * threads)
        weft_t = 0.5 + 0.5 * np.sin(y * 2 * np.pi * threads)
    over = (np.floor(x * threads) + np.floor(y * threads)) % 2
    wv = np.where(over > 0, warp_t, weft_t)
    fz = fbm(256, 2, seed)
    sl = fbm(12, 3, seed + 1, aniso=8.0) * slub
    c = col(base)[None, None, :] * (0.9 + 0.1 * wv + 0.05 * fz - 0.05 * sl)[..., None]
    if flecks > 0 and fleck_cols:
        r = rng(seed + 2)
        for i, fc in enumerate(fleck_cols):
            m = smooth(0.8, 0.86, fbm(200, 1, seed + 10 + i)) * flecks
            c = lerp(c, col(fc)[None, None, :], m)
    c = lerp(c, c * 0.9, smooth(0.5, 1, fbm(4, 4, seed + 3)) * fuzz)
    h = wv * 0.4 + fz * 0.15 + sl * 0.15
    save(name, c, h, rough - 0.05 * wv, cavity_ao(h, 2, 2.0), nstrength=nstr)


def rug(name, seed):
    """Worn Persian-style rug field: medallions, lattice, border stripes, faded where walked on."""
    x, y = grid()
    s = 2.0
    X = (x * s) % 1.0 - 0.5
    Y = (y * s) % 1.0 - 0.5
    r = np.sqrt(X * X + Y * Y)
    th = np.arctan2(Y, X)
    diamond = np.abs(X) + np.abs(Y)
    med = smooth(0.02, 0.0, np.abs(diamond - 0.32) - 0.02) + smooth(0.02, 0.0, np.abs(r - (0.14 + 0.04 * np.cos(th * 8))) - 0.015)
    center = smooth(0.07, 0.05, r)
    petals = smooth(0.02, 0.0, np.abs(r - 0.24) - 0.01) * (0.5 + 0.5 * np.cos(th * 12))
    lattice = smooth(0.015, 0.0, np.abs(np.abs(X) - np.abs(Y)) - 0.005) * smooth(0.46, 0.4, diamond)
    field = col("#6e1a17")
    navy = col("#1a2436")
    gold = col("#b58a3a")
    cream = col("#cdbb94")
    c = np.ones((N, N, 3)) * field
    c = lerp(c, navy[None, None, :], np.clip(med, 0, 1))
    c = lerp(c, gold[None, None, :], np.clip(petals + center * 0.8, 0, 1))
    c = lerp(c, cream[None, None, :], np.clip(lattice * 0.6, 0, 1))
    pile = fbm(300, 2, seed)
    c *= (0.82 + 0.3 * pile)[..., None]
    wear = smooth(0.4, 0.9, fbm(3, 5, seed + 1))
    c = lerp(c, c * 0.7 + 0.12, wear * 0.45)
    h = pile * 0.4 + np.clip(med + petals, 0, 1) * 0.05
    save(name, c, h, np.full_like(h, 0.95), nstrength=2.5)


def leather(name, seed, base="#5a3420"):
    f1, f2, _ = worley(1800, seed)
    grain = smooth(0.0, 0.012, f2 - f1)
    crease = smooth(0.6, 0.75, fbm(10, 5, seed + 1, aniso=2.0))
    wear = smooth(0.55, 0.85, fbm(5, 5, seed + 2))
    c = col(base)[None, None, :] * (0.8 + 0.2 * grain + 0.1 * fbm(40, 3, seed + 3))[..., None]
    c = lerp(c, c * 1.5 + 0.05, wear * 0.4)
    c = lerp(c, c * 0.6, crease * 0.5)
    scr = scratches(120, seed + 4, (0.01, 0.05))
    c = lerp(c, c * 1.4, scr * 0.4)
    h = grain * 0.2 - crease * 0.2 - scr * 0.05
    save(name, c, h, 0.5 + (1 - grain) * 0.15 + wear * 0.15, nstrength=3.0)


def paper(name, seed, base="#e2d3ad"):
    fibers = fbm(200, 3, seed, aniso=3.0)
    low = fbm(4, 5, seed + 1)
    foxing = smooth(0.8, 0.86, fbm(40, 3, seed + 2)) * 0.6
    c = col(base)[None, None, :] * (0.9 + 0.08 * fibers + 0.1 * low)[..., None]
    c = lerp(c, c * np.array([0.75, 0.6, 0.4]), np.clip(foxing + smooth(0.6, 1.0, low) * 0.3, 0, 1))
    h = fibers * 0.1 + low * 0.1
    save(name, c, h, 0.85 + fibers * 0.1, nstrength=1.5)


def skin(name, seed, base="#f2e8e2"):
    pores = fbm(300, 2, seed)
    blotch = fbm(8, 5, seed + 1)
    red = smooth(0.5, 0.9, fbm(5, 4, seed + 2))
    c = col(base)[None, None, :] * (0.92 + 0.1 * blotch + 0.03 * pores)[..., None]
    c = lerp(c, c * np.array([1.08, 0.88, 0.85]), red * 0.35)
    h = pores * 0.15 + blotch * 0.1
    save(name, c, h, 0.55 + pores * 0.1, nstrength=1.5)


def straw(name, seed):
    x, y = grid()
    s = 40
    over = (np.floor(x * s) + np.floor(y * s * 0.5)) % 2
    a = 0.5 + 0.5 * np.sin(y * 2 * np.pi * s * 6)
    b = 0.5 + 0.5 * np.sin(x * 2 * np.pi * s * 6)
    wv = np.where(over > 0, a, b)
    cell_x = np.abs((x * s) % 1.0 - 0.5)
    cell_y = np.abs((y * s * 0.5) % 1.0 - 0.5)
    bev = smooth(0.5, 0.35, np.maximum(cell_x, cell_y))
    c = lerp(col("#6e5428")[None, None, :], col("#d8b878")[None, None, :], wv * 0.5 + bev * 0.5)
    c *= (0.85 + 0.2 * fbm(20, 3, seed))[..., None]
    h = bev * 0.5 + wv * 0.2
    save(name, c, h, 0.7 + (1 - bev) * 0.2, nstrength=4.0)


def cork(name, seed):
    f1, f2, ids = worley(9000, seed)
    t = per_cell(ids, 9000, seed + 1, 0, 1)
    c = lerp(col("#5a3a1e")[None, None, :], col("#b88a55")[None, None, :], t * 0.7 + fbm(60, 3, seed + 2) * 0.3)
    h = smooth(0.0, 0.01, f2 - f1) * 0.3 + t * 0.2
    save(name, c, h, np.full_like(h, 0.9), nstrength=3.0)


def chalkboard(name, seed):
    base = fbm(8, 5, seed)
    smudge = smooth(0.4, 0.9, fbm(3, 5, seed + 1, aniso=3.0))
    swirl = scratches(90, seed + 2, (0.05, 0.3), 3.0, angle=0.1)
    c = lerp(np.array([0.08, 0.1, 0.09]), np.array([0.13, 0.15, 0.14]), base)
    c = lerp(c, np.array([0.34, 0.36, 0.35]), np.clip(smudge * 0.35 + blur(swirl, 3) * 0.3, 0, 1))
    h = base * 0.05
    save(name, c, h, 0.85 - smudge * 0.1, nstrength=1.0)


def honeycomb(name, seed):
    """Hexagonal comb: wax walls, honey-filled cells, some capped with pale wax."""
    x, y = grid()
    cols_n, rows_n = 24, 28
    pts = []
    for j in range(rows_n):
        for i in range(cols_n):
            pts.append(((i + 0.5 * (j % 2)) / cols_n, (j + 0.5) / rows_n))
    pts = np.array(pts) % 1.0
    f1, f2, ids = worley(len(pts), seed, jitter_pts=pts)
    wall = 1 - smooth(0.0, 0.004, f2 - f1)
    cnt = len(pts)
    capped = per_cell(ids, cnt, seed + 1, 0, 1) > 0.55
    fill = per_cell(ids, cnt, seed + 2, 0.5, 1.0)
    honey = lerp(col("#6a3408")[None, None, :], col("#e39a25")[None, None, :], np.clip(fill - f1 * 20, 0, 1))
    cap = col("#e8cf8a")[None, None, :] * (0.85 + 0.2 * fbm(80, 3, seed + 3))[..., None]
    c = np.where(capped[..., None], cap, honey)
    c = lerp(c, col("#d9b26a")[None, None, :], wall)
    h = np.where(capped, 0.7 - f1 * 3, 0.2 + f1 * 6) * (1 - wall) + wall
    ro = np.where(capped, 0.6, 0.12) * (1 - wall) + wall * 0.5
    save(name, c, h, ro, nstrength=6.0)


# ---------------------------------------------------------------- nature
def grass_ground(name, seed):
    x, y = grid()
    blades = fbm(180, 3, seed, aniso=0.25)
    blades2 = fbm(180, 3, seed + 1, aniso=4.0)
    clump_f1, clump_f2, cid = worley(300, seed + 2)
    clump = smooth(0.03, 0.0, clump_f1)
    dry = smooth(0.45, 0.8, fbm(5, 5, seed + 3))
    bare = smooth(0.62, 0.78, fbm(4, 5, seed + 4))
    g1 = col("#2e3a17")
    g2 = col("#5b6a2c")
    dead = col("#7a6a3e")
    dirt = col("#3b2e20")
    c = lerp(g1[None, None, :], g2[None, None, :], np.clip(blades * 0.6 + blades2 * 0.4, 0, 1))
    c = lerp(c, dead[None, None, :] * (0.8 + 0.3 * blades)[..., None], dry * 0.7)
    c = lerp(c, dirt[None, None, :] * (0.8 + 0.4 * fbm(60, 3, seed + 5))[..., None], bare)
    leaves = smooth(0.8, 0.84, fbm(90, 2, seed + 6))
    c = lerp(c, col("#6a4524")[None, None, :], leaves * 0.8)
    c *= (0.85 + clump * 0.2)[..., None]
    h = (blades * 0.5 + blades2 * 0.3) * (1 - bare * 0.7) + clump * 0.2
    save(name, c, h, 0.9 - bare * 0.1, cavity_ao(h, 3, 2.0), nstrength=4.0)


def dirt(name, seed, base="#5a4330", pebbles=0.6, clay=False):
    low = fbm(6, 6, seed)
    fine = fbm(140, 3, seed + 1)
    f1, f2, ids = worley(1500, seed + 2)
    peb = smooth(0.2, 0.5, (f2 - f1) * 40) * (per_cell(ids, 1500, seed + 3, 0, 1) > 1 - pebbles * 0.4)
    ruts = smooth(0.3, 0.9, fbm(4, 4, seed + 4, aniso=0.2))
    c = col(base)[None, None, :] * (0.75 + 0.35 * low + 0.1 * fine)[..., None]
    if clay:
        c = lerp(c, c * np.array([1.2, 0.85, 0.7]), smooth(0.4, 0.8, fbm(8, 4, seed + 5)) * 0.5)
    c = lerp(c, np.array([0.45, 0.42, 0.38]) * (0.7 + 0.5 * per_cell(ids, 1500, seed + 6, 0, 1))[..., None], peb)
    wet = smooth(0.55, 0.9, fbm(3, 5, seed + 7))
    c *= (1 - wet * 0.3)[..., None]
    h = low * 0.25 + fine * 0.1 + peb * 0.3 - ruts * 0.1
    save(name, c, h, np.clip(0.9 - wet * 0.45, 0.2, 1), cavity_ao(h, 3, 2.5), nstrength=5.0)


def bark(name, seed):
    x, y = grid()
    ridges = fbm(10, 6, seed + 1, aniso=0.12)
    plates = smooth(0.35, 0.6, ridges + (fbm(40, 3, seed + 2, aniso=0.3) - 0.5) * 0.3)
    furrow = 1 - plates
    c = lerp(col("#1f1a16")[None, None, :], col("#6b6258")[None, None, :], plates * (0.7 + 0.3 * fbm(60, 3, seed + 3)))
    lichen = smooth(0.66, 0.74, fbm(14, 5, seed + 4)) * plates
    c = lerp(c, col("#7d8a6a")[None, None, :], lichen * 0.6)
    moss = smooth(0.6, 0.8, fbm(8, 5, seed + 5)) * furrow
    c = lerp(c, col("#2f3a18")[None, None, :], moss * 0.7)
    h = plates * 0.7 + fbm(80, 3, seed + 6) * 0.1
    save(name, c, h, 0.9 - lichen * 0.1, cavity_ao(h, 5, 3.0), nstrength=9.0)


def foliage(name, seed, dark="#1d2a12", light="#56682c"):
    f1, f2, ids = worley(2400, seed)
    leaf = smooth(0.0, 0.01, f2 - f1)
    tone = per_cell(ids, 2400, seed + 1, 0, 1)
    c = lerp(col(dark)[None, None, :], col(light)[None, None, :], np.clip(tone * 0.7 + leaf * 0.3, 0, 1))
    c *= (0.7 + 0.4 * fbm(6, 4, seed + 2))[..., None]
    h = leaf * 0.5 + tone * 0.3
    save(name, c, h, 0.7 - tone * 0.2, cavity_ao(h, 3, 3.0), nstrength=5.0)


def spanish_moss(name, seed):
    strands = fbm(220, 3, seed, aniso=0.08)
    c = lerp(col("#3d4234")[None, None, :], col("#9a9e84")[None, None, :], strands)
    h = strands * 0.6
    save(name, c, h, np.full_like(h, 0.95), nstrength=6.0)


def macro_noise(name="macro", seed=900):
    """Large-scale grayscale variation the world shader uses to break up tiling."""
    a = fbm(4, 7, seed)
    b = fbm(9, 5, seed + 1)
    c = fbm(2, 6, seed + 2)
    img = np.stack([a, b, c], axis=-1)
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray((img * 255).astype(np.uint8), "RGB").resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))


# ---------------------------------------------------------------- foliage cards (RGBA)
def _card(name, draw_fn, seed, size=1024, out=512):
    from PIL import ImageDraw
    r = rng(seed)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_fn(d, r, size)
    img = img.resize((out, out), Image.LANCZOS)
    a = np.asarray(img).astype(np.float64)
    # bleed color into the transparent edge so mipmaps don't go dark at the rims
    rgb = a[..., :3]
    al = a[..., 3:4] / 255.0
    blurred = np.stack([ndimage.gaussian_filter(rgb[..., c] * al[..., 0], 6) for c in range(3)], -1)
    wsum = ndimage.gaussian_filter(al[..., 0], 6)[..., None] + 1e-6
    fill = blurred / wsum
    rgb = np.where(al > 0.02, rgb, fill)
    out_img = np.concatenate([rgb, a[..., 3:4]], -1)
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(np.clip(out_img, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name + ".png"))


def _leaf_color(r, dark, light, dead=0.0):
    t = r.random()
    c = col(dark) + (col(light) - col(dark)) * t
    if r.random() < dead:
        c = col("#6a5a2a") * (0.8 + 0.4 * r.random())
    return tuple(int(v * 255) for v in np.clip(c, 0, 1)) + (255,)


def leaves_card(name, seed, dark, light, count=900, leaf=(10, 22), dead=0.04):
    def draw(d, r, S):
        cx, cy = S / 2, S / 2
        for i in range(count):
            # clustered toward the middle, thinning at the rim
            ang = r.random() * 2 * np.pi
            rad = (r.random() ** 0.6) * S * 0.46
            x, y = cx + np.cos(ang) * rad, cy + np.sin(ang) * rad * 0.9
            L = r.uniform(*leaf) * S / 512
            W = L * r.uniform(0.35, 0.55)
            th = r.random() * np.pi
            pts = []
            for k in range(12):
                a2 = 2 * np.pi * k / 12
                px = np.cos(a2) * L
                py = np.sin(a2) * W * (1.0 - 0.3 * np.cos(a2))
                pts.append((x + px * np.cos(th) - py * np.sin(th), y + px * np.sin(th) + py * np.cos(th)))
            c = _leaf_color(r, dark, light, dead)
            # leaves deeper in the clump are darker
            f = 0.55 + 0.45 * (rad / (S * 0.46))
            c = (int(c[0] * f), int(c[1] * f), int(c[2] * f), 255)
            d.polygon(pts, fill=c)
        # a few twigs
        for i in range(14):
            ang = r.random() * 2 * np.pi
            L = r.uniform(0.2, 0.45) * S
            d.line([(cx, cy), (cx + np.cos(ang) * L, cy + np.sin(ang) * L)], fill=(40, 32, 24, 255), width=max(1, S // 256))
    _card(name, draw, seed)


def needles_card(name, seed):
    def draw(d, r, S):
        for b in range(14):
            x0, y0 = r.uniform(0.15, 0.85) * S, r.uniform(0.15, 0.85) * S
            ang = r.uniform(0, 2 * np.pi)
            L = r.uniform(0.25, 0.45) * S
            x1, y1 = x0 + np.cos(ang) * L, y0 + np.sin(ang) * L
            d.line([(x0, y0), (x1, y1)], fill=(52, 40, 30, 255), width=max(2, S // 200))
            for k in range(170):
                t = r.random()
                px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
                a2 = ang + r.choice([-1, 1]) * r.uniform(0.4, 1.1)
                nl = r.uniform(0.04, 0.08) * S
                c = _leaf_color(r, "#1c2a16", "#4a5e2a", 0.03)
                d.line([(px, py), (px + np.cos(a2) * nl, py + np.sin(a2) * nl)], fill=c, width=max(1, S // 400))
    _card(name, draw, seed)


def palmetto_card(name, seed):
    def draw(d, r, S):
        for f in range(3):
            cx, cy = S * r.uniform(0.35, 0.65), S * r.uniform(0.55, 0.75)
            base_ang = -np.pi / 2 + r.uniform(-0.6, 0.6)
            R = S * r.uniform(0.3, 0.42)
            d.line([(cx, cy), (cx, S)], fill=(60, 50, 30, 255), width=max(2, S // 150))
            for k in range(26):
                a2 = base_ang + (k / 25 - 0.5) * 2.4
                w = 0.045
                pts = [(cx, cy), (cx + np.cos(a2 - w) * R, cy + np.sin(a2 - w) * R), (cx + np.cos(a2) * R * 1.05, cy + np.sin(a2) * R * 1.05),
                       (cx + np.cos(a2 + w) * R, cy + np.sin(a2 + w) * R)]
                c = _leaf_color(r, "#1c3018", "#4a6a30", 0.08)
                d.polygon(pts, fill=c)
    _card(name, draw, seed)


def moss_card(name, seed):
    def draw(d, r, S):
        for i in range(260):
            x = r.uniform(0.05, 0.95) * S
            L = S * r.uniform(0.25, 0.98) * (1 - abs(x / S - 0.5) * 0.9)
            pts = []
            y = 0
            wob = r.uniform(4, 12) * S / 512
            ph = r.random() * 6
            while y < L:
                pts.append((x + np.sin(y / S * 20 + ph) * wob, y))
                y += S / 64
            g = int(r.uniform(90, 170))
            c = (int(g * 0.95), g, int(g * 0.82), 255)
            if len(pts) > 1:
                d.line(pts, fill=c, width=max(1, int(S / r.uniform(260, 520))))
    _card(name, draw, seed)


def grass_card(name, seed, dry=0.25):
    def draw(d, r, S):
        for i in range(90):
            bx = S * (0.5 + r.normal(0, 0.16))
            H = S * r.uniform(0.35, 0.98)
            lean = r.normal(0, 0.18) * S
            w = S * r.uniform(0.008, 0.018)
            dead = r.random() < dry
            c = _leaf_color(r, "#6a5a34" if dead else "#26361a", "#9a8a58" if dead else "#6a7e36", 0.0)
            pts = [(bx - w, S), (bx + lean * 0.5 + w * 0.3, S - H * 0.55), (bx + lean, S - H), (bx + lean * 0.5 - w * 0.3, S - H * 0.5), (bx + w, S)]
            d.polygon(pts, fill=c)
    _card(name, draw, seed)


# ---------------------------------------------------------------- the catalog
CATALOG = {
    "macro": lambda: macro_noise(),
    "stone_blocks": lambda: masonry("stone_blocks", 11, 6, 0.18, 0.4, "#8a8274", "#4d473f", "#5e574c", mortar_w=0.005, chip=0.8, moss=0.5),
    "stone_foundation": lambda: masonry("stone_foundation", 12, 5, 0.2, 0.45, "#6f6a60", "#35312b", "#403b33", mortar_w=0.007, chip=1.2, moss=1.0, nstr=9.0),
    "brick": lambda: masonry("brick", 13, 16, 0.24, 0.24, "#8a4a32", "#4a2418", "#8c8274", mortar_w=0.0035, chip=0.4, tint_amt=0.25, nstr=6.0),
    "cobblestone": lambda: cobblestone("cobblestone", 14),
    "gravel": lambda: gravel("gravel", 15),
    "plaster": lambda: plaster("plaster", 16),
    "plaster_dark": lambda: plaster("plaster_dark", 17, base="#8f8270", cracks=0.8, stains=0.8),
    "wallpaper": lambda: wallpaper("wallpaper", 18),
    "concrete": lambda: concrete("concrete", 19),
    "wood_planks": lambda: wood_planks("wood_planks", 20, "#7a5a3c", "#2e1f14"),
    "wood_porch": lambda: wood_planks("wood_porch", 21, "#8a8070", "#3a342c", n_rows=10, wear=0.8),
    "wood_dark": lambda: wood_solid("wood_dark", 22, "#5a3a22", "#1c110a"),
    "wood_light": lambda: wood_solid("wood_light", 23, "#b08a5c", "#5e4128", rings=16),
    "parquet": lambda: parquet("parquet", 24),
    "siding": lambda: siding("siding", 25),
    "painted_wood": lambda: painted_wood("painted_wood", 26),
    "rough_timber": lambda: rough_timber("rough_timber", 27),
    "slate_roof": lambda: slate_roof("slate_roof", 28),
    "tin_roof": lambda: tin_roof("tin_roof", 29),
    "iron": lambda: iron("iron", 30),
    "iron_clean": lambda: iron("iron_clean", 31, rust_amt=0.05),
    "painted_metal": lambda: painted_metal("painted_metal", 32),
    "brass": lambda: brass("brass", 33),
    "wool": lambda: weave("wool", 34, "#9a9a9a", threads=220, twill=True, fuzz=0.4),
    "tweed": lambda: weave("tweed", 35, "#8a8a82", threads=140, twill=True, flecks=0.35, fleck_cols=("#c9b48a", "#3a2a1a", "#6a2a2a"), slub=0.6),
    "linen": lambda: weave("linen", 36, "#e9e4d8", threads=260, slub=0.8, fuzz=0.2, rough=0.85),
    "velvet": lambda: weave("velvet", 37, "#8a8a8a", threads=400, fuzz=0.7, rough=0.95, nstr=1.0),
    "rug": lambda: rug("rug", 38),
    "leather": lambda: leather("leather", 39),
    "paper": lambda: paper("paper", 40),
    "skin": lambda: skin("skin", 41),
    "straw": lambda: straw("straw", 42),
    "cork": lambda: cork("cork", 43),
    "chalkboard": lambda: chalkboard("chalkboard", 44),
    "honeycomb": lambda: honeycomb("honeycomb", 45),
    "grass_ground": lambda: grass_ground("grass_ground", 46),
    "dirt": lambda: dirt("dirt", 47),
    "red_clay": lambda: dirt("red_clay", 48, base="#7a4a30", pebbles=0.3, clay=True),
    "bark": lambda: bark("bark", 49),
    "foliage": lambda: foliage("foliage", 50),
    "palmetto": lambda: foliage("palmetto", 51, "#1c2a18", "#4a6a32"),
    "spanish_moss": lambda: spanish_moss("spanish_moss", 52),
    "card_oak": lambda: leaves_card("card_oak", 60, "#141e10", "#3e5226", count=1100, leaf=(8, 16)),
    "card_shrub": lambda: leaves_card("card_shrub", 61, "#16220f", "#44582a", count=700, leaf=(12, 22), dead=0.08),
    "card_pine": lambda: needles_card("card_pine", 62),
    "card_palmetto": lambda: palmetto_card("card_palmetto", 63),
    "card_moss": lambda: moss_card("card_moss", 64),
    "card_grass": lambda: grass_card("card_grass", 65),
}


if __name__ == "__main__":
    names = sys.argv[1:] or list(CATALOG.keys())
    for nm in names:
        t = time.time()
        CATALOG[nm]()
        print(f"{nm:18s} {time.time() - t:5.1f}s", flush=True)
