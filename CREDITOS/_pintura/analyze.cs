using System;
using System.IO;
using System.Collections.Generic;

namespace KraLib
{
    public static class Analyze
    {
        public static Img[] LoadLayers(string zip, int W, int H, string[] names)
        {
            Img[] r = new Img[names.Length];
            for (int i = 0; i < names.Length; i++)
                r[i] = Kra.DecodeLayer(Kra.ReadEntry(zip, "unnamed/layers/" + names[i]), W, H, 0, 0);
            return r;
        }

        /// Combined ink alpha over all layers (max of alphas), 0..255
        public static byte[] InkAlpha(Img[] layers, int W, int H)
        {
            byte[] a = new byte[W * H];
            foreach (var L in layers)
                for (int i = 0; i < a.Length; i++)
                {
                    int al = (L.P[i] >> 24) & 255;
                    if (al > a[i]) a[i] = (byte)al;
                }
            return a;
        }

        public static string Histogram(byte[] a)
        {
            long[] h = new long[17];
            foreach (byte v in a) h[v / 16]++;
            var sb = new System.Text.StringBuilder();
            for (int i = 0; i < 16; i++)
                sb.AppendLine(string.Format("alpha {0,3}-{1,3}: {2}", i * 16, i * 16 + 15, h[i]));
            sb.AppendLine("alpha 255   : " + h[15]);
            return sb.ToString();
        }

        /// 4-connected labelling of pixels where line mask is false.
        /// Returns label array (0 = line pixel, >=1 region id)
        public static int[] Label(byte[] ink, int W, int H, int thr, out int nLabels)
        {
            int[] lab = new int[W * H];
            int[] stack = new int[W * H];
            int next = 0;
            for (int s = 0; s < W * H; s++)
            {
                if (ink[s] >= thr || lab[s] != 0) continue;
                next++;
                int sp = 0;
                stack[sp++] = s;
                lab[s] = next;
                while (sp > 0)
                {
                    int p = stack[--sp];
                    int x = p % W, y = p / W;
                    if (x > 0) { int q = p - 1; if (lab[q] == 0 && ink[q] < thr) { lab[q] = next; stack[sp++] = q; } }
                    if (x < W - 1) { int q = p + 1; if (lab[q] == 0 && ink[q] < thr) { lab[q] = next; stack[sp++] = q; } }
                    if (y > 0) { int q = p - W; if (lab[q] == 0 && ink[q] < thr) { lab[q] = next; stack[sp++] = q; } }
                    if (y < H - 1) { int q = p + W; if (lab[q] == 0 && ink[q] < thr) { lab[q] = next; stack[sp++] = q; } }
                }
            }
            nLabels = next;
            return lab;
        }

        public static string RegionStats(int[] lab, int n, int W, int H, int topN, string mapPath)
        {
            long[] area = new long[n + 1];
            int[] minx = new int[n + 1], miny = new int[n + 1], maxx = new int[n + 1], maxy = new int[n + 1];
            long[] sx = new long[n + 1], sy = new long[n + 1];
            for (int i = 1; i <= n; i++) { minx[i] = W; miny[i] = H; maxx[i] = -1; maxy[i] = -1; }
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    int l = lab[y * W + x];
                    if (l == 0) continue;
                    area[l]++; sx[l] += x; sy[l] += y;
                    if (x < minx[l]) minx[l] = x; if (x > maxx[l]) maxx[l] = x;
                    if (y < miny[l]) miny[l] = y; if (y > maxy[l]) maxy[l] = y;
                }
            var ids = new List<int>();
            for (int i = 1; i <= n; i++) ids.Add(i);
            ids.Sort(delegate (int a, int b) { return area[b].CompareTo(area[a]); });

            var sb = new System.Text.StringBuilder();
            sb.AppendLine("total regions: " + n);
            int shown = Math.Min(topN, ids.Count);
            for (int k = 0; k < shown; k++)
            {
                int i = ids[k];
                sb.AppendLine(string.Format("#{0,-4} id={1,-5} area={2,-8} bbox=({3},{4})-({5},{6}) c=({7},{8})",
                    k, i, area[i], minx[i], miny[i], maxx[i], maxy[i], sx[i] / area[i], sy[i] / area[i]));
            }
            // count of regions by size bucket
            int big = 0, mid = 0, small = 0;
            for (int i = 1; i <= n; i++)
            {
                if (area[i] >= 2000) big++;
                else if (area[i] >= 200) mid++;
                else small++;
            }
            sb.AppendLine(string.Format("buckets: >=2000px {0}, 200..2000 {1}, <200 {2}", big, mid, small));

            if (mapPath != null)
            {
                // pseudo-colour map
                Img m = new Img(W, H);
                var rnd = new Random(7);
                int[] col = new int[n + 1];
                for (int i = 1; i <= n; i++)
                    col[i] = unchecked((int)0xFF000000) | (rnd.Next(60, 250) << 16) | (rnd.Next(60, 250) << 8) | rnd.Next(60, 250);
                for (int i = 0; i < lab.Length; i++)
                    m.P[i] = lab[i] == 0 ? unchecked((int)0xFF000000) : col[lab[i]];
                m.Save(mapPath);
            }
            return sb.ToString();
        }
    }
}
