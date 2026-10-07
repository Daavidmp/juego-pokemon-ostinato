$wd = "C:\Users\ASUS\Music\CREDITOS\_pintura"
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
& $csc /nologo /target:library /platform:x64 /out:"$wd\kra.dll" /r:System.Drawing.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll "$wd\kra.cs" "$wd\tools.cs" "$wd\analyze.cs" "$wd\grid.cs" "$wd\probe.cs" "$wd\idmap.cs" "$wd\close.cs" "$wd\paint.cs" "$wd\telon.cs" "$wd\telonrun.cs" "$wd\idcur.cs" "$wd\diff.cs" "$wd\luz.cs" "$wd\oscurecer.cs" "$wd\cinta.cs"
if (-not $?) { exit 1 }
Add-Type -Path "$wd\kra.dll" -ReferencedAssemblies System.Drawing,System.IO.Compression,System.IO.Compression.FileSystem

# recorrido de la cinta trazado a mano sobre la imagen, de la punta izquierda
# hasta donde se esconde tras las letras por arriba
$xs = @(300,268,272,320,420,536,652,768,884,1000,1085,1155,1255,1355,1455,1555,1655,1755,1854,1954,2050,2130,2192,2222,2224,2196,2140,2060,1962,1866,1768,1678,1596,1530,1490,1465)
$ys = @(745,812,868,912,948,958,944,914,874, 828, 786, 742, 684, 646, 624, 618, 628, 644, 658, 658, 640, 600, 545, 480, 415, 358, 308, 272, 250, 247, 262, 294, 338, 394, 452, 513)

$mask = [KraLib.Cinta]::MaskOf("$wd\mask_cinta.png","$wd\notas.png",5)
$path = [KraLib.Cinta]::FromPolyline($mask,[double[]]$xs,[double[]]$ys,4,95)
"puntos=$($path.Count)  longitud=$([math]::Round($path[$path.Count-1].S))"
$hw = ($path | ForEach-Object { $_.HW })
"ancho medio=$([math]::Round((($hw | Measure-Object -Average).Average),1))  min=$([math]::Round((($hw | Measure-Object -Minimum).Minimum),1))  max=$([math]::Round((($hw | Measure-Object -Maximum).Maximum),1))"
[KraLib.Cinta]::Draw($path,"$wd\osc_preview.png","$wd\path_dbg.png")
$ff = "C:\Program Files\Krita (x64)\bin\ffmpeg.exe"
& $ff -y -loglevel error -i "$wd\path_dbg.png" -vf "scale=1500:-1" -frames:v 1 "$wd\path_v.png"
Write-Output "ok"
