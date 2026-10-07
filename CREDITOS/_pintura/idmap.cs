using System;
using System.Collections.Generic;

namespace KraLib
{
    public static class IdMap
    {
        /// Chamfer distance transform: distance of each non-line pixel from nearest line pixel.
        public static int[] Dist(int[] lab, int W, int H)
        {
            int INF = 1 << 28;
            int[] d = new int[W * H];
            for (int i = 0; i < d.Length; i++) d[i] = (lab[i] == 0) ? 0 : INF;
            // forward
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    int i = y * W + x; if (d[i] == 0) continue;
                    int m = d[i];
                    if (x > 0 && d[i - 1] + 5 < m) m = d[i - 1] + 5;
                    if (y > 0 && d[i - W] + 5 < m) m = d[i - W] + 5;
                    if (x > 0 && y > 0 && d[i - W - 1] + 7 < m) m = d[i - W - 1] + 7;
                    if (x < W - 1 && y > 0 && d[i - W + 1] + 7 < m) m = d[i - W + 1] + 7;
                    d[i] = m;
                }
            // backward
            for (int y = H - 1; y >= 0; y--)
                for (int x = W - 1; x >= 0; x--)
                {
                    int i = y * W + x; if (d[i] == 0) continue;
                    int m = d[i];
                    if (x < W - 1 && d[i + 1] + 5 < m) m = d[i + 1] + 5;
                    if (y < H - 1 && d[i + W] + 5 < m) m = d[i + W] + 5;
                    if (x < W - 1 && y < H - 1 && d[i + W + 1] + 7 < m) m = d[i + W + 1] + 7;
                    if (x > 0 && y < H - 1 && d[i + W - 1] + 7 < m) m = d[i + W - 1] + 7;
                    d[i] = m;
                }
            return d;
        }

        /// For each region: area, and the point of maximum distance (pole of inaccessibility).
        public static void Poles(int[] lab, int n, int[] d, int W, int H,
            out long[] area, out int[] px, out int[] py, out int[] maxd)
        {
            area = new long[n + 1]; px = new int[n + 1]; py = new int[n + 1]; maxd = new int[n + 1];
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    int i = y * W + x; int l = lab[i];
                    if (l == 0) continue;
                    area[l]++;
                    if (d[i] > maxd[l]) { maxd[l] = d[i]; px[l] = x; py[l] = y; }
                }
        }

        public static string Render(int[] lab, int n, byte[] ink, int W, int H, int minArea, string path)
        {
            int[] d = Dist(lab, W, H);
            long[] area; int[] px, py, maxd;
            Poles(lab, n, d, W, H, out area, out px, out py, out maxd);

            Img im = new Img(W, H);
            var rnd = new Random(11);
            int[] col = new int[n + 1];
            for (int i = 1; i <= n; i++)
                col[i] = unchecked((int)0xFF000000) | (rnd.Next(170, 256) << 16) | (rnd.Next(170, 256) << 8) | rnd.Next(170, 256);
            for (int i = 0; i < lab.Length; i++)
                im.P[i] = lab[i] == 0 ? unchecked((int)0xFF202020) : col[lab[i]];

            var sb = new System.Text.StringBuilder();
            int drawn = 0;
            for (int i = 1; i <= n; i++)
            {
                if (area[i] < minArea) continue;
                Glyph.DrawNum(im, i, px[i], py[i], unchecked((int)0xFF000000), unchecked((int)0xFFFFFFFF));
                drawn++;
                sb.AppendLine(string.Format("{0}\t{1}\t{2}\t{3}\t{4}", i, area[i], px[i], py[i], maxd[i] / 5));
            }
            im.Save(path);
            return "labelled " + drawn + " regions (of " + n + ")\n" + sb.ToString();
        }
    }
}
