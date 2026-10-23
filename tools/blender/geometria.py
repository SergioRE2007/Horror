# Lo común de los scripts de Blender del juego (crear_bosque.py, crear_casa.py): geometría en ejes del juego, la
# clase Piece (mallas por papel) y exportar a .fbx con vistas. Medidas en studs, Y arriba, -Z al frente.
# Cada script rellena ROLE_COLORS (color de cada papel en las vistas), TEXTURAS (papel -> .png con transparencia) y
# SUAVES (papeles con sombreado suave; los demás, con caras planas) y llama a exportar().
import argparse
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

OUT_DIR = os.path.join(os.path.expanduser("~"), "Documents", "Roblox", "modelos")
TESELA = 6.0  # studs por baldosa de las UV de caja (las texturas de los materiales de Roblox)
ROLE_COLORS = {"Marker": (1, 0, 1)}
TEXTURAS = {}
SUAVES = set()


# ---------- Geometría (ejes del juego; se pasan a Blender al final) ----------

def T(x=0, y=0, z=0):
    return Matrix.Translation((x, y, z))


def R(axis, degrees):
    return Matrix.Rotation(math.radians(degrees), 4, axis)


def S(sx, sy=None, sz=None):
    sy = sx if sy is None else sy
    sz = sx if sz is None else sz
    return Matrix.Diagonal((sx, sy, sz, 1))


def box(sx, sy, sz):
    x, y, z = sx / 2, sy / 2, sz / 2
    verts = [(a, b, c) for a in (-x, x) for b in (-y, y) for c in (-z, z)]
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return verts, faces


def lathe(profile, n=12, jitter=0.0, rng=None, caps=True):
    """Sólido de revolución sobre Y: profile = [(radio, y)] de abajo a arriba. Radio 0 = punta. Con `jitter`, cada
    vértice sale un poco más o menos lejos del eje (bordes irregulares)."""
    verts, rings = [], []
    for r, y in profile:
        start = len(verts)
        for i in range(n):
            a = 2 * math.pi * i / n
            k = 1 + (rng.uniform(-jitter, jitter) if jitter and r > 0 else 0)
            verts.append((r * k * math.cos(a), y, r * k * math.sin(a)))
        rings.append(start)
    faces = []
    for k in range(len(rings) - 1):
        a, b = rings[k], rings[k + 1]
        faces += [(a + i, b + i, b + (i + 1) % n, a + (i + 1) % n) for i in range(n)]
    if caps and profile[0][0] > 0:
        faces.append(tuple(rings[0] + i for i in range(n)))
    if caps and profile[-1][0] > 0:
        faces.append(tuple(rings[-1] + i for i in reversed(range(n))))
    return verts, faces


def sphere(r, n=10, rings=6):
    return lathe([(r * math.cos(math.pi * j / rings - math.pi / 2) if 0 < j < rings else 0,
                   r * math.sin(math.pi * j / rings - math.pi / 2)) for j in range(rings + 1)], n)


def cyl(r, h, n=10, r2=None):
    """Cilindro (o cono truncado) con la base en y=0."""
    return lathe([(r, 0), (r if r2 is None else r2, h)], n)


def blob(radii, seed, n=9, rings=5, jitter=0.2):
    """Bola a facetas con los vértices movidos al azar (con semilla): rocas, arbustos, musgo."""
    rng = random.Random(seed)
    verts, faces = sphere(1, n, rings)
    out = []
    for x, y, z in verts:
        k = 1 + rng.uniform(-jitter, jitter) if abs(y) < 0.999 else 1
        out.append((x * k * radii[0], y * k * radii[1], z * k * radii[2]))
    return out, faces


