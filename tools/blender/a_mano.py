# Muebles que no hay en Poly Haven, hechos por script con texturas de Poly Haven (CC0): mismo resultado que
# polyhaven.py (una malla por material, texturas envejecidas, <nombre>_piezas.json, .fbx y vista .png).
# Uso: blender -b --factory-startup --python tools/blender/a_mano.py -- --nombre Perchero
# Muebles: Perchero (con abrigo y paraguas), Cartas (sobres tirados), AlfombraLarga (la del vestíbulo); del salón,
# SofaTapado, Piano, Banqueta, Repisa, LamparaPie, AlfombraSalon y CortinaVano (la de los vanos de toda la casa); de la
# cocina, EncimeraCocina, EncimeraAbierta, FregaderoCocina, AlacenaCocina y AlacenaAbierta; del pasillo y el baño,
# VaterViejo, LavaboPie, CortinaDucha, Toallas, Paraguero y CadenaPuerta.
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
LIMPIOS = {"Sabana"}  # telas claras: las manchas grandes del envejecido las hacían parecer piedra
# Muebles enteros sin esas manchas: en la madera pintada clara de la cocina parecían camuflaje (la textura ya trae óxido).
MUEBLES_LIMPIOS = {"EncimeraCocina", "EncimeraAbierta", "FregaderoCocina", "AlacenaCocina", "AlacenaAbierta",
                   "NeveraVieja"}


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
    # Paraguas cerrado, apoyado en el pie.
    paraguas(m, rng, Vector((-0.95, 0, -0.35)), Vector((-0.28, 3.6, -0.12)))


def paraguas(m, rng, pie, arriba, grueso=1.0):
    """Paraguas cerrado de `pie` a `arriba`: tela plegada (pocos lados, con saltos) y mango curvo de madera."""
    eje = arriba - pie
    giro = T(*pie) @ eje.to_track_quat("Y", "Z").to_matrix().to_4x4()
    largo = eje.length
    m.add("Paraguas", lathe([(0.02, 0), (0.05, 0.25), (0.3, 1.0), (0.26, 2.5), (0.12, largo - 0.55), (0.04, largo - 0.4)],
                            8, jitter=0.18, rng=rng), giro @ S(grueso, 1, grueso))
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


def imagen_lisa(nombre, rgb, w=64):
    """Color liso con algo de grano (latón, teclas negras, flecos)."""
    azar = np.random.default_rng(5)
    color = np.ones((w, w, 3), dtype=np.float32) * np.array(rgb, dtype=np.float32)
    color *= (1 - azar.random((w, w, 1)).astype(np.float32) * 0.1)
    ruta = os.path.join(BAJADOS, "liso_%s.png" % nombre)
    polyhaven.guardar(nombre, color, w, w, ruta)
    return bpy.data.images.load(ruta)


def teclas_piano(w=64):
    """Una tecla blanca (marfil) con su raya oscura al borde: se repite cada 0,15 studs a lo largo del teclado."""
    color = np.ones((w, w, 3), dtype=np.float32) * np.array([0.86, 0.82, 0.7], dtype=np.float32)
    color[:, :4] = 0.12
    ruta = os.path.join(BAJADOS, "teclas_piano.png")
    polyhaven.guardar("teclas", color, w, w, ruta)
    return bpy.data.images.load(ruta)


def alfombra_persa(w=1024, tesela=10.0, mitad=(5.0, 4.3)):
    """Alfombra persa de una pieza (cenefa con motivos, campo rojo, medallón y esquinas azules), en studs: la UV de
    caja pone el centro de la alfombra en la esquina de la imagen, por eso cada píxel se pasa a (x, z) con módulo."""
    t = (np.arange(w, dtype=np.float32) / w + 0.5) % 1 - 0.5
    x = np.abs(t[None, :] * tesela)
    z = np.abs(t[:, None] * tesela)
    d = np.minimum(mitad[0] - x, mitad[1] - z)  # distancia al borde
    rojo, azul, crema = np.array([0.42, 0.08, 0.07]), np.array([0.09, 0.11, 0.2]), np.array([0.78, 0.7, 0.55])
    rgb = np.ones((w, w, 3), dtype=np.float32) * rojo
    cenefa = (d > 0.15) & (d < 0.75)
    a_lo_largo = np.where(mitad[0] - x < mitad[1] - z, z, x)
    zigzag = 0.3 + 0.3 * np.abs((a_lo_largo * 1.6) % 1 - 0.5)  # greca en zigzag a lo largo de la cenefa
    motivo = (np.abs(d - zigzag) < 0.05) & cenefa
    rgb[d <= 0.15] = azul
    rgb[cenefa] = azul * 1.3
    rgb[motivo] = crema * 0.75
    rgb[(d >= 0.75) & (d < 0.85)] = crema
    rombo = x / 2.4 + z / 1.9
    rgb[(rombo < 1) & (d >= 0.85)] = azul
    rgb[(rombo < 0.8) & (rombo > 0.7)] = crema
    rgb[rombo < 0.45] = rojo * 0.8
    rgb[(rombo < 0.2)] = crema
    esquina = (mitad[0] - 0.85 - x) / 1.6 + (mitad[1] - 0.85 - z) / 1.3
    rgb[(esquina < 1) & (d >= 0.85)] = azul
    # Florecillas por el campo rojo y desgaste.
    flor = (np.sin(x * 6) * np.sin(z * 6) > 0.85) & (rombo >= 1) & (esquina >= 1) & (d >= 0.85)
    rgb[flor] = rojo * 0.55  # florecillas oscuras (claras parecían lunares)
    azar = np.random.default_rng(9)
    rgb *= (1 - azar.random((w, w, 1)).astype(np.float32) * 0.18)
    ruta = os.path.join(BAJADOS, "alfombra_persa.png")
    polyhaven.guardar("alfombra", rgb, w, w, ruta)
    return bpy.data.images.load(ruta)


def tela(m, papel, f, nu, nv, grosor):
    """Tela con grueso (cerrada, para que se vea por las dos caras): f(u, v) -> punto, con u y v de 0 a 1."""
    P = [[Vector(f(i / nu, j / nv)) for i in range(nu + 1)] for j in range(nv + 1)]
    delante, detras = [], []
    for j in range(nv + 1):
        for i in range(nu + 1):
            du = P[j][min(i + 1, nu)] - P[j][max(i - 1, 0)]
            dv = P[min(j + 1, nv)][i] - P[max(j - 1, 0)][i]
            n = du.cross(dv).normalized() * grosor / 2
            delante.append(tuple(P[j][i] + n))
            detras.append(tuple(P[j][i] - n))
    N = len(delante)

    def k(i, j):
        return j * (nu + 1) + i

    caras = []
    for j in range(nv):
        for i in range(nu):
            q = (k(i, j), k(i + 1, j), k(i + 1, j + 1), k(i, j + 1))
            caras += [q, tuple(N + c for c in reversed(q))]
    borde = [(i, 0) for i in range(nu)] + [(nu, j) for j in range(nv)] + [(i, nv) for i in range(nu, 0, -1)] + \
        [(0, j) for j in range(nv, 0, -1)]
    for a, b in zip(borde, borde[1:] + borde[:1]):
        caras.append((k(*a), k(*b), N + k(*b), N + k(*a)))
    m.add(papel, (delante + detras, caras))


