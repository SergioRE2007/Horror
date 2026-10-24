# Muebles que no hay en Poly Haven, hechos por script con texturas de Poly Haven (CC0): mismo resultado que
# polyhaven.py (una malla por material, texturas envejecidas, <nombre>_piezas.json, .fbx y vista .png).
# Uso: blender -b --factory-startup --python tools/blender/a_mano.py -- --nombre Perchero
# Muebles: Perchero (con abrigo y paraguas), Cartas (sobres tirados), AlfombraLarga (la del vestíbulo).
import argparse
import json
import math
import os
import random
import sys
import urllib.request

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import polyhaven  # noqa: E402
from geometria import OUT_DIR, R, S, T, box, cyl, lathe, limb, render, sphere  # noqa: E402

BAJADOS = os.path.join(OUT_DIR, "polyhaven", "_bajados")
ARRIBA = {"Alfombra", "Papel"}  # papeles hechos de láminas de una sola cara


def a_blender(v):
    # Ejes del juego (Y arriba, frente a -Z) -> Blender, con el frente a -Y como los de Poly Haven: polyhaven.py
    # exporta igual y eso sale en Roblox mirando a -Z (giro, no espejo: x cambia de signo).
    return (-v[0], v[2], v[1])


def textura_ph(asset, res="1k"):
    """Baja una textura de Poly Haven y devuelve las rutas de sus mapas de color, normal y rugosidad."""
    peticion = urllib.request.Request(polyhaven.API + asset, headers={"User-Agent": "JuegoTerror/1.0"})
    with urllib.request.urlopen(peticion, timeout=60) as respuesta:
        datos = json.loads(respuesta.read())
    rutas = {}
    for mapa in ("Diffuse", "nor_gl", "Rough"):
        archivo = datos[mapa][res]["jpg"]["url"]
        rutas[mapa] = os.path.join(BAJADOS, asset, os.path.basename(archivo))
        polyhaven.bajar(archivo, rutas[mapa])
    return rutas


def material_ph(nombre, asset=None, color=None):
    """Material con los mapas de una textura de Poly Haven, o con una imagen de color hecha aquí (`color`)."""
    mat = bpy.data.materials.new(nombre)
    mat.use_nodes = True
    nodos, enlaces = mat.node_tree.nodes, mat.node_tree.links
    bsdf = next(n for n in nodos if n.type == "BSDF_PRINCIPLED")
    rutas = textura_ph(asset) if asset else {}
    imagen = nodos.new("ShaderNodeTexImage")
    imagen.image = color or bpy.data.images.load(rutas["Diffuse"])
    enlaces.new(imagen.outputs["Color"], bsdf.inputs["Base Color"])
    if asset:
        rugosidad = nodos.new("ShaderNodeTexImage")
        rugosidad.image = bpy.data.images.load(rutas["Rough"])
        rugosidad.image.colorspace_settings.name = "Non-Color"
        enlaces.new(rugosidad.outputs["Color"], bsdf.inputs["Roughness"])
        normal = nodos.new("ShaderNodeTexImage")
        normal.image = bpy.data.images.load(rutas["nor_gl"])
        normal.image.colorspace_settings.name = "Non-Color"
        mapa = nodos.new("ShaderNodeNormalMap")
        enlaces.new(normal.outputs["Color"], mapa.inputs["Color"])
        enlaces.new(mapa.outputs["Normal"], bsdf.inputs["Normal"])
    else:
        bsdf.inputs["Roughness"].default_value = 0.9
    return mat


class Mueble:
    """Piezas por papel (cada papel = un material = una MeshPart), en ejes del juego y en studs."""

    def __init__(self):
        self.partes = {}

    def add(self, papel, forma, m=None):
        verts, caras = forma
        m = m or Matrix.Identity(4)
        mias = self.partes.setdefault(papel, ([], []))
        base = len(mias[0])
        mias[0].extend(tuple(m @ Vector(v)) for v in verts)
        mias[1].extend(tuple(base + i for i in c) for c in caras)

    def rama(self, papel, a, b, r0, r1, n=8):
        m, forma = limb(a, b, r0, r1, n)
        self.add(papel, forma, m)

    def crear(self, nombre, materiales, teselas, suaves=()):
        """Un objeto por papel con UV de caja (una baldosa de textura cada `teselas[papel]` studs)."""
        objetos = []
        for papel, (verts, caras) in self.partes.items():
            malla = bpy.data.meshes.new(papel)
            malla.from_pydata([a_blender(v) for v in verts], [], caras)
            bm = bmesh.new()
            bm.from_mesh(malla)
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
            bmesh.ops.triangulate(bm, faces=bm.faces)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            if papel in ARRIBA:  # láminas de una cara (alfombra, sobres): que se vean desde arriba
                for cara in bm.faces:
                    if cara.normal.z < 0:
                        cara.normal_flip()
            uv = bm.loops.layers.uv.new("UVMap")
            for cara in bm.faces:
                eje = max(range(3), key=lambda i: abs(cara.normal[i]))
                a, b = [i for i in range(3) if i != eje]
                for loop in cara.loops:
                    loop[uv].uv = (loop.vert.co[a] / teselas[papel], loop.vert.co[b] / teselas[papel])
            bm.to_mesh(malla)
            bm.free()
            if papel in suaves:
                for cara in malla.polygons:
                    cara.use_smooth = True
            malla.materials.append(materiales[papel])
            obj = bpy.data.objects.new(papel, malla)
            bpy.context.scene.collection.objects.link(obj)
            objetos.append(obj)
        return objetos


