using System;
using System.Collections.Generic;
using System.IO;

namespace KraLib
{
    public class Nota
    {
        public int X0, Y0, W, H;        // bbox in the source
        public int[] Px;                // ARGB, W*H
        public double Cx, Cy;           // centroid in canvas coords
        public double S0, T0, Ang0, HW0;
    }

    public static class Anim
    {
        const int CW = 2484, CH = 1200;

        // ---------- note sprites ----------
        public static List<Nota> Extract(Img notes, int thr, int minArea)
        {
            int[] lab = new int[CW * CH];
            var res = new List<Nota>();
            int[] stack = new int[CW * CH];
            int next = 0;
            for (int s = 0; s < CW * CH; s++)
            {
                if (Img.A(notes.P[s]) < thr || lab[s] != 0) continue;
                next++;
                int sp = 0; stack[sp++] = s; lab[s] = next;
                int minx = CW, miny = CH, maxx = -1, maxy = -1; long n = 0, sx = 0, sy = 0;
                while (sp > 0)
                {
                    int p = stack[--sp];
                    int x = p % CW, y = p / CW;
                    n++; sx += x; sy += y;
                    if (x < minx) minx = x; if (x > maxx) maxx = x;
                    if (y < miny) miny = y; if (y > maxy) maxy = y;
                    for (int dy = -1; dy <= 1; dy++)
                        for (int dx = -1; dx <= 1; dx++)
                        {
                            int nx = x + dx, ny = y + dy;
                            if (nx < 0 || ny < 0 || nx >= CW || ny >= CH) continue;
                            int q = ny * CW + nx;
                            if (lab[q] != 0 || Img.A(notes.P[q]) < thr) continue;
                            lab[q] = next; stack[sp++] = q;
                        }
                }
                if (n < minArea) continue;
                var nt = new Nota { X0 = minx, Y0 = miny, W = maxx - minx + 1, H = maxy - miny + 1 };
                nt.Cx = (double)sx / n; nt.Cy = (double)sy / n;
                nt.Px = new int[nt.W * nt.H];
                for (int y = miny; y <= maxy; y++)
                    for (int x = minx; x <= maxx; x++)
                        if (lab[y * CW + x] == next)
                            nt.Px[(y - miny) * nt.W + (x - minx)] = notes.P[y * CW + x];
                res.Add(nt);
            }
            return res;
        }

        // ---------- path helpers ----------
        public static double Ang(List<PathPt> p, int i)
        {
            int a = Math.Max(0, i - 3), b = Math.Min(p.Count - 1, i + 3);
            return Math.Atan2(p[b].Y - p[a].Y, p[b].X - p[a].X);
        }

        public static void Place(List<PathPt> path, List<Nota> notes)
        {
            foreach (var n in notes)
            {
                int best = 0; double bd = 1e18;
                for (int i = 0; i < path.Count; i++)
                {
                    double dx = path[i].X - n.Cx, dy = path[i].Y - n.Cy;
                    double d = dx * dx + dy * dy;
                    if (d < bd) { bd = d; best = i; }
                }
                double ang = Ang(path, best);
                double nx = -Math.Sin(ang), ny = Math.Cos(ang);
                n.S0 = path[best].S;
                n.T0 = (n.Cx - path[best].X) * nx + (n.Cy - path[best].Y) * ny;
                n.Ang0 = ang;
                n.HW0 = path[best].HW;
            }
        }

        static void At(List<PathPt> path, double s, out double x, out double y,
                       out double ang, out double hw)
        {
            double total = path[path.Count - 1].S;
            while (s < 0) s += total;
            while (s >= total) s -= total;
            int i = (int)(s / total * (path.Count - 1));
            if (i < 0) i = 0; if (i > path.Count - 2) i = path.Count - 2;
            while (i > 0 && path[i].S > s) i--;
            while (i < path.Count - 2 && path[i + 1].S < s) i++;
            double f = (s - path[i].S) / Math.Max(1e-9, path[i + 1].S - path[i].S);
            x = path[i].X + (path[i + 1].X - path[i].X) * f;
            y = path[i].Y + (path[i + 1].Y - path[i].Y) * f;
            hw = path[i].HW + (path[i + 1].HW - path[i].HW) * f;
            ang = Ang(path, i);
        }