def sofa_tapado(m, rng):
    # Sofá de tres plazas tapado con una sábana hasta el suelo (casa cerrada): las formas del sofá con cajas, un remallado
    # en vóxeles las funde y redondea, y luego la tela cae en pliegues hacia abajo y se abre un poco en el suelo.
    largo, fondo = 8.8, 3.6
    cajas = [((0, 0.9, 0), (largo - 1.4, 1.8, fondo)), ((0, 2.2, 1.2), (largo - 1.2, 2.3, 1.2)),
             ((-largo / 2 + 0.45, 1.25, 0), (0.9, 2.5, fondo)), ((largo / 2 - 0.45, 1.25, 0), (0.9, 2.5, fondo)),
             ((-1.8, 1.95, -0.3), (3.4, 0.4, 2.7)), ((1.8, 1.9, -0.3), (3.4, 0.35, 2.7))]
    bm = bmesh.new()
    for centro, tam in cajas:
        hecho = bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.transform(bm, matrix=T(*centro) @ S(*tam), verts=hecho["verts"])
    malla = bpy.data.meshes.new("nucleo")
    bm.to_mesh(malla)
    bm.free()
    obj = bpy.data.objects.new("nucleo", malla)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    remallar = obj.modifiers.new("remallar", "REMESH")
    remallar.mode = "VOXEL"
    remallar.voxel_size = 0.1
    bpy.ops.object.modifier_apply(modifier="remallar")
    suave = obj.modifiers.new("suave", "SMOOTH")
    suave.factor, suave.iterations = 0.6, 5
    bpy.ops.object.modifier_apply(modifier="suave")
    malla.update()
    for v in malla.vertices:
        x, y, z = v.co
        n = Vector((v.normal.x, 0, v.normal.z))
        if n.length > 0.3:
            n.normalize()
            a_lo_largo = x if abs(n.z) > abs(n.x) else z
            pliegue = 0.2 * max(0.0, 1 - y / 2.0) ** 1.5 + 0.03
            onda = math.sin(a_lo_largo * 2.6 + 0.8 * math.sin(a_lo_largo * 0.9 + z))
            abierto = 0.2 * max(0.0, 1 - y / 0.45) ** 2
            v.co += n * (pliegue * onda + abierto)
        v.co.y = max(v.co.y + 0.03 * math.sin(x * 3.1) * math.sin(z * 2.7) * (y > 1.5), 0.01)
    bm = bmesh.new()
    bm.from_mesh(malla)
    bmesh.ops.delete(bm, geom=[c for c in bm.faces if all(v.co.y < 0.05 for v in c.verts)], context="FACES")
    bm.to_mesh(malla)
    bm.free()
    menos = obj.modifiers.new("menos", "DECIMATE")
    menos.ratio = min(1.0, 3500 / max(1, sum(len(p.vertices) - 2 for p in malla.polygons)))
    bpy.ops.object.modifier_apply(modifier="menos")
    m.add("Sabana", ([tuple(v.co) for v in malla.vertices], [tuple(p.vertices) for p in malla.polygons]))
    bpy.data.objects.remove(obj, do_unlink=True)


def piano(m, rng):
    # Piano vertical de los años 50 (1,5 m de ancho): caja, tapa, teclado abierto con partituras en el atril,
    # patas torneadas delante y dos pedales.
    m.add("Madera", box(6, 5.0, 1.3), T(0, 2.5, 0.55))
    m.add("Madera", box(6.2, 0.15, 1.45), T(0, 5.07, 0.55))
    m.add("Madera", box(5.2, 1.6, 0.08), T(0, 3.95, -0.13))
    m.add("Madera", box(5.0, 2.1, 0.08), T(0, 1.2, -0.13))
    m.add("Madera", box(5.7, 0.35, 1.1), T(0, 2.55, -0.6))
    for lado in (-1, 1):
        m.add("Madera", box(0.25, 0.55, 1.1), T(lado * 2.85, 2.95, -0.6))
        m.add("Madera", box(0.35, 0.2, 1.1), T(lado * 2.6, 0.1, -0.55))
        m.add("Madera", lathe([(0.14, 0.2), (0.18, 0.3), (0.12, 0.6), (0.16, 1.3), (0.1, 1.95), (0.17, 2.2), (0.17, 2.38)], 10),
              T(lado * 2.6, 0, -0.95))
    m.add("Teclas", box(5.4, 0.12, 0.85), T(0, 2.79, -0.62))
    for i in range(35):
        if i % 7 in (0, 1, 3, 4, 5):
            m.add("Negras", box(0.09, 0.1, 0.5), T(-2.7 + (i + 1) * 0.15, 2.9, -0.45))
    m.add("Madera", box(5.4, 0.5, 0.06), T(0, 3.05, -0.15))
    atril = T(0, 3.55, -0.25) @ R("X", -12)
    m.add("Madera", box(3, 0.9, 0.06), atril)
    for k, x in enumerate((-0.72, 0.72)):
        m.add("Papel", box(1.4, 0.95, 0.01), atril @ T(x, 0.1, -0.04) @ R("Z", (k - 0.5) * 3))
    for x in (-0.3, 0.3):
        m.add("Laton", box(0.12, 0.05, 0.4), T(x, 0.3, -0.3))


def banqueta(m, rng):
    # Banqueta del piano: asiento de cuero sobre cuatro patas torneadas.
    m.add("Madera", box(2.6, 0.25, 1.1), T(0, 1.75, 0))
    m.add("Cuero", box(2.4, 0.18, 0.95), T(0, 1.96, 0))
    for x in (-1.1, 1.1):
        for z in (-0.4, 0.4):
            m.add("Madera", lathe([(0.1, 0), (0.08, 0.3), (0.11, 0.8), (0.07, 1.4), (0.1, 1.63)], 8), T(x, 0, z))


