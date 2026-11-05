# Prepara para Roblox un bicho hecho con IA de imagen a 3D (Tripo, .glb con esqueleto Mixamo):
# quita lo que sobra, une los triángulos sueltos, baja la malla a <20.000 triángulos (lo máximo de Roblox),
# lo escala a su altura en studs, baja los brazos de la postura en T, pasa las texturas a 1024 px
# (color, normal, rugosidad y metal por separado, como las pide SurfaceAppearance) y exporta un .fbx.
# Uso: blender -b --factory-startup --python tools/blender/preparar_bicho.py -- <bicho.glb> <Nombre> <altura> <carpeta>
#        [--brazos <grados que bajan los brazos>]
# Deja <Nombre>.fbx, <Nombre>_color.png, _normal.png, _rugosidad.png, _metal.png y vistas <Nombre>1-3.png.
import argparse
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

TRIANGULOS = 19500
TEXTURA = 1024

ap = argparse.ArgumentParser()
ap.add_argument("glb")
ap.add_argument("nombre")
ap.add_argument("altura", type=float)
ap.add_argument("carpeta")
ap.add_argument("--brazos", type=float, default=70.0)
args = ap.parse_args(sys.argv[sys.argv.index("--") + 1 :])
os.makedirs(args.carpeta, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=args.glb)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
mallas = [o for o in bpy.data.objects if o.type == "MESH" and o.vertex_groups]
for o in list(bpy.data.objects):
    # Tripo deja una bola suelta (Icosphere) y vacíos encima del esqueleto
    if o.type == "MESH" and not o.vertex_groups:
        bpy.data.objects.remove(o)
cuerpo = mallas[0]
if len(mallas) > 1:
    bpy.ops.object.select_all(action="DESELECT")
    for o in mallas:
        o.select_set(True)
    bpy.context.view_layer.objects.active = cuerpo
    bpy.ops.object.join()

# Sacar el esqueleto de los vacíos que trae, conservando dónde está
for o in (arm, cuerpo):
    m = o.matrix_world.copy()
    o.parent = None if o is arm else arm
    o.matrix_world = m
for o in list(bpy.data.objects):
    if o.type == "EMPTY":
        bpy.data.objects.remove(o)

# Los triángulos vienen sueltos (cada uno con sus vértices): unirlos antes de simplificar o se deshace
bm = bmesh.new()
bm.from_mesh(cuerpo.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.00005)
bm.to_mesh(cuerpo.data)
bm.free()
bpy.context.view_layer.objects.active = cuerpo
tris = sum(len(p.vertices) - 2 for p in cuerpo.data.polygons)
if tris > TRIANGULOS:
    d = cuerpo.modifiers.new("Simplificar", "DECIMATE")
    d.ratio = TRIANGULOS / tris
    bpy.ops.object.modifier_apply(modifier=d.name)
bpy.ops.object.shade_smooth()

# Bajar los brazos (postura en T -> colgando) y dejarlo como postura de reposo
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
for lado, signo in (("Left", 1), ("Right", -1)):
    pb = arm.pose.bones.get("mixamorig:%sArm" % lado)
    if pb:
        giro = Matrix.Rotation(math.radians(args.brazos * signo), 4, "Y")
        cabeza = arm.matrix_world @ pb.head
        mundo = Matrix.Translation(cabeza) @ giro @ Matrix.Translation(-cabeza) @ (arm.matrix_world @ pb.matrix)
        pb.matrix = arm.matrix_world.inverted() @ mundo
        bpy.context.view_layer.update()
bpy.ops.object.mode_set(mode="OBJECT")
mod = next(m for m in cuerpo.modifiers if m.type == "ARMATURE")
bpy.context.view_layer.objects.active = cuerpo
bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
bpy.ops.pose.armature_apply(selected=False)
bpy.ops.object.mode_set(mode="OBJECT")
nuevo = cuerpo.modifiers.new("Armature", "ARMATURE")
nuevo.object = arm

# Escalar a la altura pedida con los pies en el suelo y centrado
vs = [cuerpo.matrix_world @ v.co for v in cuerpo.data.vertices]
alto = max(v.z for v in vs) - min(v.z for v in vs)
centro = Vector(((max(v.x for v in vs) + min(v.x for v in vs)) / 2, (max(v.y for v in vs) + min(v.y for v in vs)) / 2, min(v.z for v in vs)))
s = args.altura / alto
ajuste = Matrix.Scale(s, 4) @ Matrix.Translation(-centro)
mallaMundo = cuerpo.matrix_world.copy()
cuerpo.parent = None
cuerpo.matrix_world = ajuste @ mallaMundo
arm.matrix_world = ajuste @ arm.matrix_world
bpy.context.view_layer.update()
for o in (arm, cuerpo):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
cuerpo.parent = arm
cuerpo.name = args.nombre
cuerpo.data.name = args.nombre
arm.name = args.nombre + "_Esqueleto"
# Roblox ve los dos puntos de "mixamorig:" mal en algunos sitios: fuera el prefijo
for b in arm.data.bones:
    b.name = b.name.replace("mixamorig:", "")
