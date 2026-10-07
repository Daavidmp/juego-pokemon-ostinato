using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

namespace KraLib
{
    /// Reads Krita's animated layers: a keyframes XML mapping a time to the data file that
    /// holds the layer's content from that time on.
    public static class KrAnim
    {
        const int CW = 2484, CH = 1200;

        public class Key { public int Time; public string File; }

        public static List<Key> Keys(string kra, string layer)
        {
            string xml = Encoding.UTF8.GetString(Kra.ReadEntry(kra, "unnamed/layers/" + layer + ".keyframes.xml"));
            var list = new List<Key>();
            foreach (Match m in Regex.Matches(xml, "<keyframe[^>]*>"))
            {
                var t = Regex.Match(m.Value, "time=\"(\\d+)\"");
                var f = Regex.Match(m.Value, "frame=\"([^\"]*)\"");
                if (t.Success && f.Success)
                    list.Add(new Key { Time = int.Parse(t.Groups[1].Value), File = f.Groups[1].Value });
            }
            list.Sort(delegate (Key a, Key b) { return a.Time.CompareTo(b.Time); });
            return list;
        }

        /// index of the key in force at time t, or -1 before the first one
        public static int KeyAt(List<Key> keys, int t)
        {
            int r = -1;
            for (int i = 0; i < keys.Count; i++) { if (keys[i].Time <= t) r = i; else break; }
            return r;
        }

        /// Walks the timeline once, keeping only the blob currently in force for each layer.
        /// `action` gets the composite of those layers at every time step.
        public static void Walk(string kra, string[] layers, int t0, int t1, Action<int, Img> action)
        {
            var keys = new List<Key>[layers.Length];
            var cur = new int[layers.Length];
            var img = new Img[layers.Length];
            for (int i = 0; i < layers.Length; i++) { keys[i] = Keys(kra, layers[i]); cur[i] = -2; }

            for (int t = t0; t <= t1; t++)
            {
                bool changed = false;
                for (int i = 0; i < layers.Length; i++)
                {
                    int k = KeyAt(keys[i], t);
                    if (k == cur[i]) continue;
                    cur[i] = k; changed = true;
                    img[i] = (k < 0) ? null
                        : Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/" + keys[i][k].File), CW, CH, 0, 0);
                }
                Img comp = null;
                if (changed || t == t0)
                {
                    comp = new Img(CW, CH);
                    for (int i = 0; i < layers.Length; i++)
                    {
                        if (img[i] == null) continue;
                        for (int p = 0; p < CW * CH; p++)
                        {
                            int a = Img.A(img[i].P[p]); if (a == 0) continue;
                            if (a == 255) { comp.P[p] = img[i].P[p]; continue; }
                            int d = comp.P[p], da = Img.A(d);
                            int na = a + da * (255 - a) / 255;
                            if (na == 0) continue;
                            comp.P[p] = Img.Rgba(
                                (Img.R(img[i].P[p]) * a + Img.R(d) * da * (255 - a) / 255) / na,
                                (Img.G(img[i].P[p]) * a + Img.G(d) * da * (255 - a) / 255) / na,
                                (Img.B(img[i].P[p]) * a + Img.B(d) * da * (255 - a) / 255) / na, na);
                        }
                    }
                    lastComp = comp;
                }
                action(t, lastComp);
            }
        }
        static Img lastComp;

        /// bbox of the drawing, looking only inside the given window - the layer also carries
        /// odd marks elsewhere that must not drag the sprite's size out
        public static string BBoxIn(string kra, string[] layers, int t0, int t1,
                                    int rx0, int ry0, int rx1, int ry1)
        {
            int x0 = CW, y0 = CH, x1 = -1, y1 = -1;
            Walk(kra, layers, t0, t1, delegate (int t, Img c)
            {
                for (int y = ry0; y <= ry1; y++)
                    for (int x = rx0; x <= rx1; x++)
                    {
                        if (Img.A(c.P[y * CW + x]) < 8) continue;
                        if (x < x0) x0 = x; if (x > x1) x1 = x;
                        if (y < y0) y0 = y; if (y > y1) y1 = y;
                    }
            });
            return x0 + "," + y0 + "," + x1 + "," + y1;
        }

        public static string Report(string kra, string[] layers, int t0, int t1)
        {
            int x0 = CW, y0 = CH, x1 = -1, y1 = -1;
            var firstSeen = new List<int>();
            var sb = new StringBuilder();
            Walk(kra, layers, t0, t1, delegate (int t, Img c)
            {
                long n = 0;
                for (int y = 0; y < CH; y++)
                    for (int x = 0; x < CW; x++)
                    {
                        if (Img.A(c.P[y * CW + x]) < 8) continue;
                        n++;
                        if (x < x0) x0 = x; if (x > x1) x1 = x;
                        if (y < y0) y0 = y; if (y > y1) y1 = y;
                    }
                if (n > 0) firstSeen.Add(t);
            });
            sb.AppendLine("bbox total = (" + x0 + "," + y0 + ")-(" + x1 + "," + y1 + ")");
            if (firstSeen.Count > 0)
                sb.AppendLine("con dibujo desde t=" + firstSeen[0] + " hasta t=" + firstSeen[firstSeen.Count - 1]
                              + " (" + firstSeen.Count + " tiempos)");
            else sb.AppendLine("nunca hay dibujo");
            return sb.ToString();
        }

        /// Exports the animated layers as a cropped PNG sprite sequence, scaled for the game.
        public static string Export(string kra, string[] layers, int t0, int t1,
                                    int bx0, int by0, int bx1, int by1,
                                    double scale, string outDir, string prefix, int step)
        {
            Directory.CreateDirectory(outDir);
            int sw = (int)Math.Round((bx1 - bx0 + 1) * scale);
            int sh = (int)Math.Round((by1 - by0 + 1) * scale);
            int count = 0;
            var idx = new List<int>();
            Walk(kra, layers, t0, t1, delegate (int t, Img c)
            {
                if ((t - t0) % step != 0) return;
                using (var big = new Bitmap(CW, CH, PixelFormat.Format32bppArgb))
                {
                    var bd = big.LockBits(new Rectangle(0, 0, CW, CH), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                    System.Runtime.InteropServices.Marshal.Copy(c.P, 0, bd.Scan0, c.P.Length);
                    big.UnlockBits(bd);
                    using (var small = new Bitmap(sw, sh, PixelFormat.Format32bppArgb))
                    using (var g = Graphics.FromImage(small))
                    {
                        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                        g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
                        g.DrawImage(big, new Rectangle(0, 0, sw, sh),
                                    new Rectangle(bx0, by0, bx1 - bx0 + 1, by1 - by0 + 1), GraphicsUnit.Pixel);
                        small.Save(Path.Combine(outDir, string.Format("{0}{1:000}.png", prefix, count)), ImageFormat.Png);
                    }
                }
                count++;
            });
            return "exportados " + count + " fotogramas de " + sw + "x" + sh;
        }
    }
}
