# Crea en Blender las piezas del bosque (pinos, pino seco, copa de los árboles que se talan, rocas, arbustos, helechos
# y tronco caído) y las exporta a un .fbx para Roblox:
#   blender -b --factory-startup --python tools/blender/crear_bosque.py [-- --only Pino Roca]
# Deja bosque.blend, bosque.fbx y vistas bosque1-2.png en Documents\Roblox\modelos (con --only, bosque_parche.fbx).
# Después: node tools/blender/subir_modelo.mjs <bosque.fbx> <clave> y volcar sus MeshParts a src/shared/BosqueMallas.rbxmx
# (ver docs/sistemas/arte.md). En el juego las pone shared/Piezas.
#
# Cada pieza son varias mallas "<Pieza>_<Papel>", una por papel; el juego (shared/Piezas) les pone color y material
# según el papel. "<Pieza>_Origin" marca el centro del suelo de la pieza y Axis_* dan la escala y los ejes de la
# importación. Medidas en studs, Y arriba, -Z al frente. Las caras llevan UV de caja (una baldosa cada TESELA studs)
# para que los materiales de Roblox (madera, roca, hierba) se vean con su textura y no estirados.
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import geometria as g  # noqa: E402
from geometria import R, T, Piece, Vector, blob, box, cyl, lathe  # noqa: E402,F401

g.ROLE_COLORS.update({  # solo para verlo en Blender; en el juego manda shared/Piezas
    "Bark": (0.24, 0.18, 0.14), "Needles": (0.12, 0.2, 0.13), "NeedlesDark": (0.02, 0.05, 0.03),
    "Dead": (0.36, 0.33, 0.3), "Moss": (0.2, 0.26, 0.12), "Stone": (0.4, 0.4, 0.4), "StoneDark": (0.26, 0.26, 0.27),
    "Rama": (0.1, 0.18, 0.1), "Leaf": (0.15, 0.22, 0.12), "LeafDark": (0.09, 0.15, 0.09), "Fern": (0.17, 0.27, 0.13), "Marker": (1, 0, 1),
})


# ---------- Árboles ----------

def card(length, width, droop, lift=0.0, segments=4, u0=0.0, v0=0.1, v1=0.9):
    """Rama plana con la textura de agujas (papel "Rama", tools/texturas/agujas.ps1): una tira de `length` a lo largo
    de X y `width` de ancho (Z) que cae `droop` grados en total hacia la punta (más al final) y sube `lift` al
    principio. Con las dos caras (Roblox no pinta el revés). Devuelve (vértices, caras, uv de cada esquina)."""
    verts, faces, uvs = [], [], []
    pos, ang = Vector((0, 0, 0)), math.radians(lift)
    step = length / segments
    rows = []
    for s in range(segments + 1):
        rows.append(len(verts))
        verts += [(pos.x, pos.y, -width / 2), (pos.x, pos.y, width / 2)]
        pos = pos + Vector((math.cos(ang), math.sin(ang), 0)) * step
        ang -= math.radians(droop) * (s + 1) / (segments * (segments + 1) / 2)  # cae más hacia la punta
    for s in range(segments):
        a, b = rows[s], rows[s + 1]
        ua, ub = u0 + (1 - u0) * s / segments, u0 + (1 - u0) * (s + 1) / segments
        faces.append((a, b, b + 1, a + 1))
        uvs.append(((ua, v0), (ub, v0), (ub, v1), (ua, v1)))
        faces.append((a + 1, b + 1, b, a))
        uvs.append(((ua, v1), (ub, v1), (ub, v0), (ua, v0)))
    return verts, faces, uvs