def repisa(m, rng):
    # Frente tallado de la chimenea del salón (8 de ancho, contra el ladrillo): pilastras con basa y capitel a los lados
    # del hogar, friso con tablilla y rosetas, molduras y la repisa encima.
    for lado in (-1, 1):
        m.add("Madera", box(0.9, 4.0, 0.6), T(lado * 2.6, 2.0, -0.3))
        m.add("Madera", box(1.1, 0.4, 0.75), T(lado * 2.6, 0.2, -0.37))
        m.add("Madera", box(1.1, 0.3, 0.75), T(lado * 2.6, 4.1, -0.37))
        m.add("Madera", box(0.5, 0.4, 0.5), T(lado * 3.55, 4.3, -0.7))
        m.add("Madera", sphere(0.22, 8, 5), T(lado * 1.6, 3.85, -0.47) @ S(1, 1, 0.4))
    m.add("Madera", box(6.3, 0.75, 0.45), T(0, 3.85, -0.22))
    m.add("Madera", box(1.6, 0.5, 0.12), T(0, 3.85, -0.5))
    m.add("Madera", box(6.8, 0.12, 0.6), T(0, 4.31, -0.3))
    m.add("Madera", box(7.6, 0.1, 1.1), T(0, 4.45, -0.55))
    m.add("Madera", box(7.8, 0.22, 1.2), T(0, 4.6, -0.6))


def lampara_pie(m, rng):
    # Lámpara de pie: base y palo de latón, pantalla de tela amarillenta (hueca, para que la bombilla se vea debajo).
    m.add("Laton", lathe([(0.6, 0), (0.6, 0.1), (0.35, 0.25), (0.12, 0.4)], 14))
    m.add("Laton", cyl(0.06, 5.6, 8), T(0, 0.35, 0))
    m.add("Pantalla", lathe([(0.95, 5.25), (0.55, 6.45), (0.52, 6.43), (0.91, 5.27), (0.95, 5.25)], 18, caps=False))


def alfombra_salon(m, rng):
    # Alfombra persa de 10 x 8,6 delante de la tele, con arrugas suaves, una esquina levantada y flecos en las puntas.
    ancho, largo, alto = 10.0, 8.6, 0.06
    nx, nz = 30, 26

    def punto(i, j):
        x, z = -ancho / 2 + ancho * i / nx, -largo / 2 + largo * j / nz
        y = alto + 0.1 * max(0, math.sin(x * 0.8 + 0.6)) ** 8 + 0.05 * max(0, math.sin(z * 0.5 + x * 0.2)) ** 6
        y += 0.25 * max(0, 1 - Vector((x - ancho / 2, z + largo / 2)).length / 1.5) ** 2  # esquina levantada
        return (x, y, z)

    verts = [punto(i, j) for j in range(nz + 1) for i in range(nx + 1)]
    caras = [(j * (nx + 1) + i, j * (nx + 1) + i + 1, (j + 1) * (nx + 1) + i + 1, (j + 1) * (nx + 1) + i)
             for j in range(nz) for i in range(nx)]
    m.add("Alfombra", (verts, caras))
    for punta in (-1, 1):
        for k in range(30):
            z = -largo / 2 + 0.2 + (largo - 0.4) * k / 29
            x = punta * ancho / 2
            m.rama("Borde", (x, 0.02, z), (x + punta * rng.uniform(0.25, 0.4), 0.01, z + rng.uniform(-0.08, 0.08)), 0.03, 0.02, 3)


def cortina_vano(m, rng):
    # Cortina de terciopelo de los vanos abiertos (10,6 de alto): fruncida arriba, recogida con un cordón a media altura
    # y algo abierta abajo. Simétrica: sirve a los dos lados del vano.
    alto, atada = 10.6, 3.8

    def mitad(y):
        if y > atada:
            return 0.32 + 0.53 * ((y - atada) / (alto - atada)) ** 0.8
        return 0.32 + 0.3 * ((atada - y) / atada) ** 0.8

    def f(u, v):
        y = v * alto
        w = mitad(y)
        hondo = 0.03 + 0.15 * w / 0.85
        return ((u - 0.5) * 2 * w, y, hondo * math.sin(u * 2 * math.pi * 4.5) + 0.04 * math.sin(v * 7))

    tela(m, "Tela", f, 24, 16, 0.06)
    m.add("Cordon", lathe([(0.36, -0.1), (0.42, 0), (0.36, 0.1)], 10), T(0, atada, 0) @ S(1, 1, 0.55))
    m.rama("Cordon", (0.3, atada, -0.1), (0.38, atada - 1.1, -0.18), 0.06, 0.09, 6)


def planta_seca(m, rng):
    # Planta muerta para la maceta (MacetaPH, 1,75 de alto): tallos secos que salen de la tierra y se doblan hacia fuera,
    # con hojas arrugadas en las puntas y alguna caída sobre el borde.
    m.add("Tierra", cyl(0.95, 0.12, 14), T(0, 1.5, 0))
    for k in range(11):
        a = k * 2.4 + rng.uniform(-0.3, 0.3)
        alto, caida = rng.uniform(1.3, 3.0), rng.uniform(0.4, 1.3)
        base = (0.35 * rng.random() * math.cos(a), 1.55, 0.35 * rng.random() * math.sin(a))
        codo = (base[0] + 0.3 * caida * math.cos(a), 1.55 + alto, base[2] + 0.3 * caida * math.sin(a))
        punta = (codo[0] + caida * math.cos(a), codo[1] - caida * rng.uniform(0.6, 1.2), codo[2] + caida * math.sin(a))
        m.rama("Tallo", base, codo, 0.045, 0.03, 6)
        m.rama("Tallo", codo, punta, 0.03, 0.015, 6)
        for d in (codo, punta):
            m.add("Hoja", sphere(0.22, 6, 4), T(*d) @ R("Z", rng.uniform(-60, 60)) @ S(1, 0.15, 0.55))
    for k in range(3):
        a = rng.uniform(0, 2 * math.pi)
        m.add("Hoja", sphere(0.22, 6, 4), T(1.05 * math.cos(a), 1.72, 1.05 * math.sin(a)) @ R("Y", math.degrees(a)) @ S(1, 0.15, 0.55))


# ---------- Cocina (11.8.4): muebles de los 50, de 3 de ancho (en Roblox se estiran a lo largo), frente a -Z ----------

def puerta_cocina(m, ancho, alto, centro, bisagra, abierta=0.0):
    """Puerta de cuarterones (marco, tablero hundido y pomo) con la bisagra a un lado (-1 izquierda, 1 derecha):
    `centro` es el de la puerta cerrada, `abierta` en grados."""
    x, y, z = centro
    eje = T(x + bisagra * ancho / 2, y, z) @ R("Y", -bisagra * abierta) @ T(-bisagra * ancho / 2, 0, 0)
    for lado in (-1, 1):
        m.add("Madera", box(0.2, alto, 0.08), eje @ T(lado * (ancho / 2 - 0.1), 0, 0))
        m.add("Madera", box(ancho - 0.4, 0.2, 0.08), eje @ T(0, lado * (alto / 2 - 0.1), 0))
    m.add("Madera", box(ancho - 0.4, alto - 0.4, 0.04), eje @ T(0, 0, 0.02))
    # Pomo arriba en las de abajo y abajo en las de pared.
    m.add("Metal", sphere(0.07, 8, 5), eje @ T(-bisagra * (ancho / 2 - 0.2), (alto / 2 - 0.45) * (1 if alto < 2.5 else -1), -0.08))


