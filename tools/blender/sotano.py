# Muebles hechos a mano del sótano (11.8.13, opción A del usuario, "el banco te espera"). Como desvan.py: usa todo lo
# de a_mano.py (misma tubería, envejecido y salida) sin tocarlo, añade sus muebles a a_mano.MUEBLES y llama a su main().
# Uso: blender -b --factory-startup --python tools/blender/sotano.py -- --nombre BancoCarpintero
# Muebles: BancoCarpintero (con el tablero de herramientas de la pared), CalderaVieja (con su tiro, tubos y carbón),
# CadenasTecho, CuerdasSilla (en los ejes de SillaSotanoPH) y TarrosSotano (una fila para una balda de DespensaPH).
import math
import os
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import a_mano  # noqa: E402
from a_mano import eslabon  # noqa: E402
from geometria import R, S, T, blob, box, cyl, lathe, sphere  # noqa: E402

LISO = "liso"


def cuerda(m, papel, puntos, r=0.05, n=6):
    """Tubo que sigue una línea quebrada de puntos (cuerdas, tubos doblados)."""
    for a, b in zip(puntos, puntos[1:]):
        m.rama(papel, tuple(a), tuple(b), r, r, n)
    if r >= 0.1:  # en las finas no se notan las juntas y gastan triángulos
        for p in puntos[1:-1]:
            m.add(papel, sphere(r, n, 3), T(*p))


def helice(centro, eje, radio, vueltas, largo, pasos=10):
    """Puntos de una espiral alrededor de `eje` ("x", "y" o "z") que empieza en `centro` y avanza `largo`."""
    pts = []
    total = int(vueltas * pasos)
    for k in range(total + 1):
        a = 2 * math.pi * k / pasos
        t = largo * k / total
        c, s = radio * math.cos(a), radio * math.sin(a)
        x, y, z = centro
        if eje == "y":
            pts.append(Vector((x + c, y + t, z + s)))
        elif eje == "z":
            pts.append(Vector((x + c, y + s, z + t)))
        else:
            pts.append(Vector((x + t, y + c, z + s)))
    return pts


