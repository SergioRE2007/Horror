# Dibuja la textura de una rama de pino (agujas sobre fondo transparente) para las ramas planas de los pinos de
# Blender (tools/blender/crear_bosque.py, papel "Rama"). La rama va de la izquierda (pegada al tronco) a la derecha.
#   powershell -ExecutionPolicy Bypass -File tools/texturas/agujas.ps1 [salida.png] [semilla]
param(
	[string]$Salida = "$env:USERPROFILE\Documents\Roblox\modelos\agujas.png",
	[int]$Semilla = 7
)
Add-Type -AssemblyName System.Drawing

$TAM = 1024 # se dibuja grande y se reduce a la mitad (bordes suaves)
$bmp = New-Object System.Drawing.Bitmap $TAM, $TAM, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$lienzo = [System.Drawing.Graphics]::FromImage($bmp)
$lienzo.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$lienzo.Clear([System.Drawing.Color]::Transparent)
$azar = New-Object System.Random $Semilla

function Verde([double]$luz) {
	# Verde de abeto, de muy oscuro a algo más claro en las puntas.
	$r = [int](14 + 16 * $luz + $azar.Next(-4, 5))
	$v = [int](26 + 36 * $luz + $azar.Next(-6, 7))
	$a = [int](18 + 14 * $luz + $azar.Next(-4, 5))
	return [System.Drawing.Color]::FromArgb(255, [Math]::Max(0, $r), [Math]::Max(0, $v), [Math]::Max(0, $a))
}

# Una ramita con agujas a los dos lados, de (x0, y0) con ángulo `ang` (radianes) y largo `largo`. `ancho` = largo
# de las agujas en la base (se acortan hacia la punta).
function Ramita([double]$x0, [double]$y0, [double]$ang, [double]$largo, [double]$ancho, [double]$grosor) {
	$pasos = [int]($largo / 5)
	$dx = [Math]::Cos($ang); $dy = [Math]::Sin($ang)
	$lapiz = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 52, 38, 28)), $grosor
	$lapiz.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
	$lapiz.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
	$lienzo.DrawLine($lapiz, [float]$x0, [float]$y0, [float]($x0 + $dx * $largo), [float]($y0 + $dy * $largo))
	for ($i = 0; $i -le $pasos; $i++) {
		$t = $i / $pasos
		$px = $x0 + $dx * $largo * $t
		$py = $y0 + $dy * $largo * $t
		foreach ($lado in -1, 1) {
			for ($k = 0; $k -lt 2; $k++) {
				$abre = (0.55 + 0.35 * $azar.NextDouble()) * $lado
				$a2 = $ang + $abre
				$l = $ancho * (1 - 0.65 * $t) * (0.7 + 0.5 * $azar.NextDouble())
				$luz = [Math]::Min(1.0, 0.15 + 0.6 * $t + 0.3 * $azar.NextDouble())
				$p = New-Object System.Drawing.Pen (Verde $luz), ([float](2.2 + 1.4 * $azar.NextDouble()))
				$p.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
				$sx = $px + $azar.Next(-2, 3); $sy = $py + $azar.Next(-2, 3)
				$lienzo.DrawLine($p, [float]$sx, [float]$sy, [float]($sx + [Math]::Cos($a2) * $l), [float]($sy + [Math]::Sin($a2) * $l))
				$p.Dispose()
			}
		}
	}
	$lapiz.Dispose()
}

# La rama: un eje de izquierda a derecha, un poco curvo, con ramitas que salen hacia delante y se acortan en la punta.
$y = $TAM / 2
Ramita 10 $y 0 ($TAM - 30) 70 9
for ($i = 0; $i -lt 26; $i++) {
	$t = 0.06 + 0.9 * $i / 26
	$x = 10 + ($TAM - 40) * $t
	$lado = if ($i % 2) { -1 } else { 1 }
	$ang = $lado * (0.6 + 0.25 * $azar.NextDouble())
	$largo = (330 * [Math]::Sin([Math]::PI * [Math]::Min(1.0, $t * 1.25)) + 60) * (0.75 + 0.35 * $azar.NextDouble())
	Ramita $x ($y + $azar.Next(-6, 7)) $ang $largo 52 4
}

$lienzo.Dispose()
$final = New-Object System.Drawing.Bitmap 512, 512, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$lienzo2 = [System.Drawing.Graphics]::FromImage($final)
$lienzo2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$lienzo2.DrawImage($bmp, 0, 0, 512, 512)
$lienzo2.Dispose()
New-Item -ItemType Directory -Force (Split-Path $Salida) | Out-Null
$final.Save($Salida, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Output "Guardada $Salida"
