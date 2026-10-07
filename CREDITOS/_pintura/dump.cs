using System;
using System.IO;
using KraLib;

class Dump
{
    static void Main(string[] a)
    {
        string zip = a[0];
        string outDir = a[1];
        int W = 2484, H = 1200;
        foreach (string ln in new string[] { "layer2", "layer3", "layer4", "layer5" })
        {
            byte[] d = Kra.ReadEntry(zip, "unnamed/layers/" + ln);
            Img im = Kra.DecodeLayer(d, W, H, 0, 0);
            // stats
            long nz = 0; long opaque = 0;
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
            Console.WriteLine("{0}: nonzero={1} opaque={2} bbox=({3},{4})-({5},{6})", ln, nz, opaque, minx, miny, maxx, maxy);
            im.Save(Path.Combine(outDir, ln + ".png"));
        }
    }
}
