# Genera los PNG de texto de los dialogos a partir del GUION MAESTRO
# (recursos/dialogos_ostinato.txt), frase a frase por su codigo:
#
#   EscTxt05  Arce: Se llama Mudkip...
#
# Asi se pueden quitar o anadir frases sin descolocar el resto: cada imagen
# se llama como su codigo, y las escenas las piden por ese nombre.
#
#   textos_guion.ps1 <guion> <carpeta destino> <prefijo> [<prefijo>...]
#
# Estilos (segun el prefijo):
#   arce   - la escena de la profesora (005): 692x105, Cambria 34, 2 lineas
#   pnj    - lo que dicen los personajes del mapa (020): 684x140, Cambria 42
#            para todos, hasta 3 lineas, centrado en alto
#   escena - el resto (cuadro con retratos, 006/014): 704x108, Cambria 38,
#            2 lineas pegadas arriba (como textos.ps1)
# Si una frase no cabe, sigue en otra pantalla: CODIGOb.png (y c, d...). El
# cuadro de dialogo las enseña seguidas, con el mismo retrato.
Add-Type -AssemblyName System.Drawing

$guion = $args[0]
$destino = $args[1]
$prefijos = $args[2..($args.Count - 1)]

$PNJ = @("VecTxt", "EntTxt", "CasaTxt", "CienTxt", "AdiosPoke", "GenteTxt", "BamVec")
function Estilo($pre) {
  # la obra del teatro (025): subtitulo abajo, centrado, con el nombre en dorado y sombra
  if ($pre -eq "ObraTxt" -or $pre -eq "ObraPub") { return @{ ancho = 1560; alto = 132; tam = 46; inter = 58; y0 = 8; filasMax = 2; centrar = $false; centrarX = $true; nombre = $true; tinta = [Drawing.Color]::FromArgb(255, 250, 242, 222); oro = [Drawing.Color]::FromArgb(255, 240, 196, 92) } }
  if ($pre -eq "EscTxt") { return @{ ancho = 692; alto = 105; tam = 34; inter = 39; y0 = 0; filasMax = 2; centrar = $false; tinta = [Drawing.Color]::FromArgb(255, 34, 26, 20) } }
  if ($PNJ -contains $pre) { return @{ ancho = 684; alto = 140; tam = 42; inter = 46; y0 = -1; filasMax = 3; centrar = $true; tinta = [Drawing.Color]::FromArgb(255, 59, 50, 38) } }
  return @{ ancho = 704; alto = 108; tam = 38; inter = 46; y0 = 13; filasMax = 2; centrar = $false; tinta = [Drawing.Color]::FromArgb(255, 59, 50, 38) }
}

$formato = [Drawing.StringFormat]::GenericTypographic
$formato.FormatFlags = $formato.FormatFlags -bor [Drawing.StringFormatFlags]::NoWrap
$medidor = New-Object Drawing.Bitmap 4,4
$gm = [Drawing.Graphics]::FromImage($medidor)
$gm.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit

function Reparte($texto, $letra, $anchoMax) {
  $res = @(); $actual = ''
  foreach ($p in ($texto -split ' ')) {
    $prueba = if ($actual -eq '') { $p } else { "$actual $p" }
    if ($gm.MeasureString($prueba, $letra, 10000, $formato).Width -gt $anchoMax -and $actual -ne '') { $res += $actual; $actual = $p }
    else { $actual = $prueba }
  }
  if ($actual -ne '') { $res += $actual }
  return ,$res
}