def caja_cocina(m, ancho, alto, fondo, y0, techo=True):
    """Cuerpo hueco (costados, fondo, techo, suelo y una balda) con el interior oscuro; el frente, abierto, en -fondo/2."""
    for lado in (-1, 1):
        m.add("Madera", box(0.1, alto, fondo), T(lado * (ancho / 2 - 0.05), y0 + alto / 2, 0))
    m.add("Madera", box(ancho, 0.1, fondo), T(0, y0 + 0.05, 0))
    if techo:  # sin él en el fregadero: taparía la pila
        m.add("Madera", box(ancho, 0.1, fondo), T(0, y0 + alto - 0.05, 0))
    m.add("Interior", box(ancho - 0.2, alto - 0.2, 0.05), T(0, y0 + alto / 2, fondo / 2 - 0.05))
    m.add("Interior", box(ancho - 0.2, 0.06, fondo - 0.2), T(0, y0 + alto / 2, 0.05))


def tarros(m, rng, x0, x1, y, z):
    # Tarros de cristal con tapa, en fila sobre una balda (en la alacena abierta).
    x = x0
    while x < x1:
        r, h = rng.uniform(0.16, 0.22), rng.uniform(0.45, 0.65)
        m.add("Cristal", lathe([(0, 0), (r, 0), (r, h * 0.85), (r * 0.8, h)], 10), T(x, y, z))
        m.add("Metal", cyl(r * 0.85, 0.07, 10), T(x, y + h, z))
        x += r * 2 + 0.1


def encimera_cocina(m, rng, ancho=3.0, abierta=0.0, puertas=True):
    # Mueble bajo: zócalo hundido, cuerpo hueco, cajón con tirador, dos puertas y encimera de madera encima (3,5 de
    # alto, 2,4 de fondo con el vuelo).
    fondo = 2.2
    m.add("Interior", box(ancho, 0.35, fondo - 0.4), T(0, 0.175, 0.3))
    caja_cocina(m, ancho, 3.0, fondo, 0.35)
    z = -fondo / 2 - 0.04
    m.add("Madera", box(ancho - 0.12, 0.55, 0.08), T(0, 2.95, z))
    m.add("Metal", box(0.7, 0.08, 0.1), T(0, 2.95, z - 0.08))
    if puertas:
        hoja = (ancho - 0.12) / 2
        for k, lado in enumerate((-1, 1)):
            puerta_cocina(m, hoja - 0.04, 2.15, (lado * hoja / 2, 1.5, z), lado, abierta if k == 1 else 0)
    m.add("Encimera", box(ancho + 0.02, 0.2, fondo + 0.2), T(0, 3.4, -0.1))


def encimera_abierta(m, rng):
    encimera_cocina(m, rng, abierta=65)
    # Dentro, a la vista por la puerta abierta: una olla volcada y un par de tarros.
    tarros(m, rng, 0.3, 1.2, 1.9 + 0.03, 0.2)
    m.add("Metal", cyl(0.4, 0.5, 12), T(0.7, 0.45, 0.1) @ R("Z", 80))


def fregadero_cocina(m, rng):
    # Mueble del fregadero (4 de ancho): pila de loza honda en la encimera, grifo de pared de dos llaves y escurridor.
    ancho, fondo = 4.0, 2.2
    m.add("Interior", box(ancho, 0.35, fondo - 0.4), T(0, 0.175, 0.3))
    caja_cocina(m, ancho, 3.0, fondo, 0.35, techo=False)
    z = -fondo / 2 - 0.04
    m.add("Madera", box(ancho - 0.12, 0.55, 0.08), T(0, 2.95, z))
    hoja = (ancho - 0.12) / 2
    for lado in (-1, 1):
        puerta_cocina(m, hoja - 0.04, 2.15, (lado * hoja / 2, 1.5, z), lado)
    # Encimera con el hueco de la pila (2,6 × 1,5, algo hacia delante).
    pila_x, pila_z, pila_a = 2.6, 1.5, -0.25
    m.add("Encimera", box(ancho + 0.02, 0.2, 0.5), T(0, 3.4, 0.75))
    m.add("Encimera", box(ancho + 0.02, 0.2, 0.2), T(0, 3.4, -1.1))
    for lado in (-1, 1):
        m.add("Encimera", box((ancho - pila_x) / 2, 0.2, pila_z), T(lado * (ancho + pila_x) / 4, 3.4, pila_a))
    m.add("Esmalte", box(pila_x, 0.08, pila_z), T(0, 2.75, pila_a))
    for lado in (-1, 1):
        m.add("Esmalte", box(0.08, 0.75, pila_z), T(lado * (pila_x / 2 - 0.04), 3.1, pila_a))
        m.add("Esmalte", box(pila_x, 0.75, 0.08), T(0, 3.1, pila_a + lado * (pila_z / 2 - 0.04)))
    m.add("Interior", cyl(0.12, 0.02, 10), T(0, 2.79, pila_a))
    # Grifo: dos llaves y el caño curvo, saliendo de la pared de atrás.
    for lado in (-1, 1):
        m.rama("Metal", (lado * 0.35, 4.3, 1.1), (lado * 0.35, 4.3, 0.85), 0.05, 0.05)
        m.add("Metal", box(0.35, 0.06, 0.06), T(lado * 0.35, 4.3, 0.85))
    for a, b in (((0, 4.3, 1.1), (0, 4.3, 0.6)), ((0, 4.3, 0.6), (0, 4.0, 0.25)), ((0, 4.0, 0.25), (0, 3.75, 0.2))):
        m.rama("Metal", a, b, 0.06, 0.05)
    m.add("Metal", box(1.2, 0.08, 0.06), T(0, 4.3, 1.08))
    # Escurridor de madera a la derecha, con dos platos de pie.
    for k in range(5):
        m.add("Madera", box(0.06, 0.45, 1.0), T(1.25 + k * 0.12, 3.75, -0.1))
    m.add("Madera", box(0.7, 0.05, 1.1), T(1.5, 3.52, -0.1))


def alacena_cocina(m, rng, abierta=0.0):
    # Alacena de pared (3 de ancho, 3 de alto, 1,4 de fondo) con dos puertas y moldura abajo; la abierta, con tarros.
    ancho, alto, fondo = 3.0, 3.0, 1.4
    caja_cocina(m, ancho, alto, fondo, 0)
    z = -fondo / 2 - 0.04
    hoja = (ancho - 0.06) / 2
    for k, lado in enumerate((-1, 1)):
        puerta_cocina(m, hoja - 0.04, alto - 0.1, (lado * hoja / 2, alto / 2, z), lado, abierta if k == 0 else 0)
    m.add("Madera", box(ancho + 0.1, 0.15, fondo + 0.1), T(0, 0.075, -0.05))
    m.add("Madera", box(ancho + 0.2, 0.18, fondo + 0.15), T(0, alto - 0.09, -0.07))
    if abierta:
        tarros(m, rng, -1.3, -0.2, 0.1, 0.1)
        tarros(m, rng, -1.3, -0.1, alto / 2 + 0.03, 0.1)


