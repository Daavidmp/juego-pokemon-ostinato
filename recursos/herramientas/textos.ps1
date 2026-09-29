# Dibuja los PNG de texto del cuadro de dialogo a partir de un archivo de
# texto en UTF-8, una frase por linea. Asi los acentos viven en el archivo y
# no hay que escribirlos con codigos dentro del .ps1, que PowerShell 5.1 lee
# como ANSI y los destroza.
#
#   textos.ps1 <prefijo> <archivo>
#
# Cada linea del archivo es "lado|texto". El lado no se usa para dibujar,
# esta ahi para que el guion se lea de corrido y para poder sacarlo luego.
# Las lineas vacias y las que empiezan por # se saltan.
Add-Type -AssemblyName System.Drawing

$DST = $args[2]
$prefijo = $args[0]
$archivo = $args[1]

# El cuerpo baja de 42 a 38 para que el nombre pueda ir mas abajo y las dos
# lineas sigan cabiendo en el papel del recuadro, que son 162 px.
$ANCHO = 704; $ALTO = 108; $CUERPO = 38; $INTERLINEA = 46
$TINTA = [Drawing.Color]::FromArgb(255, 59, 50, 38)
$fuente = New-Object Drawing.Font "Cambria", $CUERPO, ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel)
$formato = [Drawing.StringFormat]::GenericTypographic
$formato.FormatFlags = $formato.FormatFlags -bor [Drawing.StringFormatFlags]::NoWrap
$medidor = New-Object Drawing.Bitmap 4,4
$gm = [Drawing.Graphics]::FromImage($medidor)
$gm.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit

function Reparte($texto) {
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
$largas = 0
for ($i = 0; $i -lt $lineas.Count; $i++) {
  $lado = $lineas[$i][0]
  $texto = $lineas[$i][1]
  $filas = Reparte $texto
  if ($filas.Count -gt 2) { $largas++ }
  $bmp = New-Object Drawing.Bitmap $ANCHO,$ALTO,([Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $pincel = New-Object Drawing.SolidBrush $TINTA
  # El texto va pegado arriba, NO centrado: si se centra, una frase de dos
  # lineas empieza 25 px mas arriba que una de una y se le mete debajo al
  # nombre. Asi las dos empiezan a la misma altura, como en el laboratorio.
  $y = 13
  foreach ($f in $filas) {
    $g.DrawString($f, $fuente, $pincel, (New-Object Drawing.PointF 0,$y), $formato)
    $y += $INTERLINEA
  }
  $g.Dispose()
  $nombre = "{0}{1:00}.png" -f $prefijo, $i
  $bmp.Save("$DST\$nombre", [Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  "{0}  {1,-3} {2} linea(s)  {3}" -f $nombre, $lado, $filas.Count, $texto
}
"--- {0} PNG, {1} con mas de dos lineas" -f $lineas.Count, $largas
