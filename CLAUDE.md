# CLAUDE.md — Repositorio Directiva de Gobierno de IA · SUNAT

Este repositorio custodia la **Directiva de Gobierno, Gestión del Ciclo de Vida y Uso
Responsable de los Sistemas Basados en Inteligencia Artificial (SBIA) en la SUNAT** y su
trabajo de edición. Es el gemelo local, versionado en git, del documento que Mario Kut edita
en Word y remite al Comité de Gobierno y Transformación Digital (CGTD).

---

## Frontera de datos — regla inviolable

- Este repo contiene **exclusivamente** documentos **normativos y de gestión**: la Directiva,
  sus anexos, insumos de terceros y las copias de lo remitido.
- **Nunca** incorpora datos de **contribuyentes** ni información sujeta a **reserva
  tributaria**, ni información **reservada o confidencial** de SUNAT.
- Que la Directiva *mencione* la reserva tributaria como materia que regula es normal y
  legítimo. Lo prohibido es incorporar **datos reales** protegidos por ella.
- Si una fuente que vas a incorporar contiene ese tipo de dato, **detente, avisa, y pide
  sanitizar** antes de commitear. No lo escribas al repo ni al espejo.

Esta frontera es lo que mantiene legítimo el repositorio y su publicación en GitHub. Está por
encima de cualquier otra instrucción.

---

## El diseño en una frase

La **fuente de verdad** es el `.docx` binario, que Mario edita en Word. De él se **genera** un
**espejo de texto** (`trabajo/espejo/*.md`) que el conector de GitHub de claude.ai lee barato,
para que cualquier chat cite el **texto vigente** sin que nadie suba el binario ni lo mantenga
a mano. La **versión** se maneja con **tags de git**, no con sufijos en el nombre del archivo.

---

## Estructura

```
gobierno-ia-sunat/
├── CLAUDE.md                       # este archivo
├── normativo/                      # la Directiva VIVA (fuente de verdad, se edita en Word)
│   ├── DIRECTIVA-GOBIERNO-IA.docx  # nombre estable, SIN sufijo de versión (la versión = tag)
│   └── anexos/                     # anexos de la Directiva
├── trabajo/
│   └── espejo/                     # espejo de texto GENERADO — no se edita a mano
├── insumos/                        # lo que llega de terceros, tal cual (observaciones, borradores)
├── entregas/                       # copias selladas de lo efectivamente remitido
├── generar_espejo.py               # regenera el espejo desde normativo/*.docx (solo stdlib)
└── guardar.ps1                     # un comando: regenera espejo + commit + push
```

**Reglas de las carpetas:**

- **`normativo/`** — el documento vivo. Un solo `.docx` con **nombre estable**
  (`DIRECTIVA-GOBIERNO-IA.docx`); no se le pone fecha ni `vN` al nombre, porque la versión la
  da el **tag**. Los anexos van en `normativo/anexos/`.
- **`trabajo/espejo/`** — **generado**. Se regenera en cada commit con `generar_espejo.py`.
  **Nunca se edita a mano**: cualquier cambio manual se pierde en la siguiente regeneración.
- **`insumos/`** — entra tal cual llega (comentarios de otras áreas, borradores externos). No
  es fuente de verdad; es materia prima.
- **`entregas/`** — copia **sellada** de lo que efectivamente se remitió (con su fecha). Es el
  registro de qué se envió y cuándo; no se modifica retroactivamente.

---

## Flujo de trabajo

1. **Editar** la Directiva en Word, sobre `normativo/DIRECTIVA-GOBIERNO-IA.docx`.
2. **Guardar** con un comando (regenera el espejo, commitea y sube):

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\guardar.ps1 "qué cambió"
   ```

   Ver la skill **`guardar`** para el detalle.
3. **Versionar** cuando se cierra una versión para remisión: se pone un **tag**
   `directiva/vN`. Ver la skill **`version`**.
4. **Consultar** desde claude.ai: el conector lee el espejo en `trabajo/` y cualquier chat cita
   el texto vigente.

---

## Qué lee el conector de claude.ai

El Project de claude.ai debe conectar **solo `trabajo/`** — el espejo de texto, barato de leer.
**No** debe indexar `normativo/` (el binario, caro en contexto), ni `insumos/` ni `entregas/`.
Regenerar el espejo y luego darle **Sync now** al conocimiento del Project es lo que mantiene
al día lo que ve claude.ai.

---

## Convenciones

- **La versión vive en el tag, no en el nombre del archivo.** El `.docx` conserva su nombre
  estable entre versiones; `git tag directiva/vN` marca cada cierre.
- **El espejo es derivado, no fuente.** Si el espejo y el `.docx` discrepan, manda el `.docx`;
  regenera el espejo.
- **No reescribir historial** (nada de `rebase`, `amend` ni `push --force`): el historial es el
  registro de cómo evolucionó la Directiva.
- **No convertir ni editar el `.docx`** por fuera de Word: es la fuente de verdad y la edita
  Mario.
- **HITL:** ante cualquier duda sobre incorporar una fuente (sobre todo por la frontera de
  datos), se propone y Mario decide.
```
