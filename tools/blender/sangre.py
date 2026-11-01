# Manchas de sangre seca (Moderate: oscura, marrón rojiza, sin vísceras) y yeso desconchado, con transparencia, para Decal: gotas que caen
# por la pared, un arrastre por el suelo y salpicaduras. Hechas con numpy, siempre iguales (semilla fija).
# Uso: blender -b --factory-startup --python tools/blender/sangre.py
# Sale en Documents\Roblox\modelos\polyhaven\texturas\Sangre<Tipo>.png.
import math
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from geometria import OUT_DIR  # noqa: E402

W = 512
COLOR = np.array([0.34, 0.04, 0.03], dtype=np.float32)  # sangre seca (como la de Mapa.abandonar, 90, 8, 8)
SALIDA = os.path.join(OUT_DIR, "polyhaven", "texturas")


def ruido(azar, celdas):
    rejilla = azar.random((celdas + 1, celdas + 1)).astype(np.float32)
    t = np.linspace(0, celdas, W, dtype=np.float32)
    i = np.minimum(t.astype(int), celdas - 1)
    f = t - i
    f = f * f * (3 - 2 * f)
    a, b = rejilla[i][:, i], rejilla[i][:, i + 1]
    c, d = rejilla[i + 1][:, i], rejilla[i + 1][:, i + 1]
    return (a * (1 - f[None, :]) + b * f[None, :]) * (1 - f[:, None]) + (c * (1 - f[None, :]) + d * f[None, :]) * f[:, None]


def disco(alfa, cx, cy, r, fuerza=1.0):
    y, x = np.mgrid[0:W, 0:W].astype(np.float32)
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
    np.maximum(alfa, np.clip((r - d) / 2, 0, 1) * fuerza, out=alfa)


def guardar(nombre, alfa, azar, rgb=None):
    borde = ruido(azar, 24)
    alfa = np.clip(alfa * (0.75 + 0.25 * borde), 0, 1)
    if rgb is None:
        rgb = COLOR[None, None, :] * (0.7 + 0.5 * ruido(azar, 12)[:, :, None])  # más oscura donde se acumuló
    rgba = np.zeros((W, W, 4), dtype=np.float32)
    rgba[:, :, :3] = rgb
    rgba[:, :, 3] = alfa
    imagen = bpy.data.images.new(nombre, W, W, alpha=True)
    imagen.pixels.foreach_set(rgba[::-1].ravel())  # Blender guarda de abajo arriba
    imagen.filepath_raw = os.path.join(SALIDA, nombre + ".png")
    imagen.file_format = "PNG"
    imagen.save()
    print("HECHA", nombre)


def gotas(azar):
    # Un manchón arriba (una mano que se apoyó y resbaló) y regueros finos que bajan.
    alfa = np.zeros((W, W), dtype=np.float32)
    mancha = ruido(azar, 6)
    y, x = np.mgrid[0:W, 0:W].astype(np.float32)
    d = np.sqrt(((x - 256) / 150) ** 2 + ((y - 120) / 90) ** 2)
    alfa = np.maximum(alfa, np.clip((1 - d) * 7 + (mancha - 0.5) * 4, 0, 1) * 0.9)
    for _ in range(9):
        x0 = azar.uniform(150, 360)
        largo = azar.uniform(120, 380)
        grosor = azar.uniform(2.5, 6)
        for k in range(int(largo)):
            disco(alfa, x0 + math.sin(k * 0.03) * 3, 150 + k, grosor * (1 - 0.5 * k / largo), 0.85)
        disco(alfa, x0, 150 + largo, grosor * 1.4, 0.9)  # la gota del final
    guardar("SangreGotas", alfa, azar)


