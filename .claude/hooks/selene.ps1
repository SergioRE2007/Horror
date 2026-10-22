# Tras editar un .lua/.luau, pasa Selene solo por ese archivo.
# Si encuentra algo, se lo enseña a Claude (código 2). Si Selene no está instalado, no hace nada.
$entrada = [Console]::In.ReadToEnd() | ConvertFrom-Json
$archivo = $entrada.tool_input.file_path
if (-not $archivo -or $archivo -notmatch '\.luau?$') { exit 0 }
if (-not (Get-Command selene -ErrorAction SilentlyContinue)) { exit 0 }
Set-Location $env:CLAUDE_PROJECT_DIR
$salida = selene --display-style Quiet --no-summary $archivo 2>&1
if ($LASTEXITCODE -ne 0 -and $salida) {
	[Console]::Error.WriteLine(($salida -join "`n"))
	exit 2
}
exit 0
