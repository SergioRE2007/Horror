# Copia del proyecto para hacer una sala en otro chat y otro Studio a la vez (pedido por el usuario: docs/plan-paralelo.md).
# Uso: powershell -ExecutionPolicy Bypass -File tools\paralelo\nueva-sala.ps1 -Sala Galeria -Puerto 34874
#   Crea ..\Horror-<Sala> (git worktree, rama sala-<sala> desde paso-11-fin), copia juego.rbxl a juego-<Sala>.rbxl y
#   deja Rojo sirviendo esa copia sin ventana en -Puerto. Los puertos del receptor y de las texturas salen del de Rojo
#   (34874 -> 8767 y 8778, 34875 -> 8768 y 8779...) y quedan en sala.json de la copia.
#   Se puede volver a lanzar (tras reiniciar el PC): lo que ya existe no se toca y solo arranca Rojo si no está.
param(
	[Parameter(Mandatory)][string]$Sala,
	[Parameter(Mandatory)][int]$Puerto,
	[string]$Desde = "paso-11-fin"
)
$ErrorActionPreference = "Stop"
if ($Puerto -lt 34874) { throw "Los puertos de sala empiezan en 34874 (34872 es el juego y 34873 el lobby)." }
$proyecto = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$copia = Join-Path (Split-Path $proyecto) "Horror-$Sala"
$rama = "sala-" + $Sala.ToLower()
$rojo = Join-Path $env:USERPROFILE ".rokit\bin\rojo.exe"

if (-not (Test-Path $copia)) {
	git -C $proyecto worktree add $copia -b $rama $Desde
	if ($LASTEXITCODE -ne 0) { throw "git worktree add ha fallado." }
}
$lugar = Join-Path $copia "juego-$Sala.rbxl"
if (-not (Test-Path $lugar)) {
	Copy-Item (Join-Path $proyecto "juego.rbxl") $lugar
}
$puertos = [ordered]@{
	sala = $Sala
	rama = $rama
	rojo = $Puerto
	receptor = 8767 + ($Puerto - 34874)
	texturas = 8778 + ($Puerto - 34874)
}
$puertos | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $copia "sala.json")

$ocupado = Get-NetTCPConnection -LocalPort $Puerto -State Listen -ErrorAction SilentlyContinue
if ($ocupado) {
	Write-Output "Rojo ya escucha en $Puerto."
} else {
	# Como la tarea "Rojo Horror": conhost --headless para que no salga ventana.
	Start-Process conhost.exe -ArgumentList "--headless `"$rojo`" serve juego.project.json --port $Puerto" -WorkingDirectory $copia -WindowStyle Hidden
	for ($i = 0; $i -lt 20 -and -not (Get-NetTCPConnection -LocalPort $Puerto -State Listen -ErrorAction SilentlyContinue); $i++) {
		Start-Sleep -Milliseconds 500
	}
	if (-not (Get-NetTCPConnection -LocalPort $Puerto -State Listen -ErrorAction SilentlyContinue)) { throw "Rojo no arranca en $Puerto." }
	Write-Output "Rojo sirviendo $copia en $Puerto."
}
Write-Output "Sala $Sala lista: abre $lugar y Rojo -> Connect al puerto $Puerto. Receptor $($puertos.receptor), texturas $($puertos.texturas)."
