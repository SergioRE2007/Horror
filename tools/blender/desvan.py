# Muebles hechos a mano de la escalera del desván y del desván (11.8.11, opción B del usuario, "al fondo, la luz
# roja"). Usa todo lo de a_mano.py (misma tubería, envejecido y salida) sin tocarlo: añade sus muebles a a_mano.MUEBLES
# y llama a su main(). Así los chats de otras salas no chocan con este en a_mano.py.
# Uso: blender -b --factory-startup --python tools/blender/desvan.py -- --nombre Maniqui
# Muebles: Maniqui, ButacaTapada, ComodaTapada, EspejoTapado, MesaRevelado, CosasRevelado (cubetas, ampliadora,
# botellas, la nota y la pistola de bengalas), FotosTendidas, CortinaNegra, FotosVigilantes, BarandillaTrampilla y
# MaletaAbierta.
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import a_mano  # noqa: E402
import polyhaven  # noqa: E402
from a_mano import BAJADOS, escritura, tela  # noqa: E402
from geometria import R, S, T, box, cyl, lathe, sphere  # noqa: E402


# ---------- Muebles tapados con sábanas ----------
def tapado(m, cajas, alto_pliegue=2.0, tris=3000):
    """Sábana que cae sobre un mueble hecho de cajas [(centro, tamaño)], como el sofá tapado del salón (a_mano): un
    remallado en vóxeles funde y redondea las cajas y luego la tela cae en pliegues y se abre un poco en el suelo."""
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
            pliegue = 0.2 * max(0.0, 1 - y / alto_pliegue) ** 1.5 + 0.03
            onda = math.sin(a_lo_largo * 2.6 + 0.8 * math.sin(a_lo_largo * 0.9 + y))
            abierto = 0.2 * max(0.0, 1 - y / 0.45) ** 2
            v.co += n * (pliegue * onda + abierto)
        v.co.y = max(v.co.y, 0.01)
    bm = bmesh.new()
    bm.from_mesh(malla)
    bmesh.ops.delete(bm, geom=[c for c in bm.faces if all(v.co.y < 0.05 for v in c.verts)], context="FACES")
    bm.to_mesh(malla)
    bm.free()
    menos = obj.modifiers.new("menos", "DECIMATE")
    menos.ratio = min(1.0, tris / max(1, sum(len(p.vertices) - 2 for p in malla.polygons)))
    bpy.ops.object.modifier_apply(modifier="menos")
    m.add("Sabana", ([tuple(v.co) for v in malla.vertices], [tuple(p.vertices) for p in malla.polygons]))
    bpy.data.objects.remove(obj, do_unlink=True)


def butaca_tapada(m, rng):
    # Butaca de orejas tapada (3,4 de ancho): asiento, respaldo alto con orejas y brazos.
    tapado(m, [((0, 0.85, 0), (2.8, 1.7, 3.0)), ((0, 2.6, 1.15), (2.9, 2.6, 0.8)), ((-1.3, 1.5, 0.1), (0.6, 1.4, 2.8)),
               ((1.3, 1.5, 0.1), (0.6, 1.4, 2.8)), ((-1.25, 3.4, 0.7), (0.5, 1.2, 1.2)), ((1.25, 3.4, 0.7), (0.5, 1.2, 1.2))])


def comoda_tapada(m, rng):
    # Cómoda alta con el espejo encima, tapada (4,6 de ancho y 6,5 de alto): la sábana se engancha en el espejo.
    tapado(m, [((0, 1.6, 0), (4.2, 3.2, 1.9)), ((0, 4.6, 0.55), (3.0, 3.0, 0.3)), ((0, 6.1, 0.55), (1.6, 0.5, 0.3))],
           alto_pliegue=3.2)


def espejo_tapado(m, rng):
    # Espejo de pie ovalado tapado, algo inclinado hacia atrás (2,6 de ancho y 6,3 de alto).
    tapado(m, [((0, 3.4, 0.25), (2.1, 5.2, 0.35)), ((0, 0.8, 0.5), (1.4, 1.6, 1.2)), ((0, 6.0, 0.15), (1.0, 0.6, 0.3))],
           alto_pliegue=4.0, tris=2000)


