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
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])

salida = os.path.join(OUT_DIR, "polyhaven", "texturas")
os.makedirs(salida, exist_ok=True)
tinte = np.array([float(c) for c in args.tinte.split(",")], dtype=np.float32) * args.oscurecer
polyhaven.sacar_texturas(a_mano.material_ph(args.nombre, args.id), os.path.join(salida, args.nombre), tinte,
                         not args.limpia)
print("HECHA", args.nombre)