for g in cuerpo.vertex_groups:
    g.name = g.name.replace("mixamorig:", "")


# Texturas a 1024: SurfaceAppearance quiere rugosidad y metal en imágenes aparte
def guardar(pixeles, nombre):
    img = bpy.data.images.new(nombre, TEXTURA, TEXTURA, alpha=False)
    img.pixels.foreach_set(pixeles.ravel())
    img.filepath_raw = os.path.join(args.carpeta, nombre + ".png")
    img.file_format = "PNG"
    img.save()


def leer(img):
    img = img.copy()
    img.scale(TEXTURA, TEXTURA)
    p = np.empty(TEXTURA * TEXTURA * 4, dtype=np.float32)
    img.pixels.foreach_get(p)
    return p.reshape(TEXTURA, TEXTURA, 4)


for img in list(bpy.data.images):
    n = img.name.lower()
    if "basecolor" in n:
        guardar(leer(img), args.nombre + "_color")
    elif "normal" in n:
        guardar(leer(img), args.nombre + "_normal")
    elif "_rm" in n:
        # glTF: rugosidad en el verde, metal en el azul
        p = leer(img)
        for canal, nombre in ((1, "_rugosidad"), (2, "_metal")):
            g = np.repeat(p[:, :, canal : canal + 1], 3, axis=2)
            guardar(np.concatenate([g, np.ones((TEXTURA, TEXTURA, 1), np.float32)], axis=2), args.nombre + nombre)

# Las del material también a 1024 y en PNG: así el .glb lleva las cuatro texturas y Roblox las pone solas
for img in list(bpy.data.images):
    if img.size[0] > TEXTURA:
        img.scale(TEXTURA, TEXTURA)
        img.file_format = "PNG"
        img.filepath_raw = os.path.join(args.carpeta, "%s_material_%s.png" % (args.nombre, img.name.split(".")[0][-2:]))
        img.save()
        img.pack()

tris = sum(len(p.vertices) - 2 for p in cuerpo.data.polygons)
print("BICHO %s: %d triángulos, %d huesos, alto %.2f" % (args.nombre, tris, len(arm.data.bones), args.altura))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(args.carpeta, args.nombre + ".blend"))
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.fbx(
    filepath=os.path.join(args.carpeta, args.nombre + ".fbx"),
    object_types={"ARMATURE", "MESH"},
    axis_forward="-Z",
    axis_up="Y",
    apply_scale_options="FBX_SCALE_UNITS",
    add_leaf_bones=False,
    use_armature_deform_only=True,
    path_mode="COPY",
    embed_textures=True,
)
# El .glb es el que se sube: el .fbx pierde la textura de color y la rugosidad/metal
bpy.ops.export_scene.gltf(
    filepath=os.path.join(args.carpeta, args.nombre + ".glb"),
    export_format="GLB",
    use_selection=False,
    export_animations=False,
    export_image_format="AUTO",
)

# Vistas para revisarlo: de frente, de lado y la cabeza de cerca
escena = bpy.context.scene
escena.render.resolution_x = escena.render.resolution_y = 800
mundo = bpy.data.worlds.new("Fondo")
escena.world = mundo
mundo.use_nodes = True
mundo.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.5, 0.5, 1)
cam = bpy.data.objects.new("Camara", bpy.data.cameras.new("Camara"))
escena.collection.objects.link(cam)
escena.camera = cam
sol = bpy.data.objects.new("Sol", bpy.data.lights.new("Sol", "SUN"))
sol.data.energy = 4
sol.rotation_euler = (math.radians(55), 0, math.radians(-40))
escena.collection.objects.link(sol)
h = args.altura
for k, (objetivo, desde) in enumerate([
    (Vector((0, 0, h * 0.5)), Vector((0.3, -1, 0.1)) * h * 1.6),
    (Vector((0, 0, h * 0.5)), Vector((1, 0, 0.1)) * h * 1.6),
    (Vector((0, -h * 0.1, h * 0.85)), Vector((0.35, -1, 0.05)) * h * 0.45),
]):
    cam.location = objetivo + desde
    cam.rotation_euler = (objetivo - cam.location).to_track_quat("-Z", "Y").to_euler()
    escena.render.filepath = os.path.join(args.carpeta, "%s%d.png" % (args.nombre, k + 1))
    bpy.ops.render.render(write_still=True)
