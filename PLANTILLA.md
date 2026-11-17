# Plantilla: replicar el esquema en otro proyecto

Este repo es el modelo del esquema de trabajo que se armó para Gobierno de IA, entre el 11 y el 16.11.2026: inbox, carpetas por día y tipo en OneDrive, espejo automático del documento principal, conocimiento del Project con núcleo normativo y Contexto vivo en Notion. Para llevarlo a otro proyecto se copian tres archivos, se cambian tres valores y se siguen los pasos manuales de abajo.

## Qué se copia

| Archivo | Para qué |
|---|---|
| `generar_espejo.py` | Convierte el `.docx` en texto: cuerpo, carátula, notas al pie y comentarios |
| `herramientas/espejo-onedrive.sh` | Busca en OneDrive el Word más reciente del tipo indicado y, si cambió, regenera el espejo |
| `.github/workflows/espejo-onedrive.yml` | Corre lo anterior cada hora en horario laboral y a pedido |

Lo demás de este repo (`normativo/`, `guardar.ps1`, `trabajo/espejo/`) es propio de Gobierno de IA y no se copia.

## Los tres valores que cambian

En `.github/workflows/espejo-onedrive.yml`, paso «Regenerar el espejo si el Word cambió»:

| Valor | Qué es | Ejemplo |
|---|---|---|
| `PROYECTO` | Carpeta del proyecto en OneDrive, con el prefijo `onedrive:` | `onedrive:Trabajo/[WORK] - INI` |
| `TIPO` | Carpeta de tipo cuyo Word se espeja | `Directiva`, `Lineamiento`, `Informes` |
| `NOMBRE` | Nombre fijo del espejo en el conocimiento | `LINEAMIENTO-INI` |

## Pasos manuales (una sola vez por proyecto)

1. **Repo nuevo y privado** en `mfkc87-svg`, con los tres archivos copiados y los tres valores cambiados.
2. **Credencial:** `gh secret set RCLONE_CONF --repo mfkc87-svg/<repo> < "%APPDATA%\rclone\rclone.conf"`. Es la misma de `entregas-onedrive`: si se renueva, se vuelve a cargar en todos los repos que la usan.
3. **Carpeta en OneDrive:** `Trabajo/<proyecto>/` con `_entrada/`. Las carpetas por día las crea Claude al entregar u ordenar.
4. **Primer Word:** dejarlo en `AAAA-MM-DD/<TIPO>/` y correr el workflow a mano (Actions → *Espejo desde OneDrive* → *Run workflow*). Debe crear `trabajo/espejo/<NOMBRE>.md`.
5. **Conocimiento del Project:** agregar GitHub → el repo nuevo, marcar `trabajo/`, y darle *Sync*. Si el proyecto cita normas, agregar también `normas-trabajo` y marcar solo los `norma.md` que se citan a diario.
6. **Notion:** página Contexto vivo del proyecto con su subpágina *Buzón de entrega* (carpeta, repo de entregas, equipo puente, tipos), y el proyecto en la base *Proyectos*.
7. **Prompt del Project:** sección «El espejo» con la compuerta de fecha, adaptada al documento y al tipo.

El modo «arrancar proyecto» de la skill `mk-core-prompts` recorre estos pasos.

## Límites conocidos

- La sincronización del repo con el conocimiento del Project no siempre se actualiza sola: después de cada versión nueva, *Sync*.
- La credencial de rclone vence cada ~90 días.
- El remoto de rclone debe apuntar al identificador corto de la unidad; con un `drive_id` que empieza con `b!`, las descargas fallan con 401.
- El proceso lee solo las carpetas del tipo indicado. Nunca lee `_entrada/` ni otros insumos.
- Vigente es el Word de la carpeta de día más reciente y, dentro de ella, el de versión más alta (`_vNN`). Un Word sin número de versión en el nombre solo gana por fecha de modificación: nombrar siempre con `_vNN`.
- Si una corrida falla, el workflow abre (o comenta) un issue «El espejo desde OneDrive falló» en el repo, y GitHub avisa por correo. Se cierra a mano cuando vuelve a funcionar.