# ---------- Muebles ----------

def perchero(m, rng):
    # Pie de tres patas y palo torneado (1,85 m), cuatro ganchos arriba.
    for k in range(3):
        a = math.radians(90 + 120 * k)
        m.rama("Madera", (0, 1.0, 0), (1.15 * math.cos(a), 0.05, 1.15 * math.sin(a)), 0.13, 0.08)
    m.add("Madera", lathe([(0.2, 0.6), (0.26, 0.9), (0.15, 1.3), (0.13, 3.5), (0.17, 3.7), (0.12, 3.9),
                           (0.12, 6.4), (0.2, 6.6), (0.12, 6.9), (0.16, 7.1), (0.08, 7.35), (0, 7.4)], 12))
    for k in range(4):
        a = math.radians(45 + 90 * k)
        punta = (0.6 * math.cos(a), 6.95, 0.6 * math.sin(a))
        m.rama("Madera", (0, 6.55, 0), punta, 0.06, 0.05, 6)
        m.add("Madera", sphere(0.08, 6, 4), T(*punta))
    # Abrigo largo colgado del gancho de delante a la derecha, caído hasta media pierna, algo arrugado.
    # Hombros anchos y caídos, cintura y vuelo abajo; aplastado de delante atrás; mangas pegadas al cuerpo y cuello
    # levantado. Gira 45° para mirar hacia fuera del gancho.
    gancho = Vector((0.42, 6.85, -0.42))
    cuerpo = T(*gancho) @ R("Y", 45) @ T(0, -0.1, -0.32)
    m.add("Abrigo", lathe([(0.14, 0), (0.42, -0.12), (0.78, -0.45), (0.8, -0.8), (0.66, -1.6), (0.62, -2.2),
                           (0.7, -3.0), (0.82, -3.8), (0.86, -4.2)], 16, jitter=0.05, rng=rng), cuerpo @ S(1, 1, 0.42))
    for lado in (-1, 1):
        hombro = cuerpo @ Vector((lado * 0.72, -0.55, 0))
        codo = cuerpo @ Vector((lado * 0.8, -1.7, -0.05))
        mano = cuerpo @ Vector((lado * 0.72, -2.75, -0.12))
        m.rama("Abrigo", hombro, codo, 0.22, 0.2, 8)
        m.rama("Abrigo", codo, mano, 0.2, 0.19, 8)
    m.add("Abrigo", lathe([(0.2, -0.1), (0.3, 0.1), (0.34, 0.3)], 12, jitter=0.1, rng=rng), cuerpo @ S(1, 1, 0.7))
    # Sombrero de fieltro en el gancho de atrás a la izquierda.
    m.add("Paraguas", lathe([(0.62, 0), (0.6, 0.04), (0.33, 0.06), (0.31, 0.38), (0.22, 0.46), (0, 0.44)], 14),
          T(-0.45, 6.92, 0.45) @ R("X", 12) @ R("Z", -8))
    # Paraguas cerrado, apoyado en el pie: tela plegada (pocos lados, con saltos) y mango curvo de madera.
    pie = Vector((-0.95, 0, -0.35))
    arriba = Vector((-0.28, 3.6, -0.12))
    eje = arriba - pie
    giro = T(*pie) @ eje.to_track_quat("Y", "Z").to_matrix().to_4x4()
    largo = eje.length
    m.add("Paraguas", lathe([(0.02, 0), (0.05, 0.25), (0.3, 1.0), (0.26, 2.5), (0.12, largo - 0.55), (0.04, largo - 0.4)],
                            8, jitter=0.18, rng=rng), giro)
    m.add("Madera", cyl(0.035, 0.5, 6), giro @ T(0, largo - 0.45, 0))
    curva = [giro @ Vector((0.18 * (1 - math.cos(t)), largo + 0.18 * math.sin(t), 0))
             for t in (0, 0.8, 1.6, 2.4, 3.1)]
    for a, b in zip(curva, curva[1:]):
        m.rama("Madera", a, b, 0.06, 0.06, 6)