def alacena_abierta(m, rng):
    alacena_cocina(m, rng, 110)


def esmalte_nevera(w=512):
    """Esmalte crema de nevera vieja: grano, mugre abajo, picaduras de óxido (más cerca del suelo) y chorretones. Una
    baldosa cubre la nevera entera de alto (la fila 0 es el suelo)."""
    azar = np.random.default_rng(7)
    v, u = np.mgrid[0:w, 0:w].astype(np.float32) / w
    rgb = np.ones((w, w, 3), dtype=np.float32) * np.array([0.8, 0.76, 0.64], dtype=np.float32)
    rgb *= (1 - azar.random((w, w, 1)).astype(np.float32) * 0.06)
    rgb *= (0.72 + 0.28 * np.clip(v / 0.18, 0, 1))[..., None]  # mugre junto al suelo
    oxido = np.array([0.4, 0.21, 0.1], dtype=np.float32)
    # Picaduras de borde irregular (radio que cambia con el ángulo), más junto a los cantos y abajo, y polvo de óxido.
    for _ in range(30):
        cu = azar.choice([azar.uniform(0, 0.12), azar.uniform(0.88, 1), azar.random()])
        cv = azar.random() ** 2.5
        r = azar.uniform(0.005, 0.02)
        ang = np.arctan2(v - cv, u - cu)
        borde = 1 + 0.22 * np.sin(2 * ang + azar.uniform(0, 6)) + 0.1 * np.sin(5 * ang + azar.uniform(0, 6))
        d = np.sqrt((u - cu) ** 2 + (v - cv) ** 2) / (r * borde)
        a = np.clip(1.2 - d, 0, 1)[..., None]
        rgb = rgb * (1 - a) + oxido * (0.6 + 0.4 * np.clip(1 - d, 0, 1))[..., None] * a
    polvo = (azar.random((w, w)) < 0.004 * (1 - v) ** 3)[..., None] * 0.7
    rgb = rgb * (1 - polvo) + oxido * polvo
    # Canto de abajo comido por el óxido, con el borde roto.
    corte = 0.035 + 0.025 * np.sin(u * 40) * np.sin(u * 13 + 1) + azar.random((1, w)) * 0.015
    a = np.clip((corte - v) / 0.01, 0, 1)[..., None] * 0.8
    rgb = rgb * (1 - a) + oxido * 0.8 * a
    for _ in range(14):  # chorretones de óxido hacia abajo
        cu, cv = azar.random(), azar.uniform(0.2, 0.9)
        largo, ancho = azar.uniform(0.05, 0.25), azar.uniform(0.002, 0.005)
        dentro = (np.abs(u - cu) < ancho) & (v < cv) & (v > cv - largo)
        a = (dentro * 0.45 * np.clip((v - (cv - largo)) / largo, 0, 1))[..., None]
        rgb = rgb * (1 - a) + oxido * a
    ruta = os.path.join(BAJADOS, "esmalte_nevera.png")
    polyhaven.guardar("esmalte", rgb, w, w, ruta)
    return bpy.data.images.load(ruta)


def perfil_redondo(ancho, alto, r, n=6):
    """Contorno de frente (x, y) con las esquinas de arriba redondeadas, desde abajo a la izquierda."""
    pts = [(-ancho / 2, 0), (ancho / 2, 0)]
    for k in range(n + 1):
        a = math.pi / 2 * k / n
        pts.append((ancho / 2 - r + r * math.cos(a), alto - r + r * math.sin(a)))
    for k in range(n + 1):
        a = math.pi / 2 + math.pi / 2 * k / n
        pts.append((-ancho / 2 + r + r * math.cos(a), alto - r + r * math.sin(a)))
    return pts


def extruir(pts, z0, z1, y0=0.0):
    """Pieza de canto recto a partir de un contorno de frente, de z0 (delante) a z1 (detrás)."""
    n = len(pts)
    verts = [(x, y + y0, z0) for x, y in pts] + [(x, y + y0, z1) for x, y in pts]
    caras = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    caras += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return verts, caras


def nevera_vieja(m, rng):
    # Nevera de los 50 (3 de ancho, 6,2 de alto): cuerpo y puerta de esquinas redondas, tirador de palanca cromado,
    # placa con la marca, bisagras y rejilla abajo.
    m.add("Esmalte", extruir(perfil_redondo(3.0, 6.0, 0.7), -1.0, 1.3, 0.2))
    m.add("Interior", box(2.9, 0.2, 2.2), T(0, 0.1, 0.15))
    m.add("Esmalte", extruir(perfil_redondo(2.84, 5.3, 0.62), -1.2, -1.0, 0.75))
    m.add("Interior", box(2.6, 0.45, 0.04), T(0, 0.45, -1.0))
    for k in range(4):
        m.add("Cromo", box(2.5, 0.05, 0.05), T(0, 0.28 + k * 0.1, -1.04))
    for y in (1.2, 5.4):
        m.add("Cromo", box(0.12, 0.5, 0.12), T(-1.44, y, -1.12))
    m.add("Cromo", box(0.9, 0.2, 0.04), T(0, 5.45, -1.21))
    for y in (3.4, 4.6):
        m.rama("Cromo", (1.12, y, -1.2), (1.12, y, -1.42), 0.06, 0.05)
    m.rama("Cromo", (1.12, 3.32, -1.42), (1.12, 4.68, -1.42), 0.07, 0.07)
    m.add("Cromo", box(0.3, 1.5, 0.04), T(1.12, 4.0, -1.21))


# ---------- Pasillo, baño y trastero (11.8.5) ----------

def loza(w=512):
    """Loza vieja de baño: blanco roto con grano, cuarteado fino, mugre abajo y chorretones de cal y óxido. Una
    baldosa cubre 4 studs de alto (la fila 0 es el suelo)."""
    azar = np.random.default_rng(5)
    v, u = np.mgrid[0:w, 0:w].astype(np.float32) / w
    rgb = np.ones((w, w, 3), dtype=np.float32) * np.array([0.84, 0.82, 0.76], dtype=np.float32)
    rgb *= (1 - azar.random((w, w, 1)).astype(np.float32) * 0.05)
    rgb *= (0.68 + 0.32 * np.clip(v / 0.3, 0, 1))[..., None]  # mugre abajo
    cal = np.array([0.5, 0.44, 0.3], dtype=np.float32)
    for _ in range(70):  # cuarteado: rayas finas sueltas
        x0, y0 = azar.random(2)
        ang = azar.uniform(0, np.pi)
        t = (u - x0) * np.cos(ang) + (v - y0) * np.sin(ang)
        d = np.abs((u - x0) * np.sin(ang) - (v - y0) * np.cos(ang))
        a = ((d < 0.0014) & (t > 0) & (t < azar.uniform(0.03, 0.12)))[..., None] * 0.4
        rgb = rgb * (1 - a) + cal * a
    oxido = np.array([0.45, 0.27, 0.12], dtype=np.float32)
    for _ in range(12):  # chorretones hacia abajo
        cu, cv = azar.random(), azar.uniform(0.3, 1)
        largo, ancho = azar.uniform(0.1, 0.4), azar.uniform(0.003, 0.008)
        dentro = (np.abs(u - cu) < ancho) & (v < cv) & (v > cv - largo)
        a = (dentro * 0.35 * np.clip((v - (cv - largo)) / largo, 0, 1))[..., None]
        rgb = rgb * (1 - a) + oxido * a
    ruta = os.path.join(BAJADOS, "loza.png")
    polyhaven.guardar("loza", rgb, w, w, ruta)
    return bpy.data.images.load(ruta)


