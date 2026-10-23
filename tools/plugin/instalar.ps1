# Copia el plugin VistaMapa a la carpeta de plugins de Studio (Studio lo carga solo; si no, reiniciar Studio).
Copy-Item -Force (Join-Path $PSScriptRoot "VistaMapa.lua") (Join-Path $env:LOCALAPPDATA "Roblox\Plugins\VistaMapa.lua")
