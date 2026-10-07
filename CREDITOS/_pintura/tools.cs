using System;
using System.IO;
using System.Collections.Generic;
using KraLib;

namespace KraLib
{
    public static class Tools
    {
        /// Decode a layer back out of a .kra and compare it with a reference PNG.
        public static string VerifyLayer(string kra, string entry, string pngRef, int W, int H)
        {
            Img a = Kra.DecodeLayer(Kra.ReadEntry(kra, entry), W, H, 0, 0);
            Img b = Img.Load(pngRef);
            long diff = 0; int worst = 0;
            for (int i = 0; i < a.P.Length; i++)
            {
                if (a.P[i] == b.P[i]) continue;
                diff++;
                int d = Math.Abs(Img.A(a.P[i]) - Img.A(b.P[i]));
                d = Math.Max(d, Math.Abs(Img.R(a.P[i]) - Img.R(b.P[i])));
                d = Math.Max(d, Math.Abs(Img.G(a.P[i]) - Img.G(b.P[i])));
                d = Math.Max(d, Math.Abs(Img.B(a.P[i]) - Img.B(b.P[i])));
                if (d > worst) worst = d;
            }
            return string.Format("{0}: pixeles distintos={1} de {2}, desviacion maxima={3}",
                entry, diff, a.P.Length, worst);
        }

        public static string DumpLayers(string zip, string outDir, int W, int H, string[] layers)
        {
            var sb = new System.Text.StringBuilder();
            foreach (string ln in layers)
            {
                byte[] d = Kra.ReadEntry(zip, "unnamed/layers/" + ln);
                Img im = Kra.DecodeLayer(d, W, H, 0, 0);
                long nz = 0, opaque = 0;
                int minx = W, miny = H, maxx = -1, maxy = -1;
                for (int y = 0; y < H; y++)
                    for (int x = 0; x < W; x++)
                    {
                        int c = im.P[y * W + x];
                        int al = (c >> 24) & 255;
                        if (al > 0)
                        {
                            nz++;
                            if (al > 200) opaque++;
                            if (x < minx) minx = x; if (x > maxx) maxx = x;
                            if (y < miny) miny = y; if (y > maxy) maxy = y;
                        }
                    }
                sb.AppendLine(string.Format("{0}: nonzero={1} opaque={2} bbox=({3},{4})-({5},{6})",
                    ln, nz, opaque, minx, miny, maxx, maxy));
                // save composited on white for viewing
                Img v = new Img(W, H);
                for (int i = 0; i < im.P.Length; i++)
                {
                    int c = im.P[i]; int a = (c >> 24) & 255;
                    int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
                    int rr = (r * a + 255 * (255 - a)) / 255;
                    int gg = (g * a + 255 * (255 - a)) / 255;
                    int bb = (b * a + 255 * (255 - a)) / 255;
                    v.P[i] = unchecked((int)0xFF000000) | (rr << 16) | (gg << 8) | bb;
                }
                v.Save(Path.Combine(outDir, ln + "_white.png"));
                im.Save(Path.Combine(outDir, ln + ".png"));
            }
            return sb.ToString();
        }
    }
}
