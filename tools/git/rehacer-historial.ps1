# Rehace main: cada commit aplastado de una PR (#N) pasa a ser un merge de verdad de su rama (refs/remotes/origin/pr/N),
# con los commits de la rama reescritos encima de los nuevos. Los árboles (el código) no cambian ni una letra.
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
$OutputEncoding = New-Object Text.UTF8Encoding $false
$extra = @{ "7c432e2" = "fdc5981"; "664429b" = "f206e22" } # ramas locales aplastadas sin PR

$mapa = @{}
$tmp = Join-Path $env:TEMP "msg-rehacer.txt"

function Lleno([string]$c) { (git rev-parse $c).Trim() }

$cabezas = @{}
foreach ($k in $extra.Keys) { $cabezas[(Lleno $k)] = (Lleno $extra[$k]) }
$primeros = git rev-list --first-parent main
foreach ($c in $primeros) {
	$msg = git log -1 --format=%s $c
	if ($msg -match '\(#(\d+)\)\s*$') {
		$ref = "refs/remotes/origin/pr/$($Matches[1])"
		$h = git rev-parse -q --verify $ref 2>$null
		if ($h) { $cabezas[$c] = $h.Trim() }
	}
}
$enMain = @{}
foreach ($c in $primeros) { $enMain[$c] = $true }

function Crear([string]$c, [string[]]$padres) {
	$meta = git log -1 --format="%an|~|%ae|~|%aI|~|%cn|~|%ce|~|%cI" $c
	$p = $meta -split "\|~\|"
	$env:GIT_AUTHOR_NAME = $p[0]; $env:GIT_AUTHOR_EMAIL = $p[1]; $env:GIT_AUTHOR_DATE = $p[2]
	$env:GIT_COMMITTER_NAME = $p[3]; $env:GIT_COMMITTER_EMAIL = $p[4]; $env:GIT_COMMITTER_DATE = $p[5]
	$cuerpo = git log -1 --format=%B $c
	[IO.File]::WriteAllText($tmp, (($cuerpo -join "`n").TrimEnd() + "`n"), (New-Object Text.UTF8Encoding $false))
	$args2 = @("commit-tree", "$c^{tree}")
	foreach ($q in $padres) { $args2 += @("-p", $q) }
	$args2 += @("-F", $tmp)
	return (& git @args2).Trim()
}

# Sin recursión por commit (PowerShell se queda sin profundidad): se recorre todo lo alcanzable desde
# $objetivo con los padres antes que los hijos. Solo se anida al saltar a la rama de una PR (pocas veces).
function MapearTodo([string]$objetivo) {
	$lineas = git rev-list --topo-order --reverse --parents $objetivo
	foreach ($l in $lineas) {
		$partes = @($l.Trim() -split ' ')
		$c = $partes[0]
		if ($mapa.ContainsKey($c)) { continue }
		$padres = @($partes | Select-Object -Skip 1)
		$nuevos = @()
		foreach ($q in $padres) { $nuevos += $mapa[$q] }
		if ($cabezas.ContainsKey($c) -and $padres.Count -eq 1) {
			$h = $cabezas[$c]
			& git merge-base --is-ancestor $h $padres[0]
			$yaDentro = $LASTEXITCODE -eq 0
			# Rama que se siguió usando tras juntarla (la #9): ya contiene este commit; se queda aplastado.
			& git merge-base --is-ancestor $c $h
			if ($LASTEXITCODE -eq 0) { $yaDentro = $true }
			if (-not $yaDentro) {
				if (-not $mapa.ContainsKey($h)) { MapearTodo $h }
				$nuevos += $mapa[$h]
			}
		}
		$mapa[$c] = Crear $c $nuevos
	}
}

MapearTodo (Lleno "main")
$nuevaPunta = $mapa[(Lleno "main")]
git update-ref refs/heads/historial-completo $nuevaPunta
"punta nueva: $nuevaPunta"
"arbol viejo: " + (git rev-parse "main^{tree}")
"arbol nuevo: " + (git rev-parse "$nuevaPunta^{tree}")
"commits main viejo: " + (git rev-list --count main)
"commits main nuevo: " + (git rev-list --count $nuevaPunta)
