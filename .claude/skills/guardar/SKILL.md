---
name: guardar
description: Guarda un avance de la Directiva en un solo paso — regenera el espejo de texto desde el .docx, commitea con tu mensaje y sube a GitHub. Úsala SIEMPRE que Mario haya editado la Directiva en Word y quiera dejar el avance versionado y disponible para claude.ai. Frases típicas "guarda esto", "commitea el avance", "sube el cambio de la directiva". Envuelve guardar.ps1; nunca edita el .docx ni el espejo a mano.
---

# Skill: guardar

Deja un avance de la Directiva **guardado y publicado en un solo paso**. Es la envoltura del
script `guardar.ps1` que vive en la raíz del repo.

## Qué hace, en orden

1. **Regenera el espejo** `trabajo/espejo/*.md` desde `normativo/*.docx` con
   `generar_espejo.py` (si hay Python en el PATH). Así claude.ai lee siempre el texto vigente.
2. **`git add -A` + `commit`** con el mensaje que le des. No hace commits vacíos.
3. **`push`** a `origin`, si hay remoto configurado.
4. Te dice si hace falta darle **Sync now** al conocimiento del Project en claude.ai (solo si
   cambió algo bajo `trabajo/` o `normativo/`).

## Uso

Desde la raíz del repo:

```powershell
powershell -ExecutionPolicy Bypass -File .\guardar.ps1 "absuelve obs. de arquitectura en 6.15"
```

Cerrando una versión (crea también el tag — ver la skill **`version`**):

```powershell
powershell -ExecutionPolicy Bypass -File .\guardar.ps1 "cierra v0.5 para remisión" -Tag directiva/v0.5
```

Saltando la regeneración del espejo (p. ej. solo cambió un insumo):

```powershell
powershell -ExecutionPolicy Bypass -File .\guardar.ps1 "agrega observaciones de OIPPI" -SinEspejo
```

## Reglas

- **El espejo es generado, nunca se edita a mano.** Este es su punto: no puede desfasarse
  porque se regenera en cada guardado.
- **Frontera de datos:** antes de guardar, verifica que lo que entra al repo no traiga datos de
  contribuyente ni reserva tributaria (ver `CLAUDE.md`). Si hay duda, para y avisa.
- **Sin Python:** el script avisa y sigue sin espejo; el conector puede leer el `.docx`, solo
  cuesta más contexto.
- **Sin remoto:** el script guarda en local y te recuerda cómo conectar `origin`.

## Cuándo NO usar esta skill

- Para **cerrar una versión formal**, usa **`version`** (o pasa `-Tag` aquí): un guardado normal
  no crea tag.
- Para incorporar un **insumo de terceros** con posible dato sensible: primero pasa por la
  revisión de frontera de datos; no lo guardes a ciegas.

## 🔄 Loop de automejora

Si al usar esta skill aparece una fricción recurrente, un límite de la herramienta o una mejora
al flujo de guardado, **propón (HITL) y aplica el cambio dentro de este archivo o de
`guardar.ps1`**, sube la versión en el Changelog y persiste lo durable. Esta sección no se
elimina.

## Changelog

- **v1.0** — Versión inicial. Envuelve `guardar.ps1`: espejo + commit + push + aviso de Sync.
