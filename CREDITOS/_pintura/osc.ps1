param([double]$k = 0.70, [double]$desat = 0.18, [string]$out = "")
$wd = "C:\Users\ASUS\Music\CREDITOS\_pintura"
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
& $csc /nologo /target:library /platform:x64 /out:"$wd\kra.dll" /r:System.Drawing.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll "$wd\kra.cs" "$wd\tools.cs" "$wd\analyze.cs" "$wd\grid.cs" "$wd\probe.cs" "$wd\idmap.cs" "$wd\close.cs" "$wd\paint.cs" "$wd\telon.cs" "$wd\telonrun.cs" "$wd\idcur.cs" "$wd\diff.cs" "$wd\luz.cs" "$wd\oscurecer.cs"
if (-not $?) { exit 1 }
Add-Type -Path "$wd\kra.dll" -ReferencedAssemblies System.Drawing,System.IO.Compression,System.IO.Compression.FileSystem

$osc = [KraLib.Oscurecer]::Run("$wd\k_final.kra","layer6","$wd\mask_madera.png",$k,$desat)
$osc.Save("$wd\osc.png")
if ($out -ne "") { [KraLib.Luz]::Write("$wd\k_final.kra",$out,$osc,"layer9","Madera mas oscura") }

# vista previa: de abajo arriba, con la madera oscurecida sobre "Papel letras"
$luz = [KraLib.Img]::Load("$wd\luz.png")
$acc = New-Object KraLib.Img 2484,1200
for($i=0;$i -lt $acc.P.Length;$i++){ $acc.P[$i] = -1 }
foreach($l in "layer8","layer7","layer6","layer9"){
  [KraLib.Luz]::Over($acc, [KraLib.Kra]::DecodeLayer([KraLib.Kra]::ReadEntry("$wd\k_final.kra","unnamed/layers/$l"),2484,1200,0,0))
}
[KraLib.Luz]::Over($acc,$osc)
[KraLib.Luz]::Over($acc,$luz)
foreach($l in "layer5","layer4","layer3","layer2"){
  [KraLib.Luz]::Over($acc, [KraLib.Kra]::DecodeLayer([KraLib.Kra]::ReadEntry("$wd\k_final.kra","unnamed/layers/$l"),2484,1200,0,0))
}
$acc.Save("$wd\osc_preview.png")
$ff = "C:\Program Files\Krita (x64)\bin\ffmpeg.exe"
& $ff -y -loglevel error -i "$wd\osc_preview.png" -vf "scale=1500:-1" -frames:v 1 "$wd\o_v.png"
& $ff -y -loglevel error -i "$wd\osc_preview.png" -vf "crop=1100:560:380:370,scale=1400:-1" -frames:v 1 "$wd\o_let.png"
Write-Output "render ok  k=$k desat=$desat"
