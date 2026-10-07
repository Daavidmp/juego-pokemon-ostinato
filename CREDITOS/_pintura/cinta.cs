using System;
using System.Collections.Generic;
using System.IO;

namespace KraLib
{
    public class PathPt { public double X, Y, HW, S; public bool Seen; }

    /// Walks the staff ribbon: steps forward and re-centres itself across the band at every
    /// step. Where the ribbon hides behind a letter it keeps going on the last heading until
    /// the band shows up again.
    public static class Cinta
    {
        const int W = 2484, H = 1200;

        static bool In(byte[] m, int x, int y)
        {
            if (x < 0 || y < 0 || x >= W || y >= H) return false;
            return m[y * W + x] != 0;
        }

        /// distance from (x,y) along (dx,dy) until the mask stops, capped at max. -1 if the
        /// starting point is not on the band at all.
        static double Edge(byte[] m, double x, double y, double dx, double dy, double max)
        {
            if (!In(m, (int)(x + 0.5), (int)(y + 0.5))) return -1;
            double k = 1;
            while (k <= max)
            {
                if (!In(m, (int)(x + dx * k + 0.5), (int)(y + dy * k + 0.5))) return k;
                k += 1;
            }
            return max;
        }

        public static List<PathPt> Track(byte[] mask, double x, double y, double dx, double dy,
                                         double step, double maxHalf, int maxSteps)
        {
            var pts = new List<PathPt>();
            double len = Math.Sqrt(dx * dx + dy * dy); dx /= len; dy /= len;
            double lastHW = 55; int lost = 0;
            for (int i = 0; i < maxSteps; i++)
            {
                // the true normal of a band is the direction in which it measures narrowest
                double n0 = Math.Atan2(dx, -dy);      // current normal angle
                double bestW = 1e9, bestAng = n0, bestA = 0, bestB = 0;
                for (double ang = n0 - 0.60; ang <= n0 + 0.601; ang += 0.03)
                {
                    double nx = Math.Cos(ang), ny = Math.Sin(ang);
                    double a2 = Edge(mask, x, y, nx, ny, maxHalf);
                    double b2 = Edge(mask, x, y, -nx, -ny, maxHalf);
                    if (a2 <= 0 || b2 <= 0 || a2 >= maxHalf || b2 >= maxHalf) continue;
                    if (a2 + b2 < bestW) { bestW = a2 + b2; bestAng = ang; bestA = a2; bestB = b2; }
                }
                // where a letter clips the ribbon the visible chord is far too narrow; trusting
                // it would tilt the heading and send the walk off the band
                bool seen = bestW < 1e8 && bestW / 2 > lastHW * 0.60 && bestW / 2 < lastHW * 1.7;
                if (seen)
                {
                    double nx = Math.Cos(bestAng), ny = Math.Sin(bestAng);
                    double shift = (bestA - bestB) / 2.0;
                    x += nx * shift * 0.6; y += ny * shift * 0.6;
                    lastHW = lastHW * 0.75 + (bestW / 2.0) * 0.25;

                    // tangent is perpendicular to that normal, kept pointing forward,
                    // and the heading may only bend a little per step
                    double tx = -ny, ty = nx;
                    if (tx * dx + ty * dy < 0) { tx = -tx; ty = -ty; }
                    double cur = Math.Atan2(dy, dx), want = Math.Atan2(ty, tx);
                    double diff = want - cur;
                    while (diff > Math.PI) diff -= 2 * Math.PI;
                    while (diff < -Math.PI) diff += 2 * Math.PI;
                    double maxTurn = 0.045;
                    if (diff > maxTurn) diff = maxTurn;
                    if (diff < -maxTurn) diff = -maxTurn;
                    double na = cur + diff;
                    dx = Math.Cos(na); dy = Math.Sin(na);
                }
                pts.Add(new PathPt { X = x, Y = y, HW = lastHW, Seen = seen });
                lost = seen ? 0 : lost + 1;
                if (lost > 110) break;          // long enough to bridge any letter, not the end
                x += dx * step; y += dy * step;
                if (x < -60 || y < -60 || x > W + 60 || y > H + 60) break;
            }
            // drop the blind tail: the walk only really knows the band up to the last sighting
            int last = pts.Count - 1;
            while (last > 0 && !pts[last].Seen) last--;
            if (last < pts.Count - 1) pts.RemoveRange(last + 1, pts.Count - 1 - last);
            return pts;
        }