def cartas(m, rng):
    # Sobres tirados junto a la puerta, unos encima de otros; cada uno con su solapa (un poco levantada).
    puestos = []
    for _ in range(9):
        x, z = rng.uniform(-1.6, 1.6), rng.uniform(-1.0, 1.0)
        y = 0.012 + 0.025 * sum(1 for px, pz in puestos if abs(px - x) < 0.9 and abs(pz - z) < 0.6)
        puestos.append((x, z))
        giro = T(x, y, z) @ R("Y", rng.uniform(0, 360)) @ R("X", rng.uniform(-2, 2))
        m.add("Papel", box(0.95, 0.02, 0.55), giro)
        m.add("Papel", ([(-0.46, 0.012, -0.26), (0.46, 0.012, -0.26), (0, 0.022, 0.05)], [(0, 2, 1)]), giro)


def alfombra_larga(m, rng):
    # Alfombra de 4,5 x 13 studs: arrugas suaves a lo ancho, una esquina doblada encima, borde y flecos en las puntas.
    ancho, largo, alto = 4.5, 13.0, 0.06
    nx, nz = 8, 40

    def punto(i, j):
        x, z = -ancho / 2 + ancho * i / nx, -largo / 2 + largo * j / nz
        y = alto + 0.12 * max(0, math.sin(z * 0.9 + 1.3)) ** 6 + 0.06 * max(0, math.sin(z * 0.37)) ** 8
        return (x, y, z)

    verts = [punto(i, j) for j in range(nz + 1) for i in range(nx + 1)]
    caras = [(j * (nx + 1) + i, j * (nx + 1) + i + 1, (j + 1) * (nx + 1) + i + 1, (j + 1) * (nx + 1) + i)
             for j in range(nz) for i in range(nx)]
    # Esquina doblada: los vértices al otro lado de la diagonal se reflejan sobre ella y suben un poco.
    esquina = Vector((ancho / 2, -largo / 2))
    normal = Vector((-1, 1)).normalized()
    d0 = 1.1
    for k, (x, y, z) in enumerate(verts):
        d = (Vector((x, z)) - esquina).dot(normal)
        if d < d0:
            p = Vector((x, z)) + normal * 2 * (d0 - d)
            verts[k] = (p.x, y + alto + 0.03, p.y)
    m.add("Alfombra", (verts, caras))
    # Borde oscuro a lo largo y flecos en las dos puntas.
    for lado in (-1, 1):
        m.add("Borde", box(0.35, 0.02, largo - 0.2), T(lado * (ancho / 2 - 0.25), alto + 0.012, 0))
    for punta in (-1, 1):
        if punta == -1:
            continue  # la punta de delante está doblada
        for k in range(18):
            x = -ancho / 2 + 0.2 + (ancho - 0.4) * k / 17
            z = punta * largo / 2
            m.rama("Borde", (x, 0.02, z), (x + rng.uniform(-0.08, 0.08), 0.01, z + punta * rng.uniform(0.25, 0.4)), 0.03, 0.02, 3)


def balaustre(m, rng):
    # Barrote torneado de la escalera (0,8 m): dados abajo y arriba, jarrón y anillos.
    m.add("Madera", lathe([(0.17, 0), (0.17, 0.45), (0.11, 0.55), (0.08, 0.8), (0.15, 1.3), (0.15, 1.45), (0.07, 2.0),
                           (0.1, 2.45), (0.07, 2.6), (0.17, 2.7), (0.17, 3.2)], 10))


def poste_escalera(m, rng):
    # Poste del arranque de la escalera: base cuadrada, fuste torneado y bola arriba.
    m.add("Madera", box(0.8, 1.6, 0.8), T(0, 0.8, 0))
    m.add("Madera", lathe([(0.42, 1.6), (0.3, 1.75), (0.22, 2.0), (0.32, 2.6), (0.32, 2.75), (0.22, 3.3), (0.42, 3.5),
                           (0.42, 3.9), (0.28, 4.05), (0.2, 4.2), (0.3, 4.45), (0.33, 4.65), (0.24, 4.85), (0, 4.95)], 12))


def roseton(m, rng):
    # Rosetón de yeso del techo, del que cuelga la araña (se pone boca abajo): anillos y una corona de hojas.
    m.add("Yeso", lathe([(1.7, 0), (1.7, 0.06), (1.5, 0.1), (1.42, 0.18), (1.2, 0.2), (1.05, 0.28), (0.8, 0.3),
                         (0.55, 0.38), (0.3, 0.42), (0.22, 0.55), (0, 0.6)], 24))
    for k in range(16):
        a = 2 * math.pi * k / 16
        m.add("Yeso", sphere(0.14, 6, 4), T(1.28 * math.cos(a), 0.22, 1.28 * math.sin(a)) @ S(1.6, 0.6, 0.8) @ R("Y", -math.degrees(a)))


