# guardar.ps1 - Un solo comando: regenera el espejo, commitea y sube.
#
# Se corre DENTRO del repo:
#
#     powershell -ExecutionPolicy Bypass -File .\guardar.ps1 "absuelve obs. de arquitectura en 6.15"
#
# Con tag de version:
#     ...\guardar.ps1 "cierra v0.5 para remision" -Tag directiva/v0.5
#
# Qué hace, en orden:
#   1. Regenera trabajo\espejo\*.md desde normativo\*.docx  (si hay Python)
#   2. git add -A  +  commit con tu mensaje
#   3. push, si hay remoto
#   4. Te dice si hace falta darle Sync now en el Project
#
# No hace commits vacios. Si no hay Python, avisa y sigue sin espejo.

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Mensaje,

    [string]$Tag,

    # Salta la regeneracion del espejo.
    [switch]$SinEspejo
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath '.git')) {
    Write-Host "ERROR: esta carpeta no es un repo git. Entra al repo y vuelve a correrlo." -ForegroundColor Red
    exit 1
}

# ---------- 1. Espejo de texto ----------------------------------------------
# El espejo es lo que hace que claude.ai lea SIEMPRE el texto vigente sin que
# subas nada. Se regenera aqui, nunca se edita a mano.
if (-not $SinEspejo) {
    if (-not (Test-Path -LiteralPath 'generar_espejo.py')) {
        Write-Host "AVISO: no encuentro generar_espejo.py en la raiz del repo. Sigo sin espejo." -ForegroundColor Yellow
    } else {
        $py = $null
        foreach ($c in @('python', 'py', 'python3')) {
            if (Get-Command $c -ErrorAction SilentlyContinue) { $py = $c; break }
        }
        if (-not $py) {
            Write-Host "AVISO: no encuentro Python en el PATH. Sigo sin regenerar el espejo." -ForegroundColor Yellow
            Write-Host "       El conector puede leer el .docx directamente, solo cuesta mas contexto."
        } else {
            Write-Host "--- Regenerando espejo de texto ---" -ForegroundColor Cyan
            & $py generar_espejo.py
            if ($LASTEXITCODE -ne 0) {
                Write-Host "ERROR al generar el espejo. No commiteo: revisa el mensaje de arriba." -ForegroundColor Red
                exit 1
            }
            Write-Host ""
        }
    }
}

# ---------- 2. Commit --------------------------------------------------------
$pendiente = git status --porcelain
if ([string]::IsNullOrWhiteSpace($pendiente)) {
    Write-Host "No hay cambios que guardar." -ForegroundColor Yellow
    exit 0
}

Write-Host "--- Cambios que se van a guardar ---" -ForegroundColor Cyan
git status --short
Write-Host ""

git add -A
git commit --quiet -m $Mensaje
Write-Host "Commit hecho: $(git log -1 --oneline)" -ForegroundColor Green

if ($Tag) {
    git tag $Tag
    Write-Host "Tag creado: $Tag" -ForegroundColor Green
}

# ---------- 3. Push ---------------------------------------------------------
$remoto = git remote 2>$null
if ([string]::IsNullOrWhiteSpace($remoto)) {
    Write-Host ""
    Write-Host "Sin remoto configurado: quedo guardado solo en local." -ForegroundColor Yellow
    Write-Host "Para que claude.ai pueda leer el texto vigente, conecta el remoto:"
    Write-Host "  git remote add origin https://github.com/<TU-USUARIO>/gobierno-ia-sunat.git"
    Write-Host "  git push -u origin main --tags"
    Write-Host ""
    Write-Host "Mientras no haya remoto, respalda con:"
    Write-Host "  git bundle create respaldo.bundle --all"
    exit 0
}

if ($Tag) { git push --quiet --follow-tags } else { git push --quiet }
Write-Host "Push hecho a origin." -ForegroundColor Green

# ---------- 4. Aviso de Sync ------------------------------------------------
# Solo avisa si cambio algo que el Project realmente lee.
$leePorConector = $pendiente -match 'trabajo/|normativo/'
Write-Host ""
if ($leePorConector) {
    Write-Host ">>> Dale un clic en 'Sync now' en el conocimiento del Project." -ForegroundColor Cyan
    Write-Host "    El espejo cambio: el proximo chat necesita la version nueva."
} else {
    Write-Host "No hace falta Sync: no cambio nada que el Project lea." -ForegroundColor DarkGray
}
