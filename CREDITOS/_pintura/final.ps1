param([double]$glow = 44, [double]$haze = 9, [double]$vig = 62, [switch]$keep)
$wd = "C:\Users\ASUS\Music\CREDITOS\_pintura"
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
& $csc /nologo /target:library /platform:x64 /out:"$wd\kra.dll" /r:System.Drawing.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll "$wd\kra.cs" "$wd\tools.cs" "$wd\analyze.cs" "$wd\grid.cs" "$wd\probe.cs" "$wd\idmap.cs" "$wd\close.cs" "$wd\paint.cs" "$wd\telon.cs" "$wd\telonrun.cs" "$wd\idcur.cs" "$wd\diff.cs" "$wd\luz.cs"
if (-not $?) { exit 1 }
Add-Type -Path "$wd\kra.dll" -ReferencedAssemblies System.Drawing,System.IO.Compression,System.IO.Compression.FileSystem

# 1) parches de papel -> capa nueva sobre "Color letras"
[KraLib.Paint]::Run("$wd\cur2.zip","$wd\papel.cfg",$wd,"$wd\k_papel.kra") | Out-Null

# 2) capa de luz, por encima de todo el color y por debajo del lineart
$luz = [KraLib.Luz]::Build($glow,$haze,$vig)
$luz.Save("$wd\luz.png")
[KraLib.Luz]::Write("$wd\k_papel.kra","$wd\k_final.kra",$luz,"layer9","Luz")

# 3) vista previa completa (de abajo arriba)
$orden = @("layer8","layer7","layer6","layer9","layer5","layer4","layer3","layer2")
$prev = [KraLib.Luz]::Preview("$wd\k_final.kra",$luz,$orden,"layer9")
$prev.Save("$wd\final_preview.png")
$ff = "C:\Program Files\Krita (x64)\bin\ffmpeg.exe"
& $ff -y -loglevel error -i "$wd\final_preview.png" -vf "scale=1500:-1" -frames:v 1 "$wd\f_v.png"
& $ff -y -loglevel error -i "$wd\final_preview.png" -vf "crop=900:520:1000:380,scale=1400:-1" -frames:v 1 "$wd\f_letras.png"
Write-Output "render ok"
