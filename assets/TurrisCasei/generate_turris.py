# -*- coding: utf-8 -*-
"""Turris Casei - casa medieval de quesos. Low-poly estilizado para Roblox.
   Footprint 40 x 50 studs, altura 25. Genera FBX + albedo + normal + previews."""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Euler

OUT = sys.argv[sys.argv.index("--") + 1]
os.makedirs(OUT, exist_ok=True)
TAU = math.tau

bpy.ops.wm.read_factory_settings(use_empty=True)

# ----------------------------------------------------------------- MATERIALES
PALETTE = [
    ("Stone",        (0.50, 0.48, 0.45), "stone"),
    ("StoneDark",    (0.34, 0.32, 0.31), "stone"),
    ("WoodDark",     (0.17, 0.09, 0.05), "wood"),
    ("WoodMid",      (0.33, 0.18, 0.09), "wood"),
    ("WoodLight",    (0.55, 0.36, 0.18), "wood"),
    ("Plaster",      (0.87, 0.79, 0.63), "plaster"),
    ("RoofTile",     (0.40, 0.15, 0.12), "tile"),
    ("Thatch",       (0.58, 0.42, 0.19), "thatch"),
    ("Emmental",     (0.98, 0.79, 0.28), "holes"),
    ("Cheddar",      (0.94, 0.52, 0.12), "holes_s"),
    ("BlueCheese",   (0.87, 0.85, 0.75), "blue"),
    ("Brie",         (0.96, 0.93, 0.81), "plaster"),
    ("Parmesan",     (0.92, 0.82, 0.52), "holes_s"),
    ("RindRed",      (0.60, 0.10, 0.09), "plaster"),
    ("RindWax",      (0.82, 0.68, 0.22), "plaster"),
    ("FabricRed",    (0.72, 0.18, 0.16), "cloth"),
    ("FabricCream",  (0.93, 0.88, 0.75), "cloth"),
    ("Metal",        (0.15, 0.14, 0.14), "metal"),
    ("Brass",        (0.72, 0.52, 0.16), "metal"),
    ("GlassWarm",    (1.00, 0.76, 0.35), "glow"),
    ("Leaf",         (0.22, 0.40, 0.15), "plaster"),
]


def ramp(nt, src, stops):
    n = nt.nodes.new("ShaderNodeValToRGB")
    el = n.color_ramp.elements
    while len(el) > 1:
        el.remove(el[-1])
    el[0].position = stops[0][0]
    el[0].color = (stops[0][1][0], stops[0][1][1], stops[0][1][2], 1.0)
    for pos, col in stops[1:]:
        e = el.new(pos)
        e.color = (col[0], col[1], col[2], 1.0)
    nt.links.new(src, n.inputs["Fac"])
    return n


def darker(c, f=0.55):
    return tuple(v * f for v in c)


def lighter(c, f=1.18):
    return tuple(min(1.0, v * f) for v in c)