        /// Build the path from a hand-traced polyline: resample it evenly, then measure the
        /// band's half width off the mask wherever the ribbon is actually visible and
        /// interpolate across the stretches hidden behind the letters.
        public static List<PathPt> FromPolyline(byte[] mask, double[] xs, double[] ys,
                                                double ds, double maxHalf)
        {
            var raw = new List<PathPt>();
            for (int i = 0; i < xs.Length; i++) raw.Add(new PathPt { X = xs[i], Y = ys[i], HW = 55 });
            var p = Resample(Smooth(raw, 2), ds);

            for (int i = 0; i < p.Count; i++)
            {
                int j0 = Math.Max(0, i - 1), j1 = Math.Min(p.Count - 1, i + 1);
                double tx = p[j1].X - p[j0].X, ty = p[j1].Y - p[j0].Y;
                double l = Math.Sqrt(tx * tx + ty * ty); if (l < 1e-9) { p[i].HW = -1; continue; }
                double nx = -ty / l, ny = tx / l;
                double a = Edge(mask, p[i].X, p[i].Y, nx, ny, maxHalf);
                double b = Edge(mask, p[i].X, p[i].Y, -nx, -ny, maxHalf);
                double hw = (a + b) / 2.0;
                // a chord shorter than this means a letter is covering part of the band, so
                // the reading says nothing about how wide the ribbon really is there
                bool good = a > 0 && b > 0 && a < maxHalf && b < maxHalf && hw >= 32;
                p[i].HW = good ? hw : -1;
            }
            // fill the unmeasured stretches, then smooth so the width never steps
            int last = -1;
            for (int i = 0; i < p.Count; i++)
            {
                if (p[i].HW < 0) continue;
                if (last >= 0 && i - last > 1)
                    for (int k = last + 1; k < i; k++)
                        p[k].HW = p[last].HW + (p[i].HW - p[last].HW) * (k - last) / (double)(i - last);
                last = i;
            }
            double first = 55; foreach (var q in p) if (q.HW > 0) { first = q.HW; break; }
            for (int i = 0; i < p.Count && p[i].HW < 0; i++) p[i].HW = first;
            for (int i = p.Count - 1; i >= 0 && p[i].HW < 0; i--) p[i].HW = p[last >= 0 ? last : 0].HW;
            for (int pass = 0; pass < 12; pass++)
                for (int i = 1; i < p.Count - 1; i++)
                    p[i].HW = (p[i - 1].HW + 2 * p[i].HW + p[i + 1].HW) / 4.0;
            foreach (var q in p) q.Seen = true;
            return p;
        }

        static List<PathPt> Smooth(List<PathPt> p, int passes)
        {
            for (int k = 0; k < passes; k++)
            {
                var o = new List<PathPt>();
                o.Add(p[0]);
                for (int i = 1; i < p.Count - 1; i++)
                {
                    o.Add(new PathPt { X = (p[i - 1].X + 2 * p[i].X + p[i + 1].X) / 4, Y = (p[i - 1].Y + 2 * p[i].Y + p[i + 1].Y) / 4, HW = p[i].HW });
                    o.Add(new PathPt { X = (p[i].X + p[i + 1].X) / 2, Y = (p[i].Y + p[i + 1].Y) / 2, HW = p[i].HW });
                }
                o.Add(p[p.Count - 1]);
                p = o;
            }
            return p;
        }

        public static List<PathPt> Resample(List<PathPt> raw, double ds)
        {
            // cumulative length
            var outp = new List<PathPt>();
            if (raw.Count < 2) return outp;
            outp.Add(new PathPt { X = raw[0].X, Y = raw[0].Y, HW = raw[0].HW, S = 0, Seen = raw[0].Seen });
            double travelled = 0, nextS = ds;
            for (int i = 1; i < raw.Count; i++)
            {
                double dx = raw[i].X - raw[i - 1].X, dy = raw[i].Y - raw[i - 1].Y;
                double seg = Math.Sqrt(dx * dx + dy * dy);
                if (seg < 1e-9) continue;
                while (nextS <= travelled + seg)
                {
                    double f = (nextS - travelled) / seg;
                    outp.Add(new PathPt
                    {
                        X = raw[i - 1].X + dx * f,
                        Y = raw[i - 1].Y + dy * f,
                        HW = raw[i - 1].HW + (raw[i].HW - raw[i - 1].HW) * f,
                        S = nextS,
                        Seen = raw[i].Seen
                    });
                    nextS += ds;
                }
                travelled += seg;
            }
            return outp;
        }

        public static void Draw(List<PathPt> p, string basePng, string outPng)
        {
            Img im = Img.Load(basePng);
            foreach (var q in p)
            {
                int col = q.Seen ? unchecked((int)0xFF00FF00) : unchecked((int)0xFFFF0000);
                for (int dy = -2; dy <= 2; dy++)
                    for (int dx = -2; dx <= 2; dx++)
                    {
                        int x = (int)q.X + dx, y = (int)q.Y + dy;
                        if (x >= 0 && y >= 0 && x < W && y < H) im[x, y] = col;
                    }
            }
            im.Save(outPng);
        }

        /// The ribbon mask comes out striped: every staff line splits the band into its own
        /// regions, so it has to be closed up before the band can be walked.
        public static byte[] MaskOf(string png, string alsoPng, int close)
        {
            Img m = Img.Load(png);
            byte[] a = new byte[W * H];
            for (int i = 0; i < W * H; i++) a[i] = (byte)(Img.A(m.P[i]) > 40 ? 255 : 0);
            if (!string.IsNullOrEmpty(alsoPng))
            {
                // the notes are drawn on the ribbon, so their ink punches holes in the band
                Img k = Img.Load(alsoPng);
                for (int i = 0; i < W * H; i++) if (Img.A(k.P[i]) > 25) a[i] = 255;
            }
            for (int p = 0; p < close; p++) a = Grow(a, true);
            for (int p = 0; p < close; p++) a = Grow(a, false);
            return a;
        }

        static byte[] Grow(byte[] s, bool dilate)
        {
            byte[] o = new byte[W * H];
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    int i = y * W + x;
                    bool v = s[i] != 0;
                    bool l = x > 0 && s[i - 1] != 0, r = x < W - 1 && s[i + 1] != 0;
                    bool u = y > 0 && s[i - W] != 0, d = y < H - 1 && s[i + W] != 0;
                    o[i] = (byte)((dilate ? (v || l || r || u || d) : (v && l && r && u && d)) ? 255 : 0);
                }
            return o;
        }
    }
}
