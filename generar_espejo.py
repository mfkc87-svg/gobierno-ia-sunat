#!/usr/bin/env python3
"""
generar_espejo.py — Genera el espejo de texto de los .docx de normativo/.

Para qué: el conector de GitHub de claude.ai lee texto barato en vez del .docx
binario. Así cualquier chat cita el texto VIGENTE sin que subas nada.

Regla de diseño: el espejo se REGENERA en cada commit y NUNCA se edita a mano.
Por eso no puede desfasarse — a diferencia de una copia mantenida a mano, que se
desfasa el primer día que corriges una coma en Word sin avisar.

Solo biblioteca estándar de Python 3. No requiere pip, ni lxml, ni pandoc.

Uso, desde la raíz del repo:
    python generar_espejo.py
o, para un solo archivo (lo usa .github/workflows/espejo-onedrive.yml):
    python generar_espejo.py --docx RUTA --salida RUTA.md --origen "ruta en OneDrive"

Lee  normativo/*.docx  (y normativo/anexos/*.docx)
Escribe  trabajo/espejo/<nombre>.md  (texto, carátula, notas al pie y comentarios)
"""
import datetime
import os
import re
import sys
import zipfile
import xml.etree.ElementTree as ET

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
ORIGEN = ["normativo", os.path.join("normativo", "anexos")]
DESTINO = os.path.join("trabajo", "espejo")


def hijos_t(run):
    """<w:t> hijos DIRECTOS. No descender: un run puede envolver un cuadro de texto."""
    return [c for c in run if c.tag == W + "t"]


def runs_de_cuadros(root):
    """IDs de los runs que viven DENTRO de un cuadro de texto.

    Necesario porque `nodo.iter(w:r)` desciende a los cuadros anidados: un párrafo
    del cuerpo que envuelve la carátula devolvería también su texto, y el código del
    documento saldría duplicado. ElementTree no tiene getparent(), así que se marcan
    por identidad antes de recorrer el cuerpo.
    """
    return {id(r) for tb in root.iter(W + "txbxContent") for r in tb.iter(W + "r")}


def texto_de(nodo, excluir=frozenset()):
    """Texto de un párrafo, respetando tabulaciones y saltos de línea."""
    partes = []
    for r in nodo.iter(W + "r"):
        if id(r) in excluir:
            continue
        for c in r:
            if c.tag == W + "t":
                partes.append(c.text or "")
            elif c.tag == W + "tab":
                partes.append("\t")
            elif c.tag == W + "br":
                partes.append("\n")
            elif c.tag == W + "footnoteReference":
                partes.append(f"[^{c.get(W + 'id')}]")
            elif c.tag == W + "endnoteReference":
                partes.append(f"[^e{c.get(W + 'id')}]")
    return "".join(partes)


def colores_resaltado(root):
    conteo = {}
    for r in root.iter(W + "r"):
        rpr = r.find(W + "rPr")
        if rpr is None:
            continue
        h = rpr.find(W + "highlight")
        if h is None:
            continue
        val = h.get(W + "val")
        if val and val != "none":
            conteo[val] = conteo.get(val, 0) + 1
    return conteo


def texto_tabla(tbl, excluir=frozenset()):
    filas = []
    for tr in tbl.findall(W + "tr"):
        celdas = []
        for tc in tr.findall(W + "tc"):
            trozos = [texto_de(p, excluir).strip() for p in tc.findall(W + "p")]
            celdas.append(" ".join(t for t in trozos if t))
        filas.append("| " + " | ".join(celdas) + " |")
    return filas


def cuerpo(root, excluir=frozenset()):
    """Recorre el body en orden documental: párrafos y tablas de primer nivel."""
    body = root.find(W + "body")
    if body is None:
        return []
    salida = []
    for hijo in body:
        if hijo.tag == W + "p":
            salida.append(texto_de(hijo, excluir).rstrip())
        elif hijo.tag == W + "tbl":
            salida.append("")
            salida.extend(texto_tabla(hijo, excluir))
            salida.append("")
    return salida


def caratula(root):
    """Texto dentro de cuadros de texto — en el METDONI, el código del documento."""
    vals = []
    for tb in root.iter(W + "txbxContent"):
        for p in tb.iter(W + "p"):
            t = texto_de(p).strip()
            if t:
                vals.append(t)
    # mc:AlternateContent duplica el cuadro; se quitan repetidos conservando el orden
    vistos, unicos = set(), []
    for v in vals:
        if v not in vistos:
            vistos.add(v)
            unicos.append(v)
    return unicos


def comentarios(z):
    """Los comentarios del Word son pendientes. Que claude.ai los vea es media victoria."""
    if "word/comments.xml" not in z.namelist():
        return []
    root = ET.fromstring(z.read("word/comments.xml"))
    out = []
    for c in root.iter(W + "comment"):
        autor = c.get(W + "author") or "?"
        fecha = (c.get(W + "date") or "")[:10]
        txt = "".join(t.text or "" for t in c.iter(W + "t")).strip()
        if txt:
            out.append(f"- **{autor}** ({fecha}): {txt}")
    return out