def make_material(name, color, kind):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    b.inputs["Roughness"].default_value = 0.78
    coord = nt.nodes.new("ShaderNodeTexCoord")
    uv = coord.outputs["Object"]

    def bump(src, strength, dist=0.12):
        bp = nt.nodes.new("ShaderNodeBump")
        bp.inputs["Strength"].default_value = strength
        bp.inputs["Distance"].default_value = dist
        nt.links.new(src, bp.inputs["Height"])
        nt.links.new(bp.outputs["Normal"], b.inputs["Normal"])

    if kind in ("holes", "holes_s"):
        sc = 0.60 if kind == "holes" else 1.05
        thr = 0.20 if kind == "holes" else 0.13
        v = nt.nodes.new("ShaderNodeTexVoronoi")
        v.inputs["Scale"].default_value = sc
        v.inputs["Randomness"].default_value = 1.0
        nt.links.new(uv, v.inputs["Vector"])
        cr = ramp(nt, v.outputs["Distance"],
                  [(0.0, darker(color, 0.32)), (thr, darker(color, 0.55)),
                   (thr + 0.03, color), (1.0, lighter(color, 1.05))])
        nt.links.new(cr.outputs["Color"], b.inputs["Base Color"])
        hr = ramp(nt, v.outputs["Distance"],
                  [(0.0, (0, 0, 0)), (thr, (0.08, 0.08, 0.08)),
                   (thr + 0.035, (1, 1, 1)), (1.0, (1, 1, 1))])
        bump(hr.outputs["Color"], 1.0, 0.75)
        b.inputs["Roughness"].default_value = 0.62

    elif kind == "stone":
        v = nt.nodes.new("ShaderNodeTexVoronoi")
        v.inputs["Scale"].default_value = 1.1
        nt.links.new(uv, v.inputs["Vector"])
        cr = ramp(nt, v.outputs["Distance"],
                  [(0.0, darker(color, 0.7)), (0.06, darker(color, 0.8)),
                   (0.12, color), (1.0, lighter(color))])
        nt.links.new(cr.outputs["Color"], b.inputs["Base Color"])
        hr = ramp(nt, v.outputs["Distance"],
                  [(0.0, (0, 0, 0)), (0.08, (0.15, 0.15, 0.15)), (0.16, (1, 1, 1))])
        bump(hr.outputs["Color"], 0.75, 0.16)

    elif kind == "wood":
        w = nt.nodes.new("ShaderNodeTexWave")
        w.wave_type = 'BANDS'
        w.bands_direction = 'Z'
        w.inputs["Scale"].default_value = 2.2
        w.inputs["Distortion"].default_value = 6.0
        w.inputs["Detail"].default_value = 3.0
        nt.links.new(uv, w.inputs["Vector"])
        cr = ramp(nt, w.outputs["Fac"],
                  [(0.25, darker(color, 0.72)), (0.75, lighter(color, 1.12))])
        nt.links.new(cr.outputs["Color"], b.inputs["Base Color"])
        bump(w.outputs["Fac"], 0.35, 0.05)

    elif kind == "plaster":
        n = nt.nodes.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = 9.0
        n.inputs["Detail"].default_value = 6.0
        nt.links.new(uv, n.inputs["Vector"])
        cr = ramp(nt, n.outputs["Fac"],
                  [(0.3, darker(color, 0.9)), (0.7, lighter(color, 1.06))])
        nt.links.new(cr.outputs["Color"], b.inputs["Base Color"])
        bump(n.outputs["Fac"], 0.22, 0.04)

    elif kind == "tile":
        w = nt.nodes.new("ShaderNodeTexWave")
        w.wave_type = 'BANDS'
        w.bands_direction = 'Z'
        w.inputs["Scale"].default_value = 5.0
        w.inputs["Distortion"].default_value = 1.5
        nt.links.new(uv, w.inputs["Vector"])
        cr = ramp(nt, w.outputs["Fac"],
                  [(0.2, darker(color, 0.7)), (0.8, lighter(color, 1.2))])
        nt.links.new(cr.outputs["Color"], b.inputs["Base Color"])
        bump(w.outputs["Fac"], 0.85, 0.14)

    elif kind == "thatch":
        n = nt.nodes.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = 26.0
        n.inputs["Detail"].default_value = 8.0
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (1.0, 1.0, 7.0)
        nt.links.new(uv, mp.inputs["Vector"])
        nt.links.new(mp.outputs["Vector"], n.inputs["Vector"])
        cr = ramp(nt, n.outputs["Fac"],
                  [(0.3, darker(color, 0.72)), (0.75, lighter(color, 1.15))])
        nt.links.new(cr.outputs["Color"], b.inputs["Base Color"])
        bump(n.outputs["Fac"], 0.9, 0.1)

    elif kind == "blue":
        n = nt.nodes.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = 7.0
        n.inputs["Detail"].default_value = 9.0
        nt.links.new(uv, n.inputs["Vector"])
        cr = ramp(nt, n.outputs["Fac"],
                  [(0.38, color), (0.48, (0.42, 0.46, 0.44)),
                   (0.56, (0.28, 0.34, 0.36)), (0.66, color)])
        nt.links.new(cr.outputs["Color"], b.inputs["Base Color"])
        bump(n.outputs["Fac"], 0.3, 0.05)

    elif kind == "cloth":
        w = nt.nodes.new("ShaderNodeTexWave")
        w.wave_type = 'BANDS'
        w.bands_direction = 'X'
        w.inputs["Scale"].default_value = 14.0
        nt.links.new(uv, w.inputs["Vector"])
        bump(w.outputs["Fac"], 0.18, 0.03)
        b.inputs["Roughness"].default_value = 0.9

    elif kind == "metal":
        b.inputs["Metallic"].default_value = 0.85
        b.inputs["Roughness"].default_value = 0.38
        n = nt.nodes.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = 30.0
        nt.links.new(uv, n.inputs["Vector"])
        bump(n.outputs["Fac"], 0.12, 0.02)

    elif kind == "glow":
        b.inputs["Emission Color"].default_value = (color[0], color[1], color[2], 1.0)
        b.inputs["Emission Strength"].default_value = 2.4
        b.inputs["Roughness"].default_value = 0.25
    return m


