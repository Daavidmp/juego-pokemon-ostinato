param([double]$sx=500,[double]$sy=920,[double]$dx=1,[double]$dy=-0.10,[double]$step=5,[double]$maxHalf=95)
$wd = "C:\Users\ASUS\Music\CREDITOS\_pintura"
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
& $csc /nologo /target:library /platform:x64 /out:"$wd\kra.dll" /r:System.Drawing.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll "$wd\kra.cs" "$wd\tools.cs" "$wd\analyze.cs" "$wd\grid.cs" "$wd\probe.cs" "$wd\idmap.cs" "$wd\close.cs" "$wd\paint.cs" "$wd\telon.cs" "$wd\telonrun.cs" "$wd\idcur.cs" "$wd\diff.cs" "$wd\luz.cs" "$wd\oscurecer.cs" "$wd\cinta.cs"
if (-not $?) { exit 1 }
Add-Type -Path "$wd\kra.dll" -ReferencedAssemblies System.Drawing,System.IO.Compression,System.IO.Compression.FileSystem
$mask = [KraLib.Cinta]::MaskOf("$wd\mask_cinta.png","$wd\notas.png",5)
$fwd = [KraLib.Cinta]::Track($mask,$sx,$sy,$dx,$dy,$step,$maxHalf,1200)
$bwd = [KraLib.Cinta]::Track($mask,$sx,$sy,(-$dx),(-$dy),$step,$maxHalf,300)
$all = New-Object 'System.Collections.Generic.List[KraLib.PathPt]'
for($i=$bwd.Count-1;$i -ge 1;$i--){ $all.Add($bwd[$i]) }
foreach($p in $fwd){ $all.Add($p) }
$res = [KraLib.Cinta]::Resample($all,4)
$len = if($res.Count -gt 0){ $res[$res.Count-1].S } else { 0 }
Write-Output ("puntos=" + $all.Count + "  remuestreado=" + $res.Count + "  longitud=" + [math]::Round($len))
[KraLib.Cinta]::Draw($all,"$wd\osc_preview.png","$wd\path_dbg.png")
$ff = "C:\Program Files\Krita (x64)\bin\ffmpeg.exe"
& $ff -y -loglevel error -i "$wd\path_dbg.png" -vf "scale=1500:-1" -frames:v 1 "$wd\path_v.png"
Write-Output "ok"