def arrastre(azar):
    # Arrastre por el suelo: una franja que se va aclarando, con huecos y bordes deshilachados.
    y, x = np.mgrid[0:W, 0:W].astype(np.float32)
    centro = 256 + 30 * np.sin(y / 90)
    ancho = 70 + 20 * ruido(azar, 8) - 40 * (y / W)
    alfa = np.clip((ancho - np.abs(x - centro)) / 12, 0, 1)
    # Rayas a lo largo del arrastre (la ropa dejó surcos): ruido que cambia de lado a lado y casi nada hacia delante.
    rayas = np.interp(x[0] - 30 * np.sin(y[:, :1] / 90), np.linspace(0, W, 90), azar.random(90))
    alfa *= np.clip((1 - y / W) * 1.4, 0, 1) * np.clip(rayas * 1.8 - 0.3, 0, 1) * (0.6 + 0.4 * ruido(azar, 6))
    guardar("SangreArrastre", alfa, azar)


def salpicadura(azar):
    alfa = np.zeros((W, W), dtype=np.float32)
    y, x = np.mgrid[0:W, 0:W].astype(np.float32)
    angulo = np.arctan2(y - 256, x - 256)
    borde = 55 * (1 + 0.25 * np.sin(5 * angulo + 1) + 0.15 * np.sin(9 * angulo + 3) + 0.1 * np.sin(17 * angulo))
    np.maximum(alfa, np.clip((borde - np.sqrt((x - 256) ** 2 + (y - 256) ** 2)) / 2, 0, 1) * 0.9, out=alfa)
    for _ in range(40):
        a = azar.uniform(0, 2 * math.pi)
        r = azar.uniform(70, 230)
        disco(alfa, 256 + math.cos(a) * r, 256 + math.sin(a) * r, azar.uniform(3, 14) * (1 - r / 300), 0.9)
    guardar("SangreSalpicadura", alfa, azar)


def desconchon(azar):
    # Papel arrancado: yeso claro y sucio en una mancha de borde roto, con el borde del papel más oscuro alrededor.
    y, x = np.mgrid[0:W, 0:W].astype(np.float32)
    angulo = np.arctan2(y - 256, x - 256)
    radio = 170 * (1 + 0.2 * np.sin(3 * angulo + 2) + 0.12 * np.sin(7 * angulo) + 0.06 * np.sin(19 * angulo + 1))
    d = np.sqrt((x - 256) ** 2 + ((y - 256) * 1.3) ** 2) + 60 * (ruido(azar, 10) - 0.5)
    alfa = np.clip((radio - d) / 3, 0, 1)
    yeso = np.array([0.42, 0.38, 0.31], dtype=np.float32)[None, None, :] * (0.65 + 0.45 * ruido(azar, 30)[:, :, None])
    filo = np.clip(1 - np.abs(radio - d - 6) / 6, 0, 1)[:, :, None]  # el borde del papel, oscuro
    guardar("Desconchon", alfa, azar, yeso * (1 - filo * 0.6))


HOLLIN = np.array([0.05, 0.045, 0.04], dtype=np.float32)


def hollin(azar):
    # Hollín esparcido delante del hogar (salón, 11.8.2): abanico negro que sale de un lado y se va aclarando.
    y, x = np.mgrid[0:W, 0:W].astype(np.float32)
    d = np.sqrt(((x - 256) / 230) ** 2 + ((y - 40) / 420) ** 2)
    alfa = np.clip((1 - d) * 2.2, 0, 1) * (0.35 + 0.65 * ruido(azar, 10)) * np.clip(1.3 - y / W, 0, 1)
    guardar("Hollin", alfa, azar, HOLLIN[None, None, :] * (0.8 + 0.4 * ruido(azar, 20)[:, :, None]))