def vater_viejo(m, rng):
    # Váter de principios de siglo: taza de loza sobre un pie (1,55 de alto), asiento de madera con la tapa levantada y
    # cisterna alta de hierro en la pared (a 7,6) con el tubo de bajada y la cadena con tirador. Espalda a +Z.
    taza = T(0, 0, -0.15) @ S(1, 1, 1.25)
    m.add("Loza", lathe([(0.5, 0), (0.42, 0.15), (0.36, 0.6), (0.46, 1.05), (0.72, 1.45), (0.76, 1.55), (0.64, 1.56),
                         (0.5, 1.3), (0.28, 1.0), (0, 0.95)], 16), taza)
    m.add("Loza", box(0.7, 1.3, 0.7), T(0, 0.75, 0.75))  # cuello hasta la pared
    m.add("Madera", lathe([(0.76, 1.57), (0.8, 1.62), (0.74, 1.67), (0.5, 1.67), (0.46, 1.62), (0.5, 1.57), (0.76, 1.57)],
                          16, caps=False), taza)
    # Tapa levantada contra el tubo (gira en la bisagra de atrás).
    m.add("Madera", cyl(0.76, 0.07, 16), T(0, 1.66, 0.85) @ R("X", 100) @ T(0, 0, -0.95) @ S(1, 1, 1.25))
    m.add("Hierro", box(1.9, 0.95, 0.75), T(0, 7.6, 0.92))
    m.add("Hierro", box(2.05, 0.12, 0.85), T(0, 8.13, 0.88))  # tapa con reborde
    for lado in (-1, 1):  # ménsulas
        m.add("Hierro", box(0.12, 0.6, 0.6), T(lado * 0.7, 6.95, 1.0))
    m.rama("Metal", (0, 7.13, 0.95), (0, 1.5, 0.95), 0.09, 0.09)  # tubo de bajada
    m.rama("Metal", (0, 1.5, 0.95), (0, 1.3, 0.6), 0.09, 0.09)
    m.add("Metal", box(0.5, 0.06, 0.06), T(0.75, 7.2, 0.6))  # palanca
    for k in range(18):  # cadena: eslabones cruzados
        m.add("Metal", box(0.05, 0.13, 0.02) if k % 2 else box(0.02, 0.13, 0.05), T(1.0, 7.15 - k * 0.14, 0.6))
    m.add("Loza", lathe([(0, 0), (0.09, 0.05), (0.11, 0.25), (0.06, 0.45), (0, 0.5)], 8), T(1.0, 4.55, 0.6))


def lavabo_pie(m, rng):
    # Lavabo de pie de loza (4 de alto): pie torneado, pila ovalada honda con reborde, trasera con dos grifos de cruceta
    # y el caño. Espalda a +Z.
    m.add("Loza", lathe([(0.55, 0), (0.45, 0.12), (0.3, 0.5), (0.26, 1.8), (0.34, 2.4), (0.5, 2.7), (0, 2.75)], 14))
    pila = T(0, 0, -0.05) @ S(1, 1, 0.78)
    m.add("Loza", lathe([(0.5, 2.6), (0.95, 2.95), (1.12, 3.25), (1.15, 3.38), (1.0, 3.4), (0.85, 3.2), (0.35, 3.0),
                         (0, 2.98)], 18), pila)
    m.add("Loza", box(2.3, 0.75, 0.3), T(0, 3.65, 0.78))  # trasera
    m.add("Loza", box(2.3, 0.18, 0.55), T(0, 3.32, 0.66))  # repisa de los grifos
    for lado in (-1, 1):
        m.rama("Metal", (lado * 0.6, 3.4, 0.7), (lado * 0.6, 3.75, 0.7), 0.05, 0.05)
        m.add("Metal", box(0.36, 0.05, 0.05), T(lado * 0.6, 3.75, 0.7))
        m.add("Metal", box(0.05, 0.05, 0.36), T(lado * 0.6, 3.75, 0.7))
    m.rama("Metal", (0, 3.4, 0.6), (0, 3.7, 0.55), 0.06, 0.06)
    m.rama("Metal", (0, 3.7, 0.55), (0, 3.6, 0.15), 0.05, 0.045)
    m.add("Interior", cyl(0.1, 0.02, 10), T(0, 3.0, -0.05))  # desagüe


def camino_u(largo, fondo, r, n=6):
    """Barra en U vista desde arriba (x, z): de atrás a la izquierda, por delante, a atrás a la derecha, con las dos
    esquinas de delante redondeadas. Devuelve los puntos y su largo acumulado."""
    pts = [(-largo / 2, fondo / 2), (-largo / 2, -fondo / 2 + r)]
    for k in range(1, n + 1):
        a = math.pi + math.pi / 2 * k / n
        pts.append((-largo / 2 + r + r * math.cos(a), -fondo / 2 + r + r * math.sin(a)))
    for k in range(n + 1):
        a = 1.5 * math.pi + math.pi / 2 * k / n
        pts.append((largo / 2 - r + r * math.cos(a), -fondo / 2 + r + r * math.sin(a)))
    pts.append((largo / 2, fondo / 2))
    acum = [0.0]
    for a, b in zip(pts, pts[1:]):
        acum.append(acum[-1] + math.dist(a, b))
    return pts, acum


def en_camino(pts, acum, s):
    """Punto (x, z) y normal hacia fuera a la distancia `s` de un camino_u."""
    for i in range(len(pts) - 1):
        if s <= acum[i + 1] or i == len(pts) - 2:
            t = (s - acum[i]) / max(acum[i + 1] - acum[i], 1e-6)
            (x0, z0), (x1, z1) = pts[i], pts[i + 1]
            dx, dz = (x1 - x0), (z1 - z0)
            largo = math.hypot(dx, dz) or 1
            return (x0 + dx * t, z0 + dz * t), (dz / largo, -dx / largo)


