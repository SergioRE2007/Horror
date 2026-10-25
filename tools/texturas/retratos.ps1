# Fotos de familia en sepia con las caras rayadas (pasillo, 11.8.5), para la foto del marco ovalado de Poly Haven
# (CuadroFamiliaPH_2). Las figuras van en el centro: el óvalo del marco solo enseña el medio de la imagen.
# Uso: powershell -File tools/texturas/retratos.ps1  ->  modelos\polyhaven\CuadroFamiliaPH\Retrato1..3_color.png
Add-Type -AssemblyName System.Drawing
$salida = Join-Path $PSScriptRoot "..\..\..\modelos\polyhaven\CuadroFamiliaPH"
$azar = New-Object System.Random 7
$N = 1024

function Color($r, $g, $b, $a = 255) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }

# Una persona: cuerpo oscuro, cara clara con pelo y la cara rayada con algo punzante.
function Persona($g, $cx, $cy, $t, $ropa, $velo) {
	$cuerpo = New-Object System.Drawing.SolidBrush $ropa
	$falda = if ($velo) { 1.9 } else { 1.3 } # el vestido de novia, con vuelo
	$puntos = @(@(-0.28, 0.45), @(0.28, 0.45), @(0.85, 0.8), @(1.2, 1.3), @($falda, 4.6), @(-$falda, 4.6), @(-1.2, 1.3), @(-0.85, 0.8)) |
		ForEach-Object { New-Object System.Drawing.PointF ([float]($cx + $_[0] * $t)), ([float]($cy + $_[1] * $t)) }
	$g.FillClosedCurve($cuerpo, [System.Drawing.PointF[]]$puntos, "Alternate", 0.25)
	if (-not $velo) { # cuello blanco de la camisa
		$cuello = @(@(-0.3, 0.5), @(0.3, 0.5), @(0, 1.1)) | ForEach-Object { New-Object System.Drawing.PointF ([float]($cx + $_[0] * $t)), ([float]($cy + $_[1] * $t)) }
		$g.FillPolygon((New-Object System.Drawing.SolidBrush (Color 200 186 156)), [System.Drawing.PointF[]]$cuello)
	}
	$pelo = New-Object System.Drawing.SolidBrush (Color 52 38 26)
	if ($velo) {
		$g.FillEllipse((New-Object System.Drawing.SolidBrush (Color 214 200 170 200)), $cx - 1.0 * $t, $cy - 0.75 * $t, 2.0 * $t, 3.2 * $t)
	}
	$g.FillEllipse($pelo, $cx - 0.6 * $t, $cy - 0.8 * $t, 1.2 * $t, 1.3 * $t)
	$g.FillEllipse((New-Object System.Drawing.SolidBrush (Color 190 164 124)), $cx - 0.5 * $t, $cy - 0.6 * $t, 1.0 * $t, 1.25 * $t)
	for ($k = 0; $k -lt 45; $k++) {
		$c = if ($azar.NextDouble() -lt 0.6) { Color 236 226 204 220 } else { Color 30 22 16 200 }
		$lapiz = New-Object System.Drawing.Pen $c, (1.5 + 3 * $azar.NextDouble())
		$x0 = $cx + ($azar.NextDouble() - 0.5) * 1.1 * $t; $y0 = $cy - 0.6 * $t + $azar.NextDouble() * 1.3 * $t
		$x1 = $x0 + ($azar.NextDouble() - 0.5) * 1.2 * $t; $y1 = $y0 + ($azar.NextDouble() - 0.5) * 0.9 * $t
		$g.DrawLine($lapiz, [float]$x0, [float]$y0, [float]$x1, [float]$y1)
	}
}

# { nombre, figuras: x, y, tamaño, ropa (r, g, b), velo }
$fotos = @(
	@("Retrato1", @(@(420, 470, 95, @(40, 30, 22), $false), @(610, 490, 88, @(205, 190, 160), $true))), # boda
	@("Retrato2", @(@(380, 400, 85, @(38, 28, 20), $false), @(620, 420, 80, @(70, 52, 38), $false),
		@(440, 610, 60, @(90, 70, 50), $false), @(570, 625, 55, @(120, 96, 70), $false))), # padres y dos niños
	@("Retrato3", @(, @(512, 450, 120, @(60, 46, 34), $false))) # una niña sola (la coma: lista de una figura)
)
foreach ($foto in $fotos) {
	$img = New-Object System.Drawing.Bitmap $N, $N
	$g = [System.Drawing.Graphics]::FromImage($img)
	$g.SmoothingMode = "AntiAlias"
	$fondo = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 0), (New-Object System.Drawing.Point 0, $N), (Color 168 140 100), (Color 112 88 60)
	$g.FillRectangle($fondo, 0, 0, $N, $N)
	# Telón de estudio detrás, algo más oscuro, y el suelo.
	$g.FillRectangle((New-Object System.Drawing.SolidBrush (Color 120 96 68 120)), 0, 0, $N, 760)
	foreach ($p in $foto[1]) { Persona $g $p[0] $p[1] $p[2] (Color $p[3][0] $p[3][1] $p[3][2]) $p[4] }
	# Grano, manchas de humedad y un pliegue.
	for ($k = 0; $k -lt 30000; $k++) {
		$v = $azar.Next(0, 2) * 200
		$img.SetPixel($azar.Next(0, $N), $azar.Next(0, $N), (Color $v ($v * 0.9) ($v * 0.75)))
	}
	for ($k = 0; $k -lt 8; $k++) {
		$r = 40 + $azar.Next(0, 120)
		$g.FillEllipse((New-Object System.Drawing.SolidBrush (Color 80 58 34 50)), $azar.Next(0, $N), $azar.Next(0, $N), $r, $r * 0.7)
	}
	$g.DrawLine((New-Object System.Drawing.Pen (Color 225 210 180 120), 3), 150, $azar.Next(200, 800), 870, $azar.Next(200, 800))
	# Viñeta: los bordes, oscuros.
	$camino = New-Object System.Drawing.Drawing2D.GraphicsPath
	$camino.AddEllipse(-0.35 * $N, -0.35 * $N, 1.7 * $N, 1.7 * $N) # más grande que la imagen: tapa también las esquinas
	$vineta = New-Object System.Drawing.Drawing2D.PathGradientBrush $camino
	$vineta.CenterColor = Color 0 0 0 0
	$vineta.SurroundColors = @(Color 20 12 6 255)
	$g.FillRectangle($vineta, 0, 0, $N, $N)
	$img.Save((Join-Path $salida "$($foto[0])_color.png"), [System.Drawing.Imaging.ImageFormat]::Png)
	$g.Dispose(); $img.Dispose()
	"HECHA $($foto[0])"
}
