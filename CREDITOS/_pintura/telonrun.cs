using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace KraLib
{
    public static class TelonRun
    {
        const int W = 2484, H = 1200;

        static readonly int[][] PolyL = {
            new[]{0,0}, new[]{445,0}, new[]{150,610}, new[]{150,940},
            new[]{250,1010}, new[]{250,1200}, new[]{0,1200} };
        static readonly int[][] PolyR = {
            new[]{2484,0}, new[]{2040,0}, new[]{2345,620}, new[]{2200,900},
            new[]{2200,1200}, new[]{2484,1200} };

        static bool In(int[][] p, int x, int y)
        {
            bool inside = false;
            for (int i = 0, j = p.Length - 1; i < p.Length; j = i++)
                if (((p[i][1] > y) != (p[j][1] > y)) &&
                    (x < (double)(p[j][0] - p[i][0]) * (y - p[i][1]) / (double)(p[j][1] - p[i][1]) + p[i][0]))
                    inside = !inside;
            return inside;
        }

        public static string Run(string kra, string userLayer, string outDir, string outKra,
                                 double ampRed, double ampGold)
        {
            Img[] layers = Analyze.LoadLayers(kra, W, H, new[] { "layer2", "layer3", "layer4", "layer5" });
            byte[] ink = Analyze.InkAlpha(layers, W, H);
            int n;
            int[] lab = Analyze.Label(ink, W, H, 48, out n);
            int[] dist = IdMap.Dist(lab, W, H);
            long[] area; int[] px, py, maxd;
            IdMap.Poles(lab, n, dist, W, H, out area, out px, out py, out maxd);

            // a region belongs to the curtain if its deepest point falls in the drapes
            bool[] curtainRegion = new bool[n + 1];
            int cnt = 0;
            for (int l = 1; l <= n; l++)
            {
                if (area[l] == 0) continue;
                bool c = In(PolyL, px[l], py[l]) || In(PolyR, px[l], py[l])
                      || (px[l] >= 430 && px[l] <= 2060 && py[l] <= 90);
                curtainRegion[l] = c;
                if (c) cnt++;
            }
            Img user = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/" + userLayer), W, H, 0, 0);

            bool[] zone = new bool[W * H];
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    int i = y * W + x; int l = lab[i];
                    if (l != 0 && curtainRegion[l]) { zone[i] = true; continue; }
                    // the user repainted by hand some spots the automatic fill had left as
                    // backdrop; anything warm inside the drape outline counts as curtain
                    bool inDrape = In(PolyL, x, y) || In(PolyR, x, y) || (x >= 430 && x <= 2060 && y <= 90);
                    if (inDrape && Img.A(user.P[i]) != 0 && Img.R(user.P[i]) > Img.B(user.P[i]) + 20)
                        zone[i] = true;
                }
            Img shaded = Telon.Run(user, lab, n, zone, curtainRegion, ampRed, ampGold, "regiones de telon=" + cnt);

            // small shapes inside the drape are not folds, so they came out as holes and the
            // old painting showed through. Continue the neighbouring shading into them - but
            // never into the embroidered hem, which is the user's own design.
            bool[] fillable = new bool[W * H];
            int holes = 0;
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    int i = y * W + x;
                    if (!zone[i] || Img.A(shaded.P[i]) != 0) continue;
                    bool hem = (x < 290 || x > 2190) && y > 755;
                    if (hem) continue;
                    fillable[i] = true; holes++;
                }
            FillHoles(shaded, fillable);
            // a nearest-neighbour fill leaves vertical streaks; soften just those pixels
            BlurMasked(shaded, fillable, 3, 3);

            // let the colour creep a few px under the drawn strokes so no old seam shows
            SpreadBounded(shaded, lab, 4);

            shaded.Save(Path.Combine(outDir, "telon_sombras.png"));

            // preview: user layer, our shading over it, then the rest of the document
            Img prev = user.Clone();
            for (int i = 0; i < W * H; i++) if (Img.A(shaded.P[i]) != 0) prev.P[i] = shaded.P[i];
            Img letras = null;
            try { letras = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/layer7"), W, H, 0, 0); }
            catch { }
            if (letras != null)
                for (int i = 0; i < W * H; i++) if (Img.A(letras.P[i]) != 0) prev.P[i] = letras.P[i];
            foreach (Img L in layers)
                for (int i = 0; i < W * H; i++)
                {
                    int a = Img.A(L.P[i]); if (a == 0) continue;
                    prev.P[i] = Img.Rgba(
                        (Img.R(L.P[i]) * a + Img.R(prev.P[i]) * (255 - a)) / 255,
                        (Img.G(L.P[i]) * a + Img.G(prev.P[i]) * (255 - a)) / 255,
                        (Img.B(L.P[i]) * a + Img.B(prev.P[i]) * (255 - a)) / 255, 255);
                }
            prev.Save(Path.Combine(outDir, "telon_preview.png"));

            if (!string.IsNullOrEmpty(outKra)) Write(kra, outKra, shaded, userLayer);
            return "ok, regiones de telon=" + cnt;
        }

        /// flood the marked pixels with the colour of the nearest already-shaded pixel
        static void FillHoles(Img col, bool[] fillable)
        {
            var cur = new List<int>();
            bool[] done = new bool[W * H];
            for (int i = 0; i < W * H; i++)
            {
                if (!fillable[i]) done[i] = true;
                if (Img.A(col.P[i]) != 0) { done[i] = true; cur.Add(i); }
            }
            while (cur.Count > 0)
            {
                var next = new List<int>();
                foreach (int p in cur)
                {
                    int x = p % W, y = p / W, c = col.P[p];
                    int[] nb = { x > 0 ? p - 1 : -1, x < W - 1 ? p + 1 : -1, y > 0 ? p - W : -1, y < H - 1 ? p + W : -1 };
                    foreach (int t in nb)
                        if (t >= 0 && !done[t]) { done[t] = true; col.P[t] = c; next.Add(t); }
                }
                cur = next;
            }
        }

        /// box-blur, reading everything but writing only where `mask` is set
        static void BlurMasked(Img col, bool[] mask, int radius, int passes)
        {
            for (int p = 0; p < passes; p++)
            {
                int[] src = (int[])col.P.Clone();
                for (int y = 0; y < H; y++)
                    for (int x = 0; x < W; x++)
                    {
                        int i = y * W + x;
                        if (!mask[i]) continue;
                        long r = 0, g = 0, b = 0; int cnt = 0;
                        for (int dy = -radius; dy <= radius; dy++)
                            for (int dx = -radius; dx <= radius; dx++)
                            {
                                int nx = x + dx, ny = y + dy;
                                if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
                                int c = src[ny * W + nx];
                                if (Img.A(c) == 0) continue;
                                r += Img.R(c); g += Img.G(c); b += Img.B(c); cnt++;
                            }
                        if (cnt > 0) col.P[i] = Img.Rgba((int)(r / cnt), (int)(g / cnt), (int)(b / cnt), 255);
                    }
            }
        }

        static void SpreadBounded(Img col, int[] lab, int steps)
        {
            var cur = new List<int>();
            bool[] done = new bool[W * H];
            for (int i = 0; i < W * H; i++)
            {
                if (lab[i] != 0) done[i] = true;
                if (lab[i] != 0 && Img.A(col.P[i]) != 0) cur.Add(i);
            }
            for (int s = 0; s < steps; s++)
            {
                var next = new List<int>();
                foreach (int p in cur)
                {
                    int x = p % W, y = p / W, c = col.P[p];
                    int[] nb = { x > 0 ? p - 1 : -1, x < W - 1 ? p + 1 : -1, y > 0 ? p - W : -1, y < H - 1 ? p + W : -1 };
                    foreach (int t in nb)
                        if (t >= 0 && !done[t]) { done[t] = true; col.P[t] = c; next.Add(t); }
                }
                cur = next;
            }
        }

        static void Write(string srcZip, string dstPath, Img shaded, string above)
        {
            byte[] blob = Kra.EncodeLayer(shaded);
            byte[] icc = Kra.ReadEntry(srcZip, "unnamed/layers/layer2.icc");
            string doc = Encoding.UTF8.GetString(Kra.ReadEntry(srcZip, "maindoc.xml"));

            // pick a free layerN name
            var entries = new HashSet<string>(Kra.ListEntries(srcZip));
            int idx = 8;
            while (entries.Contains("unnamed/layers/layer" + idx)) idx++;
            string lf = "layer" + idx;

            string xml = "   <layer opacity=\"255\" onionskin=\"0\" name=\"Telon sombras\" channelflags=\"\" visible=\"1\" x=\"0\" intimeline=\"0\" channellockflags=\"\" locked=\"0\" filename=\"" + lf + "\" y=\"0\" uuid=\"{b1c0de00-0000-4000-8000-0000000000" + idx.ToString("D2") + "}\" colorspacename=\"RGBA\" nodetype=\"paintlayer\" compositeop=\"normal\" colorlabel=\"0\" collapsed=\"0\"/>\n";
            // directly above the user's layer => immediately before its line (first = top)
            int p2 = doc.IndexOf("filename=\"" + above + "\"");
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
                foreach (string name in order)
                {
                    if (name == "mimetype") continue;
                    byte[] data = extra.ContainsKey(name) ? extra[name] : src[name];
                    var e = z.CreateEntry(name, System.IO.Compression.CompressionLevel.Optimal);
                    using (var s = e.Open()) s.Write(data, 0, data.Length);
                }
            }
        }
    }
}