# ------------------------------------------------------------------ GEOMETRIA
bm = bmesh.new()
MI = {k: i for i, (k, _, _) in enumerate(PALETTE)}


def _faces_of(verts):
    vs = set(verts)
    out = []
    for v in verts:
        for f in v.link_faces:
            if f in out:
                continue
            if all(x in vs for x in f.verts):
                out.append(f)
    return out


def paint(verts, mat):
    for f in _faces_of(verts):
        f.material_index = mat


def box(size, loc, mat, rot=None):
    r = bmesh.ops.create_cube(bm, size=1.0)
    vs = r['verts']
    bmesh.ops.scale(bm, vec=Vector(size), verts=vs)
    if rot:
        bmesh.ops.transform(bm, matrix=Euler(rot, 'XYZ').to_matrix().to_4x4(), verts=vs)
    bmesh.ops.translate(bm, vec=Vector(loc), verts=vs)
    paint(vs, mat)
    return vs


def cyl(r1, h, loc, mat, seg=16, r2=None, rot=None):
    r = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg,
                              radius1=r1, radius2=(r1 if r2 is None else r2), depth=h)
    vs = r['verts']
    if rot:
        bmesh.ops.transform(bm, matrix=Euler(rot, 'XYZ').to_matrix().to_4x4(), verts=vs)
    bmesh.ops.translate(bm, vec=Vector(loc), verts=vs)
    paint(vs, mat)
    return vs


def wheel(r, h, z0, mat, seg=20, cut=0.0, cx=0.0, cy=8.0, r_top=None, rot0=0.0):
    """Rueda de queso, con cuna opcional (cut en radianes)."""
    rt = r if r_top is None else r_top
    full = cut < 1e-6
    span = TAU - cut
    n = seg if full else max(4, int(seg * span / TAU))
    z1 = z0 + h
    top, bot = [], []
    cnt = n if full else n + 1
    for i in range(cnt):
        a = rot0 + ((TAU * i / n) if full else (0.5 * cut + span * i / n))
        top.append(bm.verts.new((cx + math.cos(a) * rt, cy + math.sin(a) * rt, z1)))
        bot.append(bm.verts.new((cx + math.cos(a) * r, cy + math.sin(a) * r, z0)))
    ct = bm.verts.new((cx, cy, z1))
    cb = bm.verts.new((cx, cy, z0))
    F = []
    for i in range(n):
        j = (i + 1) % cnt if full else i + 1
        F.append(bm.faces.new((bot[i], bot[j], top[j], top[i])))
        F.append(bm.faces.new((ct, top[i], top[j])))
        F.append(bm.faces.new((cb, bot[j], bot[i])))
    if not full:
        F.append(bm.faces.new((ct, cb, bot[0], top[0])))
        F.append(bm.faces.new((ct, top[-1], bot[-1], cb)))
    for f in F:
        f.material_index = mat
    return F


def frustum(lo, up, z0, z1, mat, cap=True):
    x0, y0, x1, y1 = lo
    X0, Y0, X1, Y1 = up
    b = [bm.verts.new(p) for p in ((x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0))]
    t = [bm.verts.new(p) for p in ((X0, Y0, z1), (X1, Y0, z1), (X1, Y1, z1), (X0, Y1, z1))]
    F = [bm.faces.new((b[i], b[(i + 1) % 4], t[(i + 1) % 4], t[i])) for i in range(4)]
    if cap:
        F.append(bm.faces.new(t))
    for f in F:
        f.material_index = mat
    return F


# ---- constantes de layout
BX, BY0, BY1 = 14.0, -4.0, 20.0
STONE_T, TIMBER_T, ROOF_T = 2.2, 6.8, 10.4
TCX, TCY = 0.0, 8.0
CY = (BY0 + BY1) / 2.0
JX, JY0, JY1 = BX + 0.6, BY0 - 0.6, BY1 + 0.6

# ---- planta de piedra + sillares de esquina embebidos
box((BX * 2, BY1 - BY0, STONE_T), (0, CY, STONE_T / 2), MI["Stone"])
for zq in (0.5, 1.6):
    for sx in (-1, 1):
        box((1.1, 1.1, 0.85), (sx * (BX - 0.3), BY0 + 0.3, zq), MI["StoneDark"])
        box((1.1, 1.1, 0.85), (sx * (BX - 0.3), BY1 - 0.3, zq), MI["StoneDark"])

