using System;
using System.Collections.Generic;

namespace KraLib
{
    public static class Probe
    {
        public static string At(int[] lab, int W, int[] xs, int[] ys)
        {
            var sb = new System.Text.StringBuilder();
            for (int i = 0; i < xs.Length; i++)
                sb.AppendLine(string.Format("({0},{1}) -> region {2}", xs[i], ys[i], lab[ys[i] * W + xs[i]]));
            return sb.ToString();
        }

        /// paint given region ids red over the greyscale lineart
        public static void Show(int[] lab, byte[] ink, int W, int H, int[] ids, string path)
        {
            var set = new HashSet<int>(ids);
            Img im = new Img(W, H);
            for (int i = 0; i < W * H; i++)
            {
                int v = 255 - ink[i];
                if (set.Contains(lab[i]))
                    im.P[i] = unchecked((int)0xFF000000) | (255 << 16) | ((v / 3) << 8) | (v / 3);
                else
                    im.P[i] = unchecked((int)0xFF000000) | (v << 16) | (v << 8) | v;
            }
            im.Save(path);
        }
    }
}