def cortina_ducha(m, rng):
    # Cortina corrida alrededor de la bañera de patas (7,5 × 3,2): barra en U a 7,4 del suelo, sujeta a la pared y al
    # techo (11,8) por una varilla, y la tela tapando el frente y los dos lados hasta dentro de la bañera, con pliegues
    # y el bajo irregular. No se ve qué hay dentro. Espalda (la pared) a +Z.
    largo, fondo, alto, abajo = 7.3, 2.9, 7.4, 1.6
    pts, acum = camino_u(largo, fondo, 0.6)
    total = acum[-1]

    def f(u, v):
        (x, z), (nx, nz) = en_camino(pts, acum, u * total)
        pliegue = 0.13 * math.sin(u * total / 0.42 * math.pi) * (0.55 + 0.45 * (1 - v))
        bajo = abajo + 0.12 * math.sin(u * total * 2.3) + 0.08 * math.sin(u * total * 5.1 + 1)
        y = bajo + v * (alto - 0.12 - bajo)
        return (x + nx * pliegue, y, z + nz * pliegue)

    tela(m, "Tela", f, 140, 10, 0.03)
    for a, b in zip(pts, pts[1:]):
        m.rama("Metal", (a[0], alto, a[1]), (b[0], alto, b[1]), 0.05, 0.05, 6)
    for k in range(int(total / 0.42)):  # anillas
        (x, z), _ = en_camino(pts, acum, (k + 0.5) * 0.42)
        m.add("Metal", box(0.05, 0.22, 0.05), T(x, alto - 0.08, z))
    for x in (-largo / 2, largo / 2):  # a la pared
        m.add("Metal", cyl(0.14, 0.05, 8), T(x, alto, fondo / 2) @ R("X", 90))
    m.rama("Metal", (0, alto, -fondo / 2), (0, 11.8, -fondo / 2), 0.04, 0.04, 6)  # varilla al techo
    m.add("Metal", cyl(0.18, 0.05, 8), T(0, 11.75, -fondo / 2))


def toallas(m, rng):
    # Dos toallas sucias tiradas en el suelo: una hecha un montón y otra medio extendida encima de una esquina.
    def monton(cx, cz, ancho, hondo, alto, giro, semilla):
        def f(u, v):
            x, z = (u - 0.5) * ancho, (v - 0.5) * hondo
            bulto = math.exp(-((x / (ancho * 0.35)) ** 2 + (z / (hondo * 0.35)) ** 2))
            y = 0.05 + alto * bulto * (0.65 + 0.35 * math.sin(7 * x + semilla) * math.sin(5 * z)) \
                + 0.04 * math.sin(13 * x + 3 * z + semilla)
            c, s = math.cos(giro), math.sin(giro)
            return (cx + x * c - z * s, y, cz + x * s + z * c)
        tela(m, "Toalla", f, 18, 14, 0.06)
    monton(0, 0, 2.4, 1.6, 0.8, 0.3, 1.0)
    monton(1.0, 0.6, 2.0, 1.3, 0.3, -0.7, 2.5)


def paraguero(m, rng):
    # Paragüero de latón (2,2 de alto) con dos paraguas cerrados y un bastón de madera.
    m.add("Laton", lathe([(0.52, 0), (0.56, 0.08), (0.5, 0.2), (0.5, 1.9), (0.56, 2.1), (0.54, 2.2), (0.48, 2.2),
                          (0.46, 0.3), (0, 0.28)], 14))
    paraguas(m, rng, Vector((0.12, 0.3, 0.05)), Vector((0.55, 4.1, -0.25)), 0.55)
    paraguas(m, rng, Vector((-0.15, 0.3, 0.1)), Vector((-0.6, 3.9, 0.35)), 0.55)
    m.rama("Madera", (0.05, 0.3, -0.15), (-0.1, 3.4, -0.6), 0.06, 0.05, 6)
    m.add("Madera", sphere(0.1, 6, 4), T(-0.1, 3.45, -0.6))


def eslabon(m, papel, centro, direccion, giro, r=0.12, grueso=0.035):
    """Eslabón de cadena (anillo alargado) en `centro`, a lo largo de `direccion`, girado `giro` grados sobre ella."""
    perfil = [(r + grueso * math.cos(a), grueso * math.sin(a)) for a in (2 * math.pi * k / 6 for k in range(7))]
    orienta = Vector(direccion).normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
    # El anillo sale tumbado (en el plano XZ): se alarga en Z, que se lleva a lo largo de la cadena.
    m.add(papel, lathe(perfil, 8, caps=False), T(*centro) @ orienta @ R("Z", giro) @ S(1, 1, 1.7))