# ---- piso entramado (jetty)
box((JX * 2, JY1 - JY0, TIMBER_T - STONE_T), (0, (JY0 + JY1) / 2, (STONE_T + TIMBER_T) / 2), MI["Plaster"])
box((JX * 2 + 0.3, JY1 - JY0 + 0.3, 0.45), (0, (JY0 + JY1) / 2, STONE_T + 0.15), MI["WoodDark"])


def timber_wall(const, rng, z0, z1, axis, sign):
    a, b_ = rng
    n = max(3, int((b_ - a) / 4.2))
    th, dp = 0.42, 0.34
    for i in range(n + 1):
        p = a + (b_ - a) * i / n
        loc = (const + sign * dp / 2, p, (z0 + z1) / 2) if axis == 'X' else (p, const + sign * dp / 2, (z0 + z1) / 2)
        sz = (dp, th, z1 - z0) if axis == 'X' else (th, dp, z1 - z0)
        box(sz, loc, MI["WoodDark"])
    for zz in (z0 + 0.22, z1 - 0.22):
        loc = (const + sign * dp / 2, (a + b_) / 2, zz) if axis == 'X' else ((a + b_) / 2, const + sign * dp / 2, zz)
        sz = (dp, b_ - a, 0.45) if axis == 'X' else (b_ - a, dp, 0.45)
        box(sz, loc, MI["WoodDark"])
    for i in range(n):
        p0 = a + (b_ - a) * i / n
        p1 = a + (b_ - a) * (i + 1) / n
        mid = (p0 + p1) / 2
        L = math.hypot(p1 - p0, z1 - z0 - 0.9)
        ang_ = math.atan2(z1 - z0 - 0.9, p1 - p0)
        for s in (1, -1):
            if axis == 'X':
                box((dp, L, 0.32), (const + sign * dp / 2, mid, (z0 + z1) / 2), MI["WoodMid"], rot=(s * ang_, 0, 0))
            else:
                box((L, dp, 0.32), (mid, const + sign * dp / 2, (z0 + z1) / 2), MI["WoodMid"], rot=(0, -s * ang_, 0))


timber_wall(JY0, (-JX, JX), STONE_T + 0.35, TIMBER_T, 'Y', -1)
timber_wall(JY1, (-JX, JX), STONE_T + 0.35, TIMBER_T, 'Y', 1)
timber_wall(-JX, (JY0, JY1), STONE_T + 0.35, TIMBER_T, 'X', -1)
timber_wall(JX, (JY0, JY1), STONE_T + 0.35, TIMBER_T, 'X', 1)


def window(loc, w, h, face):
    x, y, z = loc
    d = 0.5
    box((w, d, h) if face == 'Y' else (d, w, h), (x, y, z), MI["GlassWarm"])
    fr = 0.26
    if face == 'Y':
        box((w + fr * 2, d * 1.2, fr), (x, y, z + h / 2), MI["WoodDark"])
        box((w + fr * 2, d * 1.2, fr), (x, y, z - h / 2), MI["WoodDark"])
        box((fr, d * 1.2, h), (x - w / 2, y, z), MI["WoodDark"])
        box((fr, d * 1.2, h), (x + w / 2, y, z), MI["WoodDark"])
        box((0.14, d * 1.3, h), (x, y, z), MI["WoodDark"])
        box((w, d * 1.3, 0.14), (x, y, z), MI["WoodDark"])
    else:
        box((d * 1.2, w + fr * 2, fr), (x, y, z + h / 2), MI["WoodDark"])
        box((d * 1.2, w + fr * 2, fr), (x, y, z - h / 2), MI["WoodDark"])
        box((d * 1.2, fr, h), (x, y - w / 2, z), MI["WoodDark"])
        box((d * 1.2, fr, h), (x, y + w / 2, z), MI["WoodDark"])
        box((d * 1.3, 0.14, h), (x, y, z), MI["WoodDark"])
        box((d * 1.3, w, 0.14), (x, y, z), MI["WoodDark"])


WZ, WH = 4.5, 2.6
for xw in (-8.5, 8.5):
    window((xw, JY0, WZ), 2.8, WH, 'Y')
window((0, JY1, WZ), 3.2, WH, 'Y')
for yw in (2.0, 9.0, 16.0):
    window((-JX, yw, WZ), 2.8, WH, 'X')
    window((JX, yw, WZ), 2.8, WH, 'X')

