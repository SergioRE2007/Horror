# Dibuja manchas de sangre (blancas sobre transparente: el juego las tiñe con Decal.Color3) en PNG de 512 px.
# Uso: powershell -File tools/texturas/sangre.ps1 <carpeta de salida>
param([string]$salida = ".")
Add-Type -AssemblyName System.Drawing

function Mancha([int]$semilla, [string]$ruta, [int]$gotas, [int]$chorros) {
	$azar = New-Object System.Random $semilla
	$bmp = New-Object System.Drawing.Bitmap 512, 512
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
	$g.Clear([System.Drawing.Color]::Transparent)
	# Charco central: muchas elipses solapadas, más opacas en el centro.
	for ($i = 0; $i -lt 40; $i++) {
		$r = 30 + $azar.NextDouble() * 70
		$ang = $azar.NextDouble() * [Math]::PI * 2
		$d = $azar.NextDouble() * 70
		$x = 256 + [Math]::Cos($ang) * $d - $r
		$y = 256 + [Math]::Sin($ang) * $d - $r
		$alfa = 120 + $azar.Next(0, 110)
		$pincel = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($alfa, 255, 255, 255))
		$g.FillEllipse($pincel, [float]$x, [float]$y, [float]($r * 2), [float]($r * (1.4 + $azar.NextDouble() * 0.6)))
		$pincel.Dispose()
	}
	# Gotas alrededor, más pequeñas cuanto más lejos.
	for ($i = 0; $i -lt $gotas; $i++) {
		$ang = $azar.NextDouble() * [Math]::PI * 2
		$d = 110 + $azar.NextDouble() * 130
		$r = [Math]::Max(2, 18 - $d / 16 + $azar.NextDouble() * 6)
		$x = 256 + [Math]::Cos($ang) * $d
		$y = 256 + [Math]::Sin($ang) * $d
		$pincel = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(230, 255, 255, 255))
		$g.FillEllipse($pincel, [float]($x - $r), [float]($y - $r), [float]($r * 2), [float]($r * 2))
		$pincel.Dispose()
	}
	# Chorros que caen hacia abajo (para las paredes).
	for ($i = 0; $i -lt $chorros; $i++) {
		$x = 180 + $azar.NextDouble() * 150
		$ancho = 6 + $azar.NextDouble() * 10
		$largo = 80 + $azar.NextDouble() * 160
		$pincel = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(220, 255, 255, 255))
		$g.FillRectangle($pincel, [float]($x - $ancho / 2), [float]256, [float]$ancho, [float]$largo)
		$g.FillEllipse($pincel, [float]($x - $ancho * 0.8), [float](256 + $largo - $ancho), [float]($ancho * 1.6), [float]($ancho * 1.8))
		$pincel.Dispose()
	}
	$g.Dispose()
	$bmp.Save($ruta, [System.Drawing.Imaging.ImageFormat]::Png)
	$bmp.Dispose()
}

Mancha 1 (Join-Path $salida "sangre1.png") 40 0
Mancha 2 (Join-Path $salida "sangre2.png") 25 4
Mancha 3 (Join-Path $salida "sangre3.png") 60 0
