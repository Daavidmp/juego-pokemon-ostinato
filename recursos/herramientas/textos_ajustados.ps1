# Como textos.ps1, pero para los personajes secundarios del mapa (vecinos,
# entrenadores de ruta): cada frase se escribe con la LETRA MAS GRANDE QUE
# QUEPA en el pergamino, en hasta tres lineas y centrada en alto, para que el
# cuadro no quede con huecos vacios.
#
#   textos_ajustados.ps1 <prefijo> <archivo> <carpeta destino> [tamano]
#
# Con [tamano], todas las frases van a ESA letra (asi todos los personajes
# hablan con letra igual) y avisa con "NO CABE" de las que no entran.
#
# Cada linea del archivo es "lado|texto"; las vacias y las que empiezan por #
# se saltan. Los PNG salen de 684x140: el hueco util del pergamino (704x145)
# menos el sitio de la hojita de "pulsa para seguir", abajo a la derecha.
Add-Type -AssemblyName System.Drawing

$prefijo = $args[0]
$archivo = $args[1]
$DST = $args[2]
$FIJO = if ($args.Count -gt 3) { [int]$args[3] } else { 0 }

$ANCHO = 684; $ALTO = 140
$MAXIMO = 76; $MINIMO = 30; $MAXFILAS = 3
$TINTA = [Drawing.Color]::FromArgb(255, 59, 50, 38)
$formato = [Drawing.StringFormat]::GenericTypographic
$formato.FormatFlags = $formato.FormatFlags -bor [Drawing.StringFormatFlags]::NoWrap
$medidor = New-Object Drawing.Bitmap 4,4
$gm = [Drawing.Graphics]::FromImage($medidor)
$gm.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit

function Fuente($tam) { return New-Object Drawing.Font "Cambria", $tam, ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel) }

function Reparte($texto, $fuente) {
  $filas = @(); $actual = ''
  foreach ($p in ($texto -split ' ')) {
    $prueba = if ($actual -eq '') { $p } else { "$actual $p" }
    if ($gm.MeasureString($prueba, $fuente, 10000, $formato).Width -gt $ANCHO -and $actual -ne '') { $filas += $actual; $actual = $p }
    else { $actual = $prueba }
  }
  if ($actual -ne '') { $filas += $actual }
  return ,$filas
}

$lineas = @()
foreach ($l in [IO.File]::ReadAllLines($archivo, [Text.Encoding]::UTF8)) {
  $t = $l.Trim()
  if ($t -eq '' -or $t.StartsWith('#')) { continue }
  $lineas += ,($t -split '\|', 2)
}

Get-ChildItem "$DST\$prefijo*.png" -ErrorAction SilentlyContinue | Remove-Item -Force
for ($i = 0; $i -lt $lineas.Count; $i++) {
  $texto = $lineas[$i][1]
  # la letra mas grande con la que la frase cabe entera en el hueco
  $tam = if ($FIJO -gt 0) { $FIJO } else { $MAXIMO }
  while ($true) {
    $fuente = Fuente $tam
    $filas = Reparte $texto $fuente
    $inter = [int]($tam * 1.1)
    $cabe = ($filas.Count -le $MAXFILAS) -and ($filas.Count * $inter -le $ALTO)
    foreach ($f in $filas) { if ($gm.MeasureString($f, $fuente, 10000, $formato).Width -gt $ANCHO) { $cabe = $false } }
    if ($cabe -or $tam -le $MINIMO -or $FIJO -gt 0) { break }
    $fuente.Dispose()
    $tam -= 2
  }
  $bmp = New-Object Drawing.Bitmap $ANCHO,$ALTO,([Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $pincel = New-Object Drawing.SolidBrush $TINTA
  # el bloque de texto, centrado en alto; la tinta de Cambria cae un poco por
  # debajo de su caja, asi que se sube un pelo
  $bloque = $filas.Count * $inter
  $y = [int](($ALTO - $bloque) / 2 - $tam * 0.06)
  foreach ($f in $filas) {
    $g.DrawString($f, $fuente, $pincel, (New-Object Drawing.PointF 0,$y), $formato)
    $y += $inter
  }
  $g.Dispose()
  $fuente.Dispose()
  $nombre = "{0}{1:00}.png" -f $prefijo, $i
  $bmp.Save("$DST\$nombre", [Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  $aviso = if ($cabe) { "" } else { "NO CABE  " }
  "{0}{1}  {2} px  {3} linea(s)  {4}" -f $aviso, $nombre, $tam, $filas.Count, $texto
}