        /// draw one note at arc position s, clipped to the ribbon, with a soft fade at the
        /// two ends of the run so nothing pops in or out
        public static void DrawNote(Img dst, Nota n, List<PathPt> path, double s,
                                    byte[] clip, double fadeLen, double extraAlpha)
        {
            double total = path[path.Count - 1].S;
            double x, y, ang, hw;
            At(path, s, out x, out y, out ang, out hw);
            double k = n.HW0 > 1 ? hw / n.HW0 : 1;
            if (k < 0.55) k = 0.55; if (k > 1.5) k = 1.5;
            double nx = -Math.Sin(ang), ny = Math.Cos(ang);
            double cx = x + nx * n.T0 * k, cy = y + ny * n.T0 * k;
            double rot = ang - n.Ang0;

            double fade = 1;
            if (s < fadeLen) fade = s / fadeLen;
            else if (s > total - fadeLen) fade = (total - s) / fadeLen;
            fade *= extraAlpha;
            if (fade <= 0.01) return;

            double c = Math.Cos(-rot) / k, sn = Math.Sin(-rot) / k;
            double rad = Math.Sqrt(n.W * n.W + n.H * n.H) * 0.5 * k + 2;
            int lx = (int)(cx - rad), hx = (int)(cx + rad), ly = (int)(cy - rad), hy = (int)(cy + rad);
            double ox = n.Cx - n.X0, oy = n.Cy - n.Y0;

            for (int py = Math.Max(0, ly); py <= Math.Min(CH - 1, hy); py++)
                for (int px = Math.Max(0, lx); px <= Math.Min(CW - 1, hx); px++)
                {
                    int di = py * CW + px;
                    if (clip != null && clip[di] == 0) continue;
                    double dx = px - cx, dy = py - cy;
                    double sxp = dx * c - dy * sn + ox;
                    double syp = dx * sn + dy * c + oy;
                    if (sxp < 0 || syp < 0 || sxp > n.W - 1.001 || syp > n.H - 1.001) continue;
                    int ix = (int)sxp, iy = (int)syp;
                    double fx = sxp - ix, fy = syp - iy;
                    int p00 = n.Px[iy * n.W + ix], p10 = n.Px[iy * n.W + ix + 1];
                    int p01 = n.Px[(iy + 1) * n.W + ix], p11 = n.Px[(iy + 1) * n.W + ix + 1];
                    double a = (Img.A(p00) * (1 - fx) + Img.A(p10) * fx) * (1 - fy)
                             + (Img.A(p01) * (1 - fx) + Img.A(p11) * fx) * fy;
                    a *= fade;
                    if (a < 1) continue;
                    double r = (Img.R(p00) * (1 - fx) + Img.R(p10) * fx) * (1 - fy)
                             + (Img.R(p01) * (1 - fx) + Img.R(p11) * fx) * fy;
                    double g = (Img.G(p00) * (1 - fx) + Img.G(p10) * fx) * (1 - fy)
                             + (Img.G(p01) * (1 - fx) + Img.G(p11) * fx) * fy;
                    double b = (Img.B(p00) * (1 - fx) + Img.B(p10) * fx) * (1 - fy)
                             + (Img.B(p01) * (1 - fx) + Img.B(p11) * fx) * fy;
                    if (a > 255) a = 255;
                    int d0 = dst.P[di];
                    dst.P[di] = Img.Rgba(
                        (int)((r * a + Img.R(d0) * (255 - a)) / 255),
                        (int)((g * a + Img.G(d0) * (255 - a)) / 255),
                        (int)((b * a + Img.B(d0) * (255 - a)) / 255), 255);
                }
        }

        /// cut a rectangle out of a layer and hand it back as its own sprite
        public static Img CutOut(Img layer, int x0, int y0, int x1, int y1)
        {
            Img s = new Img(CW, CH);
            for (int y = y0; y <= y1; y++)
                for (int x = x0; x <= x1; x++)
                {
                    int i = y * CW + x;
                    s.P[i] = layer.P[i];
                    layer.P[i] = 0;
                }
            return s;
        }

        /// composite src over dst with a global alpha and an optional uniform scale about a pivot
        public static void OverScaled(Img dst, Img src, double alpha, double scale, double pivX, double pivY)
        {
            if (alpha <= 0.002) return;
            if (Math.Abs(scale - 1) < 1e-4)
            {
                for (int i = 0; i < CW * CH; i++)
                {
                    int a = (int)(Img.A(src.P[i]) * alpha); if (a <= 0) continue;
                    if (a > 255) a = 255;
                    int d = dst.P[i];
                    dst.P[i] = Img.Rgba(
                        (Img.R(src.P[i]) * a + Img.R(d) * (255 - a)) / 255,
                        (Img.G(src.P[i]) * a + Img.G(d) * (255 - a)) / 255,
                        (Img.B(src.P[i]) * a + Img.B(d) * (255 - a)) / 255, 255);
                }
                return;
            }
            for (int y = 0; y < CH; y++)
                for (int x = 0; x < CW; x++)
                {
                    double sxp = (x - pivX) / scale + pivX, syp = (y - pivY) / scale + pivY;
                    if (sxp < 0 || syp < 0 || sxp > CW - 1.001 || syp > CH - 1.001) continue;
                    int ix = (int)sxp, iy = (int)syp;
                    double fx = sxp - ix, fy = syp - iy;
                    int p00 = src.P[iy * CW + ix], p10 = src.P[iy * CW + ix + 1];
                    int p01 = src.P[(iy + 1) * CW + ix], p11 = src.P[(iy + 1) * CW + ix + 1];
                    double a = ((Img.A(p00) * (1 - fx) + Img.A(p10) * fx) * (1 - fy)
                              + (Img.A(p01) * (1 - fx) + Img.A(p11) * fx) * fy) * alpha;
                    if (a < 1) continue; if (a > 255) a = 255;
                    double r = (Img.R(p00) * (1 - fx) + Img.R(p10) * fx) * (1 - fy) + (Img.R(p01) * (1 - fx) + Img.R(p11) * fx) * fy;
                    double g = (Img.G(p00) * (1 - fx) + Img.G(p10) * fx) * (1 - fy) + (Img.G(p01) * (1 - fx) + Img.G(p11) * fx) * fy;
                    double b = (Img.B(p00) * (1 - fx) + Img.B(p10) * fx) * (1 - fy) + (Img.B(p01) * (1 - fx) + Img.B(p11) * fx) * fy;
                    int i = y * CW + x, d = dst.P[i];
                    dst.P[i] = Img.Rgba(
                        (int)((r * a + Img.R(d) * (255 - a)) / 255),
                        (int)((g * a + Img.G(d) * (255 - a)) / 255),
                        (int)((b * a + Img.B(d) * (255 - a)) / 255), 255);
                }
        }
    }
}
