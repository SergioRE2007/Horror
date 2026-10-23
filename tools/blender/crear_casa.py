# Crea en Blender los muebles de la casa y los exporta a un .fbx para Roblox:
#   blender -b --factory-startup --python tools/blender/crear_casa.py [-- --only Cama Sofa]
# Deja casa.blend, casa.fbx y vistas casa1-3.png en Documents\Roblox\modelos (con --only, casa_parche.*). Se pasan
# al juego como el bosque (docs/sistemas/arte.md) a src/shared/CasaMallas.rbxmx y los pone shared/Piezas.
# Cada mueble tiene las medidas del bloque de juego/servidor/Mapa al que tapa (que se queda, invisible, para chocar):
# origen en el centro de su base en el suelo y el frente hacia -Z.
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import geometria as g  # noqa: E402
from geometria import R, S, T, Vector, blob, box, cyl, lathe  # noqa: E402,F401

g.ROLE_COLORS.update({  # solo para verlo en Blender; en el juego manda shared/Piezas
    "Wood": (0.28, 0.2, 0.14), "WoodDark": (0.18, 0.12, 0.09), "WoodLight": (0.38, 0.29, 0.2),
    "Fabric": (0.31, 0.18, 0.16), "Cloth": (0.59, 0.56, 0.49), "Blanket": (0.27, 0.24, 0.2),
    "Metal": (0.35, 0.35, 0.36), "MetalDark": (0.16, 0.16, 0.17), "Ceramic": (0.67, 0.64, 0.59),
    "Grime": (0.24, 0.2, 0.16), "Counter": (0.34, 0.33, 0.31), "Paper": (0.7, 0.67, 0.55),
    "BookA": (0.35, 0.12, 0.11), "BookB": (0.16, 0.2, 0.27), "BookC": (0.43, 0.38, 0.27),
    "Bulb": (1.0, 0.89, 0.67), "Painting": (0.2, 0.16, 0.13), "Rug": (0.36, 0.15, 0.13),
})
g.SUAVES.update({"Cloth", "Blanket", "Fabric", "Ceramic"})


def bx(p, role, sx, sy, sz, x=0.0, y=0.0, z=0.0, m=None):
    """Caja con la base en y (no el centro): más fácil de leer con las medidas de Mapa."""
    p.add(role, box(sx, sy, sz), (m or T()) @ T(x, y + sy / 2, z))


def cushion(p, role, sx, sy, sz, x, y, z, seed, m=None):
    """Cojín: una caja blanda (bola aplastada casi cuadrada)."""
    shape = blob((sx / 2, sy / 2, sz / 2), seed, 12, 6, 0.04)
    verts = [(math.copysign(abs(vx) ** 0.55 * (sx / 2) ** 0.45, vx), vy, math.copysign(abs(vz) ** 0.55 * (sz / 2) ** 0.45, vz))
             for vx, vy, vz in shape[0]]
    p.add(role, (verts, shape[1]), (m or T()) @ T(x, y + sy / 2, z))


# ---------- Dormitorio ----------

def cama(p):
    """Cama de 5,2 x 8,2 con la cabecera al frente (-Z). Debajo queda hueco (hasta 2 de alto) para esconderse."""
    for x in (-2.45, 2.45):
        bx(p, "WoodDark", 0.4, 5.6, 0.4, x, 0, -4.0)  # postes de la cabecera
        p.add("WoodDark", sphere_top(0.28), T(x, 5.75, -4.0))
        bx(p, "WoodDark", 0.4, 3.0, 0.4, x, 0, 3.95)  # de los pies
        bx(p, "Wood", 0.25, 0.6, 7.6, x, 1.7, 0)  # largueros
    bx(p, "Wood", 4.5, 2.4, 0.18, 0, 2.6, -4.0)  # cabecero
    for k in range(5):
        bx(p, "WoodDark", 0.22, 2.2, 0.26, -1.8 + k * 0.9, 2.7, -4.0)
    bx(p, "WoodDark", 4.9, 0.3, 0.3, 0, 5.0, -4.0)
    bx(p, "Wood", 4.5, 0.9, 0.18, 0, 1.9, 3.95)  # piecero
    bx(p, "Wood", 4.9, 0.15, 7.8, 0, 2.05, 0)  # somier
    cushion(p, "Cloth", 4.8, 0.95, 7.7, 0, 2.2, 0, 3)  # colchón
    cushion(p, "Cloth", 3.4, 0.55, 1.3, 0, 3.12, -3.2, 5)  # almohada
    # Manta de los pies a medio colchón, colgando por los lados y los pies.
    bx(p, "Blanket", 5.0, 0.12, 5.0, 0, 3.12, 1.4)
    for x in (-2.52, 2.52):
        bx(p, "Blanket", 0.08, 1.0, 5.0, x, 2.2, 1.4)
    bx(p, "Blanket", 5.0, 1.0, 0.08, 0, 2.2, 3.92)
    bx(p, "Blanket", 4.6, 0.25, 0.6, 0, 3.12, -1.1)  # el doblez


