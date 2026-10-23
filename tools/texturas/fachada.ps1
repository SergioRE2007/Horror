# Texturas de la fachada (11.6), en PNG de 512 px que se repiten sin costuras: tablas horizontales de madera vieja con
# la pintura desconchada y tejas de pizarra escalonadas. Salen claras y casi grises: el juego las tiñe con
# Texture.Color3.
# Uso: powershell -File tools/texturas/fachada.ps1 <carpeta de salida>
param([string]$salida = ".")
Add-Type -AssemblyName System.Drawing

$N = 512

function Gris([int]$v, [int]$alfa = 255) {
	$v = [Math]::Max(0, [Math]::Min(255, $v))
	return [System.Drawing.Color]::FromArgb($alfa, $v, $v, [Math]::Max(0, $v - 6))
}

# Rectángulo que se repite: si se sale por un borde, se pinta también por el otro.
function Rect($g, $pincel, [double]$x, [double]$y, [double]$w, [double]$h) {
	foreach ($dx in @(-$N, 0, $N)) {
		foreach ($dy in @(-$N, 0, $N)) {
			$g.FillRectangle($pincel, [float]($x + $dx), [float]($y + $dy), [float]$w, [float]$h)
		}
	}
}

function Elipse($g, $pincel, [double]$x, [double]$y, [double]$w, [double]$h) {
	foreach ($dx in @(-$N, 0, $N)) {
		foreach ($dy in @(-$N, 0, $N)) {
			$g.FillEllipse($pincel, [float]($x + $dx), [float]($y + $dy), [float]$w, [float]$h)
		}
	}
}

# Tablas solapadas: 8 por imagen (64 px cada una). Arriba de cada tabla, la sombra de la de encima; abajo, el canto
# claro. Vetas, juntas escalonadas, clavos y la pintura que se cae a trozos.
function Tablas([string]$ruta) {
	$azar = New-Object System.Random 11
	$bmp = New-Object System.Drawing.Bitmap $N, $N
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
	$alto = 64
	for ($t = 0; $t -lt 8; $t++) {
		$y = $t * $alto
		# Cada tabla en trozos con su propio tono; la junta, en un sitio distinto en cada fila.
		$junta = $azar.Next(0, $N)
		foreach ($tramo in @(@(0, $junta), @($junta, ($N - $junta)))) {
			$base = 168 + $azar.Next(-14, 14)
			$p = New-Object System.Drawing.SolidBrush (Gris $base)
			Rect $g $p $tramo[0] $y $tramo[1] $alto
			$p.Dispose()
		}
		# Degradado de la tabla: más oscura arriba (la tapa la de encima) y clara abajo (el canto).
		for ($k = 0; $k -lt 14; $k++) {
			$p = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(150 - $k * 10, 0, 0, 0))
			Rect $g $p 0 ($y + $k) $N 1
			$p.Dispose()
		}
		$p = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(70, 255, 255, 255))
		Rect $g $p 0 ($y + $alto - 6) $N 3
		$p.Dispose()
		$p = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(220, 0, 0, 0))
		Rect $g $p 0 ($y + $alto - 2) $N 2
		$p.Dispose()
		# Junta vertical.
		$p = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(200, 0, 0, 0))
		Rect $g $p $junta $y 2 $alto
		$p.Dispose()
		# Vetas.
		for ($i = 0; $i -lt 26; $i++) {
			$alfa = $azar.Next(20, 60)
			$v = if ($azar.NextDouble() -lt 0.6) { 0 } else { 255 }
			$p = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($alfa, $v, $v, $v))
			Rect $g $p ($azar.Next(0, $N)) ($y + 14 + $azar.Next(0, $alto - 22)) (40 + $azar.Next(0, 220)) 1
			$p.Dispose()
		}
		# Clavos, a los dos lados de la junta.
		$p = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(200, 30, 26, 24))
		foreach ($x in @(($junta - 8), ($junta + 6))) {
			Elipse $g $p $x ($y + $alto - 16) 3 3
		}
		$p.Dispose()
	}
	# Pintura desconchada: manchas claras (la pintura vieja que queda) y, dentro, la madera más oscura.
	for ($i = 0; $i -lt 70; $i++) {
		$x = $azar.Next(0, $N); $y = $azar.Next(0, $N)
		$w = 10 + $azar.Next(0, 60); $h = 3 + $azar.Next(0, 12)
		$p = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($azar.Next(25, 70), 235, 232, 222))
		Elipse $g $p $x $y $w $h
		$p.Dispose()
		if ($azar.NextDouble() -lt 0.5) {
			$p = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($azar.Next(40, 90), 40, 30, 22))
			Elipse $g $p ($x + $w * 0.2) ($y + $h * 0.2) ($w * 0.5) ($h * 0.5)
			$p.Dispose()
		}
	}
	# Churretes de humedad que bajan.
	for ($i = 0; $i -lt 10; $i++) {
		$x = $azar.Next(0, $N); $y0 = $azar.Next(0, $N)
		$largo = 60 + $azar.Next(0, 200)
		for ($k = 0; $k -lt $largo; $k += 2) {
			$p = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb([int](40 * (1 - $k / $largo)), 20, 18, 12))
			Rect $g $p ($x + [Math]::Sin($k / 17) * 2) ($y0 + $k) 5 2
			$p.Dispose()
		}
	}
	$g.Dispose()
	$bmp.Save($ruta, [System.Drawing.Imaging.ImageFormat]::Png)
	$bmp.Dispose()
}