# ---------- Banco de carpintero ----------
def banco_carpintero(m, rng):
    # Banco de carpintero de 9 × 2,8 (tablero a 3,4) contra la pared del fondo; el que trabaja, delante (-Z). Tablero de
    # tablones gruesos con agujeros de tope, patas de 0,5, travesaños, balda baja con recortes de madera, tornillo de pata
    # de madera a la izquierda, virutas encima y en el suelo; detrás, el tablero de la pared (8,8 × 3,4, de 3,9 a 7,3)
    # con clavijas para las herramientas (las cuelga Mapa) y una repisa arriba con tarros de clavos.
    for k in range(4):
        m.add("Madera", box(9.0, 0.35, 0.69), T(0, 3.225, -1.04 + k * 0.695) @ R("Z", rng.uniform(-0.2, 0.2)))
    for x in (-3.6, -2.4, -1.2, 0.0, 1.2, 2.4):
        m.add("Interior", box(0.14, 0.01, 0.14), T(x, 3.405, -1.12))
    for x in (-4.0, 4.0):
        for z in (-1.0, 1.0):
            m.add("Madera", box(0.5, 3.05, 0.5), T(x, 1.525, z))
        m.add("Madera", box(0.3, 0.3, 2.0), T(x, 0.6, 0))
        m.add("Madera", box(0.3, 0.25, 2.0), T(x, 2.85, 0))
    for z in (-1.0, 1.0):
        m.add("Madera", box(7.6, 0.35, 0.3), T(0, 0.6, z))
    m.add("Madera", box(7.6, 0.12, 2.2), T(0, 0.83, 0))
    # Recortes de madera en la balda baja.
    for k, (largo, x) in enumerate(((3.2, -2.0), (2.4, 1.6), (1.6, 2.8), (2.8, -1.4))):
        m.add("Madera", box(largo, 0.18, 0.45), T(x, 0.98 + (k // 2) * 0.18, -0.5 + (k % 2) * 0.65) @ R("Y", rng.uniform(-6, 6)))
    # Tornillo de pata a la izquierda: la quijada de madera, el husillo y la palanca.
    m.add("Madera", box(0.9, 3.1, 0.32), T(-3.3, 1.75, -1.56))
    m.add("Tornillo", cyl(0.15, 1.3, 10), T(-3.3, 2.95, -2.0) @ R("X", 90))
    m.add("Tornillo", cyl(0.07, 1.7, 8), T(-4.15, 2.95, -2.05) @ R("Z", -90))
    for x in (-4.15, -2.45):
        m.add("Tornillo", sphere(0.11, 8, 4), T(x, 2.95, -2.05))
    # Virutas: rizos finos tumbados encima del banco y unos pocos caídos delante.
    for k in range(14):
        encima = k < 10
        x = rng.uniform(0.6, 3.8) if encima else rng.uniform(-1.0, 3.0)
        y = 3.42 if encima else 0.03
        z = rng.uniform(-1.0, 0.6) if encima else rng.uniform(-2.4, -1.6)
        r, vueltas = rng.uniform(0.07, 0.13), rng.uniform(2.5, 4.5)
        pts = [Vector((r * (1 - a * 0.06) * math.cos(a), 0.02 + 0.06 * math.sin(a * 0.5), r * (1 - a * 0.06) * math.sin(a)))
               for a in (i * vueltas / 7 for i in range(8))]
        mat = T(x, y, z) @ R("Y", rng.uniform(0, 360))
        cuerda(m, "Viruta", [mat @ p for p in pts], r=0.02, n=4)
    # El tablero de la pared, con clavijas y la repisa de arriba.
    m.add("Tablero", box(8.8, 3.4, 0.15), T(0, 5.6, 1.33))
    for x in (-4.4, 4.4):
        m.add("Madera", box(0.25, 3.6, 0.3), T(x, 5.6, 1.3))
    for x, y in ((-3.3, 6.6), (-2.2, 6.6), (-1.0, 6.6), (0.4, 6.6), (1.8, 6.6), (3.2, 6.6), (-2.8, 5.0), (1.0, 5.0), (2.6, 5.0)):
        m.add("Clavija", cyl(0.06, 0.4, 6), T(x, y, 1.25) @ R("X", -90))
    m.add("Madera", box(8.8, 0.15, 0.8), T(0, 7.4, 0.95))
    for k, x in enumerate((-3.4, -2.8, -2.2, 2.6, 3.3)):
        r, h = 0.2 + 0.03 * (k % 2), 0.5 + 0.08 * (k % 3)
        m.add("Cristal", lathe([(0, 0), (r, 0), (r, h * 0.85), (r * 0.8, h)], 10), T(x, 7.475, 0.9))
        m.add("Clavos", cyl(r * 0.92, h * 0.55, 10), T(x, 7.48, 0.9))
        m.add("Metal", cyl(r * 0.85, 0.07, 10), T(x, 7.475 + h, 0.9))


# ---------- Caldera ----------
def caldera_vieja(m, rng):
    # Caldera de carbón de hierro fundido (4 × 5,4 × 3,6), de secciones con nervios. El frente (-Z) da a la sala: puerta
    # del fuego entreabierta y negra por dentro, puerta de las cenizas, manómetro y remaches. Detrás (+Z), el tiro sube
    # a 8 y se mete en la pared (z 2,5); dos tubos de agua suben al techo (8,6). Al lado (+X), un montón de carbón.
    m.add("Hierro", box(4.2, 0.5, 3.8), T(0, 0.25, 0))
    m.add("Hierro", box(3.3, 4.6, 3.4), T(0, 2.8, 0))
    for k in range(6):
        m.add("Hierro", box(3.6, 4.7, 0.42), T(0, 2.85, -1.45 + k * 0.58))
    m.add("Hierro", box(3.8, 0.35, 3.7), T(0, 5.37, 0))
    m.add("Hierro", box(3.8, 4.9, 0.16), T(0, 2.95, -1.82))
    for x in (-1.75, 1.75):
        for k in range(8):
            m.add("Hierro", sphere(0.06, 6, 3), T(x, 0.8 + k * 0.6, -1.92))
    # Puerta del fuego, entreabierta sobre su bisagra (x -0.8), y el hueco negro.
    m.add("Interior", box(1.5, 1.1, 0.05), T(0, 3.3, -1.88))
    m.add("Hierro", box(1.6, 1.2, 0.12), T(-0.8, 3.3, -1.97) @ R("Y", 35) @ T(0.8, 0, 0))
    m.add("Laton", cyl(0.06, 0.35, 6), T(-0.8, 3.3, -1.97) @ R("Y", 35) @ T(1.45, 0, -0.06) @ R("X", 90))
    for y in (2.85, 3.75):
        m.add("Hierro", cyl(0.08, 0.3, 6), T(-0.85, y, -1.95))
    # Puerta de las cenizas, cerrada.
    m.add("Hierro", box(1.6, 0.7, 0.12), T(0, 1.2, -1.95))
    for x in (-0.45, 0, 0.45):
        m.add("Interior", box(0.25, 0.08, 0.02), T(x, 1.2, -2.02))
    m.add("Laton", cyl(0.05, 0.3, 6), T(0.6, 1.2, -2.0) @ R("X", 90))
    # Manómetro.
    m.add("Laton", cyl(0.34, 0.12, 14), T(1.05, 4.55, -1.9) @ R("X", -90))
    m.add("Esfera", cyl(0.28, 0.02, 14), T(1.05, 4.55, -2.02) @ R("X", -90))
    m.add("Interior", box(0.03, 0.22, 0.01), T(1.05, 4.6, -2.045) @ R("Z", 50))
    # El tiro: sube detrás y entra en la pared.
    m.add("Tubo", cyl(0.42, 2.6, 12), T(0, 5.5, 0.9))
    cuerda(m, "Tubo", [Vector((0, 7.7, 0.9)), Vector((0, 8.0, 1.25)), Vector((0, 8.0, 2.55))], r=0.42, n=12)
    m.add("Tubo", cyl(0.5, 0.2, 12), T(0, 8.0, 2.4) @ R("X", 90))
    # Los tubos del agua: suben por los lados de atrás hasta el techo, con una llave de paso.
    for x in (-1.25, 1.25):
        cuerda(m, "Tubo", [Vector((x, 5.5, 1.3)), Vector((x, 7.2, 1.3)), Vector((x, 7.5, 1.6)), Vector((x, 8.6, 1.6))], r=0.14, n=8)
        m.add("Tubo", cyl(0.2, 0.25, 8), T(x, 6.4, 1.3))
    m.add("Laton", cyl(0.25, 0.06, 10), T(1.25, 6.55, 1.0) @ R("X", 90))
    # Carbón amontonado contra el lado de +X.
    for k in range(34):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0, 1.0) ** 0.7
        alto = (1.0 - d) * 1.2
        m.add("Carbon", blob((0.22, 0.18, 0.22), 100 + k, 6, 4, 0.35),
              T(3.0 + d * 1.1 * math.cos(a), 0.12 + rng.uniform(0, alto), -0.2 + d * 1.3 * math.sin(a)))


# ---------- Cadenas del techo ----------
def cadenas_techo(m, rng):
    # Tres cadenas que cuelgan de una argolla en la viga (la placa arriba, a 5,6 del punto más bajo): una acaba en un
    # gancho de carnicero, otra en un grillete abierto y la tercera, corta, suelta.
    H = 5.6
    m.add("Hierro", box(1.6, 0.12, 0.5), T(0.2, H - 0.06, 0))
    for x, largo, giro, final in ((-0.4, 4.6, 0, "gancho"), (0.3, 3.4, 30, "grillete"), (0.85, 2.4, 60, None)):
        n = int(largo / 0.3)
        for k in range(n):
            y = H - 0.25 - k * 0.3
            eslabon(m, "Hierro", (x, y, 0), (0, -1, 0), giro + 90 * (k % 2), r=0.14, grueso=0.04)
        fin = H - 0.25 - n * 0.3
        if final == "gancho":
            pts = [Vector((x, fin + 0.1, 0)), Vector((x, fin - 0.5, 0)), Vector((x + 0.15, fin - 0.75, 0)),
                   Vector((x + 0.38, fin - 0.7, 0)), Vector((x + 0.45, fin - 0.45, 0)), Vector((x + 0.38, fin - 0.3, 0))]
            cuerda(m, "Hierro", pts, r=0.05, n=6)
        elif final == "grillete":
            for k in range(10):
                a, b = math.pi * k / 10, math.pi * (k + 1) / 10
                m.rama("Hierro", (x + 0.22 * math.cos(a), fin - 0.15 - 0.3 * math.sin(a), 0),
                       (x + 0.22 * math.cos(b), fin - 0.15 - 0.3 * math.sin(b), 0), 0.05, 0.05, 6)
            m.add("Hierro", cyl(0.06, 0.3, 6), T(x + 0.22, fin - 0.15, 0) @ R("Z", 90) @ T(0, -0.15, 0))


# ---------- Cuerdas de la silla ----------
SILLA = {"pata_x": 1.06, "pata_z": -0.79, "detras_z": 1.05, "asiento": 1.8, "brazo": 2.55}  # SillaSotanoPH, medida


def cuerdas_silla(m, rng):
    # En los ejes de SillaSotanoPH (pivote abajo en el centro, frente a -Z): vueltas en las dos patas de delante y en los
    # brazos; la del brazo derecho, cortada, cuelga hasta el suelo; un lazo flojo caído sobre el asiento desde el
    # respaldo, y un rollo suelto en el suelo delante. Quien estaba atado ya no está.
    px, pz = SILLA["pata_x"], SILLA["pata_z"]
    for lado in (-1, 1):
        cuerda(m, "Cuerda", helice((lado * px, 0.32, pz), "y", 0.16, 3, 0.25), r=0.045)
        m.add("Cuerda", blob((0.1, 0.08, 0.1), 7 + lado, 6, 4, 0.2), T(lado * px, 0.45, pz - 0.17))
    # Brazos: espiral a lo largo de z.
    for lado in (-1, 1):
        pts = helice((lado * 1.02, SILLA["brazo"], -0.6), "z", 0.14, 3, 0.45)
        cuerda(m, "Cuerda", pts, r=0.045)
    # La del brazo derecho (+X), cortada: cae al suelo y se enrosca.
    fin = Vector((1.02, SILLA["brazo"] - 0.14, -0.15))
    cuerda(m, "Cuerda", [fin, fin + Vector((0.25, -0.6, -0.1)), fin + Vector((0.35, -1.6, -0.25)),
                         fin + Vector((0.3, -2.3, -0.4)), Vector((1.6, 0.05, -0.9)), Vector((1.9, 0.05, -1.3))], r=0.045)
    # Lazo flojo: rodea los postes del respaldo y cae sobre el asiento.
    y = 3.0
    dz = SILLA["detras_z"]
    cuerda(m, "Cuerda", [Vector((-1.04, y, dz + 0.12)), Vector((1.04, y, dz + 0.12)), Vector((1.1, y - 0.05, dz - 0.1)),
                         Vector((0.7, SILLA["asiento"] + 0.08, 0.2)), Vector((0, SILLA["asiento"] + 0.06, -0.3)),
                         Vector((-0.7, SILLA["asiento"] + 0.08, 0.1)), Vector((-1.1, y - 0.05, dz - 0.1)),
                         Vector((-1.04, y, dz + 0.12))], r=0.045)
    # Rollo en el suelo, delante a la izquierda.
    pts = []
    for k in range(40):
        a = k * 0.45
        r = 0.18 + k * 0.012
        pts.append(Vector((-1.3 + r * math.cos(a), 0.05 + 0.03 * (k % 3), -1.9 + r * math.sin(a))))
    cuerda(m, "Cuerda", pts, r=0.045, n=5)


# ---------- Tarros de la despensa ----------
def tarros_sotano(m, rng):
    # Una balda de tarros (5 de largo, dos filas) para DespensaPH: conservas viejas de color turbio; en dos, algo pálido
    # flotando. Unos con etiqueta. Origen: el centro de la balda.
    for fila, z in ((0, -0.35), (1, 0.4)):
        x = -2.35 + fila * 0.3
        while x < 2.3:
            r = rng.uniform(0.17, 0.25)
            h = rng.uniform(0.5, 0.85) if fila == 0 else rng.uniform(0.6, 0.9)
            m.add("Cristal", lathe([(0, 0), (r, 0), (r, h * 0.85), (r * 0.78, h)], 12), T(x, 0, z))
            lleno = rng.uniform(0.5, 0.8)
            m.add("Contenido", lathe([(0, 0.02), (r * 0.9, 0.02), (r * 0.9, h * lleno), (0, h * lleno)], 10), T(x, 0, z))
            if rng.random() < 0.3:
                m.add("Palido", blob((r * 0.55, r * 0.45, r * 0.5), int(x * 100), 6, 4, 0.3), T(x, h * lleno * 0.5, z))
            if rng.random() < 0.6:
                m.add("Tapa", cyl(r * 0.82, 0.08, 10), T(x, h, z))
            if fila == 0 and rng.random() < 0.6:
                m.add("Etiqueta", cyl(r * 1.01, h * 0.3, 12), T(x, h * 0.3, z))
            x += r * 2 + rng.uniform(0.05, 0.15)


# ---------- Registro ----------
a_mano.MUEBLES.update({
    "BancoCarpintero": (banco_carpintero, {
        "Madera": "wood_table_worn", "Tablero": "worn_planks", "Interior": (LISO, (0.04, 0.03, 0.02)),
        "Tornillo": (LISO, (0.3, 0.2, 0.12)), "Viruta": (LISO, (0.56, 0.42, 0.27)), "Clavija": (LISO, (0.4, 0.3, 0.2)),
        "Cristal": (LISO, (0.34, 0.38, 0.32)), "Clavos": (LISO, (0.3, 0.29, 0.27)), "Metal": (LISO, (0.28, 0.22, 0.16))},
        {"Madera": 3, "Tablero": 3, **{p: 1 for p in ("Interior", "Tornillo", "Viruta", "Clavija", "Cristal", "Clavos", "Metal")}},
        {"Madera": (0.85, 0.78, 0.7)}, ("Viruta", "Tornillo", "Clavija", "Cristal", "Metal")),
    "CalderaVieja": (caldera_vieja, {
        "Hierro": "rusty_metal_02", "Tubo": "rust_coarse_01", "Interior": (LISO, (0.02, 0.02, 0.02)),
        "Laton": (LISO, (0.45, 0.35, 0.18)), "Esfera": (LISO, (0.7, 0.66, 0.55)), "Carbon": (LISO, (0.06, 0.06, 0.06))},
        {"Hierro": 3, "Tubo": 2, **{p: 1 for p in ("Interior", "Laton", "Esfera", "Carbon")}},
        {"Hierro": (0.55, 0.5, 0.48), "Tubo": (0.6, 0.55, 0.5)}, ("Tubo", "Laton")),
    "CadenasTecho": (cadenas_techo, {"Hierro": (LISO, (0.26, 0.2, 0.16))}, {"Hierro": 1}, {}, ("Hierro",)),
    "CuerdasSilla": (cuerdas_silla, {"Cuerda": "rough_linen"}, {"Cuerda": 0.6}, {"Cuerda": (0.62, 0.5, 0.34)}, ("Cuerda",)),
    "TarrosSotano": (tarros_sotano, {
        "Cristal": (LISO, (0.36, 0.4, 0.32)), "Contenido": (LISO, (0.24, 0.16, 0.07)), "Palido": (LISO, (0.62, 0.55, 0.47)),
        "Tapa": (LISO, (0.3, 0.22, 0.15)), "Etiqueta": None},
        {"Cristal": 1, "Contenido": 1, "Palido": 1, "Tapa": 1, "Etiqueta": 1}, {}, ("Cristal", "Contenido", "Palido", "Tapa")),
})
a_mano.LIMPIOS |= {"Viruta"}

if __name__ == "__main__":
    a_mano.main()