# puerta
box((3.4, 0.6, 4.0), (0, BY0 - 0.1, 2.0), MI["WoodMid"])
box((4.0, 0.5, 0.38), (0, BY0 - 0.25, 4.1), MI["WoodDark"])
for xb in (-1.5, 0, 1.5):
    box((0.2, 0.5, 3.8), (xb, BY0 - 0.3, 2.0), MI["WoodDark"])
cyl(0.16, 0.5, (1.0, BY0 - 0.5, 2.1), MI["Brass"], seg=8, rot=(math.pi / 2, 0, 0))

# ---- tejado con pendiente real, hueco superior menor que la rueda base
frustum((-JX - 1.5, JY0 - 1.5, JX + 1.5, JY1 + 1.5),
        (-8.0, CY - 8.0, 8.0, CY + 8.0),
        TIMBER_T, ROOF_T, MI["RoofTile"], cap=True)
box((JX * 2 + 3.4, JY1 - JY0 + 3.4, 0.4), (0, CY, TIMBER_T + 0.08), MI["WoodDark"])

# chimenea
box((1.9, 1.9, 5.6), (-11.2, 17.6, 7.4), MI["StoneDark"])
box((2.5, 2.5, 0.45), (-11.2, 17.6, 10.3), MI["Stone"])

# ---- TORRE DE QUESOS (auto-ajustada para rematar exactamente en 25.0)
FINIAL_H = 1.6
TZ0, TZ1 = ROOF_T, 25.0 - FINIAL_H
#         tipo     h    r_bot r_top  material      corte  dir     dx    dy   rotZ
STACK = [("wheel", 2.6, 10.0,  9.9, "RindRed",     0.00,  0.0,    0.0,  0.0, 0.0),
         ("wheel", 2.8,  9.4,  9.3, "Emmental",    0.62, -1.571,  0.3, -0.2, 0.0),
         ("block", 2.2, 14.4, 14.4, "Cheddar",     0.00,  0.0,   -0.4,  0.3, 0.30),
         ("wheel", 2.4,  8.3,  8.1, "BlueCheese",  0.00,  0.0,    0.5,  0.2, 0.0),
         ("wheel", 2.0,  6.7,  6.9, "Brie",        0.00,  0.0,   -0.3, -0.4, 0.0),
         ("wheel", 2.2,  5.5,  5.2, "Emmental",    0.52, -1.25,   0.2,  0.1, 0.0),
         ("wheel", 1.7,  4.3,  2.8, "Parmesan",    0.00,  0.0,    0.0,  0.0, 0.0)]

k = (TZ1 - TZ0) / sum(x[1] for x in STACK)
z = TZ0
placed = []
for kind, bh, rb, rt, matn, cut, cdir, dx, dy, rz in STACK:
    h = bh * k
    if kind == "wheel":
        wheel(rb, h, z, MI[matn], seg=(22 if rb > 8 else 18), cut=cut,
              cx=TCX + dx, cy=TCY + dy, r_top=rt, rot0=cdir)
    else:
        box((rb, rb, h), (TCX + dx, TCY + dy, z + h / 2), MI[matn], rot=(0, 0, rz))
    placed.append((kind, z, z + h, rb, rt, dx, dy, rz))
    z += h
TOP = z

# aros de madera solo en tres juntas
for i in (0, 2, 4):
    kind, z0_, z1_, rb, rt, dx, dy, rz = placed[i]
    if kind == "wheel":
        cyl(rt * 0.99, 0.24, (TCX + dx, TCY + dy, z1_), MI["WoodMid"], seg=20)
    else:
        box((rb * 1.05, rb * 1.05, 0.26), (TCX + dx, TCY + dy, z1_), MI["WoodMid"], rot=(0, 0, rz))

# faja de cera y plataforma de madera bajo la torre
wheel(10.06, 0.42, placed[0][1] + 0.5, MI["RindWax"], seg=22, cx=TCX, cy=TCY)
cyl(10.5, 0.4, (TCX, TCY, ROOF_T + 0.08), MI["WoodDark"], seg=22)

# remate: mastil + banderin (tope exacto 25.0)
cyl(0.15, FINIAL_H, (TCX, TCY, TOP + FINIAL_H / 2), MI["Metal"], seg=6)
box((1.4, 0.08, 0.7), (TCX + 0.7, TCY, TOP + FINIAL_H - 0.45), MI["FabricRed"])

