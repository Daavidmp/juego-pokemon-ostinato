using System;
using System.IO;

namespace KraLib
{
    public static class IdCur
    {
        public static string Run(string kra, string outDir, int minArea)
        {
            int W = 2484, H = 1200;
            Img[] layers = Analyze.LoadLayers(kra, W, H, new[] { "layer2", "layer3", "layer4", "layer5" });
            byte[] ink = Analyze.InkAlpha(layers, W, H);
            byte[] mask = Close.Dilate(ink, W, H, 930, 140, 1550, 360, 2);
            int n;
            int[] lab = Analyze.Label(mask, W, H, 48, out n);
            string s = IdMap.Render(lab, n, ink, W, H, minArea, Path.Combine(outDir, "ids_cur.png"));
            File.WriteAllText(Path.Combine(outDir, "ids_cur.txt"), s);
            return s.Split('\n')[0];
        }
    }
}
