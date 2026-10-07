using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace KraLib
{
    /// A translucent lighting glaze: warm key light from the top of the stage,
    /// a gentle haze that lifts the whole image, and a soft vignette.
    public static class Luz
    {
        const int W = 2484, H = 1200;

        static double Cl(double v) { return v < 0 ? 0 : (v > 1 ? 1 : v); }
        static double Sm(double t) { t = Cl(t); return t * t * (3 - 2 * t); }

        public static Img Build(double glowA, double hazeA, double vigA)
        {
            int warm = 0xFFE2AE;     // stage light
            int cool = 0x0A1226;     // the dark the vignette sinks into
            Img o = new Img(W, H);
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    double dx = (x - 1240) / 1000.0, dy = (y - 330) / 640.0;
                    double g = Math.Exp(-(dx * dx + dy * dy) * 1.15);
                    double ag = glowA * g + hazeA;              // warm glaze

                    double rx = (x - 1242) / 1242.0, ry = (y - 600) / 690.0;
                    double r = Math.Sqrt(rx * rx + ry * ry);
                    double v = Sm((r - 0.60) / 0.62);
                    v = Math.Max(v, 0.85 * Sm((y - 985) / 250.0));   // settle the empty floor
                    double av = vigA * v;

                    // vignette over glaze
                    double a1 = Cl(ag / 255.0), a2 = Cl(av / 255.0);
                    double ao = a2 + a1 * (1 - a2);
                    if (ao < 0.004) continue;
                    double rr = (Img.R(cool) * a2 + Img.R(warm) * a1 * (1 - a2)) / ao;
                    double gg = (Img.G(cool) * a2 + Img.G(warm) * a1 * (1 - a2)) / ao;
                    double bb = (Img.B(cool) * a2 + Img.B(warm) * a1 * (1 - a2)) / ao;
                    o.P[y * W + x] = Img.Rgba((int)rr, (int)gg, (int)bb, (int)(ao * 255 + 0.5));
                }
            return o;
        }

        /// composite the whole document, with the glaze sitting above `aboveLayer`
        public static Img Preview(string kra, Img luz, string[] colourLayers, string aboveLayer)
        {
            Img acc = new Img(W, H);
            for (int i = 0; i < W * H; i++) acc.P[i] = unchecked((int)0xFFFFFFFF);
            foreach (string ln in colourLayers)
            {
                Img L = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/" + ln), W, H, 0, 0);
                Over(acc, L);
                if (ln == aboveLayer) Over(acc, luz);
            }
            return acc;
        }

        public static void Over(Img dst, Img src)
        {
            for (int i = 0; i < W * H; i++)
            {
                int a = Img.A(src.P[i]); if (a == 0) continue;
                if (a == 255) { dst.P[i] = src.P[i]; continue; }
                dst.P[i] = Img.Rgba(
                    (Img.R(src.P[i]) * a + Img.R(dst.P[i]) * (255 - a)) / 255,
                    (Img.G(src.P[i]) * a + Img.G(dst.P[i]) * (255 - a)) / 255,
                    (Img.B(src.P[i]) * a + Img.B(dst.P[i]) * (255 - a)) / 255, 255);
            }
        }

        public static string Write(string srcZip, string dstPath, Img luz, string above, string name)
        {
            byte[] blob = Kra.EncodeLayer(luz);
            byte[] icc = Kra.ReadEntry(srcZip, "unnamed/layers/layer2.icc");
            string doc = Encoding.UTF8.GetString(Kra.ReadEntry(srcZip, "maindoc.xml"));

            var entries = new HashSet<string>(Kra.ListEntries(srcZip));
            int idx = 9;
            while (entries.Contains("unnamed/layers/layer" + idx)) idx++;
            string lf = "layer" + idx;

            string xml = "   <layer opacity=\"255\" onionskin=\"0\" name=\"" + name + "\" channelflags=\"\" visible=\"1\" x=\"0\" intimeline=\"0\" channellockflags=\"\" locked=\"0\" filename=\"" + lf + "\" y=\"0\" uuid=\"{b1c0de00-0000-4000-8000-0000000000" + idx.ToString("D2") + "}\" colorspacename=\"RGBA\" nodetype=\"paintlayer\" compositeop=\"normal\" colorlabel=\"0\" collapsed=\"0\"/>\n";
            int p2 = doc.IndexOf("filename=\"" + above + "\"");
            if (p2 < 0) throw new Exception("no encuentro la capa " + above);
            int at = doc.LastIndexOf('\n', p2) + 1;
            doc = doc.Substring(0, at) + xml + doc.Substring(at);

            var extra = new Dictionary<string, byte[]>();
            extra["maindoc.xml"] = Encoding.UTF8.GetBytes(doc);
            extra["unnamed/layers/" + lf] = blob;
            extra["unnamed/layers/" + lf + ".defaultpixel"] = new byte[4];
            extra["unnamed/layers/" + lf + ".icc"] = icc;

            var order = new List<string>();
            var src = new Dictionary<string, byte[]>();
            foreach (string e in Kra.ListEntries(srcZip)) { order.Add(e); src[e] = Kra.ReadEntry(srcZip, e); }
            foreach (var kv in extra) if (!order.Contains(kv.Key)) order.Add(kv.Key);

            if (File.Exists(dstPath)) File.Delete(dstPath);
            using (var fs = new FileStream(dstPath, FileMode.Create))
            using (var z = new System.IO.Compression.ZipArchive(fs, System.IO.Compression.ZipArchiveMode.Create))
            {
                var me = z.CreateEntry("mimetype", System.IO.Compression.CompressionLevel.NoCompression);
                using (var s = me.Open()) { var b = src["mimetype"]; s.Write(b, 0, b.Length); }
                foreach (string nm in order)
                {
                    if (nm == "mimetype") continue;
                    byte[] data = extra.ContainsKey(nm) ? extra[nm] : src[nm];
                    var e = z.CreateEntry(nm, System.IO.Compression.CompressionLevel.Optimal);
                    using (var s = e.Open()) s.Write(data, 0, data.Length);
                }
            }
            return lf + " -> " + name;
        }
    }
}