# ---- toldo solido a rayas
AW_Y0, AW_Z0 = JY0 - 1.7, 5.2
AW_Y1, AW_Z1 = -11.8, 3.7
AW_DEPTH = AW_Y0 - AW_Y1
AW_DROP = AW_Z0 - AW_Z1
AW_L = math.hypot(AW_DEPTH, AW_DROP)
AW_A = math.atan2(AW_DROP, AW_DEPTH)
AW_CY, AW_CZ = (AW_Y0 + AW_Y1) / 2, (AW_Z0 + AW_Z1) / 2
AW_W, AW_N = 26.0, 13
sw = AW_W / AW_N
box((AW_W, AW_L, 0.16), (0, AW_CY, AW_CZ - 0.10), MI["FabricCream"], rot=(AW_A, 0, 0))
for i in range(AW_N):
    xs = -AW_W / 2 + sw * (i + 0.5)
    box((sw, AW_L, 0.16), (xs, AW_CY, AW_CZ + 0.04),
        MI["FabricRed"] if i % 2 == 0 else MI["FabricCream"], rot=(AW_A, 0, 0))
box((AW_W + 0.5, 0.42, 0.55), (0, AW_Y1, AW_Z1 - 0.1), MI["WoodDark"])
for i in range(AW_N):
    xs = -AW_W / 2 + sw * (i + 0.5)
    box((sw * 0.86, 0.18, 0.5), (xs, AW_Y1 - 0.12, AW_Z1 - 0.62),
        MI["FabricRed"] if i % 2 == 0 else MI["FabricCream"])
for xp in (-12.2, -4.2, 4.2, 12.2):
    box((0.45, 0.45, AW_Z1), (xp, AW_Y1, AW_Z1 / 2), MI["WoodDark"])

# ---- mostrador
box((24.0, 2.6, 1.7), (0, -8.0, 0.85), MI["WoodMid"])
box((25.0, 3.2, 0.3), (0, -8.0, 1.85), MI["WoodLight"])
wheel(1.5, 0.8, 2.0, MI["Emmental"], seg=12, cut=0.9, rot0=-1.571, cx=-7.5, cy=-8.0)
wheel(1.3, 0.7, 2.0, MI["RindRed"], seg=12, cx=-3.8, cy=-7.9)
wheel(1.3, 0.7, 2.7, MI["Cheddar"], seg=12, cx=-3.8, cy=-7.9)
box((2.1, 2.1, 1.3), (5.0, -7.9, 2.65), MI["Parmesan"], rot=(0, 0, 0.35))
wheel(1.6, 0.9, 2.0, MI["Brie"], seg=12, cx=9.2, cy=-8.0)


# ---- props de plaza
def barrel(x, y, r=1.3, h=2.6):
    cyl(r, h, (x, y, h / 2), MI["WoodMid"], seg=12)
    for zz in (h * 0.25, h * 0.75):
        cyl(r * 1.06, 0.2, (x, y, zz), MI["Metal"], seg=12)


def crate(x, y, s=2.0, rz=0.0):
    box((s, s, s), (x, y, s / 2), MI["WoodLight"], rot=(0, 0, rz))
    box((s * 1.03, s * 1.03, 0.2), (x, y, s * 0.25), MI["WoodDark"], rot=(0, 0, rz))
    box((s * 1.03, s * 1.03, 0.2), (x, y, s * 0.8), MI["WoodDark"], rot=(0, 0, rz))


for bx_, by_ in ((-17.0, -13.5), (-14.6, -16.4), (16.8, -13.0), (18.0, -17.2), (-17.6, -20.4)):
    barrel(bx_, by_)
crate(12.6, -19.0, 2.2, 0.3)
crate(13.0, -19.4, 1.6, -0.2)
crate(-11.4, -21.6, 2.0, 0.6)
wheel(1.8, 1.0, 0.0, MI["RindRed"], seg=12, cx=-8.4, cy=-16.8)
wheel(1.6, 0.9, 1.0, MI["Emmental"], seg=12, cut=1.0, rot0=-1.571, cx=-8.4, cy=-16.8)
wheel(2.0, 1.1, 0.0, MI["Cheddar"], seg=12, cx=8.8, cy=-22.0)
for cx_, cy_, s_, rz_ in ((-4.5, -20.0, 1.3, 0.4), (3.0, -17.5, 1.1, -0.6), (-1.0, -22.5, 1.5, 0.9)):
    box((s_, s_, s_), (cx_, cy_, s_ / 2), MI["Emmental"], rot=(0, 0, rz_))