def notas(z, parte, etiqueta, prefijo):
    """Notas al pie (o al final) del Word. Muchas citas normativas viven ahi: sin ellas,
    el espejo haria creer que un numeral ya no cita la norma que cumple."""
    if parte not in z.namelist():
        return []
    root = ET.fromstring(z.read(parte))
    out = []
    for n in root.iter(W + etiqueta):
        if n.get(W + "type") in ("separator", "continuationSeparator", "continuationNotice"):
            continue
        txt = " ".join(t for t in (texto_de(p).strip() for p in n.iter(W + "p")) if t)
        if txt:
            out.append(f"[^{prefijo}{n.get(W + 'id')}]: {txt}")
    return out


def espejar(ruta_docx, destino, origen=None):
    z = zipfile.ZipFile(ruta_docx)
    root = ET.fromstring(z.read("word/document.xml"))

    en_cuadros = runs_de_cuadros(root)
    lineas = cuerpo(root, en_cuadros)
    caja = caratula(root)
    coms = comentarios(z)
    pies = notas(z, "word/footnotes.xml", "footnote", "")
    finales = notas(z, "word/endnotes.xml", "endnote", "e")
    hl = colores_resaltado(root)
    mtime = datetime.datetime.fromtimestamp(os.path.getmtime(ruta_docx))

    partes = [
        "<!-- ARCHIVO GENERADO POR generar_espejo.py — NO EDITAR A MANO -->",
        "",
        f"# Espejo de texto — {os.path.basename(ruta_docx)}",
        "",
        "> **Esto no es la fuente de verdad.** La fuente es "
        f"`{origen or ruta_docx.replace(os.sep, '/')}`, que Mario edita en Word.",
        "> Este archivo se regenera en cada commit para que claude.ai pueda leer y citar el "
        "texto vigente sin que nadie suba el binario. Si lo editas a mano, tu cambio se "
        "pierde en la siguiente regeneración.",
        "",
        f"- Última modificación del `.docx`: **{mtime:%d.%m.%Y %H:%M}**",
    ] + ([f"- Archivo fuente: `{origen}`"] if origen else []) + [
        f"- Párrafos: {sum(1 for l in lineas if l.strip())}",
        f"- Resaltados: {hl if hl else 'ninguno'}"
        + ("  ·  amarillo = 1.ª iteración, cian = 2.ª" if hl else ""),
        f"- Notas al pie: {len(pies)}" + (f" · notas al final: {len(finales)}" if finales else ""),
        f"- Comentarios pendientes en el documento: {len(coms)}",
        "",
    ]

    if caja:
        partes += ["## Carátula — contenido de los cuadros de texto", ""]
        partes += [f"- {v}" for v in caja]
        partes += [""]

    partes += ["---", "", "## Texto del documento", ""]
    # Colapsa rachas de líneas vacías para que el espejo no se infle
    anterior_vacia = False
    for l in lineas:
        vacia = not l.strip()
        if vacia and anterior_vacia:
            continue
        partes.append(l)
        anterior_vacia = vacia

    if pies or finales:
        partes += ["", "---", "",
                   "## Notas al pie",
                   "",
                   "Cada llamada `[^n]` del texto remite a la nota `[^n]` de esta lista. "
                   "Las citas normativas que no estan en el cuerpo suelen estar aqui.",
                   ""]
        partes += pies + finales

    if coms:
        partes += ["", "---", "",
                   "## Comentarios en el documento",
                   "",
                   "Son **pendientes atrapados en el archivo**: no aparecen en ningún briefing. "
                   "Conviene llevarlos al backlog de Notion.",
                   ""]
        partes += coms

    texto = "\n".join(partes).rstrip() + "\n"
    with open(destino, "w", encoding="utf-8", newline="\n") as f:
        f.write(texto)
    return len(texto), sum(hl.values()) if hl else 0, len(coms)


def main():
    # Modo archivo único (lo usa el proceso automático de GitHub):
    #   python generar_espejo.py --docx RUTA --origen "texto" --salida RUTA.md
    args = sys.argv[1:]
    if "--docx" in args:
        val = lambda k, d=None: args[args.index(k) + 1] if k in args else d
        ruta, salida = val("--docx"), val("--salida")
        if not ruta or not salida:
            print("Uso: --docx RUTA --salida RUTA.md [--origen TEXTO]")
            return 2
        os.makedirs(os.path.dirname(salida) or ".", exist_ok=True)
        n, hl, coms = espejar(ruta, salida, val("--origen"))
        print(f"  {ruta}  ->  {salida}   ({n:,} caracteres · {hl} resaltados · {coms} comentarios)")
        return 0

    encontrados = []
    for carpeta in ORIGEN:
        if not os.path.isdir(carpeta):
            continue
        for nombre in sorted(os.listdir(carpeta)):
            if nombre.lower().endswith(".docx") and not nombre.startswith("~$"):
                encontrados.append(os.path.join(carpeta, nombre))

    if not encontrados:
        print("No hay .docx en normativo/. Nada que espejar.")
        return 0

    os.makedirs(DESTINO, exist_ok=True)
    print(f"Espejando {len(encontrados)} documento(s) -> {DESTINO}/")
    for ruta in encontrados:
        base = os.path.splitext(os.path.basename(ruta))[0]
        salida = os.path.join(DESTINO, base + ".md")
        try:
            n, hl, coms = espejar(ruta, salida)
        except Exception as e:
            print(f"  ERROR con {ruta}: {e}")
            return 1
        print(f"  {ruta}  ->  {salida}   ({n:,} caracteres · {hl} resaltados · {coms} comentarios)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