def huellas(azar):
    # Huellas de hollín de algo que salió de la chimenea: planta alargada y tres uñas delante, alternando los pies y
    # cada vez más flojas (la imagen se recorre de arriba abajo).
    alfa = np.zeros((W, W), dtype=np.float32)
    for k in range(4):
        cx, cy = 256 + (60 if k % 2 else -60), 60 + k * 125
        fuerza = 0.95 - 0.2 * k
        for t in range(14):
            disco(alfa, cx + azar.uniform(-3, 3), cy + t * 3, 22 - abs(t - 6) * 1.5, fuerza)
        for dx in (-22, 0, 22):
            for t in range(18):
                disco(alfa, cx + dx * (1 + t / 30), cy + 44 + t * 2.4, 5 - t * 0.2, fuerza)
    guardar("Huellas", alfa, azar, HOLLIN[None, None, :] * (0.8 + 0.4 * ruido(azar, 20)[:, :, None]))


def aranazos(azar):
    # Arañazos de uñas en la puerta del sótano (pasillo, 11.8.5): grupos de cuatro surcos que bajan, de madera rascada
    # más clara, con algo de sangre seca donde empiezan (alguien quiso abrirla con las manos).
    alfa = np.zeros((W, W), dtype=np.float32)
    sangre = np.zeros((W, W), dtype=np.float32)
    for _ in range(6):
        x0, y0 = azar.uniform(90, 420), azar.uniform(30, 260)
        largo, tuerce = azar.uniform(120, 240), azar.uniform(-0.25, 0.25)
        for dedo in range(4):
            dx = dedo * 17 + azar.uniform(-2, 2)
            n = int(largo * azar.uniform(0.7, 1))
            for k in range(0, n, 2):
                x, y = x0 + dx + tuerce * k + 4 * math.sin(k / 40), y0 + k
                disco(alfa, x, y, 4.2 * (1 - 0.5 * k / n), 0.9)
                if k < 40:
                    disco(sangre, x, y, 3.5, 1 - k / 40)
    madera = np.array([0.74, 0.62, 0.46], dtype=np.float32)[None, None, :] * (0.8 + 0.3 * ruido(azar, 20)[:, :, None])
    rgb = madera * (1 - sangre[:, :, None]) + COLOR[None, None, :] * sangre[:, :, None]
    guardar("Aranazos", alfa, azar, rgb)


def grietas(azar):
    # Espejo roto de un golpe (baño, 11.8.5): grietas claras que salen del punto del golpe, un anillo alrededor y un
    # poco de sangre seca en el centro.
    alfa = np.zeros((W, W), dtype=np.float32)
    sangre = np.zeros((W, W), dtype=np.float32)
    cx, cy = 230, 200
    for k in range(14):
        a = 2 * math.pi * k / 14 + azar.uniform(-0.2, 0.2)
        x, y, largo = cx, cy, azar.uniform(150, 320)
        for t in range(0, int(largo), 2):
            a += azar.uniform(-0.08, 0.08)
            x, y = x + 2 * math.cos(a), y + 2 * math.sin(a)
            disco(alfa, x, y, 2.8 * (1 - 0.5 * t / largo), 0.95)
    for k in range(60):  # el anillo, a trozos
        a = 2 * math.pi * k / 60
        r = 55 + azar.uniform(-6, 6)
        disco(alfa, cx + r * math.cos(a), cy + r * math.sin(a), 2.4, 0.9)
    disco(alfa, cx, cy, 14, 0.8)
    disco(sangre, cx, cy, 22, 1)
    for _ in range(6):
        disco(sangre, cx + azar.uniform(-30, 30), cy + azar.uniform(-10, 40), azar.uniform(3, 8), 1)
    np.maximum(alfa, sangre * 0.9, out=alfa)
    rgb = np.ones((W, W, 3), dtype=np.float32) * 0.85
    rgb = rgb * (1 - sangre[:, :, None]) + COLOR[None, None, :] * sangre[:, :, None]
    guardar("Grietas", alfa, azar, rgb)


os.makedirs(SALIDA, exist_ok=True)
azar = np.random.default_rng(13)
gotas(azar)
arrastre(azar)
salpicadura(azar)
desconchon(azar)
hollin(azar)
huellas(azar)
aranazos(azar)
grietas(azar)
