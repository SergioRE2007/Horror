# Baja una textura de Poly Haven (CC0) y la envejece como los muebles, para un MaterialVariant de paredes, suelos y
# techos (en Roblox el color de la pieza no tiñe la textura de un MaterialVariant: el tinte va aquí).
# Uso: blender -b --factory-startup --python tools/blender/textura_ph.py -- --id wooden_panels --nombre PanelVestibulo
#      [--tinte 0.8,0.7,0.6] [--oscurecer 0.85] [--limpia]
# Sale en Documents\Roblox\modelos\polyhaven\texturas\: <nombre>_color, _normal y _rugosidad (.png).
import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import a_mano  # noqa: E402
import polyhaven  # noqa: E402
from geometria import OUT_DIR  # noqa: E402

parser = argparse.ArgumentParser()
parser.add_argument("--id", required=True)
parser.add_argument("--nombre", required=True)
parser.add_argument("--tinte", default="1,1,1")
parser.add_argument("--oscurecer", type=float, default=0.85)
parser.add_argument("--limpia", action="store_true", help="sin manchas (en suelos se ven en cuadrícula)")
parser.add_argument("--rayas", action="store_true", help="papel de rayas verticales (salón)")
parser.add_argument("--flores", action="store_true", help="papel de florecillas (dormitorio de abajo)")
parser.add_argument("--damasco", action="store_true", help="papel de damasco (galería o dormitorio grande)")
parser.add_argument("--damasco-estilo", choices=("galeria", "dormitorio"), default="galeria",
                    help="con --damasco: medallones dorados de galería u ojivas del dormitorio grande")
parser.add_argument("--colores", default="0.5,0.56,0.44/0.8,0.74,0.6/0.42,0.14,0.12",
                    help="con --rayas: banda ancha, banda clara e hilo (r,g,b separados por /)")
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])

salida = os.path.join(OUT_DIR, "polyhaven", "texturas")
os.makedirs(salida, exist_ok=True)
tinte = np.array([float(c) for c in args.tinte.split(",")], dtype=np.float32) * args.oscurecer
polyhaven.sacar_texturas(a_mano.material_ph(args.nombre, args.id), os.path.join(salida, args.nombre), tinte,
                         not args.limpia)
print("HECHA", args.nombre)

