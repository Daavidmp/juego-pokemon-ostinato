param([double]$red = 0.55, [double]$gold = 0.26, [string]$kra = "")
$wd = "C:\Users\ASUS\Music\CREDITOS\_pintura"
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
& $csc /nologo /target:library /platform:x64 /out:"$wd\kra.dll" /r:System.Drawing.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll "$wd\kra.cs" "$wd\tools.cs" "$wd\analyze.cs" "$wd\grid.cs" "$wd\probe.cs" "$wd\idmap.cs" "$wd\close.cs" "$wd\paint.cs" "$wd\telon.cs" "$wd\telonrun.cs"
if (-not $?) { exit 1 }
Add-Type -Path "$wd\kra.dll" -ReferencedAssemblies System.Drawing,System.IO.Compression,System.IO.Compression.FileSystem
[KraLib.TelonRun]::Run("$wd\cur.zip","layer6",$wd,$kra,$red,$gold)
$ff = "C:\Program Files\Krita (x64)\bin\ffmpeg.exe"
& $ff -y -loglevel error -i "$wd\telon_preview.png" -vf "crop=470:1200:0:0,scale=-1:1250" -frames:v 1 "$wd\t_L.png"
& $ff -y -loglevel error -i "$wd\telon_preview.png" -vf "scale=1500:-1" -frames:v 1 "$wd\t_full.png"
Write-Output "render ok"
