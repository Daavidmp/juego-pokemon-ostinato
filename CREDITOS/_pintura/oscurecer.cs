using System;

namespace KraLib
{
    /// Re-tones the OSTINATO wood: darker, oak-coloured, with the grain brought up, and with
    /// the contact shadow the pasted paper sheets cast on it. Everything is derived from what
    /// is already painted underneath, so the user's own retouching survives.
    public static class Oscurecer
    {
        const int W = 2484, H = 1200;

        static double Cl(double v, double lo, double hi) { return v < lo ? lo : (v > hi ? hi : v); }

        /// separable box blur of a luminance plane
        static double[] Blur(double[] src, int r)
        {
            double[] a = new double[W * H], b = new double[W * H];
            for (int y = 0; y < H; y++)
            {
                double acc = 0; int n = 0;
                for (int x = -r; x <= r; x++) { if (x >= 0 && x < W) { acc += src[y * W + x]; n++; } }
                for (int x = 0; x < W; x++)
                {
                    a[y * W + x] = acc / n;
                    int add = x + r + 1, rem = x - r;
                    if (add < W) { acc += src[y * W + add]; n++; }
                    if (rem >= 0) { acc -= src[y * W + rem]; n--; }
                }
            }
            for (int x = 0; x < W; x++)
            {
                double acc = 0; int n = 0;
                for (int y = -r; y <= r; y++) { if (y >= 0 && y < H) { acc += a[y * W + x]; n++; } }
                for (int y = 0; y < H; y++)
                {
                    b[y * W + x] = acc / n;
                    int add = y + r + 1, rem = y - r;
                    if (add < H) { acc += a[add * W + x]; n++; }
                    if (rem >= 0) { acc -= a[rem * W + x]; n--; }
                }
            }
            return b;
        }

        public static Img Run(string kra, string sourceLayer, string maskPng, double k, double desat)
        {
            return Run2(kra, sourceLayer, maskPng, null, k, desat, 0, 0, 0, 0);
        }

        /// oak      : 0 = leave the hue, 1 = full shift toward oak (less orange, more tawny)
        /// grain    : how much the grain is brought up (local contrast)
        /// shadowAmt: how dark the paper's contact shadow gets
        /// shadowR  : how far that shadow reaches, in px
        public static Img Run2(string kra, string sourceLayer, string maskPng, string paperPng,
                               double k, double desat, double oak, double grain,
                               double shadowAmt, double shadowR)
        {
            Img src = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/" + sourceLayer), W, H, 0, 0);
            Img mask = Img.Load(maskPng);
            byte[] paper = null;
            if (!string.IsNullOrEmpty(paperPng))
            {
                Img p = Img.Load(paperPng);
                paper = new byte[W * H];
                for (int i = 0; i < W * H; i++) paper[i] = (byte)(Img.A(p.P[i]) > 60 ? 255 : 0);
            }

            double[] lum = new double[W * H];
            for (int i = 0; i < W * H; i++)
                lum[i] = 0.299 * Img.R(src.P[i]) + 0.587 * Img.G(src.P[i]) + 0.114 * Img.B(src.P[i]);
            double[] soft = grain > 0 ? Blur(lum, 5) : null;

            // the light comes from up-left, so the sheets drop their shadow down-right
            const double ux = 0.55, uy = 0.84;

            Img o = new Img(W, H);
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    int i = y * W + x;
                    if (Img.A(mask.P[i]) == 0) continue;
                    int c = src.P[i];
                    if (Img.A(c) == 0) continue;

                    double r = Img.R(c), g = Img.G(c), b = Img.B(c);
                    double L = lum[i];

                    // bring the grain up before anything else touches the tone
                    if (soft != null)
                    {
                        double d = (L - soft[i]) * grain;
                        r += d; g += d; b += d;
                    }

                    // toward oak: a shade less orange, a shade cooler
                    if (oak > 0)
                    {
                        r *= 1 - 0.075 * oak;
                        g *= 1 + 0.005 * oak;
                        b *= 1 + 0.170 * oak;
                    }

                    // desat < 0 saturates, which is what keeps a dark brown from going grey
                    double L2 = 0.299 * r + 0.587 * g + 0.114 * b;
                    r += (L2 - r) * desat; g += (L2 - g) * desat; b += (L2 - b) * desat;

                    // pull the light tones down hard, leave the grain and the burnt edges alone
                    double f = 1 - (1 - k) * Math.Pow(Cl(L2, 0, 255) / 255.0, 0.7);

                    // contact shadow of the paper sheets lying on the wood
                    if (paper != null && shadowAmt > 0)
                    {
                        double sh = 0;
                        for (double d = 1; d <= shadowR; d += 1)
                        {
                            int sx = (int)(x - ux * d + 0.5), sy = (int)(y - uy * d + 0.5);
                            if (sx < 0 || sy < 0 || sx >= W || sy >= H) break;
                            if (paper[sy * W + sx] == 0) continue;
                            double v = 1 - (d - 1) / shadowR;
                            if (v > sh) sh = v;
                        }
                        if (sh > 0) f *= 1 - shadowAmt * sh * sh;
                    }

                    r *= f; g *= f; b *= f;
                    o.P[i] = Img.Rgba((int)Cl(r, 0, 255), (int)Cl(g, 0, 255), (int)Cl(b, 0, 255), 255);
                }
            return o;
        }
    }
}