def sphere_top(r):
    return lathe([(0, -r), (r * 0.8, -r * 0.5), (r, 0), (r * 0.8, r * 0.5), (0, r)], 10)


def armario_marco(p):
    """Molduras del armario de lamas (4,6 de ancho, 8 de alto, 3 de fondo, centro a 4 del suelo): copete y zócalo.
    Las lamas y los costados son los bloques de Mapa, que se ven (las rendijas son del juego)."""
    bx(p, "WoodDark", 5.0, 0.5, 3.3, 0, 8.0, 0.1)
    bx(p, "WoodDark", 4.8, 0.25, 3.15, 0, 7.8, 0.05)
    bx(p, "WoodDark", 4.9, 0.4, 3.2, 0, -0.05, 0.05)
    for x in (-1.6, 1.6):
        bx(p, "Metal", 0.12, 0.6, 0.12, x * 0.15, 3.7, -1.5)  # tiradores


# ---------- Salón ----------

def sofa(p):
    """Sofá de 8 de ancho: asiento de z -1,5 a 1,5 y respaldo detrás (+Z)."""
    for x in (-3.7, 3.7):
        for z in (-1.3, 2.3):
            bx(p, "WoodDark", 0.3, 0.35, 0.3, x, 0, z)
    bx(p, "Fabric", 8.0, 1.1, 4.0, 0, 0.35, 0.5)  # base
    bx(p, "Fabric", 8.0, 3.6, 0.8, 0, 0.35, 2.1)  # respaldo
    for x in (-3.6, 3.6):
        bx(p, "Fabric", 0.8, 1.9, 4.0, x, 0.35, 0.5)  # brazos
        p.add("Fabric", cyl(0.45, 4.0, 10), T(x, 2.25, -1.5) @ R("X", 90))
    for x in (-1.6, 1.6):
        cushion(p, "Fabric", 3.15, 0.7, 2.9, x, 1.45, -0.15, 11 + int(x))
        cushion(p, "Fabric", 3.1, 2.0, 0.75, x, 1.9, 1.45, 21 + int(x), R("X", -8))


def mesita(p):
    """Mesa baja de 4 x 3 y 1,5 de alto."""
    bx(p, "Wood", 4.0, 0.22, 3.0, 0, 1.28)
    bx(p, "WoodDark", 3.6, 0.12, 2.6, 0, 0.35)  # balda de abajo
    for x in (-1.8, 1.8):
        for z in (-1.3, 1.3):
            bx(p, "WoodDark", 0.22, 1.28, 0.22, x, 0, z)
    bx(p, "Paper", 0.9, 0.04, 1.2, -0.8, 1.5, 0.2, R("Y", 14))  # una revista


def alfombra(p):
    bx(p, "Rug", 9.0, 0.06, 7.0)
    for x in (-4.4, 4.4):
        bx(p, "WoodDark", 0.2, 0.065, 7.0, x, 0, 0)


def cuadro(p):
    """Cuadro para colgar (2,4 x 3): el origen es el centro de abajo del marco, pegado a la pared por detrás (+Z)."""
    for x in (-1.1, 1.1):
        bx(p, "WoodDark", 0.2, 3.0, 0.15, x, 0, 0)
    for y in (0, 2.8):
        bx(p, "WoodDark", 2.4, 0.2, 0.15, 0, y, 0)
    bx(p, "Painting", 2.0, 2.6, 0.06, 0, 0.2, 0.03)


def lampara(p):
    """Lámpara de techo: el origen es el punto del techo; cuelga 1. La bombilla es el bloque de Mapa (Generador le
    cambia el color al encenderla), a 0,62 del techo."""
    p.add("MetalDark", cyl(0.35, 0.12, 10), T(0, -0.12, 0))
    p.add("MetalDark", cyl(0.04, 0.3, 5), T(0, -0.42, 0))
    p.add("MetalDark", lathe([(1.1, -1.0), (0.85, -0.75), (0.3, -0.45), (0.15, -0.42)], 14, caps=False))


# ---------- Cocina ----------

def mesa(p):
    """Mesa de comedor de 6 x 4, tablero de 2,8 a 3,2 de alto."""
    bx(p, "Wood", 6.0, 0.4, 4.0, 0, 2.8)
    bx(p, "WoodDark", 5.4, 0.35, 3.4, 0, 2.45)
    for x in (-2.6, 2.6):
        for z in (-1.6, 1.6):
            p.add("WoodDark", lathe([(0.2, 0), (0.15, 0.3), (0.2, 1.2), (0.12, 2.0), (0.18, 2.8)], 8), T(x, 0, z))