def cadena_puerta(m, rng):
    # Cadena de lado a lado de la puerta del sótano (4,8 de ancho), de dos argollas del marco a 5 del suelo, caída en
    # medio, con un candado grande colgando; y otra más corta, en diagonal. Óxido. El frente (la sala) a -Z.
    def cadena(a, b, caida):
        a, b = Vector(a), Vector(b)
        n = int((b - a).length / 0.21)
        puntos = [a.lerp(b, k / n) - Vector((0, caida * math.sin(math.pi * k / n), 0)) for k in range(n + 1)]
        for k, (p, q) in enumerate(zip(puntos, puntos[1:])):
            eslabon(m, "Metal", (p + q) / 2, q - p, 90 * (k % 2))
        return puntos
    for x in (-2.75, 2.75):  # argollas
        m.add("Metal", box(0.25, 0.4, 0.12), T(x, 5.0, 0.0))
    puntos = cadena((-2.75, 5.0, -0.12), (2.75, 5.0, -0.12), 0.7)
    medio = puntos[len(puntos) // 2]
    cadena((-2.75, 7.3, -0.1), (2.75, 3.4, -0.1), 0.25)
    for y in (7.3, 3.4):
        m.add("Metal", box(0.25, 0.4, 0.12), T(-2.75 if y > 5 else 2.75, y, 0.0))
    # Candado: arco y cuerpo.
    for k in range(7):
        a, b = math.pi * k / 7, math.pi * (k + 1) / 7
        m.rama("Metal", (medio.x + 0.22 * math.cos(a), medio.y - 0.35 + 0.3 * math.sin(a), medio.z - 0.05),
               (medio.x + 0.22 * math.cos(b), medio.y - 0.35 + 0.3 * math.sin(b), medio.z - 0.05), 0.04, 0.04, 6)
    m.add("Metal", box(0.62, 0.7, 0.26), T(medio.x, medio.y - 0.7, medio.z - 0.05))
    m.add("Interior", box(0.08, 0.2, 0.02), T(medio.x, medio.y - 0.8, medio.z - 0.19))


COCINA = {"Madera": "distressed_painted_planks", "Encimera": "kitchen_wood", "Interior": ("liso", (0.07, 0.055, 0.045)),
          "Metal": ("liso", (0.36, 0.34, 0.31)), "Esmalte": ("liso", (0.72, 0.7, 0.64)),
          "Cristal": ("liso", (0.3, 0.34, 0.22))}
TESELAS_COCINA = {"Madera": 3, "Encimera": 3, "Interior": 1, "Metal": 1, "Esmalte": 1, "Cristal": 1}


def solo(papeles):
    return {p: COCINA[p] for p in papeles}, {p: TESELAS_COCINA[p] for p in papeles}


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
    # Salón (11.8.2). Una tupla ("liso", rgb) = color liso; una función = imagen hecha aquí.
    "SofaTapado": (sofa_tapado, {"Sabana": "rough_linen"}, {"Sabana": 2}, {"Sabana": (0.86, 0.84, 0.79)}, ("Sabana",)),
    "Piano": (piano, {"Madera": "rosewood_veneer1", "Teclas": teclas_piano, "Negras": ("liso", (0.04, 0.04, 0.04)),
                      "Laton": ("liso", (0.5, 0.38, 0.18)), "Papel": None},
              {"Madera": 3, "Teclas": 0.15, "Negras": 1, "Laton": 1, "Papel": 1.4}, {"Madera": (0.5, 0.38, 0.34)}, ()),
    "Banqueta": (banqueta, {"Madera": "rosewood_veneer1", "Cuero": "brown_leather"}, {"Madera": 3, "Cuero": 2},
                 {"Madera": (0.5, 0.38, 0.34)}, ()),
    "Repisa": (repisa, {"Madera": "dark_wood"}, {"Madera": 2}, {}, ()),
    "LamparaPie": (lampara_pie, {"Laton": ("liso", (0.42, 0.33, 0.18)), "Pantalla": "rough_linen"},
                   {"Laton": 1, "Pantalla": 1.5}, {"Pantalla": (0.95, 0.8, 0.55)}, ("Laton", "Pantalla")),
    "AlfombraSalon": (alfombra_salon, {"Alfombra": alfombra_persa, "Borde": ("liso", (0.75, 0.7, 0.6))},
                      {"Alfombra": 10, "Borde": 1}, {}, ()),
    "CortinaVano": (cortina_vano, {"Tela": "velour_velvet", "Cordon": ("liso", (0.45, 0.34, 0.16))},
                    {"Tela": 2.5, "Cordon": 1}, {"Tela": (0.6, 0.3, 0.3)}, ("Tela", "Cordon")),
    # Cocina (11.8.4).
    "EncimeraCocina": (encimera_cocina, *solo(("Madera", "Encimera", "Interior", "Metal")), {}, ()),
    "EncimeraAbierta": (encimera_abierta, *solo(("Madera", "Encimera", "Interior", "Metal", "Cristal")), {}, ()),
    "FregaderoCocina": (fregadero_cocina, *solo(("Madera", "Encimera", "Interior", "Metal", "Esmalte")), {}, ()),
    "AlacenaCocina": (alacena_cocina, *solo(("Madera", "Interior", "Metal")), {}, ()),
    "AlacenaAbierta": (alacena_abierta, *solo(("Madera", "Interior", "Metal", "Cristal")), {}, ()),
    # Pedido por el usuario: la nevera oxidada del Creator Store no le gustaba.
    "NeveraVieja": (nevera_vieja, {"Esmalte": esmalte_nevera, "Cromo": ("liso", (0.55, 0.55, 0.53)),
                                   "Interior": ("liso", (0.05, 0.05, 0.05))},
                    {"Esmalte": 6.4, "Cromo": 1, "Interior": 1}, {}, ("Cromo",)),
    # Comedor (11.8.3).
    "PlantaSeca": (planta_seca, {"Tallo": ("liso", (0.3, 0.22, 0.14)), "Hoja": ("liso", (0.3, 0.21, 0.11)),
                                 "Tierra": ("liso", (0.12, 0.09, 0.07))},
                   {"Tallo": 1, "Hoja": 1, "Tierra": 1}, {}, ("Tallo", "Hoja")),
    # Pasillo, baño y trastero (11.8.5).
    "VaterViejo": (vater_viejo, {"Loza": loza, "Madera": "dark_wood", "Hierro": "rusty_painted_metal",
                                 "Metal": ("liso", (0.36, 0.34, 0.31))},
                   {"Loza": 4, "Madera": 2, "Hierro": 2, "Metal": 1}, {"Hierro": (0.5, 0.58, 0.5)}, ("Loza", "Metal")),
    "LavaboPie": (lavabo_pie, {"Loza": loza, "Metal": ("liso", (0.4, 0.38, 0.34)), "Interior": ("liso", (0.05, 0.05, 0.05))},
                  {"Loza": 4, "Metal": 1, "Interior": 1}, {}, ("Loza", "Metal")),
    "CortinaDucha": (cortina_ducha, {"Tela": "rough_linen", "Metal": ("liso", (0.4, 0.38, 0.34))},
                     {"Tela": 2.5, "Metal": 1}, {"Tela": (0.8, 0.82, 0.74)}, ("Tela",)),
    "Toallas": (toallas, {"Toalla": "rough_linen"}, {"Toalla": 1.5}, {"Toalla": (0.8, 0.74, 0.66)}, ("Toalla",)),
    "Paraguero": (paraguero, {"Laton": ("liso", (0.42, 0.33, 0.18)), "Paraguas": "poly_wool_herringbone",
                              "Madera": "dark_wood"},
                  {"Laton": 1, "Paraguas": 1.5, "Madera": 2}, {"Paraguas": (0.18, 0.17, 0.17)}, ("Laton", "Paraguas")),
    # Hierro gris con el envejecido: la textura de óxido no se distinguía de la madera oscura de la puerta.
    "CadenaPuerta": (cadena_puerta, {"Metal": ("liso", (0.5, 0.48, 0.45)), "Interior": ("liso", (0.03, 0.03, 0.03))},
                     {"Metal": 1, "Interior": 1}, {}, ("Metal",)),
}


def imagen(papel, t):
    """La imagen de color de un papel sin textura de Poly Haven (ver MUEBLES)."""
    if t is None:
        return papel_viejo()
    if callable(t):
        return t()
    return imagen_lisa(papel, t[1])


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
    materiales = {p: material_ph(p, t) if isinstance(t, str) else material_ph(p, None, imagen(p, t))
                  for p, t in texturas.items()}
    objetos = m.crear(args.nombre, materiales, teselas, suaves)

    salida = os.path.join(OUT_DIR, "polyhaven", args.nombre)
    os.makedirs(salida, exist_ok=True)
    base = os.path.join(salida, args.nombre)
    piezas = []
    for k, obj in enumerate(sorted(objetos, key=lambda o: o.name), 1):
        papel = obj.name
        obj.name = obj.data.name = "%s_%d" % (args.nombre, k) if len(objetos) > 1 else args.nombre
        tinte = np.array(tintes.get(papel, (1, 1, 1)), dtype=np.float32) * args.oscurecer
        piezas.append(polyhaven.pieza(obj, base + ("_%d" % k if len(objetos) > 1 else ""), tinte, papel not in LIMPIOS and args.nombre not in MUEBLES_LIMPIOS))
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