# ---------- Maniquí de costura ----------
def maniqui(m, rng):
    # Maniquí de costura (busto de tela sobre un palo con tres patas), 6,2 de alto: en la penumbra parece alguien.
    perfil = [(0.0, 0.0), (0.62, 0.02), (0.72, 0.25), (0.66, 0.55), (0.5, 0.9), (0.47, 1.05), (0.58, 1.45),
              (0.66, 1.75), (0.68, 1.95), (0.55, 2.2), (0.3, 2.32), (0.17, 2.4), (0.15, 2.65), (0.0, 2.72)]
    m.add("Lienzo", lathe(perfil, 20), T(0, 3.4, 0) @ S(1.25, 1, 0.8))
    m.add("Madera", lathe([(0.14, 0), (0.17, 0.08), (0.12, 0.2), (0.0, 0.26)], 12), T(0, 6.1, 0))  # remate del cuello
    m.add("Madera", cyl(0.08, 3.5, 10), T(0, 0.2, 0))
    m.add("Madera", lathe([(0.25, 0), (0.25, 0.08), (0.12, 0.3), (0.08, 0.6)], 12), T(0, 0.15, 0))
    for k in range(3):
        a = math.radians(90 + 120 * k)
        m.rama("Madera", (0, 0.35, 0), (math.cos(a) * 1.0, 0.05, math.sin(a) * 1.0), 0.08, 0.06, 6)
    m.add("Metal", cyl(0.2, 0.12, 12), T(0, 3.35, 0))  # la rueda de ajustar la altura


# ---------- Cuarto de revelado ----------
def mesa_revelado(m, rng):
    # Mesa de trabajo de tablas (7 × 3,2 × 3): tablero grueso, patas cuadradas, travesaños y balda de abajo.
    m.add("Madera", box(7.0, 0.25, 3.0), T(0, 3.07, 0))
    for x in (-3.2, 3.2):
        for z in (-1.2, 1.2):
            m.add("Madera", box(0.35, 2.95, 0.35), T(x, 1.47, z))
        m.add("Madera", box(0.25, 0.3, 2.4), T(x, 2.75, 0))
    for z in (-1.2, 1.2):
        m.add("Madera", box(6.0, 0.3, 0.2), T(0, 2.75, z))
    m.add("Madera", box(6.6, 0.15, 2.6), T(0, 0.55, 0))


FOTO = 0.0  # se rellena con el atlas de las fotos de flash (casillas de 256 en una imagen de 1024 × 512)