def silla(p):
    """Silla de comedor mirando a -Z: asiento a 1,9."""
    bx(p, "Wood", 1.8, 0.2, 1.8, 0, 1.7)
    for x in (-0.75, 0.75):
        for z in (-0.75, 0.75):
            bx(p, "WoodDark", 0.18, 1.7, 0.18, x, 0, z)
        bx(p, "WoodDark", 0.18, 2.3, 0.18, x, 1.9, 0.75)
    for y in (2.6, 3.4, 4.0):
        bx(p, "Wood", 1.5, 0.22, 0.12, 0, y, 0.75)


def cocina(p):
    """Encimera de 14 x 2 contra la pared de atrás (+Z): muebles con puertas, fregadero, fogones y armarios arriba."""
    bx(p, "Wood", 14.0, 3.2, 2.0, 0, 0, 0)
    bx(p, "Counter", 14.2, 0.3, 2.2, 0, 3.2, -0.05)
    bx(p, "WoodDark", 14.0, 0.25, 1.8, 0, 0, 0.05)  # zócalo
    for k in range(7):
        x = -6.0 + k * 2.0
        if k == 1:
            continue  # ahí va el horno
        bx(p, "WoodLight", 1.8, 2.5, 0.08, x, 0.45, -1.02)
        bx(p, "Metal", 0.12, 0.5, 0.12, x + 0.6, 2.3, -1.12)
    # Fregadero bajo la ventana (la de la cocina queda en x = 2 de aquí): la pila hundida y el grifo.
    bx(p, "Metal", 2.8, 0.06, 1.5, 2.0, 3.5, -0.05)
    bx(p, "Grime", 2.4, 0.07, 1.1, 2.0, 3.5, -0.05)
    p.branch("Metal", (2.0, 3.5, 0.75), (2.0, 4.6, 0.75), 0.08, 0.07, 6)
    p.branch("Metal", (2.0, 4.6, 0.75), (2.0, 4.5, 0.1), 0.07, 0.06, 6)
    # Cocina de hierro con el horno y cuatro fuegos.
    bx(p, "MetalDark", 2.0, 3.2, 1.9, -4.0, 0, -0.05)
    bx(p, "Metal", 1.6, 1.4, 0.06, -4.0, 0.6, -1.02)
    bx(p, "Metal", 1.0, 0.08, 0.1, -4.0, 2.2, -1.06)
    for dx in (-0.45, 0.45):
        for dz in (-0.45, 0.45):
            p.add("MetalDark", cyl(0.32, 0.08, 10), T(-4.0 + dx, 3.5, -0.05 + dz))
    # Armarios de arriba, contra la pared, a los lados de la ventana.
    for x in (-5.5, -2.0, 6.3):
        bx(p, "Wood", 3.4, 2.6, 1.1, x, 6.4, 0.45)
        bx(p, "WoodLight", 1.5, 2.3, 0.06, x - 0.8, 6.55, -0.12)
        bx(p, "WoodLight", 1.5, 2.3, 0.06, x + 0.8, 6.55, -0.12)
    # Unas latas y un tarro encima.
    rng = random.Random(4)
    for x in (-6.4, -5.8, 5.9, 6.6):
        p.add("Metal" if rng.random() < 0.5 else "Paper", cyl(0.25, 0.6, 8), T(x, 9.0, 0.45))


def estanteria(p):
    """Estantería de 6 x 7 x 1,5 contra la pared (+Z), con libros."""
    for x in (-2.9, 2.9):
        bx(p, "WoodDark", 0.2, 7.0, 1.5, x, 0, 0)
    bx(p, "WoodDark", 6.0, 7.0, 0.1, 0, 0, 0.7)
    rng = random.Random(9)
    for k in range(5):
        y = 0.1 + k * 1.65
        bx(p, "Wood", 5.6, 0.15, 1.4, 0, y, 0)
        if k == 4:
            break
        x = -2.7
        while x < 2.5:
            w = rng.uniform(0.18, 0.4)
            h = rng.uniform(0.9, 1.4)
            if rng.random() < 0.12:
                x += rng.uniform(0.4, 1.0)  # hueco
                continue
            lean = 0 if rng.random() < 0.85 else rng.uniform(8, 18)
            bx(p, rng.choice(("BookA", "BookB", "BookC")), w, h, rng.uniform(0.9, 1.15), x + w / 2, y + 0.15, 0.05,
               R("Z", -lean) if lean else None)
            x += w + 0.02
    bx(p, "WoodDark", 6.0, 0.15, 1.5, 0, 6.85, 0)


# ---------- Baño ----------

