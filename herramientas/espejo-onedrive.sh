#!/usr/bin/env bash
# Regenera el espejo desde el Word vigente de la Directiva en OneDrive.
#
# Lee SOLO archivos .docx dentro de carpetas «Directiva» del proyecto
# (<proyecto>/AAAA-MM-DD/Directiva/*.docx). Nunca lee _entrada/ ni otros insumos.
# El .docx se descarga al runner temporal y no se guarda en el repo: al repo solo
# va el espejo de texto y su ficha de fuente (trabajo/espejo/fuente.json).
#
# Vigente = el .docx de mayor fecha de modificación. Si no cambió desde la última
# corrida (misma ruta, fecha y hash), no hace nada.
set -euo pipefail

PROYECTO="${PROYECTO:-onedrive:Trabajo/[WORK] - Gobierno IA}"
SALIDA="trabajo/espejo/DIRECTIVA-GOBIERNO-IA.md"
FICHA="trabajo/espejo/fuente.json"
TMP="$(mktemp -d)"

rclone lsjson "$PROYECTO" --recursive --files-only --hash \
  --include "/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/Directiva/*.docx" \
  > "$TMP/lista.json"

python3 - "$TMP/lista.json" "$FICHA" "$TMP/elegido.json" <<'PY'
import json, sys
lista = [f for f in json.load(open(sys.argv[1])) if not f["Name"].startswith("~$")]
if not lista:
    print("No hay .docx en <AAAA-MM-DD>/Directiva/. Nada que espejar.")
    sys.exit(0)
v = max(lista, key=lambda f: f["ModTime"])
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
  --origen "Trabajo/[WORK] - Gobierno IA/$RUTA"
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
