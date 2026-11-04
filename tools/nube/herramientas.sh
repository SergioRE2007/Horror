#!/bin/bash
# Herramientas para una sesión en la nube (sin Windows ni Rokit): selene 0.32.0 y lune 0.10.5 de Linux en
# /tmp/herramientas/bin, y el roblox.yml de selene (está en .gitignore). Uso, desde la raíz del repo:
#   bash tools/nube/herramientas.sh
# Luego: /tmp/herramientas/bin/selene src   y   /tmp/herramientas/bin/lune run tests/regressions.luau
# `selene generate-roblox-std` baja el API-Dump de una URL vieja (CloneTrooper1019) que el proxy no deja: se baja el de
# MaximumADHD, se sirve en local y se parchea en una copia del binario la URL por una http://127.0.0.1 del mismo largo.
set -euo pipefail
RAIZ="$(git rev-parse --show-toplevel)" # la raíz del repo: ahí va el roblox.yml
D=/tmp/herramientas
mkdir -p "$D/bin" "$D/dl" "$D/api"
cd "$D/dl"
[ -f selene.zip ] || curl -sSL -o selene.zip https://github.com/Kampfkarren/selene/releases/download/0.32.0/selene-0.32.0-linux.zip
[ -f lune.zip ] || curl -sSL -o lune.zip https://github.com/lune-org/lune/releases/download/v0.10.5/lune-0.10.5-linux-x86_64.zip
python3 -I -c "import zipfile; zipfile.ZipFile('selene.zip').extractall('sel'); zipfile.ZipFile('lune.zip').extractall('lun')"
cp sel/selene "$D/bin/selene"
cp lun/lune "$D/bin/lune"
chmod +x "$D/bin/selene" "$D/bin/lune"
cd "$D/api"
[ -f API-Dump.json ] || curl -sSL -o API-Dump.json https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json
python3 -I - "$D" <<'EOF'
import os, sys
d = sys.argv[1]
orig = b"https://raw.githubusercontent.com/CloneTrooper1019/Roblox-Client-Tracker/roblox/API-Dump.json"
base = b"http://127.0.0.1:8765/"
nombre = b"a" * (len(orig) - len(base) - 5) + b".json"
nueva = base + nombre
datos = open(d + "/bin/selene", "rb").read()
assert datos.count(orig) == 1, "la URL del API-Dump no está en este selene"
open(d + "/bin/selene-generar", "wb").write(datos.replace(orig, nueva))
os.chmod(d + "/bin/selene-generar", 0o755)
destino = d + "/api/" + nombre.decode()
if not os.path.exists(destino):
    os.link(d + "/api/API-Dump.json", destino)
EOF
python3 -I -m http.server 8765 --bind 127.0.0.1 --directory "$D/api" >/dev/null 2>&1 &
SERVIDOR=$!
sleep 1
cd "$RAIZ"
NO_PROXY=127.0.0.1,localhost no_proxy=127.0.0.1,localhost "$D/bin/selene-generar" generate-roblox-std
kill "$SERVIDOR" 2>/dev/null || true
"$D/bin/selene" --version
"$D/bin/lune" --version
echo "Listo: $D/bin/selene src  y  $D/bin/lune run tests/regressions.luau"