def atlas_flash(w=1024, h=512):
    """Fotos de flash del rico (pista 10): casi negras, con lo que pilló el flash quemado en blanco: troncos y unos ojos,
    un brazo largo con garras, algo que se arrastra, el pasillo de la casa con ojos al fondo, una boca de dientes finos,
    la mano contra el cristal, un solo ojo y una foto velada. Sin sangre (Moderate)."""
    azar = np.random.default_rng(31)
    rgb = np.zeros((h, w, 3), dtype=np.float32)
    U, V = np.meshgrid(np.arange(256, dtype=np.float32) / 256, np.arange(256, dtype=np.float32) / 256)
    for k in range(8):
        x0, y0 = (k % 4) * 256, (k // 4) * 256
        f = np.zeros((256, 256), dtype=np.float32)
        luz = np.clip(1.2 - np.hypot(U - 0.5, V - 0.5) * 2.2, 0, 1)  # el flash: centro quemado, bordes negros
        if k == 0:  # troncos y dos ojos entre ellos
            for c in (0.15, 0.42, 0.8):
                f = np.maximum(f, (np.abs(U - c - 0.02 * np.sin(V * 9)) < 0.05) * 0.8)
            for ex in (0.58, 0.64):
                f = np.maximum(f, (np.hypot(U - ex, V - 0.58) < 0.012) * 1.6)
        elif k == 1:  # brazo largo y flaco con garras que entra desde un lado
            brazo = np.abs(V - 0.55 - 0.15 * (U - 0.3)) < 0.03 + 0.02 * (U < 0.4)
            f = np.maximum(f, (brazo & (U < 0.7)) * 1.0)
            for d in (-0.06, 0.0, 0.06):
                f = np.maximum(f, (np.abs(V - 0.6 - d - 0.4 * (U - 0.7)) < 0.008) * ((U > 0.68) & (U < 0.86)) * 1.0)
        elif k == 2:  # algo pálido que se arrastra por el suelo, movido
            for s in range(6):
                f = np.maximum(f, (np.hypot((U - 0.3 - s * 0.05) * 0.6, V - 0.35) < 0.1) * (0.9 - s * 0.12))
            f = np.maximum(f, (V < 0.22) * 0.35)
        elif k == 3:  # el pasillo de la casa con dos ojos al fondo
            pared = np.abs(U - 0.5) > 0.12 + 0.35 * np.abs(V - 0.5)
            f = np.maximum(f, pared * 0.55 * (1 - np.abs(V - 0.5)))
            for ex in (0.48, 0.52):
                f = np.maximum(f, (np.hypot(U - ex, V - 0.52) < 0.007) * 1.8)
        elif k == 4:  # boca abierta de dientes finos, de muy cerca
            boca = np.hypot((U - 0.5) * 0.7, V - 0.5) < 0.22
            f = np.maximum(f, boca * 0.15)
            dientes = boca & (((U * 30) % 1) < 0.35) & ((np.abs(V - 0.5) > 0.12) & (np.abs(V - 0.5) < 0.2))
            f = np.maximum(f, dientes * 1.3)
            f = np.maximum(f, (~boca & (np.hypot((U - 0.5) * 0.7, V - 0.5) < 0.3)) * 0.6)
        elif k == 5:  # una mano de dedos largos contra el cristal
            palma = np.hypot(U - 0.5, V - 0.38) < 0.11
            dedos = np.zeros_like(palma)
            for d in range(4):
                cx = 0.4 + d * 0.065
                dedos |= (np.abs(U - cx - (V - 0.45) * (d - 1.5) * 0.08) < 0.018) & (V > 0.45) & (V < 0.78 - abs(d - 1.5) * 0.04)
            f = np.maximum(f, (palma | dedos) * 1.1)
        elif k == 6:  # un solo ojo enorme en la oscuridad
            f = np.maximum(f, (np.hypot((U - 0.55) * 0.6, V - 0.5) < 0.06) * 1.5)
            f = f - (np.hypot(U - 0.55, V - 0.5) < 0.02) * 1.5
        else:  # velada: casi blanca, con una sombra
            f = 0.9 - (np.hypot((U - 0.5) * 1.6, V - 0.4) < 0.18) * 0.7
            luz = np.ones_like(luz)
        f = np.clip(f * (0.4 + 0.8 * luz), 0, 1) + azar.random((256, 256)).astype(np.float32) * 0.06
        gris = np.clip(f, 0, 1)[:, :, None] * np.array([0.92, 0.9, 0.84], dtype=np.float32)
        borde = (U < 0.05) | (U > 0.95) | (V < 0.05) | (V > 0.95)
        gris[borde] = np.array([0.85, 0.83, 0.78])
        rgb[y0:y0 + 256, x0:x0 + 256] = gris
    ruta = os.path.join(BAJADOS, "atlas_flash.png")
    polyhaven.guardar("atlas_flash", rgb, w, h, ruta)
    return bpy.data.images.load(ruta)


def foto_colgada(m, papel, centro, giro, casilla, ancho=0.8, alto=1.0):
    """Una foto de una casilla del atlas de flash, colgada de frente (mira a -Z), con su UV propia."""
    x, y, z = centro
    c, s = math.cos(giro), math.sin(giro)
    pts = [(-ancho / 2, -alto), (ancho / 2, -alto), (ancho / 2, 0), (-ancho / 2, 0)]
    verts = [(x + px * c - py * s, y + px * s + py * c, z) for px, py in pts]
    # Con grueso (caja cerrada): una lámina de una cara salía del revés en Roblox y no se veía.
    verts += [(vx, vy, z + 0.03) for vx, vy, _ in verts]
    m.add(papel, (verts, [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]))
    m.fotos.append((verts[:4], casilla))


def uv_fotos(m, w_casillas=4, h_casillas=2):
    """UV del atlas: cada vértice va a la esquina de su casilla (por cercanía a las cuatro esquinas de cada foto)."""
    def uv(x, y, z):
        for esquinas, casilla in m.fotos:
            for k, (ex, ey, ez) in enumerate(esquinas):
                if abs(ex - x) < 1e-3 and abs(ey - y) < 1e-3 and abs(ez - z) < 0.05:
                    col, fila = casilla % w_casillas, casilla // w_casillas
                    du, dv = ((1, 0), (0, 0), (0, 1), (1, 1))[k]  # de frente la derecha es -x
                    return ((col + du) / w_casillas, (fila + dv) / h_casillas)
        return (0, 0)
    return uv


def fotos_tendidas(m, rng):
    # Cuerda de tender de 9 con siete fotos de flash cogidas con pinzas, combada en medio (de punta a punta, en x).
    m.fotos = []
    puntos = [(-4.5 + 9 * k / 16, -0.35 * math.sin(math.pi * k / 16), 0) for k in range(17)]
    for a, b in zip(puntos, puntos[1:]):
        m.rama("Cuerda", a, b, 0.025, 0.025, 5)
    for k in range(7):
        x = -3.6 + k * 1.2
        y = -0.35 * math.sin(math.pi * (x + 4.5) / 9)
        m.add("Pinza", box(0.1, 0.32, 0.12), T(x, y - 0.05, 0))
        foto_colgada(m, "Foto", (x, y - 0.1, 0.0), rng.uniform(-0.12, 0.12), k)
    m.uv["Foto"] = uv_fotos(m)


def cortina_negra(m, rng):
    # Cortina negra de la puerta del cuarto de revelado (4,4 de ancho y 7,6 de alto): barra arriba y dos paños con
    # pliegues; el de la derecha recogido a un lado, que deja una rendija por la que sale la luz roja.
    m.add("Metal", cyl(0.06, 4.6, 8), T(2.3, 7.5, 0) @ R("Z", 90))
    for lado, ancho, abierto in ((-1, 2.3, 0.0), (1, 1.6, 0.5)):
        def f(u, v, lado=lado, ancho=ancho, abierto=abierto):
            x0 = -2.2 if lado < 0 else 2.2 - ancho
            x = x0 + u * ancho
            if abierto:  # se recoge hacia el borde de fuera abajo
                x = 2.2 - (2.2 - x) * (1 - abierto * (1 - v) ** 1.5)
            return (x, 0.15 + v * 7.3, 0.12 * math.sin(u * ancho * 6.5) + 0.03 * math.sin(v * 9))
        tela(m, "Tela", f, 28, 10, 0.05)


# ---------- Cosas de la mesa de revelado ----------
def cosas_revelado(m, rng):
    # Lo de encima de la mesa (mismos ejes que MesaRevelado: el tablero a 3,2): tres cubetas con líquido, pinzas,
    # botellas de químicos marrones, la ampliadora en la punta derecha, la lámpara roja de seguridad colgada en la pared,
    # la nota del rico (pista 10) y la pistola de bengalas con tres cartuchos (12.2).
    y = 3.2
    for k, (x, liquido) in enumerate(((-2.6, "Revelador"), (-1.2, "Paro"), (0.2, "Fijador"))):
        m.add("Cubeta", box(1.25, 0.05, 1.0), T(x, y + 0.025, -0.2))
        for dx, dz, sx, sz in ((0, -0.5, 1.25, 0.05), (0, 0.5, 1.25, 0.05), (-0.6, 0, 0.05, 1.0), (0.6, 0, 0.05, 1.0)):
            m.add("Cubeta", box(sx, 0.22, sz), T(x + dx, y + 0.11, -0.2 + dz))
        m.add(liquido, box(1.15, 0.03, 0.9), T(x, y + 0.14, -0.2))
    m.rama("Metal", (-1.9, y + 0.05, -0.75), (-1.55, y + 0.28, -0.35), 0.025, 0.02, 5)
    m.rama("Metal", (-1.85, y + 0.05, -0.8), (-1.5, y + 0.3, -0.42), 0.025, 0.02, 5)
    for x, z, alto in ((-2.9, 0.95, 1.0), (-2.5, 1.05, 0.85), (-2.15, 0.9, 1.1), (-1.6, 1.1, 0.7)):
        m.add("Botella", lathe([(0.17, 0), (0.17, alto * 0.7), (0.06, alto * 0.85), (0.06, alto)], 10), T(x, y, z))
        m.add("Tapon", cyl(0.07, 0.1, 8), T(x, y + alto, z))
        m.add("Etiqueta", box(0.2, alto * 0.3, 0.02), T(x, y + alto * 0.35, z - 0.17))
    # Ampliadora: base, columna, cabezal con el fuelle y la lente mirando abajo.
    m.add("Madera", box(1.5, 0.12, 1.4), T(2.4, y + 0.06, 0))
    m.add("Metal", cyl(0.07, 3.2, 10), T(2.4, y + 0.1, 0.55))
    m.add("Metal", box(0.7, 0.75, 0.75), T(2.4, y + 2.6, 0.1))
    m.add("Fuelle", lathe([(0.3, 0), (0.33, 0.1), (0.3, 0.2), (0.33, 0.3), (0.3, 0.4)], 4), T(2.4, y + 1.85, 0.1) @ R("Y", 45))
    m.add("Metal", cyl(0.14, 0.3, 12), T(2.4, y + 1.55, 0.1))
    m.add("Metal", box(0.3, 0.12, 0.5), T(2.4, y + 2.6, 0.5))
    # La nota (pista 10), con letra a mano, y las fotos sueltas de al lado.
    m.add("Escrito", box(0.75, 0.01, 1.0), T(1.15, y + 0.005, -0.75) @ R("Y", -12))
    # Pistola de bengalas (naranja, de cañón ancho) sobre su caja abierta, y tres cartuchos rojos de culo de latón.
    m.add("Caja", box(1.5, 0.3, 0.9), T(1.2, y + 0.15, 0.75))
    m.add("Forro", box(1.38, 0.02, 0.78), T(1.2, y + 0.29, 0.75))
    m.add("Caja", box(1.5, 0.9, 0.06), T(1.2, y + 0.75, 1.22) @ R("X", -15))
    cx, cy, cz = 0.9, y + 0.38, 0.72
    m.add("Naranja", cyl(0.12, 0.85, 12), T(cx + 0.2, cy, cz) @ R("Z", -90))  # cañón
    m.add("Naranja", box(0.45, 0.24, 0.2), T(cx + 0.05, cy, cz))
    m.add("Naranja", box(0.18, 0.5, 0.17), T(cx - 0.15, cy - 0.06, cz) @ R("Z", 70))  # culata, tumbada
    m.add("Negro", box(0.04, 0.15, 0.04), T(cx + 0.05, cy - 0.08, cz))
    for k in range(3):
        x = 0.7 + k * 0.17
        m.add("Rojo", cyl(0.07, 0.45, 10), T(x, y + 0.37, 0.45) @ R("X", 90))
        m.add("Laton", cyl(0.08, 0.05, 10), T(x, y + 0.37, 0.43) @ R("X", 90))
    # Lámpara roja de seguridad: caja de chapa con el cristal rojo hacia abajo, en un brazo que sale de la pared de atrás.
    m.add("Metal", box(0.12, 0.12, 0.9), T(-0.9, y + 3.2, 1.05))
    m.add("Metal", box(0.7, 0.45, 0.5), T(-0.9, y + 3.05, 0.55))
    m.add("RojoLuz", box(0.6, 0.04, 0.4), T(-0.9, y + 2.81, 0.55))


# ---------- Escalera del desván ----------
FOTOS_PARED = [  # (x, y, giro, casilla, tachada) de las fotos de los vigilantes clavadas en la pared, de frente (-Z)
    (-2.9, 6.6, 0.06, 0), (-1.7, 6.9, -0.05, 1), (-0.4, 6.5, 0.1, 2), (0.9, 6.8, -0.08, 3), (2.2, 6.6, 0.04, 4),
    (-2.4, 5.1, -0.1, 5), (-1.1, 5.3, 0.07, 6), (0.3, 5.0, -0.03, 7), (1.6, 5.3, 0.12, 8), (2.9, 5.0, -0.06, 9),
    (-1.8, 3.7, 0.05, 10), (-0.4, 3.6, -0.09, 11), (1.0, 3.8, 0.03, 12), (2.3, 3.5, -0.12, 13),
    (3.6, 6.2, 0.08, 14), (-3.6, 5.6, -0.07, 15),
]


def atlas_vigilantes(w=1024, h=1024):
    """Dieciséis fotos de carné en sepia de los vigilantes que mandó el rico, cada uno distinto (pelo, gorra, bigote);
    casi todas tachadas con una cruz de lápiz rojo y con una fecha a mano debajo. La última, sin tachar y sin cara: un
    hueco para el siguiente (el jugador)."""
    azar = np.random.default_rng(57)
    rgb = np.zeros((h, w, 3), dtype=np.float32)
    U, V = np.meshgrid(np.arange(256, dtype=np.float32) / 256, np.arange(256, dtype=np.float32) / 256)
    rojo = np.array([0.55, 0.06, 0.05], dtype=np.float32)
    for k in range(16):
        x0, y0 = (k % 4) * 256, (k // 4) * 256
        sepia = np.array([0.66, 0.54, 0.4], dtype=np.float32) * (0.7 + 0.35 * V[:, :, None])
        foto = np.ones((256, 256, 3), dtype=np.float32) * sepia
        px, ancho = 0.5 + azar.uniform(-0.06, 0.06), azar.uniform(0.11, 0.15)
        cabeza = np.hypot((U - px) / ancho * 0.13, (V - 0.6) / 1.25) < 0.1
        hombros = (np.abs(U - px) < 0.2 + (0.42 - V) * 0.6) & (V < 0.42) & (V > 0.18)
        if k < 15:
            foto[hombros] = np.array([0.2, 0.16, 0.12]) * azar.uniform(0.7, 1.3)
            foto[cabeza] = np.array([0.56, 0.45, 0.34]) * azar.uniform(0.85, 1.1)
            pelo = cabeza & (V > 0.66 + azar.uniform(-0.02, 0.03))
            foto[pelo] = np.array([0.16, 0.12, 0.09]) * azar.uniform(0.6, 1.8)
            if k % 3 == 0:  # gorra
                foto[(np.abs(U - px) < ancho * 1.1) & (np.abs(V - 0.72) < 0.03)] = np.array([0.12, 0.1, 0.08])
            if k % 4 == 1:  # bigote
                foto[(np.abs(U - px) < 0.035) & (np.abs(V - 0.55) < 0.008)] = np.array([0.15, 0.11, 0.08])
            for ex in (-0.035, 0.035):  # ojos
                foto[np.hypot(U - px - ex, V - 0.62) < 0.009] = np.array([0.12, 0.09, 0.07])
        else:  # el hueco del siguiente: solo la silueta, sin cara
            foto[hombros | cabeza] = np.array([0.32, 0.27, 0.21])
        foto *= (1 - azar.random((256, 256, 1)).astype(np.float32) * 0.12)
        borde = (U < 0.07) | (U > 0.93) | (V < 0.2) | (V > 0.94)
        foto[borde] = np.array([0.84, 0.8, 0.7])
        renglon = (V > 0.07) & (V < 0.11) & (U > 0.2) & (U < 0.8) & (np.sin(U * 70 + k) > -0.3)  # la fecha a mano
        foto[renglon] = np.array([0.2, 0.17, 0.2])
        if k < 14:
            for signo in (1, -1):
                foto[(np.abs((V - 0.57) - signo * (U - 0.5)) < 0.02) & (V > 0.2)] = rojo
        rgb[y0:y0 + 256, x0:x0 + 256] = foto
    ruta = os.path.join(BAJADOS, "atlas_vigilantes.png")
    polyhaven.guardar("atlas_vigilantes", rgb, w, h, ruta)
    return bpy.data.images.load(ruta)


def fotos_vigilantes(m, rng):
    # Dieciséis fotos de los vigilantes clavadas en la pared con chinchetas, torcidas, de 0,9 × 1,1 (de punta a punta
    # 8 de ancho, de 2,4 a 7,5 de alto). Pegadas a la pared: la espalda en z = 0, la cara hacia -Z.
    m.fotos = []
    for x, y, giro, casilla in [f[:4] for f in FOTOS_PARED]:
        foto_colgada(m, "Foto", (x, y + 0.55, -0.02), giro, casilla, 0.9, 1.1)
        m.add("Chincheta", sphere(0.05, 6, 3), T(x - math.sin(giro) * 0.0, y + 0.45, -0.05))
    m.uv["Foto"] = uv_fotos(m, 4, 4)


def barandilla_trampilla(m, rng):
    # Barandilla de madera alrededor del hueco de la trampilla (4,4 × 8,4 por fuera, abierta por -Z, por donde se sube):
    # postes cuadrados, pasamanos a 3,2 y un travesaño a media altura.
    x, z0, z1 = 2.2, -4.2, 4.2
    postes = [(-x, z0), (-x, 0), (-x, z1), (x, z0), (x, 0), (x, z1), (0, z1)]
    for px, pz in postes:
        m.add("Madera", box(0.3, 3.4, 0.3), T(px, 1.7, pz))
    for alto, grueso in ((3.2, 0.22), (1.6, 0.14)):
        for px in (-x, x):
            m.add("Madera", box(grueso, grueso, z1 - z0), T(px, alto, 0))
        m.add("Madera", box(2 * x, grueso, grueso), T(0, alto, z1))


def maleta_abierta(m, rng):
    # Maleta de cuero abierta en el suelo (3,2 × 2,2), la tapa caída hacia atrás, con ropa de hombre revuelta: camisa,
    # chaqueta y una corbata que cuelga por fuera.
    m.add("Cuero", box(3.0, 0.08, 2.0), T(0, 0.04, 0))
    for dx, dz, sx, sz in ((0, -0.98, 3.0, 0.08), (0, 0.98, 3.0, 0.08), (-1.48, 0, 0.08, 2.0), (1.48, 0, 0.08, 2.0)):
        m.add("Cuero", box(sx, 0.75, sz), T(dx, 0.375, dz))
    m.add("Forro", box(2.85, 0.02, 1.85), T(0, 0.09, 0))
    m.add("Cuero", box(3.0, 0.1, 2.0), T(0, 0.75, 1.0) @ R("X", -70) @ T(0, 0, 1.0))
    m.add("Forro", box(2.85, 0.02, 1.85), T(0, 0.75, 1.0) @ R("X", -70) @ T(0, 0.06, 1.0))
    for x in (-0.9, 0.9):
        m.add("Metal", box(0.25, 0.15, 0.08), T(x, 0.6, -1.03))
    def camisa(u, v):
        return (-1.3 + u * 2.0, 0.55 + 0.18 * math.sin(u * 7 + v * 3) + 0.1 * math.sin(v * 11), -0.8 + v * 1.4)
    tela(m, "Camisa", camisa, 14, 10, 0.05)
    def chaqueta(u, v):
        return (-0.2 + u * 1.5, 0.7 + 0.15 * math.sin(u * 6 - v * 4), -0.6 + v * 1.5)
    tela(m, "Chaqueta", chaqueta, 12, 10, 0.06)
    def corbata(u, v):
        x = 1.2 + u * 0.12
        if v < 0.5:
            return (x, 0.8 + 0.05 * math.sin(v * 8), -0.2 - v * 1.4)
        return (x, 0.8 - (v - 0.5) * 1.55, -0.9 - (v - 0.5) * 0.6)
    tela(m, "Corbata", corbata, 2, 12, 0.03)


# ---------- Registro ----------
LISO = "liso"
a_mano.LIMPIOS |= {"Escrito"}
a_mano.MUEBLES.update({
    "Maniqui": (maniqui, {"Lienzo": "rough_linen", "Madera": "dark_wood", "Metal": (LISO, (0.4, 0.36, 0.3))},
                {"Lienzo": 1.5, "Madera": 2, "Metal": 1}, {"Lienzo": (0.72, 0.62, 0.5)}, ("Lienzo", "Madera", "Metal")),
    # La sábana, como la del sofá tapado del salón: la misma imagen (Roblox da el mismo id).
    "ButacaTapada": (butaca_tapada, {"Sabana": "rough_linen"}, {"Sabana": 2}, {"Sabana": (0.86, 0.84, 0.79)}, ("Sabana",)),
    "ComodaTapada": (comoda_tapada, {"Sabana": "rough_linen"}, {"Sabana": 2}, {"Sabana": (0.86, 0.84, 0.79)}, ("Sabana",)),
    "EspejoTapado": (espejo_tapado, {"Sabana": "rough_linen"}, {"Sabana": 2}, {"Sabana": (0.86, 0.84, 0.79)}, ("Sabana",)),
    "MesaRevelado": (mesa_revelado, {"Madera": "dark_wood"}, {"Madera": 2}, {}, ()),
    "CosasRevelado": (cosas_revelado, {
        "Cubeta": (LISO, (0.75, 0.72, 0.66)), "Revelador": (LISO, (0.33, 0.26, 0.14)), "Paro": (LISO, (0.4, 0.38, 0.22)),
        "Fijador": (LISO, (0.28, 0.3, 0.28)), "Metal": (LISO, (0.2, 0.2, 0.21)), "Botella": (LISO, (0.22, 0.12, 0.05)),
        "Tapon": (LISO, (0.08, 0.08, 0.08)), "Etiqueta": (LISO, (0.75, 0.7, 0.58)), "Madera": "dark_wood",
        "Fuelle": (LISO, (0.06, 0.06, 0.06)), "Escrito": escritura, "Caja": (LISO, (0.2, 0.16, 0.12)),
        "Forro": (LISO, (0.35, 0.06, 0.07)), "Naranja": (LISO, (0.85, 0.35, 0.08)), "Negro": (LISO, (0.05, 0.05, 0.05)),
        "Rojo": (LISO, (0.6, 0.08, 0.06)), "Laton": (LISO, (0.5, 0.38, 0.18)), "RojoLuz": (LISO, (0.9, 0.08, 0.05))},
        {"Madera": 2, "Escrito": 1.2, **{p: 1 for p in ("Cubeta", "Revelador", "Paro", "Fijador", "Metal", "Botella", "Tapon",
                                                         "Etiqueta", "Fuelle", "Caja", "Forro", "Naranja", "Negro", "Rojo",
                                                         "Laton", "RojoLuz")}},
        {}, ("Botella", "Tapon", "Metal", "Naranja", "Rojo", "Laton")),
    "FotosTendidas": (fotos_tendidas, {"Cuerda": (LISO, (0.55, 0.5, 0.42)), "Pinza": (LISO, (0.45, 0.35, 0.22)),
                                       "Foto": atlas_flash}, {"Cuerda": 1, "Pinza": 1, "Foto": 1}, {}, ("Cuerda",)),
    "CortinaNegra": (cortina_negra, {"Tela": "velour_velvet", "Metal": (LISO, (0.2, 0.2, 0.21))}, {"Tela": 2.5, "Metal": 1},
                     {"Tela": (0.16, 0.14, 0.14)}, ("Tela", "Metal")),
    "FotosVigilantes": (fotos_vigilantes, {"Foto": atlas_vigilantes, "Chincheta": (LISO, (0.6, 0.06, 0.05))},
                        {"Foto": 1, "Chincheta": 1}, {}, ("Chincheta",)),
    "BarandillaTrampilla": (barandilla_trampilla, {"Madera": "dark_wood"}, {"Madera": 2}, {}, ()),
    "MaletaAbierta": (maleta_abierta, {"Cuero": "brown_leather", "Forro": (LISO, (0.35, 0.08, 0.08)),
                                       "Metal": (LISO, (0.5, 0.42, 0.25)), "Camisa": "rough_linen",
                                       "Chaqueta": "poly_wool_herringbone", "Corbata": (LISO, (0.25, 0.08, 0.1))},
                      {"Cuero": 2, "Forro": 1, "Metal": 1, "Camisa": 1.5, "Chaqueta": 1.5, "Corbata": 1},
                      {"Camisa": (0.8, 0.78, 0.7), "Chaqueta": (0.3, 0.28, 0.26)}, ("Camisa", "Chaqueta", "Corbata")),
})
a_mano.LIMPIOS |= {"Foto", "Lienzo", "Forro"}  # con las manchas grandes del envejecido parecían camuflaje

if __name__ == "__main__":
    a_mano.main()
