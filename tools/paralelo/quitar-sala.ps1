# Quita la copia de una sala cuando su rama ya está juntada (docs/plan-paralelo.md, paso C).
# Uso: powershell -ExecutionPolicy Bypass -File tools\paralelo\quitar-sala.ps1 -Sala Galeria
#   Para el Rojo de esa copia, quita ..\Horror-<Sala> (git se niega si tiene cambios sin commit) y borra la rama
#   sala-<sala> solo si ya está juntada (su PR MERGED o git branch -d).
param([Parameter(Mandatory)][string]$Sala)
$ErrorActionPreference = "Stop"
$proyecto = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$copia = Join-Path (Split-Path $proyecto) "Horror-$Sala"
if (-not (Test-Path $copia)) { throw "No existe $copia." }
$datos = Get-Content -Raw (Join-Path $copia "sala.json") | ConvertFrom-Json

# El rojo.exe de Rokit lanza otro rojo.exe hijo: se paran los dos (los que sirven en el puerto de esta sala).
Get-CimInstance Win32_Process -Filter "Name='rojo.exe'" |
	Where-Object { $_.CommandLine -match "--port $($datos.rojo)\b" } |
	ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep 1

git -C $proyecto worktree remove $copia
if ($LASTEXITCODE -ne 0) { throw "La copia tiene cambios sin commit: no se quita." }
# Se junta con squash (gh pr merge --squash): git no la ve juntada y -d falla. Se borra si su PR está MERGED.
$estado = gh pr view $datos.rama --json state -q .state 2>$null
if ($estado -eq "MERGED") {
	git -C $proyecto branch -D $datos.rama
} else {
	git -C $proyecto branch -d $datos.rama
}
Write-Output "Sala $Sala quitada."
