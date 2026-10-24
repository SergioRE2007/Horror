# Pasa un modelo de Poly Haven (CC0) a un mueble del juego: lo baja, lo junta en una sola malla, lo escala a studs,
# lo gira con el frente a -Z del juego, le pone el pivote abajo en el centro, lo simplifica hasta --tris triángulos y
# saca sus texturas para un SurfaceAppearance (color, normal, rugosidad y metal) más una vista .png.
# Uso: blender -b --factory-startup --python tools/blender/polyhaven.py -- --id ArmChair_01 --nombre Butaca
#      [--alto 4 | --escala 4] [--girar 0] [--tris 5000] [--res 1k] [--oscurecer 0.85]
# Sale en Documents\Roblox\modelos\polyhaven\<nombre>\: <nombre>.fbx, <nombre>_color/_normal/_rugosidad/_metal.png y
# <nombre>.png. Luego: subir_modelo.mjs con el .fbx y upload_image de Studio con las texturas (docs/sistemas/polyhaven.md).
import argparse
import json
import math
import os
import sys
import urllib.request

import bpy
import numpy as np
from mathutils import Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from geometria import OUT_DIR, render  # noqa: E402

API = "https://api.polyhaven.com/files/"
STUDS_POR_METRO = 4.0  # como la nevera y el reloj de ahora (1,7 m -> 6,9 studs)


def bajar(url, destino):
    if os.path.exists(destino):
        return
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    peticion = urllib.request.Request(url, headers={"User-Agent": "JuegoTerror/1.0"})
    # A un .part y luego renombrar: una descarga cortada no se da por buena la próxima vez.
    with urllib.request.urlopen(peticion, timeout=60) as respuesta, open(destino + ".part", "wb") as archivo:
        archivo.write(respuesta.read())
    os.replace(destino + ".part", destino)


def bajar_modelo(asset, res, carpeta):
    peticion = urllib.request.Request(API + asset, headers={"User-Agent": "JuegoTerror/1.0"})
    with urllib.request.urlopen(peticion, timeout=60) as respuesta:
        datos = json.loads(respuesta.read())
    gltf = datos["gltf"][res]["gltf"]
    ruta = os.path.join(carpeta, os.path.basename(gltf["url"]))
    bajar(gltf["url"], ruta)
    for nombre, archivo in gltf.get("include", {}).items():
        bajar(archivo["url"], os.path.join(carpeta, nombre))
    return ruta


def textura(material, tipo_entrada):
    """La imagen que llega (directa o por un nodo de normal o de separar) a la entrada del Principled BSDF."""
    bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    pendientes = [bsdf.inputs[tipo_entrada]]
    while pendientes:
        entrada = pendientes.pop()
        for enlace in entrada.links:
            nodo = enlace.from_node
            if nodo.type == "TEX_IMAGE":
                return nodo.image, enlace.from_socket.name
            pendientes.extend(i for i in nodo.inputs if i.is_linked)
    return None, None


def canal(image, indice):
    w, h = image.size
    pixeles = np.empty(w * h * 4, dtype=np.float32)
    image.pixels.foreach_get(pixeles)
    return pixeles.reshape(h, w, 4)[:, :, indice], w, h


def guardar(nombre, rgb, w, h, ruta):
    imagen = bpy.data.images.new(nombre, w, h, alpha=False)
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[:, :, :3] = rgb
    imagen.pixels.foreach_set(rgba.ravel())
    imagen.filepath_raw = ruta
    imagen.file_format = "PNG"
    imagen.save()