# --rayas: papel pintado de rayas verticales de los años 50 (salón, 11.8.2), encima del papel viejo de Poly Haven: banda
# verde salvia y banda crema con un hilo rojo oscuro (otros con --colores, como el pasillo); 8 rayas por baldosa (con
# StudsPerTile 8, una cada stud).
if args.rayas:
    import bpy

    ruta = os.path.join(salida, args.nombre) + "_color.png"
    imagen = bpy.data.images.load(ruta)
    w, h = imagen.size
    pixeles = np.empty(w * h * 4, dtype=np.float32)
    imagen.pixels.foreach_get(pixeles)
    rgb = pixeles.reshape(h, w, 4)[:, :, :3]
    luz = rgb.mean(axis=2, keepdims=True) / max(rgb.mean(), 1e-3)
    columna = np.arange(w) % (w // 8) / (w // 8)
    ancha, clara, hilo = ([float(c) for c in color.split(",")] for color in args.colores.split("/"))
    raya = np.where(columna[:, None] < 0.5, ancha, clara).astype(np.float32)
    raya[(columna > 0.73) & (columna < 0.77)] = hilo
    rgb = rgb * 0.4 + luz * raya[None, :, :] * rgb.mean() * 1.1
    polyhaven.guardar("rayas", rgb, w, h, ruta)
    print("RAYAS", args.nombre)

# --flores: papel de florecillas de abuela (dormitorio de abajo, 11.8.6), encima del papel viejo de Poly Haven: ramitos
# de capullos rosa desvaído con dos hojas verde oliva, en filas alternas, sobre el fondo crema; 4 por fila por baldosa.
if args.flores:
    import bpy

    ruta = os.path.join(salida, args.nombre) + "_color.png"
    imagen = bpy.data.images.load(ruta)
    w, h = imagen.size
    pixeles = np.empty(w * h * 4, dtype=np.float32)
    imagen.pixels.foreach_get(pixeles)
    rgb = pixeles.reshape(h, w, 4)[:, :, :3]
    luz = rgb.mean(axis=2, keepdims=True) / max(rgb.mean(), 1e-3)
    n = 4
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    fila = np.floor(yy / h * n)
    u = (xx / w * n + 0.5 * (fila % 2)) % 1 - 0.5  # media vuelta cada fila
    v = (yy / h * n) % 1 - 0.5
    fondo, rosa, rosa_osc, hoja = (np.array(c, dtype=np.float32) for c in
                                   ((0.82, 0.76, 0.6), (0.72, 0.45, 0.44), (0.5, 0.25, 0.27), (0.42, 0.46, 0.3)))
    color = np.ones((h, w, 3), dtype=np.float32) * fondo
    for su, sv, k in ((-0.1, -0.02, 1.0), (0.1, 0.06, 0.8)):  # dos capullos por ramito
        d = np.hypot(u - su, (v - sv) * 1.2)
        color[d < 0.075 * k] = rosa
        espiral = np.abs(np.sin(np.arctan2(v - sv, u - su) * 2 + d * 90)) < 0.35
        color[(d < 0.06 * k) & espiral] = rosa_osc
    for su, sv, giro in ((-0.02, 0.13, 0.6), (0.17, -0.07, -0.8)):  # hojas
        a, b = u - su, v - sv
        c, s = np.cos(giro), np.sin(giro)
        color[((a * c - b * s) / 0.07) ** 2 + ((a * s + b * c) / 0.028) ** 2 < 1] = hoja
    tallo = (np.abs(v - 0.02 - (u * 0.5)) < 0.006) & (np.abs(u) < 0.13)
    color[tallo] = hoja * 0.8
    rgb = rgb * 0.35 + luz * color * rgb.mean() * 1.15
    polyhaven.guardar("flores", rgb, w, h, ruta)
    print("FLORES", args.nombre)

# --damasco: papel de damasco de casa rica (galería, 11.8.7), encima del papel viejo de Poly Haven: medallones lobulados
# de oro viejo con una flor de lis dentro, sobre azul pizarra, en filas alternas, y una red de rombos fina; 3 por fila por
# baldosa.
# --damasco --damasco-estilo dormitorio: papel de damasco de casa rica (dormitorio grande, 11.8.8), encima del papel viejo de Poly Haven: medallones
# en forma de ojiva con una flor de lis dentro, un tono más claro que el fondo azul grisáceo y
# perfilados en oscuro; 3 por fila por baldosa, en filas alternas.
if args.damasco:
    import bpy

    ruta = os.path.join(salida, args.nombre) + "_color.png"
    imagen = bpy.data.images.load(ruta)
    w, h = imagen.size
    pixeles = np.empty(w * h * 4, dtype=np.float32)
    imagen.pixels.foreach_get(pixeles)
    rgb = pixeles.reshape(h, w, 4)[:, :, :3]
    luz = rgb.mean(axis=2, keepdims=True) / max(rgb.mean(), 1e-3)
    n = 3
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    fila = np.floor(yy / h * n)
    if args.damasco_estilo == "galeria":
        u = (xx / w * n + 0.5 * (fila % 2)) % 1 - 0.5
        v = (yy / h * n) % 1 - 0.5
        fondo, oro, oro_osc = (np.array(c, dtype=np.float32) for c in ((0.3, 0.35, 0.4), (0.62, 0.56, 0.4), (0.44, 0.4, 0.3)))
        color = np.ones((h, w, 3), dtype=np.float32) * fondo
        d = np.hypot(u, v * 0.8)
        a = np.arctan2(v, u)
        borde = 0.3 + 0.05 * np.cos(4 * a) + 0.025 * np.cos(8 * a)  # medallón lobulado
        color[(d < borde) & (d > borde - 0.035)] = oro
        color[(d < borde - 0.07) & (d > borde - 0.085)] = oro_osc
        # Flor de lis: pétalo de en medio y dos curvos a los lados, con su atadura.
        # (+v es arriba en la imagen: los pétalos suben desde la atadura y debajo queda el pie.)
        color[(u / 0.045) ** 2 + ((v - 0.05) / 0.13) ** 2 < 1] = oro
        for lado in (-1, 1):
            c, sn = np.cos(lado * 0.6), np.sin(lado * 0.6)
            pu, pv = u - lado * 0.085, v - 0.01
            color[((pu * c - pv * sn) / 0.03) ** 2 + ((pu * sn + pv * c) / 0.085) ** 2 < 1] = oro
        color[(u / 0.03) ** 2 + ((v + 0.13) / 0.05) ** 2 < 1] = oro
        color[(np.abs(u) < 0.11) & (np.abs(v + 0.07) < 0.018)] = oro_osc
        # Red de rombos fina entre medallones.
        color[np.abs(np.abs(u) + np.abs(v) - 0.5) < 0.008] = oro_osc
    else:
        u = np.abs((xx / w * n + 0.5 * (fila % 2)) % 1 - 0.5)  # simétrico: solo la mitad derecha
        v = (yy / h * n) % 1 - 0.5  # en Blender la fila 0 es la de abajo: v crece hacia arriba
        fondo, claro, perfil = (np.array(c, dtype=np.float32) for c in ((0.3, 0.4, 0.5), (0.5, 0.58, 0.64), (0.19, 0.25, 0.32)))
        color = np.ones((h, w, 3), dtype=np.float32) * fondo
        t = np.clip(v + 0.5, 0, 1)
        borde = 0.33 * np.sin(np.pi * t) ** 0.75 * (1.15 - 0.45 * t)  # ojiva, más ancha abajo
        color[(u < borde) & (u > borde - 0.035)] = perfil
        dentro = u < borde - 0.06
        color[dentro & (u > borde - 0.085)] = claro
        # Flor de lis: pétalo de arriba, dos laterales curvados, tallo y atadura.
        color[dentro & ((u / 0.06) ** 2 + ((v - 0.12) / 0.16) ** 2 < 1)] = claro
        ang = 0.7
        a, b = u - 0.11, v - 0.02
        lat = ((a * np.cos(ang) - b * np.sin(ang)) / 0.04) ** 2 + ((a * np.sin(ang) + b * np.cos(ang)) / 0.12) ** 2 < 1
        color[dentro & lat] = claro
        color[dentro & (np.abs(v + 0.08) < 0.018) & (u < 0.1)] = perfil
        color[dentro & (u < 0.018) & (v < -0.08) & (v > -0.3)] = claro
    rgb = rgb * 0.35 + luz * color * rgb.mean() * 1.15
    polyhaven.guardar("damasco", rgb, w, h, ruta)
    print("DAMASCO", args.nombre)
