using System;
using System.Collections.Generic;

namespace KraLib
{
    /// Re-models the shading of the curtains, keeping the colours the user painted.
    public static class Telon
    {
        const int W = 2484, H = 1200;
        const double CX = 1242;          // stage centre: where the light comes from

        static double Cl(double v) { return v < 0 ? 0 : (v > 1 ? 1 : v); }
        static double Sm(double t) { t = Cl(t); return t * t * (3 - 2 * t); }
        static double Sq(double v) { return v * v; }
        static double G(double x, double c, double s) { return Math.Exp(-Sq((x - c) / s)); }

        /// cross-fold light profile. s = 0 shadow side, 1 lit side. returns -1.15 .. 1
        static double Profile(double s)
        {
            double core = G(s, 0.13, 0.17);     // core shadow, just off the shadow edge
            double bounce = G(s, 0.00, 0.06);     // light bounced back at the very edge
            double sheen = G(s, 0.78, 0.14);     // narrow velvet sheen
            double seam = G(s, 1.00, 0.07);     // dark seam where it meets the next fold
            double tilt = s - 0.5;
            double f = -1.05 * core + 0.40 * bounce + 1.00 * sheen - 0.45 * seam + 0.50 * tilt;
            return f < -1.15 ? -1.15 : (f > 1.0 ? 1.0 : f);
        }

        static int Shade(int baseCol, double f)
        {
            int r = Img.R(baseCol), g = Img.G(baseCol), b = Img.B(baseCol);
            if (f < 0)
            {
                // toward a deep, slightly cooler shadow instead of flat black
                double t = -f;
                int sr = (int)(r * 0.38), sg = (int)(g * 0.34), sb = (int)(b * 0.48 + 8);
                return Img.Rgba((int)(r + (sr - r) * t), (int)(g + (sg - g) * t), (int)(b + (sb - b) * t), 255);
            }
            else
            {
                // the sheen brightens the fabric's own hue, it does not wash out to white
                int hr = Math.Min(255, (int)(r * 1.35 + 60));
                int hg = Math.Min(255, (int)(g * 1.35 + 55));
                int hb = Math.Min(255, (int)(b * 1.30 + 45));
                return Img.Rgba((int)(r + (hr - r) * f), (int)(g + (hg - g) * f), (int)(b + (hb - b) * f), 255);
            }
        }

        /// march from (x,y) along (dx,dy) while staying in region `l`; returns the distance
        static double March(int[] lab, int l, int x, int y, double dx, double dy, double max)
        {
            for (double k = 1; k <= max; k += 1.0)
            {
                int nx = (int)(x + dx * k + 0.5), ny = (int)(y + dy * k + 0.5);
                if (nx < 0 || ny < 0 || nx >= W || ny >= H) return k;
                if (lab[ny * W + nx] != l) return k;
            }
            return max;
        }

        /// user  = the user's painted layer
        /// lab   = region labels, zone = which pixels belong to the curtain
        public static Img Run(Img user, int[] lab, int n, bool[] zone, bool[] foldAllowed,
                              double ampRed, double ampGold, string report)
        {
            // ---- per region: area, bbox, principal axis ----
            long[] area = new long[n + 1];
            long[] sx = new long[n + 1], sy = new long[n + 1];
            int[] x0 = new int[n + 1], y0 = new int[n + 1], x1 = new int[n + 1], y1 = new int[n + 1];
            for (int i = 1; i <= n; i++) { x0[i] = W; y0[i] = H; x1[i] = -1; y1[i] = -1; }
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    int i = y * W + x; if (!zone[i]) continue;
                    int l = lab[i]; if (l == 0) continue;
                    area[l]++; sx[l] += x; sy[l] += y;
                    if (x < x0[l]) x0[l] = x; if (x > x1[l]) x1[l] = x;
                    if (y < y0[l]) y0[l] = y; if (y > y1[l]) y1[l] = y;
                }
            double[] cxx = new double[n + 1], cyy = new double[n + 1], cxy = new double[n + 1];
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    int i = y * W + x; if (!zone[i]) continue;
                    int l = lab[i]; if (l == 0 || area[l] == 0) continue;
                    double dx = x - (double)sx[l] / area[l], dy = y - (double)sy[l] / area[l];
                    cxx[l] += dx * dx; cyy[l] += dy * dy; cxy[l] += dx * dy;
                }