def bough(p, rng, y, angle, length, droop, lift, trunk_r):
    """Una rama: dos tiras con la textura, una tumbada y otra de canto girada, para que tenga volumen desde
    cualquier lado. Sale del tronco y cae hacia la punta."""
    base = R("Y", angle) @ T(trunk_r * 0.5, y, 0) @ R("X", rng.uniform(-15, 15))
    width = length * rng.uniform(0.8, 1.0)
    p.add_uv("Rama", card(length, width, droop, lift), base)
    p.add_uv("Rama", card(length * 0.9, width * 0.8, droop * 1.1, lift), base @ R("X", 90 + rng.uniform(-25, 25)))


def pine_crown(p, rng, bottom, top, spread, whorls, gaps=0.0, per_whorl=9, core=False):
    """Copa de pino de `bottom` a `top`: verticilos de ramas que se acortan hacia arriba; las de abajo caen y suben
    un poco en la punta, las de arriba apuntan al cielo. Dentro, un cono oscuro para que la copa no se vea hueca.
    `gaps` = probabilidad de que falte una rama (más ralo, más tétrico)."""
    for k in range(whorls):
        t = k / (whorls - 1)
        y = bottom + (top - bottom) * t + rng.uniform(-0.5, 0.5)
        length = spread * (1 - t) ** 0.85 + 1.6
        droop = 38 - 30 * t + rng.uniform(-8, 8)
        lift = 6 + 26 * t
        start = rng.uniform(0, 360)
        count = max(4, round(per_whorl * (1 - 0.35 * t)))
        for b in range(count):
            if rng.random() < gaps:
                continue
            bough(p, rng, y, start + b * 360 / count + rng.uniform(-20, 20), length * rng.uniform(0.8, 1.15),
                  droop, lift, 1.0 - t * 0.7)
    if core:
        p.add("NeedlesDark", lathe([(spread * 0.16, bottom), (spread * 0.1, (bottom + top) / 2), (0, top - 2)], 7,
                                   0.15, rng))
    # La guía de arriba: unas ramitas de pie.
    for k in range(3):
        p.add_uv("Rama", card(4.5, 2.2, -10, 75), T(0, top - 1, 0) @ R("Y", k * 120 + rng.uniform(-20, 20)))


def bark_trunk(p, height, base_radius, n=14):
    p.add("Bark", lathe([(base_radius * 1.45, 0), (base_radius, 1.4), (base_radius * 0.75, height * 0.5),
                         (base_radius * 0.22, height)], n))


def pino(p):
    """Pino alto del bosque: 60 de alto, tronco de 1 de radio (el juego lo escala al tronco que hay)."""
    rng = random.Random(11)
    bark_trunk(p, 60, 1.0)
    pine_crown(p, rng, 16, 60, 9.0, 30)


def pino_b(p):
    """Otro pino, más ralo y con la copa más alta."""
    rng = random.Random(23)
    bark_trunk(p, 60, 1.0)
    pine_crown(p, rng, 24, 60, 7.5, 24, gaps=0.3)


def pino_seco(p):
    """Pino muerto: tronco gris y ramas secas que caen."""
    rng = random.Random(37)
    p.add("Dead", lathe([(1.45, 0), (1.0, 1.4), (0.7, 30), (0.15, 60)], 8))
    for k in range(42):
        y = rng.uniform(10, 56)
        a = rng.uniform(0, 2 * math.pi)
        r_trunk = 1.0 - y / 70
        length = rng.uniform(2, 7) * (1.1 - y / 80) * (0.4 if rng.random() < 0.3 else 1)  # algunas, rotas
        out = Vector((math.cos(a), 0, math.sin(a)))
        start = Vector((0, y, 0)) + out * r_trunk * 0.8
        end = start + out * length + Vector((0, -length * rng.uniform(0.2, 0.6), 0))
        p.branch("Dead", start, end, 0.22, 0.04, 5)
        if length > 3:
            mid = start.lerp(end, 0.6)
            twig = mid + Vector((rng.uniform(-1, 1), -rng.uniform(0.5, 1.5), rng.uniform(-1, 1)))
            p.branch("Dead", mid, twig, 0.08, 0.02, 4)
    p.add("Moss", blob((1.6, 0.5, 1.6), 3, 8, 4, 0.3), T(0, 0.3, 0))