def banera(p):
    """Bañera de patas de 7 x 3,5 (largo en X) y 2,5 de alto."""
    shell = lathe([(0.82, 0.55), (0.95, 0.9), (1.0, 1.6), (1.0, 2.5)], 18)
    p.add("Ceramic", shell, S(3.4, 1, 1.7))
    p.add("Ceramic", lathe([(0.98, 2.5), (1.03, 2.55), (1.0, 2.6)], 18), S(3.4, 1, 1.7))  # borde
    p.add("Grime", lathe([(0.9, 2.62), (0.0, 2.62)], 18), S(3.25, 1, 1.55))  # el fondo, visto desde arriba
    for x in (-2.5, 2.5):
        for z in (-1.0, 1.0):
            p.add("Metal", lathe([(0.18, 0), (0.28, 0.12), (0.14, 0.4), (0.2, 0.62)], 8), T(x, 0, z))
    p.branch("Metal", (3.1, 2.6, 0), (3.6, 3.4, 0), 0.07, 0.07, 6)


def vater(p):
    """Váter mirando a -Z: la cisterna atrás (+Z)."""
    p.add("Ceramic", lathe([(0.55, 0), (0.45, 0.4), (0.6, 1.0), (0.85, 1.55)], 14), S(1, 1, 1.3) @ T(0, 0, -0.2))
    p.add("Grime", lathe([(0.7, 1.56), (0.0, 1.56)], 14), S(1, 1, 1.3) @ T(0, 0, -0.2))
    p.add("Ceramic", lathe([(0.82, 0), (0.86, 0.06), (0.82, 0.12)], 14, caps=False), S(1, 1, 1.3) @ T(0, 1.58, -0.2))
    bx(p, "Ceramic", 1.8, 1.6, 0.7, 0, 1.4, 1.0)
    bx(p, "Ceramic", 1.9, 0.12, 0.8, 0, 3.0, 1.0)


def lavabo(p):
    """Lavabo de pie mirando a -Z, contra la pared (+Z), y un espejo roto encima."""
    p.add("Ceramic", lathe([(0.45, 0), (0.3, 0.4), (0.28, 2.0), (0.6, 2.5)], 12), T(0, 0, 0.3))
    p.add("Ceramic", lathe([(0.6, 2.4), (1.2, 2.8), (1.25, 3.05)], 16), S(1, 1, 0.8) @ T(0, 0, 0.3))
    p.add("Grime", lathe([(1.1, 3.05), (0.0, 3.05)], 16), S(1, 1, 0.8) @ T(0, 0, 0.3))
    p.branch("Metal", (0, 3.05, 1.1), (0, 3.6, 1.1), 0.06, 0.06, 6)
    p.branch("Metal", (0, 3.6, 1.1), (0, 3.5, 0.65), 0.06, 0.05, 6)
    bx(p, "WoodDark", 2.2, 2.8, 0.12, 0, 4.4, 1.15)
    bx(p, "Metal", 1.9, 2.5, 0.05, 0, 4.55, 1.08)


# ---------- Arriba ----------

def escritorio(p):
    """Escritorio de 6 x 3 x 3 con cajones a la derecha; el frente (los cajones) a -Z."""
    bx(p, "Wood", 6.0, 0.25, 3.0, 0, 2.75)
    bx(p, "WoodDark", 2.0, 2.75, 2.8, 1.9, 0, 0)
    for k in range(3):
        bx(p, "WoodLight", 1.8, 0.75, 0.06, 1.9, 0.2 + k * 0.85, -1.42)
        bx(p, "Metal", 0.4, 0.1, 0.1, 1.9, 0.55 + k * 0.85, -1.5)
    for z in (-1.3, 1.3):
        bx(p, "WoodDark", 0.25, 2.75, 0.25, -2.8, 0, z)
    rng = random.Random(12)
    for k in range(5):
        bx(p, "Paper", 0.9, 0.02, 1.2, rng.uniform(-2.3, 0.2), 3.0 + k * 0.02, rng.uniform(-0.8, 0.8),
           R("Y", rng.uniform(-30, 30)))




PIECES = {
    "Cama": cama, "ArmarioMarco": armario_marco, "Sofa": sofa, "Mesita": mesita, "Alfombra": alfombra,
    "Cuadro": cuadro, "Lampara": lampara, "Mesa": mesa, "Silla": silla, "Cocina": cocina, "Estanteria": estanteria,
    "Banera": banera, "Vater": vater, "Lavabo": lavabo, "Escritorio": escritorio,
}

if __name__ == "__main__":
    # Vistas: los muebles en fila, de lado y un poco desde arriba.
    g.exportar(PIECES, "casa", [(120, 330, 70, 4, 25, 18), (440, 330, 70, 4, 25, 18), (200, 90, 40, 3, 35, 25)],
               "Generar los muebles de la casa o solo los indicados.")