def papel_viejo(w=256):
    """Color de papel amarillento con grano y manchas, hecho aquí (en Poly Haven no hay papel)."""
    azar = np.random.default_rng(3)
    base = np.array([0.74, 0.68, 0.55], dtype=np.float32)
    rgb = np.ones((w, w, 3), dtype=np.float32) * base
    rgb *= (1 - azar.random((w, w, 1)).astype(np.float32) * 0.08)
    # A un .png y cargarlo: una imagen hecha con images.new se leía negra al envejecerla.
    ruta = os.path.join(BAJADOS, "papel_viejo.png")
    polyhaven.guardar("papel", rgb, w, w, ruta)
    return bpy.data.images.load(ruta)


MUEBLES = {
    # nombre: (función, {papel: textura de Poly Haven o None = papel_viejo}, {papel: studs por baldosa},
    #          {papel: tinte}, papeles suaves)
    "Perchero": (perchero, {"Madera": "dark_wood", "Abrigo": "poly_wool_herringbone", "Paraguas": "poly_wool_herringbone"},
                 {"Madera": 2, "Abrigo": 2.5, "Paraguas": 1.5},
                 {"Abrigo": (0.55, 0.45, 0.38), "Paraguas": (0.18, 0.17, 0.17)}, ("Abrigo", "Paraguas")),
    "Cartas": (cartas, {"Papel": None}, {"Papel": 1}, {}, ()),
    "Balaustre": (balaustre, {"Madera": "dark_wood"}, {"Madera": 2}, {}, ("Madera",)),
    "PosteEscalera": (poste_escalera, {"Madera": "dark_wood"}, {"Madera": 2}, {}, ("Madera",)),
    "Roseton": (roseton, {"Yeso": "worn_cracked_plaster"}, {"Yeso": 3}, {"Yeso": (0.8, 0.78, 0.72)}, ("Yeso",)),
    "AlfombraLarga": (alfombra_larga, {"Alfombra": "quatrefoil_jacquard_fabric", "Borde": "dirty_carpet"},
                      {"Alfombra": 3, "Borde": 2}, {"Alfombra": (0.75, 0.6, 0.55)}, ()),
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--nombre", required=True, choices=sorted(MUEBLES))
    parser.add_argument("--oscurecer", type=float, default=0.85)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    funcion, texturas, teselas, tintes, suaves = MUEBLES[args.nombre]

    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    m = Mueble()
    funcion(m, random.Random(11))
    materiales = {p: material_ph(p, t, None if t else papel_viejo()) for p, t in texturas.items()}
    objetos = m.crear(args.nombre, materiales, teselas, suaves)

    salida = os.path.join(OUT_DIR, "polyhaven", args.nombre)
    os.makedirs(salida, exist_ok=True)
    base = os.path.join(salida, args.nombre)
    piezas = []
    for k, obj in enumerate(sorted(objetos, key=lambda o: o.name), 1):
        papel = obj.name
        obj.name = obj.data.name = "%s_%d" % (args.nombre, k) if len(objetos) > 1 else args.nombre
        tinte = np.array(tintes.get(papel, (1, 1, 1)), dtype=np.float32) * args.oscurecer
        piezas.append(polyhaven.pieza(obj, base + ("_%d" % k if len(objetos) > 1 else ""), tinte))
    with open(base + "_piezas.json", "w", encoding="utf-8") as archivo:
        json.dump(piezas, archivo, indent=1)
    bpy.ops.export_scene.fbx(filepath=base + ".fbx", object_types={"MESH"}, axis_forward="-Z", axis_up="Y",
                             apply_scale_options="FBX_SCALE_UNITS", path_mode="STRIP", embed_textures=False)
    bpy.context.view_layer.update()
    puntos = [o.matrix_world @ Vector(c) for o in objetos for c in o.bound_box]
    tam = [max(p[i] for p in puntos) - min(p[i] for p in puntos) for i in range(3)]
    tris = sum(len(p.vertices) - 2 for o in objetos for p in o.data.polygons)
    print("PIEZAS %s" % ", ".join("%s%s" % (p["malla"], "" if p["texturas"] else " (liso)") for p in piezas))
    print("TAM %.3f %.3f %.3f (studs: ancho, alto, fondo)  triangulos %d" % (tam[0], tam[2], tam[1], tris))
    lado = max(tam[0], tam[2], tam[1] * 0.6) * 1.3
    bpy.context.scene.render.resolution_percentage = 50
    render(base + ".png", 0, lado, lado, tam[2] / 2, angle=210, pitch=25)


if __name__ == "__main__":  # textura_ph.py la importa por sus funciones
    main()
