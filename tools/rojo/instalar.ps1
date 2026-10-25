# Deja Rojo sirviendo juego.project.json siempre, fuera de las conversaciones con Claude (pedido por el usuario: que
# Studio no se desconecte cada vez). Tarea de Windows "Rojo Horror": arranca al iniciar sesión, sin ventana, sin
# límite de tiempo y se reinicia sola si se cae. Claude no la reinicia: solo comprueba http://localhost:34872/api/rojo.
# Uso: powershell -ExecutionPolicy Bypass -File tools\rojo\instalar.ps1   (y para arrancarla ya: Start-ScheduledTask "Rojo Horror")
$proyecto = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$rojo = Join-Path $env:USERPROFILE ".rokit\bin\rojo.exe"
$accion = New-ScheduledTaskAction -Execute "conhost.exe" -Argument "--headless `"$rojo`" serve juego.project.json" -WorkingDirectory $proyecto
$inicio = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$ajustes = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 99 -RestartInterval (New-TimeSpan -Minutes 1) `
	-AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName "Rojo Horror" -Action $accion -Trigger $inicio -Settings $ajustes -Force | Out-Null
Write-Output "Tarea 'Rojo Horror' instalada (arranca al iniciar sesión)."