def lantern(x, y, h=6.0):
    cyl(0.2, h, (x, y, h / 2), MI["Metal"], seg=8)
    box((0.95, 0.95, 1.15), (x, y, h + 0.5), MI["GlassWarm"])
    box((1.15, 1.15, 0.22), (x, y, h + 1.15), MI["Metal"])
    box((0.45, 0.45, 0.38), (x, y, h + 1.4), MI["Brass"])


lantern(-18.4, -9.5)
lantern(18.4, -9.5)

# carreta
box((4.8, 2.5, 0.4), (-16.0, -0.8, 2.0), MI["WoodLight"], rot=(0, 0, 0.25))
for wy in (-1.25, 1.25):
    cyl(1.5, 0.32, (-16.0 + wy * 0.25, -0.8 + wy, 1.5), MI["WoodDark"], seg=12, rot=(0, math.pi / 2, 0.25))
wheel(1.2, 0.7, 2.2, MI["Brie"], seg=12, cx=-15.3, cy=-0.5)

# ---- cartel colgante
SGX, SGY = 17.8, -19.4
box((0.55, 0.55, 8.2), (SGX, -16.0, 4.1), MI["WoodDark"])
box((0.45, 4.4, 0.45), (SGX, -17.7, 7.9), MI["WoodDark"])
box((0.35, 6.2, 2.7), (SGX, SGY, 6.0), MI["WoodLight"])
box((0.44, 6.6, 0.32), (SGX, SGY, 7.3), MI["WoodDark"])
box((0.44, 6.6, 0.32), (SGX, SGY, 4.7), MI["WoodDark"])
for cy_ in (SGY - 2.6, SGY + 2.6):
    cyl(0.08, 1.0, (SGX, cy_, 7.6), MI["Metal"], seg=6)

bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
me = bpy.data.meshes.new("TurrisCasei")
bm.to_mesh(me)
bm.free()
obj = bpy.data.objects.new("TurrisCasei", me)
bpy.context.collection.objects.link(obj)
for n_, c_, k_ in PALETTE:
    me.materials.append(make_material(n_, c_, k_))

# ---- texto 3D del cartel
cu = bpy.data.curves.new("SignTxt", type='FONT')
cu.body = "TURRIS\nCASEI"
cu.align_x = 'CENTER'
cu.align_y = 'CENTER'
cu.size = 1.0
cu.space_line = 0.95
cu.extrude = 0.03
cu.resolution_u = 2
tob = bpy.data.objects.new("SignTxt", cu)
bpy.context.collection.objects.link(tob)
bpy.context.view_layer.objects.active = tob
bpy.ops.object.select_all(action='DESELECT')
tob.select_set(True)
bpy.ops.object.convert(target='MESH')
tob = bpy.context.object
bb = [Vector(c) for c in tob.bound_box]
w = max(v.x for v in bb) - min(v.x for v in bb)
h = max(v.y for v in bb) - min(v.y for v in bb)
s = min(5.2 / max(w, 1e-6), 1.9 / max(h, 1e-6))
tob.scale = (s, s, 1.0)
tob.rotation_euler = (math.pi / 2, 0, math.pi / 2)
tob.location = (SGX + 0.20, SGY, 6.0)
tob.data.materials.append(bpy.data.materials["WoodDark"])
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

bpy.ops.object.select_all(action='DESELECT')
tob.select_set(True)
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.object.join()
obj = bpy.context.object
obj.name = "TurrisCasei"

me = obj.data
me.calc_loop_triangles()
tris = len(me.loop_triangles)
dim = obj.dimensions
zs = [v.co.z for v in me.vertices]
print("STATS tris=%d verts=%d dims=%.2f x %.2f x %.2f  zmin=%.2f zmax=%.2f"
      % (tris, len(me.vertices), dim.x, dim.y, dim.z, min(zs), max(zs)))

# ------------------------------------------------------------------- UV + BAKE
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
try:
    bpy.ops.object.shade_auto_smooth(angle=math.radians(34))
except Exception as _e:
    print("auto_smooth no disponible:", _e)
    bpy.ops.object.shade_flat()
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.004)
bpy.ops.object.mode_set(mode='OBJECT')
print("UV ok")

