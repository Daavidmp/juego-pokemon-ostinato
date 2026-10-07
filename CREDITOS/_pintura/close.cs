using System;

namespace KraLib
{
    public static class Close
    {
        /// Dilate the ink mask by `k` px (max filter) but only inside the given rect.
        public static byte[] Dilate(byte[] ink, int W, int H, int x0, int y0, int x1, int y1, int k)
        {
            byte[] o = (byte[])ink.Clone();
            for (int pass = 0; pass < k; pass++)
            {
                byte[] s = (byte[])o.Clone();
                for (int y = Math.Max(1, y0); y <= Math.Min(H - 2, y1); y++)
                    for (int x = Math.Max(1, x0); x <= Math.Min(W - 2, x1); x++)
                    {
                        int i = y * W + x;
                        int m = s[i];
                        if (s[i - 1] > m) m = s[i - 1];
                        if (s[i + 1] > m) m = s[i + 1];
                        if (s[i - W] > m) m = s[i - W];
                        if (s[i + W] > m) m = s[i + W];
                        o[i] = (byte)m;
                    }
            }
            return o;
        }

        /// Draw an opaque straight segment into the ink mask (to close a gap by hand).
        public static void Cut(byte[] ink, int W, int H, int x0, int y0, int x1, int y1, int thick)
        {
            int steps = Math.Max(Math.Abs(x1 - x0), Math.Abs(y1 - y0)) * 2 + 1;
            for (int s = 0; s <= steps; s++)
            {
                double t = (double)s / steps;
                int cx = (int)Math.Round(x0 + (x1 - x0) * t);
                int cy = (int)Math.Round(y0 + (y1 - y0) * t);
                for (int dy = -thick; dy <= thick; dy++)
                    for (int dx = -thick; dx <= thick; dx++)
                    {
                        int x = cx + dx, y = cy + dy;
                        if (x < 0 || y < 0 || x >= W || y >= H) continue;
                        ink[y * W + x] = 255;
                    }
            }
        }
    }
}