def copa_talable(p):
    """La copa de los árboles que se talan (26 de alto): el tronco es la pieza del juego que cae. Sin tronco aquí."""
    rng = random.Random(51)
    pine_crown(p, rng, 5, 26, 5.5, 16)


# ---------- Suelo del bosque ----------

def roca(p, seed, size):
    rng = random.Random(seed)
    p.add("StoneDark", blob((size, size * 0.6, size * 0.85), seed, 16, 9, 0.18), T(0, size * 0.25, 0))
    p.add("Stone", blob((size * 0.55, size * 0.35, size * 0.5), seed + 1, 12, 7, 0.2),
          T(size * 0.45, size * 0.15, size * 0.3) @ R("Y", rng.uniform(0, 360)))
    p.add("Moss", blob((size * 0.75, size * 0.22, size * 0.62), seed + 2, 12, 6, 0.2), T(-size * 0.1, size * 0.6, 0))


def roca_a(p):
    roca(p, 61, 3.0)


def roca_b(p):
    roca(p, 71, 5.0)


def arbusto(p):
    rng = random.Random(81)
    for k in range(6):
        a = k / 6 * 2 * math.pi + rng.uniform(-0.3, 0.3)
        d = rng.uniform(0.6, 1.6)
        size = rng.uniform(1.2, 1.9)
        p.add("Leaf" if k % 2 else "LeafDark", blob((size, size * 0.8, size), 90 + k, 12, 7, 0.25),
              T(math.cos(a) * d, size * 0.6, math.sin(a) * d))


def helecho(p):
    """Helecho: hojas con la textura de agujas que salen del centro hacia arriba y se curvan hasta el suelo."""
    rng = random.Random(97)
    for k in range(10):
        a = k / 10 * 360 + rng.uniform(-14, 14)
        length = rng.uniform(2.6, 3.8)
        p.add_uv("Rama", card(length, length * 0.75, rng.uniform(70, 95), rng.uniform(45, 65), 5),
                 R("Y", a) @ T(0, 0.05, 0) @ R("X", rng.uniform(-20, 20)))


def tronco_caido(p):
    rng = random.Random(101)
    p.branch("Bark", (-7, 1.0, 0), (7, 0.9, 0.3), 1.15, 0.85, 9)
    p.add("Dead", cyl(0.95, 0.1, 9), T(7.05, 0.9, 0.3) @ R("Z", -90))
    p.branch("Bark", (-2, 1.6, 0), (-3.5, 3.8, 1.2), 0.3, 0.08, 5)
    p.branch("Bark", (3, 1.5, -0.3), (4.2, 2.6, -2.4), 0.25, 0.06, 5)
    for k in range(4):
        x = -5 + k * 3.2 + rng.uniform(-0.5, 0.5)
        p.add("Moss", blob((1.4, 0.35, 0.9), 110 + k, 7, 4, 0.3), T(x, 1.95, 0.1))


PIECES = {
    "Pino": pino, "PinoB": pino_b, "PinoSeco": pino_seco, "CopaTalable": copa_talable,
    "RocaA": roca_a, "RocaB": roca_b, "Arbusto": arbusto, "Helecho": helecho, "TroncoCaido": tronco_caido,
}


g.TEXTURAS["Rama"] = os.path.join(g.OUT_DIR, "agujas.png")  # la de tools/texturas/agujas.ps1
g.SUAVES.update({"Bark", "Dead", "Moss", "Stone", "StoneDark", "Leaf", "LeafDark"})

if __name__ == "__main__":
    # Vistas: los árboles enteros, lo del suelo y el pino de cerca.
    g.exportar(PIECES, "bosque", [(60, 190, 80, 32), (230, 160, 40, 2, 25, 18), (0, 36, 40, 34, 25, 4)],
               "Generar las piezas del bosque o solo las indicadas.")