def limb(a, b, r0, r1, n=7):
    """Tronco o rama: cono truncado desde el punto a hasta el punto b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    m = T(*a) @ d.to_track_quat("Y", "Z").to_matrix().to_4x4()
    return m, cyl(r0, d.length, n, r1)


class Piece:
    def __init__(self):
        self.parts = {}
        self.uvs = {}  # [papel] = uv de cada esquina de cada cara, para los papeles con textura (sin UV de caja)

    def add(self, role, shape, matrix=None):
        verts, faces = shape
        matrix = matrix or Matrix.Identity(4)
        mine = self.parts.setdefault(role, ([], []))
        base = len(mine[0])
        mine[0].extend(tuple(matrix @ Vector(v)) for v in verts)
        mine[1].extend(tuple(base + i for i in f) for f in faces)

    def add_uv(self, role, shape, matrix=None):
        verts, faces, uvs = shape
        self.add(role, (verts, faces), matrix)
        self.uvs.setdefault(role, []).extend(uvs)

    def branch(self, role, a, b, r0, r1, n=7):
        m, shape = limb(a, b, r0, r1, n)
        self.add(role, shape, m)



# ---------- Pasar a Blender y exportar ----------

def to_blender(v):
    # Ejes del juego (X, Y arriba, Z atrás) -> Blender (Z arriba), de forma que el FBX (Y arriba, -Z al frente)
    # salga otra vez en ejes del juego.
    return (v[0], -v[2], v[1])


def material(role):
    """Solo para las vistas: el color del papel y, si tiene, su textura con transparencia (TEXTURAS)."""
    mat = bpy.data.materials.get(role)
    if mat:
        return mat
    mat = bpy.data.materials.new(role)
    mat.diffuse_color = ROLE_COLORS[role] + (1,)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs[0].default_value = ROLE_COLORS[role] + (1,)
    if role in TEXTURAS and os.path.exists(TEXTURAS[role]):
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(TEXTURAS[role])
        mat.node_tree.links.new(tex.outputs[0], bsdf.inputs[0])
        alpha = next(i for i in bsdf.inputs if i.identifier == "Alpha")
        mat.node_tree.links.new(tex.outputs[1], alpha)
        try:
            mat.surface_render_method = "DITHERED"
        except (AttributeError, TypeError):
            mat.blend_method = "CLIP"
    return mat


def make_object(name, role, verts, faces, offset, uvs=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([to_blender((x + offset[0], y + offset[1], z + offset[2])) for x, y, z in verts], [], faces)
    if uvs:
        # Las ramas planas: sus UV y sus dos caras tal cual (juntar vértices o recalcular normales las rompería).
        layer = mesh.uv_layers.new(name="UVMap")
        for poly, corners in zip(mesh.polygons, uvs):
            for loop_index, uv in zip(poly.loop_indices, corners):
                layer.data[loop_index].uv = uv
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(material(role))
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # UV de caja: cada cara toma los dos ejes en los que menos mira, en baldosas de TESELA studs.
    uv = bm.loops.layers.uv.new("UVMap")
    for face in bm.faces:
        n = face.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        a, b = [i for i in range(3) if i != axis]
        for loop in face.loops:
            co = loop.vert.co
            loop[uv].uv = (co[a] / TESELA, co[b] / TESELA)
    bm.to_mesh(mesh)
    bm.free()
    if role in SUAVES:
        for poly in mesh.polygons:
            poly.use_smooth = True  # redondeado, sin facetas (corteza, roca, tela)
    mesh.materials.append(material(role))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def marker(name, position):
    verts, faces = box(0.1, 0.1, 0.1)
    make_object(name, "Marker", verts, faces, position)


def render(path, center_x, width, height, look_y, angle=25.0, pitch=8.0):
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    if not any(o.type == "LIGHT" for o in scene.objects):
        sun = bpy.data.objects.new("sol", bpy.data.lights.new("sol", "SUN"))
        sun.data.energy = 3.0
        sun.rotation_euler = (math.radians(50), 0, math.radians(30))
        scene.collection.objects.link(sun)
    scene.render.resolution_x = 1600
    scene.render.resolution_y = int(1600 * height / width)
    scene.render.filepath = path
    if not scene.world:
        scene.world = bpy.data.worlds.new("w")
    scene.world.color = (0.5, 0.55, 0.6)
    scene.world.use_nodes = True
    fondo = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
    fondo.inputs[0].default_value = (0.5, 0.55, 0.6, 1)
    fondo.inputs[1].default_value = 0.8
    a, b = math.radians(angle), math.radians(pitch)
    look = Vector((center_x, 0, look_y))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = width
    cam.data.clip_end = 3000
    cam.location = look + Vector((math.sin(a) * math.cos(b), math.cos(a) * math.cos(b), math.sin(b))) * 800
    cam.rotation_euler = (look - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam
    bpy.ops.render.render(write_still=True)



def exportar(pieces, base, vistas, descripcion):
    """Crea las piezas (`pieces`: nombre -> función(p)), una al lado de otra de 40 en 40 (`separacion` en la función
    si hace falta), y exporta <base>.fbx (con --only, <base>_parche.fbx) y las vistas: [(centro x, ancho, alto,
    altura que se mira, giro, inclinación)]."""
    parser = argparse.ArgumentParser(description=descripcion)
    parser.add_argument("--output-dir", default=OUT_DIR)
    parser.add_argument("--only", nargs="+", choices=tuple(pieces))
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)

    marker("Axis_Origin", (-40, 0, 0))
    marker("Axis_Up", (-40, 2, 0))
    marker("Axis_Front", (-40, 0, -2))

    for index, (name, build) in enumerate(pieces.items()):
        if args.only and name not in args.only:
            continue
        p = Piece()
        build(p)
        offset = (index * 40.0, 0, 0)
        marker("%s_Origin" % name, offset)
        for role, (verts, faces) in p.parts.items():
            obj = make_object("%s_%s" % (name, role), role, verts, faces, offset, p.uvs.get(role))
            if len(obj.data.polygons) > 9000:
                print("AVISO: %s tiene %d triángulos" % (obj.name, len(obj.data.polygons)))

    out = args.output_dir
    os.makedirs(out, exist_ok=True)
    name = base + "_parche" if args.only else base
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, name + ".blend"))
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(out, name + ".fbx"),
        object_types={"MESH"},
        axis_forward="-Z",
        axis_up="Y",
        apply_scale_options="FBX_SCALE_UNITS",
        mesh_smooth_type="FACE",
    )
    print("Exportadas", len(args.only or pieces), "piezas")
    for k, vista in enumerate(vistas):
        render(os.path.join(out, "%s%d.png" % (name, k + 1)), *vista)