function Pinta($lineas, $est, $salida, $nom = $null) {
  $bmp = New-Object Drawing.Bitmap $est.ancho, $est.alto, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $gr = [Drawing.Graphics]::FromImage($bmp)
  $gr.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $gr.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $pincel = New-Object Drawing.SolidBrush $est.tinta
  $letra = New-Object Drawing.Font "Cambria", $est.tam, ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel)
  if ($est.centrar) { $yy = [int](($est.alto - $lineas.Count * $est.inter) / 2 - $est.tam * 0.06) } else { $yy = $est.y0 }
  $sombra = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(230, 10, 6, 14))
  $primera = $true
  foreach ($l in $lineas) {
    $xx = 0
    if ($est.centrarX) { $xx = [int](($est.ancho - $gm.MeasureString($l, $letra, 10000, $formato).Width) / 2) }
    if ($est.nombre) { foreach ($d in @(@(3, 3), @(2, 0), @(0, 2))) { $gr.DrawString($l, $letra, $sombra, (New-Object Drawing.PointF ($xx + $d[0]), ($yy + $d[1])), $formato) } }
    $cab = if ($nom) { "${nom}:" } else { $null }
    if ($primera -and $cab -and $l.StartsWith($cab)) {
      # el nombre de quien habla en dorado y el resto en crema
      $oro = New-Object Drawing.SolidBrush $est.oro
      $gr.DrawString($cab, $letra, $oro, (New-Object Drawing.PointF $xx, $yy), $formato)
      $resto = $l.Substring($cab.Length)
      $wcab = $gm.MeasureString("$cab" + "x", $letra, 10000, $formato).Width - $gm.MeasureString("x", $letra, 10000, $formato).Width
      $gr.DrawString($resto, $letra, $pincel, (New-Object Drawing.PointF ($xx + $wcab), $yy), $formato)
      $oro.Dispose()
    } else {
      $gr.DrawString($l, $letra, $pincel, (New-Object Drawing.PointF $xx, $yy), $formato)
    }
    $primera = $false
    $yy += $est.inter
  }
  $sombra.Dispose()
  $gr.Dispose(); $letra.Dispose(); $pincel.Dispose()
  $bmp.Save($salida, [Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}

# Si la frase no cabe en una pantalla, se parte en dos donde mejor se lea:
# primero por un final de frase (. ? ! : ;), si no por una coma y si no por
# el espacio mas cercano a la mitad; siempre que la primera parte quepa.
function Partir($texto, $letra, $est) {
  $lin = Reparte $texto $letra $est.ancho
  if ($lin.Count -le $est.filasMax) { return ,@(,$lin) }
  $mitad = $texto.Length / 2
  $cortes = @()
  for ($k = 1; $k -lt $texto.Length - 1; $k++) {
    if ($texto[$k + 1] -ne ' ' -and $texto[$k] -ne ' ') { continue }
    if ('.?!:;'.IndexOf($texto[$k]) -ge 0 -and $texto[$k + 1] -eq ' ') { $cortes += ,@(($k + 1), 0) }
    elseif ($texto[$k] -eq ',' -and $texto[$k + 1] -eq ' ') { $cortes += ,@(($k + 1), 1) }
    elseif ($texto[$k] -eq ' ') { $cortes += ,@($k, 2) }
  }
  $orden = @($cortes | Sort-Object { $_[1] }, { [math]::Abs($_[0] - $mitad) })
  # primero, un corte que deje solo dos pantallas
  foreach ($c in $orden) {
    $a = $texto.Substring(0, $c[0]).Trim()
    $b = $texto.Substring($c[0]).Trim()
    if ($a -eq '' -or $b -eq '') { continue }
    $la = Reparte $a $letra $est.ancho
    $lb = Reparte $b $letra $est.ancho
    if ($la.Count -le $est.filasMax -and $lb.Count -le $est.filasMax) { $dos = @(); $dos += ,$la; $dos += ,$lb; return ,$dos }
  }
  foreach ($c in $orden) {
    $a = $texto.Substring(0, $c[0]).Trim()
    $b = $texto.Substring($c[0]).Trim()
    if ($a -eq '' -or $b -eq '') { continue }
    $la = Reparte $a $letra $est.ancho
    if ($la.Count -gt $est.filasMax) { continue }
    $resto = Partir $b $letra $est
    return ,(@(,$la) + $resto)
  }
  $res = @()
  for ($k = 0; $k -lt $lin.Count; $k += $est.filasMax) { $res += ,@($lin | Select-Object -Skip $k -First $est.filasMax) }
  return ,$res
}

$patron = '^([A-Za-z]+)(\d\d)\s+([^:]+):\s?(.*)$'
foreach ($l in [IO.File]::ReadAllLines($guion, [Text.Encoding]::UTF8)) {
  if ($l -notmatch $patron) { continue }
  $pre = $Matches[1]; $num = $Matches[2]; $nom = $Matches[3].Trim(); $texto = $Matches[4].Trim()
  if ($prefijos -notcontains $pre) { continue }
  $est = Estilo $pre
  if ($est.nombre) { $texto = "${nom}: $texto" } else { $nom = $null }
  $letra = New-Object Drawing.Font "Cambria", $est.tam, ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel)
  $pantallas = Partir $texto $letra $est
  $letra.Dispose()
  $codigo = "$pre$num"
  # las pantallas de continuacion que hubiera de antes, fuera
  foreach ($s in "b", "c", "d") { $v = "$destino\$codigo$s.png"; if (Test-Path $v) { [IO.File]::Delete($v) } }
  $trozos = $pantallas.Count
  for ($t = 0; $t -lt $trozos; $t++) {
    $suf = @("", "b", "c", "d")[$t]
    Pinta $pantallas[$t] $est "$destino\$codigo$suf.png" $(if ($t -eq 0) { $nom } else { $null })
  }
  $nota = if ($trozos -gt 1) { "  ($trozos pantallas: " + (($pantallas | ForEach-Object { $_ -join ' / ' }) -join '  ||  ') + ")" } else { "" }
  "{0}  {1}{2}" -f $codigo, $texto, $nota
}