            // fold direction (major axis) and the scan direction across it
            double[] nx2 = new double[n + 1], ny2 = new double[n + 1];
            bool[] isFold = new bool[n + 1];
            bool[] horizontal = new bool[n + 1];
            int folds = 0;
            for (int l = 1; l <= n; l++)
            {
                if (!foldAllowed[l]) continue;   // only real drape regions, never the backdrop
                if (area[l] < 2200) continue;
                int bw = x1[l] - x0[l] + 1, bh = y1[l] - y0[l] + 1;
                if (bw < 40 && bh < 40) continue;
                if (bh < 110 && bw < 180) continue;      // ornament motifs are small in both axes
                double a = cxx[l] / area[l], b = cxy[l] / area[l], c = cyy[l] / area[l];
                double tr = a + c, det = a * c - b * b;
                double lam = tr / 2 + Math.Sqrt(Math.Max(0, tr * tr / 4 - det));   // major eigenvalue
                double vx = b, vy = lam - a;                                       // major axis
                double len = Math.Sqrt(vx * vx + vy * vy);
                if (len < 1e-6) { vx = 0; vy = 1; len = 1; }
                vx /= len; vy /= len;
                double px = -vy, py = vx;                 // perpendicular = across the fold
                if (Math.Abs(px) < 0.30) { horizontal[l] = true; if (py < 0) { px = -px; py = -py; } }
                else if (px < 0) { px = -px; py = -py; }  // always point to the right
                nx2[l] = px; ny2[l] = py;
                isFold[l] = true; folds++;
            }

            // ---- pass 1: the cross-fold profile and the global light, per pixel ----
            float[] ff = new float[W * H];
            float[] gg = new float[W * H];
            bool[] ok = new bool[W * H];
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    int i = y * W + x;
                    if (!zone[i]) continue;
                    int l = lab[i];
                    if (l == 0 || !isFold[l]) continue;
                    int c0 = user.P[i];
                    if (Img.A(c0) == 0) continue;

                    double dPlus = March(lab, l, x, y, nx2[l], ny2[l], 200);
                    double dMinus = March(lab, l, x, y, -nx2[l], -ny2[l], 200);
                    double w = dPlus + dMinus;
                    if (w < 5) continue;
                    double u = dMinus / w;                       // 0 at the -perp edge, 1 at +perp

                    // which side faces the stage light
                    double s;
                    if (horizontal[l]) s = 1.0 - u;               // the swag is lit from above
                    else s = (x < CX) ? u : 1.0 - u;              // side facing the centre

                    // the sheen wanders a little along the fold so it is not a ruled line
                    s = Cl(s + 0.055 * Math.Sin(y * 0.0125 + l * 1.7) + 0.03 * Math.Sin(y * 0.031 + l));

                    double f = Profile(s);

                    // a narrow fold is a crease: less sheen, more shadow
                    double narrow = 0.70 + 0.30 * Sm((w - 20) / 55.0);
                    if (f > 0) f *= narrow;
                    // where the band pinches to nothing (the points of the swag) the profile
                    // swings wildly from pixel to pixel, so fade it out to the flat tone
                    f *= Sm((w - 12) / 22.0);