RES = 2048
alb = bpy.data.images.new("TurrisCasei_Albedo", RES, RES, alpha=False)
nrm = bpy.data.images.new("TurrisCasei_Normal", RES, RES, alpha=False, float_buffer=False)
nrm.colorspace_settings.name = 'Non-Color'
slots = []
for m in me.materials:
    nt = m.node_tree
    t = nt.nodes.new("ShaderNodeTexImage")
    nt.nodes.active = t
    slots.append(t)

sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = 1
sc.render.bake.margin = 20
sc.render.bake.use_selected_to_active = False

for t in slots:
    t.image = alb
sc.render.bake.use_pass_direct = False
sc.render.bake.use_pass_indirect = False
sc.render.bake.use_pass_color = True
bpy.ops.object.bake(type='DIFFUSE')
alb.filepath_raw = os.path.join(OUT, "TurrisCasei_Albedo.png")
alb.file_format = 'PNG'
alb.save()
print("BAKE albedo ok")

for t in slots:
    t.image = nrm
bpy.ops.object.bake(type='NORMAL')
nrm.filepath_raw = os.path.join(OUT, "TurrisCasei_Normal.png")
nrm.file_format = 'PNG'
nrm.save()
print("BAKE normal ok")

# ---- material unico horneado
baked = bpy.data.materials.new("TurrisCasei_Baked")
baked.use_nodes = True
nt = baked.node_tree
b = nt.nodes.get("Principled BSDF")
ta = nt.nodes.new("ShaderNodeTexImage")
ta.image = alb
tn = nt.nodes.new("ShaderNodeTexImage")
tn.image = nrm
nm = nt.nodes.new("ShaderNodeNormalMap")
nt.links.new(ta.outputs["Color"], b.inputs["Base Color"])
nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
b.inputs["Roughness"].default_value = 0.8
me.materials.clear()
me.materials.append(baked)

# ---------------------------------------------------------------------- EXPORT
fbx = os.path.join(OUT, "TurrisCasei.fbx")
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True)
bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, axis_forward='-Z', axis_up='Y',
                         global_scale=1.0, apply_unit_scale=True, path_mode='COPY',
                         embed_textures=False, mesh_smooth_type='FACE',
                         use_mesh_modifiers=True, bake_space_transform=False)
print("FBX ok", os.path.exists(fbx))
bpy.ops.wm.obj_export(filepath=os.path.join(OUT, "TurrisCasei.obj"),
                      export_selected_objects=True, forward_axis='NEGATIVE_Z', up_axis='Y')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "TurrisCasei.blend"))

# --------------------------------------------------------------------- PREVIEW
gp = bpy.data.meshes.new("gp")
gbm = bmesh.new()
bmesh.ops.create_grid(gbm, x_segments=1, y_segments=1, size=90)
gbm.to_mesh(gp)
gbm.free()
gobj = bpy.data.objects.new("Ground", gp)
bpy.context.collection.objects.link(gobj)
gm = bpy.data.materials.new("G")
gm.use_nodes = True
gm.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.30, 0.28, 0.26, 1)
gp.materials.append(gm)

world = bpy.data.worlds.new("W")
bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.38, 0.45, 0.62, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.5

sun = bpy.data.lights.new("Sun", 'SUN')
sun.energy = 4.0
sun.angle = 0.15
sun.color = (1.0, 0.90, 0.74)
sob = bpy.data.objects.new("Sun", sun)
bpy.context.collection.objects.link(sob)
sob.rotation_euler = (math.radians(52), 0, math.radians(35))

cam = bpy.data.cameras.new("Cam")
cam.lens = 52
cob = bpy.data.objects.new("Cam", cam)
bpy.context.collection.objects.link(cob)
bpy.context.scene.camera = cob

sc.render.engine = 'CYCLES'
sc.cycles.samples = 48
sc.cycles.use_denoising = True
try:
    sc.view_settings.view_transform = 'Standard'
except Exception as _e:
    print("view_transform:", _e)
sc.render.resolution_x = 1100
sc.render.resolution_y = 820

VIEWS = [("hero", Vector((58, -66, 34)), Vector((0, 1, 11.0))),
         ("front", Vector((0, -92, 22)), Vector((0, 2, 11.5))),
         ("detail", Vector((26, -30, 21)), Vector((0, 4, 16.5)))]
for nm_, loc, tgt in VIEWS:
    cob.location = loc
    cob.rotation_euler = (tgt - loc).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(OUT, "preview_%s.png" % nm_)
    bpy.ops.render.render(write_still=True)
    print("RENDER", nm_)

print("DONE")
