#!/usr/bin/env bash
# Regenera el espejo desde el Word vigente de la Directiva en OneDrive.
#
# Lee SOLO archivos .docx dentro de las carpetas del tipo indicado
# (<proyecto>/AAAA-MM-DD/<TIPO>/*.docx). Nunca lee _entrada/ ni otros insumos.
# El .docx se descarga al runner temporal y no se guarda en el repo: al repo solo
# va el espejo de texto y su ficha de fuente (trabajo/espejo/fuente.json).
#
# Vigente = el .docx de la carpeta de día más reciente y, dentro de ella, el de versión
# más alta. Si no cambió desde la última corrida (misma ruta, fecha y hash), no hace nada.
set -euo pipefail

# Parámetros del proyecto (los fija el workflow; estos son los valores de Gobierno de IA)
PROYECTO="${PROYECTO:-onedrive:Trabajo/[WORK] - Gobierno IA}"   # carpeta del proyecto en OneDrive
TIPO="${TIPO:-Directiva}"                                       # carpeta de tipo que se espeja
NOMBRE="${NOMBRE:-DIRECTIVA-GOBIERNO-IA}"                       # nombre fijo del espejo
SALIDA="trabajo/espejo/$NOMBRE.md"
FICHA="trabajo/espejo/fuente.json"
ORIGEN_BASE="${PROYECTO#onedrive:}"
TMP="$(mktemp -d)"

rclone lsjson "$PROYECTO" --recursive --files-only --hash \
  --include "/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/$TIPO/*.docx" \
  > "$TMP/lista.json"

python3 - "$TMP/lista.json" "$FICHA" "$TMP/elegido.json" <<'PY'
import json, sys
lista = [f for f in json.load(open(sys.argv[1])) if not f["Name"].startswith("~$")]
if not lista:
    print("No hay .docx en las carpetas AAAA-MM-DD del tipo. Nada que espejar.")
    sys.exit(0)
import re
def clave(f):
    # Vigente = carpeta de día más reciente; dentro de ella, la versión más alta del nombre
    # (_vNN o _vN.M); la fecha de modificación solo desempata. Así, abrir y tocar una versión
    # vieja (Word en línea guarda solo) no la vuelve vigente.
    dia = f["Path"].split("/", 1)[0]
    m = re.search(r"_v(\d+)(?:\.(\d+))?", f["Name"])
    ver = (int(m.group(1)), int(m.group(2) or 0)) if m else (0, 0)
    return (dia, ver, f["ModTime"])
v = max(lista, key=clave)
elegido = {"ruta": v["Path"], "modtime": v["ModTime"], "bytes": v["Size"],
           "hash": (v.get("Hashes") or {}).get("quickxor", "")}
try:
    previo = json.load(open(sys.argv[2]))
except Exception:
    previo = {}
if all(previo.get(k) == elegido[k] for k in ("ruta", "modtime", "hash")):
    print(f"Sin cambios: {elegido['ruta']} ({elegido['modtime']}).")
    sys.exit(0)
json.dump(elegido, open(sys.argv[3], "w"), ensure_ascii=False, indent=1)
print(f"Vigente: {elegido['ruta']} ({elegido['modtime']}).")
PY

[ -f "$TMP/elegido.json" ] || exit 0

RUTA="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['ruta'])" "$TMP/elegido.json")"
# rclone conserva la fecha de modificación de OneDrive en la copia local
rclone copyto "$PROYECTO/$RUTA" "$TMP/vigente.docx"
TZ=America/Lima python3 generar_espejo.py --docx "$TMP/vigente.docx" --salida "$SALIDA" \
  --origen "$ORIGEN_BASE/$RUTA"
cp "$TMP/elegido.json" "$FICHA"
rm -rf "$TMP"

git add "$SALIDA" "$FICHA"
if git diff --cached --quiet; then
  echo "El espejo no cambió."; exit 0
fi
git -c user.name="espejo-onedrive" -c user.email="actions@users.noreply.github.com" \
  commit -q -m "Espejo desde OneDrive: $RUTA"
git push -q
echo "Espejo actualizado desde $RUTA"
