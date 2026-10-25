# Carpeta fanart_faltan\ con los Pokémon que pueden salir en una partida randomizada y aún no tienen fanart.
#   fanart_faltan.ps1 [-Juego <id de datos\juegos>]
# Los Pokémon salen del registro de la randomización (iniciales, fijos, salvajes y los que te dan en
# intercambios) más sus evoluciones (de PokéAPI, guardadas en tools\evoluciones.json). Cada carpeta de
# fanart_faltan es un acceso (junction) a la de fanart\: lo que se pega ahí es lo que usa la app.
param([string]$Juego = "")
$ErrorActionPreference = "Stop"
$L = Split-Path -Parent $PSScriptRoot; $F = "$L\fanart"; $FF = "$L\fanart_faltan"
if (-not $Juego) { $Juego = (Get-ChildItem "$L\datos\juegos" -Directory | ? { Test-Path "$($_.FullName)\randomizacion.log" } | Sort LastWriteTime -Desc | Select -First 1).Name }
$log = Get-Content "$L\datos\juegos\$Juego\randomizacion.log" -Encoding utf8

# nombre -> número, de la tabla de estadísticas del propio registro
$num = @{}
foreach ($linea in $log) { if ($linea -match '^\s*(\d+)\|([^|]+)\|') { $n = [int]$matches[1]; if ($n -le 721) { $num[$matches[2].Trim().ToLower()] = $n } } }
$sale = New-Object 'System.Collections.Generic.HashSet[int]'
# el apóstrofo tipográfico de Farfetch’d se cambia por el normal
function Poner($nombre) { $k = $nombre.Trim().ToLower() -replace [string][char]0x2019, "'"; if ($num.ContainsKey($k)) { [void]$sale.Add($num[$k]) } }
$seccion = ''
foreach ($linea in $log) {
  if ($linea -match '^--(.+)--$') { $seccion = $matches[1]; continue }
  switch -Regex ($seccion) {
    'Starters' { if ($linea -match '^Set starter \d+ to (.+)$') { Poner $matches[1] } }
    'Static'   { if ($linea -match '=>\s*(.+)$') { Poner $matches[1] } }
    'Wild'     { if ($linea -match '^(\S.*?)\s+Lv\d') { Poner $matches[1] } }
    'Trades'   { if ($linea -match '->\s+\S.*\s+the\s+(\S+)\s*$') { Poner $matches[1] } }
  }
}
"Pokémon que se pueden conseguir: $($sale.Count)"

# evoluciones: cadenas de PokéAPI, una vez
$cache = "$L\tools\evoluciones.json"
if (-not (Test-Path $cache)) {
  [Net.ServicePointManager]::SecurityProtocol = 'Tls12'; $cadenas = @()
  $lista = Invoke-RestMethod "https://pokeapi.co/api/v2/evolution-chain?limit=600" -UseBasicParsing
  foreach ($c in $lista.results) {
    $d = Invoke-RestMethod $c.url -UseBasicParsing; $todos = @()
    $pila = @($d.chain); while ($pila.Count) { $x = $pila[0]; $pila = @($pila | Select -Skip 1)
      $todos += [int]($x.species.url -replace '.*/(\d+)/$', '$1'); $pila += @($x.evolves_to) }
    $cadenas += ,@($todos | ? { $_ -le 721 })
  }
  [IO.File]::WriteAllText($cache, (ConvertTo-Json @($cadenas) -Depth 4 -Compress))
}
$cadenas = Get-Content $cache -Raw | ConvertFrom-Json
# cada uno con los que vienen después de él en su cadena (una cadena de PokéAPI va de la base a las últimas)
$antes = $sale.Count
foreach ($c in $cadenas) { $c = @($c); for ($i = 0; $i -lt $c.Count; $i++) { if ($sale.Contains([int]$c[$i])) { for ($k = $i + 1; $k -lt $c.Count; $k++) { [void]$sale.Add([int]$c[$k]) } } } }
"Con sus evoluciones: $($sale.Count) (+$($sale.Count - $antes))"

# los que no tienen imagen en su carpeta de fanart
if (Test-Path $FF) { Get-ChildItem $FF -Directory | % { cmd /c rmdir "$($_.FullName)" } }
New-Item -ItemType Directory $FF -Force | Out-Null
$faltan = 0
foreach ($n in ($sale | Sort-Object)) {
  $c = Get-ChildItem $F -Directory | ? { $_.Name -match ('^0*' + $n + ' ') } | Select -First 1
  if (-not $c) { continue }
  if (Get-ChildItem $c.FullName -File | ? { $_.Extension -match '^\.(png|jpe?g|webp)$' }) { continue }
  New-Item -ItemType Junction -Path "$FF\$($c.Name)" -Target $c.FullName | Out-Null; $faltan++
}
Set-Content "$FF\LEEME.txt" @("Pokemon que te pueden salir en esta partida y aun no tienen fan art ($faltan).",
  "Cada carpeta es un acceso a la de fanart\: pega aqui el dibujo y la app lo usa.",
  "Para rehacer la lista (al pegar mas, o con otra randomizacion): app\fanart_faltan.ps1") -Encoding utf8
"Sin fan art: $faltan"