                    // ---- global lighting: added up and capped, never stacked ----
                    double dxc = Math.Abs(x - CX);
                    double away = 0.17 * Sm((dxc - 790) / 440.0);   // falls off away from the stage
                    double under = 0.15 * Sm((155 - y) / 155.0);    // shadow under the valance
                    double floorD = 0.07 * Sm((y - 1000) / 200.0);
                    double gather = 0.15 * G(y, 602, 78);           // pinched by the tieback
                    double gLum = 1 - Math.Min(0.30, away + under + floorD + gather);
                    ff[i] = (float)f; gg[i] = (float)gLum; ok[i] = true;
                }

            // ---- pass 2: blur ALONG the fold. Fold outlines stop part way down, so the
            // profile jumps in horizontal steps where one strip becomes another; smoothing
            // lengthwise removes those steps and leaves the cross-fold modelling intact ----
            float[] fs = new float[W * H];
            const int N = 22;
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    int i = y * W + x;
                    if (!ok[i]) continue;
                    int l = lab[i];
                    double vx = -ny2[l], vy = nx2[l];     // along the fold = perpendicular to the scan
                    double acc = 0, wsum = 0;
                    for (int k = -N; k <= N; k++)
                    {
                        int sx2 = (int)(x + vx * k + 0.5), sy2 = (int)(y + vy * k + 0.5);
                        if (sx2 < 0 || sy2 < 0 || sx2 >= W || sy2 >= H) continue;
                        int j = sy2 * W + sx2;
                        if (!ok[j]) continue;
                        double wgt = 1.0 - Math.Abs(k) / (double)(N + 1);
                        acc += ff[j] * wgt; wsum += wgt;
                    }
                    fs[i] = wsum > 0 ? (float)(acc / wsum) : ff[i];
                }

            // ---- the flat base colour of every (region, fabric/hem) pair, so the modelling
            // starts from one clean tone instead of fighting the shading already painted ----
            double[,] sr2 = new double[n + 1, 2], sg2 = new double[n + 1, 2], sb2 = new double[n + 1, 2];
            double[,] sl2 = new double[n + 1, 2]; long[,] cn2 = new long[n + 1, 2];
            for (int i = 0; i < W * H; i++)
            {
                if (!ok[i]) continue;
                int c0 = user.P[i]; int l = lab[i];
                int cls = (Img.G(c0) - Img.B(c0)) > 25 ? 1 : 0;
                sr2[l, cls] += Img.R(c0); sg2[l, cls] += Img.G(c0); sb2[l, cls] += Img.B(c0);
                sl2[l, cls] += 0.299 * Img.R(c0) + 0.587 * Img.G(c0) + 0.114 * Img.B(c0);
                cn2[l, cls]++;
            }

            // ---- pass 3: colour ----
            Img outImg = new Img(W, H);
            for (int i = 0; i < W * H; i++)
            {
                if (!ok[i]) continue;
                int c0 = user.P[i]; int l = lab[i];
                bool gold = (Img.G(c0) - Img.B(c0)) > 25;
                int cls = gold ? 1 : 0;
                if (cn2[l, cls] < 12) continue;          // too few pixels to judge a base tone
                double amp = gold ? ampGold : ampRed;
                double gLum = gold ? 1 - (1 - gg[i]) * 0.5 : gg[i];

                double mr = sr2[l, cls] / cn2[l, cls], mg = sg2[l, cls] / cn2[l, cls], mb = sb2[l, cls] / cn2[l, cls];
                double ml = sl2[l, cls] / cn2[l, cls];
                double target = gold ? 122.0 : 93.0;
                double k2 = ml < 4 ? 1 : target / ml;
                k2 = Math.Max(0.5, Math.Min(2.2, k2));
                int flat = Img.Rgba((int)Math.Min(255, mr * k2), (int)Math.Min(255, mg * k2),
                                    (int)Math.Min(255, mb * k2), 255);

                // keep a little of their brush texture, not their modelling
                double lum0 = 0.299 * Img.R(c0) + 0.587 * Img.G(c0) + 0.114 * Img.B(c0);
                double tex = ml < 4 ? 0 : Math.Max(-0.5, Math.Min(0.5, lum0 / ml - 1)) * 0.18;

                int c = Shade(flat, fs[i] * amp + tex);
                c = Img.Rgba((int)Cl0(Img.R(c) * gLum), (int)Cl0(Img.G(c) * gLum), (int)Cl0(Img.B(c) * gLum), 255);
                outImg.P[i] = c;
            }

            Console.WriteLine(report + " pliegues=" + folds);
            return outImg;
        }

        static double Cl0(double v) { return v < 0 ? 0 : (v > 255 ? 255 : v); }
    }
}
