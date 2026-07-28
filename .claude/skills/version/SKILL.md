---
name: version
description: Cierra una versión de la Directiva marcándola con un tag de git (directiva/vN). Úsala cuando Mario dé por cerrada una versión para remitir al CGTD o dejar un hito estable. Frases típicas "marca la versión", "cierra la v0.5", "etiqueta esta versión para remisión". La versión vive en el TAG, no en el nombre del archivo el .docx conserva su nombre estable entre versiones.
---

# Skill: version

Marca un **hito estable** de la Directiva con un **tag de git**. En este repo la versión **no**
va en el nombre del archivo (el `.docx` se llama siempre `DIRECTIVA-GOBIERNO-IA.docx`): va en el
tag. Así el historial de git es la línea de versiones, y no se acumulan copias `_v2_v3_final`.

## Convención de tags

```
directiva/vN[.M]
```

- `directiva/v0.2`, `directiva/v0.5`, `directiva/v1.0`, …
- Correlativo por **fecha de cierre**. La versión vigente es el tag de mayor número.
- Un tag apunta al **commit** donde el `.docx` y su espejo quedaron en el estado de esa versión.

## Cómo cerrar una versión

1. Asegúrate de que el avance está guardado y el espejo regenerado (skill **`guardar`**).
2. Crea el tag sobre el commit vigente:

   ```powershell
   git tag directiva/v0.5
   git push origin directiva/v0.5
   ```

   O en un solo paso al guardar:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\guardar.ps1 "cierra v0.5 para remisión" -Tag directiva/v0.5
   ```

## Consultar versiones

```powershell
git tag --list "directiva/*"                 # lista las versiones
git show directiva/v0.5 --stat               # qué cambió en esa versión
git diff directiva/v0.4 directiva/v0.5        # diferencia entre dos versiones
```

Con `git config diff.word.textconv` configurado y `pandoc` instalado, el `git diff` muestra el
`.docx` como texto legible. Sin pandoc, git compara el binario; no es un error.

## Relación con `entregas/`

El tag marca **qué** se cerró; `entregas/` guarda la **copia sellada** de lo efectivamente
remitido, con su fecha. Al remitir una versión, conviene: (1) tag `directiva/vN`, y (2) copiar
el `.docx` de esa versión a `entregas/AAAA-MM-DD-directiva-vN.docx` como registro de lo enviado.

## Reglas

- **No reescribir historial:** nada de mover tags ya publicados, `amend` ni `push --force`. Una
  versión cerrada es un registro; si hay que corregir, se hace una versión nueva.
- **Frontera de datos:** una versión que se marca es una que se puede publicar en GitHub. Si
  tuviera dato sensible, no se cierra hasta sanitizar.

## 🔄 Loop de automejora

Si la convención de versionado necesita ajustarse (nuevo esquema de numeración, relación con
remesas, etc.), **propón (HITL) y actualiza este archivo**, sube la versión en el Changelog y
persiste lo durable. Esta sección no se elimina.

## Changelog

- **v1.0** — Versión inicial. Tags `directiva/vN`, consulta de versiones y relación con
  `entregas/`.