def manchas(w, h, semilla=7):
    """Factor de oscuridad 0,55-1 con manchas grandes y suaves y algo de grano (suciedad), igual en cada exportación."""
    azar = np.random.default_rng(semilla)
    total = np.zeros((h, w), dtype=np.float32)
    for celdas, peso in ((4, 0.5), (10, 0.3), (40, 0.2)):
        rejilla = azar.random((celdas + 1, celdas + 1)).astype(np.float32)
        ys = np.linspace(0, celdas, h, dtype=np.float32)
        xs = np.linspace(0, celdas, w, dtype=np.float32)
        y0, x0 = np.minimum(ys.astype(int), celdas - 1), np.minimum(xs.astype(int), celdas - 1)
        fy, fx = (ys - y0)[:, None], (xs - x0)[None, :]
        fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
        a, b = rejilla[y0][:, x0], rejilla[y0][:, x0 + 1]
        c, d = rejilla[y0 + 1][:, x0], rejilla[y0 + 1][:, x0 + 1]
        total += peso * ((a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy)
    # Solo lo más alto del ruido se vuelve mancha, para que no quede todo gris por igual.
    mancha = np.clip((total - 0.55) / 0.25, 0, 1)
    grano = azar.random((h, w)).astype(np.float32) * 0.08
    return 1 - mancha * 0.45 - grano


def sacar_texturas(material, base, oscurecer):
    color, _ = textura(material, "Base Color")
    if color:
        color.colorspace_settings.name = "sRGB"
        w, h = color.size
        pixeles = np.empty(w * h * 4, dtype=np.float32)
        color.pixels.foreach_get(pixeles)
        rgb = pixeles.reshape(h, w, 4)[:, :, :3]
        # Envejecer (casa abandonada): menos saturado, amarillento de polvo, más oscuro y con manchas sueltas.
        gris = rgb.mean(axis=2, keepdims=True)
        rgb = (rgb * 0.7 + gris * 0.3) * np.array([1.0, 0.93, 0.8], dtype=np.float32) * oscurecer
        rgb *= manchas(w, h)[:, :, None]
        guardar("color", rgb, w, h, base + "_color.png")
        color.filepath = base + "_color.png"  # la vista .png enseña ya la textura envejecida
        color.reload()
    normal, _ = textura(material, "Normal")
    if normal:
        normal.colorspace_settings.name = "Non-Color"
        w, h = normal.size
        pixeles = np.empty(w * h * 4, dtype=np.float32)
        normal.pixels.foreach_get(pixeles)
        guardar("normal", pixeles.reshape(h, w, 4)[:, :, :3], w, h, base + "_normal.png")
    # glTF: rugosidad en el verde y metal en el azul de la misma imagen (arm = AO, rugosidad, metal).
    for entrada, nombre, indice in (("Roughness", "rugosidad", 1), ("Metallic", "metal", 2)):
        imagen, salida = textura(material, entrada)
        if not imagen:
            continue
        imagen.colorspace_settings.name = "Non-Color"
        if salida in ("Red", "R"):
            indice = 0
        elif salida in ("Green", "G"):
            indice = 1
        elif salida in ("Blue", "B"):
            indice = 2
        valores, w, h = canal(imagen, indice)
        guardar(nombre, np.repeat(valores[:, :, None], 3, axis=2), w, h, base + "_%s.png" % nombre)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--id", required=True)
    parser.add_argument("--nombre", required=True)
    parser.add_argument("--alto", type=float, help="alto final en studs (si no, --escala studs por metro)")
    parser.add_argument("--escala", type=float, default=STUDS_POR_METRO)
    parser.add_argument("--girar", type=float, default=0, help="grados sobre la vertical, si en Roblox sale de espaldas")
    parser.add_argument("--tris", type=int, default=5000)
    parser.add_argument("--res", default="1k")
    parser.add_argument("--oscurecer", type=float, default=0.85)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])

    salida = os.path.join(OUT_DIR, "polyhaven", args.nombre)
    os.makedirs(salida, exist_ok=True)
    ruta = bajar_modelo(args.id, args.res, os.path.join(OUT_DIR, "polyhaven", "_bajados", args.id))

    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=ruta)
    mallas = [o for o in bpy.data.objects if o.type == "MESH"]
    materiales = {s.material for o in mallas for s in o.material_slots if s.material}
    if len(materiales) > 1:
        print("AVISO: %d materiales; solo se sacan las texturas del primero" % len(materiales))

    bpy.ops.object.select_all(action="DESELECT")
    for o in mallas:
        o.select_set(True)
    bpy.context.view_layer.objects.active = mallas[0]
    if len(mallas) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    for o in list(bpy.data.objects):
        if o != obj:
            bpy.data.objects.remove(o, do_unlink=True)
    # Todo a la malla: el importador de glTF gira con cuaterniones (rotation_euler no hace nada) y a veces con un padre.
    obj.data.transform(obj.matrix_world)
    obj.parent = None
    obj.matrix_world = Matrix.Identity(4)

    # Probado con la butaca: lo que mira a -Y de Blender (como vienen los de Poly Haven) sale mirando a -Z en Roblox.
    alturas = [v.co.z for v in obj.data.vertices]
    alto_m = max(alturas) - min(alturas)
    escala = args.alto / alto_m if args.alto else args.escala
    obj.data.transform(Matrix.Rotation(math.radians(args.girar), 4, "Z") @ Matrix.Scale(escala, 4))
    obj.data.update()
    puntos = [v.co for v in obj.data.vertices]
    minimo = [min(p[i] for p in puntos) for i in range(3)]
    maximo = [max(p[i] for p in puntos) for i in range(3)]
    centro = ((minimo[0] + maximo[0]) / 2, (minimo[1] + maximo[1]) / 2, minimo[2])
    for v in obj.data.vertices:
        v.co.x -= centro[0]
        v.co.y -= centro[1]
        v.co.z -= centro[2]

    triangulos = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if triangulos > args.tris:
        mod = obj.modifiers.new("simplificar", "DECIMATE")
        mod.ratio = args.tris / triangulos
        bpy.ops.object.modifier_apply(modifier=mod.name)
    final = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    obj.name = args.nombre
    obj.data.name = args.nombre

    base = os.path.join(salida, args.nombre)
    if materiales:
        sacar_texturas(next(iter(materiales)), base, args.oscurecer)
    else:
        print("AVISO: sin material, no hay texturas")
    bpy.ops.export_scene.fbx(
        filepath=base + ".fbx",
        object_types={"MESH"},
        axis_forward="-Z",
        axis_up="Y",
        apply_scale_options="FBX_SCALE_UNITS",
        path_mode="STRIP",
        embed_textures=False,
    )
    d = obj.dimensions
    print("TAM %.3f %.3f %.3f (studs: ancho, alto, fondo)  triangulos %d -> %d" % (d.x, d.z, d.y, triangulos, final))
    lado = max(d.x, d.z) * 1.4
    bpy.context.scene.render.resolution_percentage = 50
    render(base + ".png", 0, lado, lado, d.z / 2, angle=210, pitch=15)


main()
