using System;
using System.IO;

namespace KraLib
{
    public static class Diff
    {
        public static string Map(string kra, string entry, string pngRef, string outPath, int W, int H)
        {
            Img a = Kra.DecodeLayer(Kra.ReadEntry(kra, entry), W, H, 0, 0);
            Img b = Img.Load(pngRef);
            Img m = new Img(W, H);
            int x0 = W, y0 = H, x1 = -1, y1 = -1; long n = 0;
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    int i = y * W + x;
                    int d = Math.Abs(Img.A(a.P[i]) - Img.A(b.P[i]));
                    d = Math.Max(d, Math.Abs(Img.R(a.P[i]) - Img.R(b.P[i])));
                    d = Math.Max(d, Math.Abs(Img.G(a.P[i]) - Img.G(b.P[i])));
                    d = Math.Max(d, Math.Abs(Img.B(a.P[i]) - Img.B(b.P[i])));
                    if (d > 6)
                    {
                        m.P[i] = unchecked((int)0xFFFF0000); n++;
                        if (x < x0) x0 = x; if (x > x1) x1 = x;
                        if (y < y0) y0 = y; if (y > y1) y1 = y;
                    }
                    else m.P[i] = unchecked((int)0xFF202020);
                }
            m.Save(outPath);
            return string.Format("cambiados {0} px, bbox=({1},{2})-({3},{4})", n, x0, y0, x1, y1);
        }
    }
}
