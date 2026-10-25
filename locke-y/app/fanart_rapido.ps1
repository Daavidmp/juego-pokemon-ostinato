# Ayuda para ir poniendo fanarts a mano, uno por Pokémon, sin buscar carpetas:
#   clic derecho > Ejecutar con PowerShell   (o: powershell -File app\fanart_rapido.ps1)
# Va por los Pokémon de fanart_faltan\ (los que te pueden salir y no tienen dibujo; se rehace con
# app\fanart_faltan.ps1). Para cada uno abre la búsqueda en Pinterest; tú eliges y descargas un dibujo, y
# en cuanto aparece en Descargas se mueve a la carpeta de ese Pokémon y se pasa al siguiente.
#   S = saltar este Pokémon · Q = terminar
param([string]$Descargas = (Join-Path $env:USERPROFILE "Downloads"))
$L = Split-Path -Parent $PSScriptRoot
$faltan = Get-ChildItem "$L\fanart_faltan" -Directory | Sort-Object Name
$exts = '.png', '.jpg', '.jpeg', '.webp'
function Imagenes { Get-ChildItem $Descargas -File | ? { $exts -contains $_.Extension.ToLower() } | % FullName }

$hechos = 0
foreach ($c in $faltan) {
  if (Get-ChildItem $c.FullName -File | ? { $exts -contains $_.Extension.ToLower() }) { continue }   # ya tiene
  $nombre = $c.Name -replace '^\d+\s+', ''
  $q = [uri]::EscapeDataString("$nombre pokemon fanart")
  Start-Process "https://www.pinterest.com/search/pins/?q=$q"
  Write-Host ""
  Write-Host ("[{0}] {1}: descarga un dibujo  (S saltar, Q terminar)" -f ($hechos + 1), $c.Name) -ForegroundColor Cyan
  $antes = @(Imagenes)
  while ($true) {
    if ([Console]::KeyAvailable) {
      $k = [Console]::ReadKey($true).Key
      if ($k -eq 'Q') { Write-Host "Terminado: $hechos puestos."; exit }
      if ($k -eq 'S') { Write-Host "  saltado"; break }
    }
    $nuevo = @(Imagenes) | ? { $antes -notcontains $_ } | Select -First 1
    if ($nuevo) {
      Start-Sleep -Milliseconds 800                     # que el navegador acabe de escribirlo
      try {
        Move-Item -LiteralPath $nuevo -Destination $c.FullName -ErrorAction Stop
        Write-Host ("  puesto: {0}" -f (Split-Path $nuevo -Leaf)) -ForegroundColor Green
        $hechos++; break
      } catch { Start-Sleep -Milliseconds 500 }       # aún se está descargando
    }
    Start-Sleep -Milliseconds 300
  }
}
Write-Host "No quedan Pokémon sin fan art. Puestos: $hechos"