# Tejas de pizarra: 8 filas, cada fila corrida media teja. Cada teja con su tono, el borde de abajo redondeado y
# oscuro; alguna rota o que falta (hueco negro).
function Tejas([string]$ruta) {
	$azar = New-Object System.Random 23
	$bmp = New-Object System.Drawing.Bitmap $N, $N
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
	$p = New-Object System.Drawing.SolidBrush (Gris 40)
	$g.FillRectangle($p, 0, 0, $N, $N)
	$p.Dispose()
	$alto, $ancho = 64, 64
	for ($f = 0; $f -lt 8; $f++) {
		$y = $f * $alto
		$corrido = if ($f % 2 -eq 0) { 0 } else { $ancho / 2 }
		for ($c = 0; $c -lt 8; $c++) {
			$x = $c * $ancho + $corrido
			$falta = $azar.NextDouble() -lt 0.04
			if ($falta) { continue }
			$tono = 150 + $azar.Next(-28, 28)
			# Cada teja, de un largo un poco distinto: el borde de abajo no sale recto.
			$p = New-Object System.Drawing.SolidBrush (Gris $tono)
			Rect $g $p ($x + 1) ($y - 6) ($ancho - 3) ($alto - 4 + $azar.Next(-5, 3))
			$p.Dispose()
			# Sombra de la fila de encima y canto de abajo oscuro.
			for ($k = 0; $k -lt 12; $k++) {
				$p = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(130 - $k * 10, 0, 0, 0))
				Rect $g $p ($x + 1) ($y + $k) ($ancho - 3) 1
				$p.Dispose()
			}
			$p = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(60, 255, 255, 255))
			Rect $g $p ($x + 2) ($y + $alto - 14) ($ancho - 5) 2
			$p.Dispose()
			# Manchas de liquen y desgaste.
			for ($i = 0; $i -lt 4; $i++) {
				$v = if ($azar.NextDouble() -lt 0.5) { 0 } else { 255 }
				$p = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($azar.Next(15, 45), $v, $v, $v))
				Elipse $g $p ($x + $azar.Next(2, $ancho - 18)) ($y + $azar.Next(8, $alto - 20)) ($azar.Next(6, 18)) ($azar.Next(4, 10))
				$p.Dispose()
			}
			# Teja rota: una raja en diagonal.
			if ($azar.NextDouble() -lt 0.08) {
				$lapiz = New-Object System.Drawing.Pen ((Gris 30), 2)
				$g.DrawLine($lapiz, [float]($x + 10), [float]($y + 10), [float]($x + 40), [float]($y + $alto - 14))
				$lapiz.Dispose()
			}
		}
	}
	$g.Dispose()
	$bmp.Save($ruta, [System.Drawing.Imaging.ImageFormat]::Png)
	$bmp.Dispose()
}

New-Item -ItemType Directory -Force $salida | Out-Null
Tablas (Join-Path $salida "tablas.png")
Tejas (Join-Path $salida "tejas.png")
