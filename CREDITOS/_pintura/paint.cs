using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;

namespace KraLib
{
    public class Mat
    {
        public string Name;
        public int Base, Shadow, Light;
        public string Style = "CEL";   // CEL | FOLD | FLAT | GLOW
        public double Amount = 1.0;    // shading strength
        public double Vary = 0.0;      // per-region tonal variation (0..1)
    }

    public static class Paint
    {
        const int W = 2484, H = 1200;
        static string ColorLayerName = "Color";
        static bool NoInk = false;
        static string LayerFile = "layer6";      // zip entry for the new colour layer
        static string InsertBefore = null;       // put it directly above this layer
        static string PreviewUnder = null;       // existing layer to preview on top of

        // ---------- helpers ----------
        static int Hex(string s)
        {
            s = s.TrimStart('#');
            int v = int.Parse(s, NumberStyles.HexNumber);
            return unchecked((int)0xFF000000) | v;
        }
        static int Mix(int a, int b, double t)
        {
            if (t <= 0) return a; if (t >= 1) return b;
            int r = (int)(Img.R(a) + (Img.R(b) - Img.R(a)) * t);
            int g = (int)(Img.G(a) + (Img.G(b) - Img.G(a)) * t);
            int bl = (int)(Img.B(a) + (Img.B(b) - Img.B(a)) * t);
            return Img.Rgba(r, g, bl, 255);
        }
        static double Clamp01(double v) { return v < 0 ? 0 : (v > 1 ? 1 : v); }
        static double Smooth(double t) { t = Clamp01(t); return t * t * (3 - 2 * t); }

        // ---------- zones ----------
        abstract class Zone { public string M; public double RMin = -1, RMax = -1;
            public abstract bool Has(int x, int y); }
        class ZRect : Zone { public int X0, Y0, X1, Y1;
            public override bool Has(int x, int y) { return x >= X0 && x <= X1 && y >= Y0 && y <= Y1; } }
        class ZEll : Zone { public double Cx, Cy, Rx, Ry;
            public override bool Has(int x, int y)
            { double a = (x - Cx) / Rx, b = (y - Cy) / Ry; return a * a + b * b <= 1.0; } }
        class ZPoly : Zone { public int[] Px, Py;
            public override bool Has(int x, int y)
            {
                bool inside = false;
                for (int i = 0, j = Px.Length - 1; i < Px.Length; j = i++)
                    if (((Py[i] > y) != (Py[j] > y)) &&
                        (x < (double)(Px[j] - Px[i]) * (y - Py[i]) / (double)(Py[j] - Py[i]) + Px[i]))
                        inside = !inside;
                return inside;
            } }
        class ZIds : Zone { public HashSet<int> Ids; public override bool Has(int x, int y) { return false; } }
        // assign the region that contains each of these points
        class ZPts : Zone { public List<int> Xs = new List<int>(), Ys = new List<int>();
            public override bool Has(int x, int y) { return false; } }
        // remap regions that already carry material `From` and whose radius is in range
        class ZWhen : Zone { public string From; public override bool Has(int x, int y) { return false; } }

        // ---------- main ----------
        public static string Run(string zip, string cfgPath, string outDir, string outKra)
        {
            var log = new StringBuilder();

            string[] lnames = { "layer2", "layer3", "layer4", "layer5" };
            Img[] layers = Analyze.LoadLayers(zip, W, H, lnames);
            byte[] ink = Analyze.InkAlpha(layers, W, H);

            // gap closing declared in the config (DILATE x0 y0 x1 y1 k / CUT x0 y0 x1 y1 thick),
            // applied to the mask used for region finding only - the drawn ink is untouched
            byte[] mask = (byte[])ink.Clone();
            foreach (string rawLine0 in File.ReadAllLines(cfgPath))
            {
                var t0 = rawLine0.Trim().Split(new char[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
                if (t0.Length == 0 || t0[0].StartsWith("#")) continue;
                if (t0[0] == "DILATE")
                    mask = Close.Dilate(mask, W, H, int.Parse(t0[1]), int.Parse(t0[2]), int.Parse(t0[3]), int.Parse(t0[4]), int.Parse(t0[5]));
                else if (t0[0] == "CUT")
                    Close.Cut(mask, W, H, int.Parse(t0[1]), int.Parse(t0[2]), int.Parse(t0[3]), int.Parse(t0[4]), int.Parse(t0[5]));
            }

            int n;
            int[] lab = Analyze.Label(mask, W, H, 48, out n);
            int[] dist = IdMap.Dist(lab, W, H);
            long[] area; int[] px, py, maxd;
            IdMap.Poles(lab, n, dist, W, H, out area, out px, out py, out maxd);

            // ---- parse config ----
            var mats = new Dictionary<string, Mat>();
            var zones = new List<Zone>();
            var inkFills = new List<string[]>();
            string def = null;
            double glowCx = 1240, glowCy = 430, glowR = 900;
            foreach (string rawLine in File.ReadAllLines(cfgPath))
            {
                string line = rawLine.Trim();
                if (line.Length == 0 || line[0] == '#') continue;
                var t = line.Split(new char[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
                switch (t[0])
                {
                    case "MAT":
                        {
                            var m = new Mat();
                            m.Name = t[1]; m.Base = Hex(t[2]); m.Shadow = Hex(t[3]); m.Light = Hex(t[4]);
                            m.Style = t[5];
                            m.Amount = t.Length > 6 ? double.Parse(t[6], CultureInfo.InvariantCulture) : 1.0;
                            m.Vary = t.Length > 7 ? double.Parse(t[7], CultureInfo.InvariantCulture) : 0.0;
                            mats[m.Name] = m;
                            break;
                        }
                    case "GLOW":
                        glowCx = double.Parse(t[1], CultureInfo.InvariantCulture);
                        glowCy = double.Parse(t[2], CultureInfo.InvariantCulture);
                        glowR = double.Parse(t[3], CultureInfo.InvariantCulture);
                        break;
                    case "DEF": def = t[1]; break;
                    case "NOINK": NoInk = true; break;
                    case "COLORNAME": ColorLayerName = line.Substring(line.IndexOf(' ') + 1).Trim(); break;
                    case "LAYERFILE": LayerFile = t[1]; break;
                    case "INSERTBEFORE": InsertBefore = t[1]; break;
                    case "PREVIEWUNDER": PreviewUnder = t[1]; break;
                    case "INKFILL": inkFills.Add(t); break;
                    case "RECT":
                        {
                            var z = new ZRect { M = t[1], X0 = int.Parse(t[2]), Y0 = int.Parse(t[3]), X1 = int.Parse(t[4]), Y1 = int.Parse(t[5]) };
                            if (t.Length > 7) { z.RMin = double.Parse(t[6], CultureInfo.InvariantCulture); z.RMax = double.Parse(t[7], CultureInfo.InvariantCulture); }
                            zones.Add(z); break;
                        }
                    case "ELL":
                        {
                            var z = new ZEll { M = t[1], Cx = double.Parse(t[2], CultureInfo.InvariantCulture), Cy = double.Parse(t[3], CultureInfo.InvariantCulture), Rx = double.Parse(t[4], CultureInfo.InvariantCulture), Ry = double.Parse(t[5], CultureInfo.InvariantCulture) };
                            if (t.Length > 7) { z.RMin = double.Parse(t[6], CultureInfo.InvariantCulture); z.RMax = double.Parse(t[7], CultureInfo.InvariantCulture); }
                            zones.Add(z); break;
                        }
                    case "POLY":
                        {
                            var xs = new List<int>(); var ys = new List<int>();
                            for (int i = 2; i < t.Length; i++)
                            {
                                var p = t[i].Split(',');
                                xs.Add(int.Parse(p[0])); ys.Add(int.Parse(p[1]));
                            }
                            zones.Add(new ZPoly { M = t[1], Px = xs.ToArray(), Py = ys.ToArray() });
                            break;
                        }
                    case "PT":
                        {
                            var z = new ZPts { M = t[1] };
                            for (int i = 2; i + 1 < t.Length; i += 2)
                            { z.Xs.Add(int.Parse(t[i])); z.Ys.Add(int.Parse(t[i + 1])); }
                            zones.Add(z); break;
                        }
                    case "WHEN":
                        {
                            var z = new ZWhen { From = t[1], M = t[2] };
                            z.RMin = double.Parse(t[3], CultureInfo.InvariantCulture);
                            z.RMax = double.Parse(t[4], CultureInfo.InvariantCulture);
                            zones.Add(z); break;
                        }
                    case "ID":
                        {
                            var ids = new HashSet<int>();
                            for (int i = 2; i < t.Length; i++) ids.Add(int.Parse(t[i]));
                            zones.Add(new ZIds { M = t[1], Ids = ids });
                            break;
                        }
                }
            }

            // ---- assign material per region (by pole point) ----
            string[] rm = new string[n + 1];
            for (int i = 1; i <= n; i++) rm[i] = def;
            foreach (var z in zones)
            {
                var zi = z as ZIds;
                if (zi != null) { for (int i = 1; i <= n; i++) if (zi.Ids.Contains(i)) rm[i] = z.M; continue; }
                var zp = z as ZPts;
                if (zp != null)
                {
                    for (int i = 0; i < zp.Xs.Count; i++)
                    {
                        int l = lab[zp.Ys[i] * W + zp.Xs[i]];
                        if (l != 0) rm[l] = z.M;
                    }
                    continue;
                }
                var zw = z as ZWhen;
                if (zw != null)
                {
                    for (int i = 1; i <= n; i++)
                    {
                        if (rm[i] != zw.From) continue;
                        double rr = maxd[i] / 5.0;
                        if (rr < zw.RMin || rr > zw.RMax) continue;
                        rm[i] = zw.M;
                    }
                    continue;
                }
                for (int i = 1; i <= n; i++)
                {
                    if (!z.Has(px[i], py[i])) continue;
                    double r = maxd[i] / 5.0;
                    if (z.RMin >= 0 && r < z.RMin) continue;
                    if (z.RMax >= 0 && r > z.RMax) continue;
                    rm[i] = z.M;
                }
            }

            // per-region tonal jitter, so flat fills do not read as printed vector
            double[] jit = new double[n + 1];
            for (int i = 1; i <= n; i++)
            {
                uint h = (uint)i * 2654435761u; h ^= h >> 13; h *= 1274126177u; h ^= h >> 16;
                jit[i] = (h % 1000) / 1000.0 - 0.5;   // -0.5 .. +0.5
            }

            // ---- flats + shading ----
            Img col = new Img(W, H);
            // light direction (unit-ish), shadow falls down-right
            const double ux = 0.55, uy = 0.84;
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    int i = y * W + x;
                    int l = lab[i];
                    if (l == 0) continue;
                    Mat m;
                    if (!mats.TryGetValue(rm[l] ?? def, out m)) { col.P[i] = unchecked((int)0xFFFF00FF); continue; }
                    if (m.Style == "NONE") continue;   // left transparent on purpose
                    int bas = m.Base;
                    if (m.Vary > 0)
                    {
                        double v = jit[l] * m.Vary;
                        bas = Mix(bas, v < 0 ? m.Shadow : m.Light, Math.Abs(v));
                    }
                    int c = bas;
                    double d = dist[i] / 5.0;

                    if (m.Style == "FOLD")
                    {
                        double md = Math.Max(6.0, maxd[l] / 5.0);
                        double t = Clamp01(d / (0.55 * md));
                        c = Mix(m.Shadow, bas, Smooth(t));
                        if (t > 0.82) c = Mix(c, m.Light, Smooth((t - 0.82) / 0.18) * 0.55);
                    }
                    else if (m.Style == "CEL")
                    {
                        double wSh = 15.0 * m.Amount, wLi = 9.0 * m.Amount;
                        double kS = March(lab, l, x, y, ux, uy, wSh);
                        double kL = March(lab, l, x, y, -ux, -uy, wLi);
                        double s = 1.0 - Clamp01(kS / wSh);
                        double li = 1.0 - Clamp01(kL / wLi);
                        c = Mix(c, m.Shadow, Smooth(s) * 0.85);
                        c = Mix(c, m.Light, Smooth(li) * 0.40);
                        // slight contact darkening right at the outline
                        if (d < 3.5) c = Mix(c, m.Shadow, (1 - d / 3.5) * 0.20);
                    }
                    else if (m.Style == "GLOW")
                    {
                        double dx = (x - glowCx) / glowR, dy = (y - glowCy) / (glowR * 0.72);
                        double g = Math.Exp(-(dx * dx + dy * dy) * 1.5);
                        c = Mix(bas, m.Light, g * 0.95);
                        double vy = Clamp01((y - 620.0) / 640.0);
                        c = Mix(c, m.Shadow, vy * 0.55);
                    }
                    col.P[i] = c;
                }

            // ---- spread colour under the ink lines ----
            // bounded: the stroke pixels form one connected network across the whole canvas,
            // so an unbounded flood would trail colour along every line in the drawing
            SpreadUnderLines(col, lab, W, H, 3);

            // ---- INKFILL <layerIdx> <hex> <lo> <hi>: fill a drawn shape (the note heads)
            //      with solid colour, only where this layer already paints something ----
            foreach (var f in inkFills)
            {
                Img src = layers[int.Parse(f[1])];
                int fc = Hex(f[2]);
                double lo = double.Parse(f[3], CultureInfo.InvariantCulture);
                double hi = double.Parse(f[4], CultureInfo.InvariantCulture);
                for (int i = 0; i < W * H; i++)
                {
                    if (Img.A(col.P[i]) == 0) continue;
                    double a = Img.A(src.P[i]);
                    double t = Clamp01((a - lo) / (hi - lo));
                    if (t <= 0) continue;
                    col.P[i] = Mix(col.P[i], fc, t);
                }
            }

            // ---- ink layer ----
            Img inkImg = new Img(W, H);
            int inkCol = 0x171210;
            for (int i = 0; i < W * H; i++)
            {
                double a = ink[i];
                double t = Clamp01((a - 22.0) / 66.0);
                t = Math.Pow(t, 0.78);
                int ia = (int)(t * 255 + 0.5);
                if (ia > 0) inkImg.P[i] = (ia << 24) | inkCol;
            }

            // ---- flatten preview ----
            // when we only deliver the colour layer, preview it under the user's own pencil
            // lineart (bottom to top) rather than under our boosted ink
            Img over = inkImg;
            if (NoInk)
            {
                over = new Img(W, H);
                foreach (Img Ly in layers)
                    for (int i = 0; i < W * H; i++)
                    {
                        int sa = Img.A(Ly.P[i]); if (sa == 0) continue;
                        int da = Img.A(over.P[i]);
                        int na = sa + da * (255 - sa) / 255;
                        if (na == 0) continue;
                        int r = (Img.R(Ly.P[i]) * sa + Img.R(over.P[i]) * da * (255 - sa) / 255) / na;
                        int g = (Img.G(Ly.P[i]) * sa + Img.G(over.P[i]) * da * (255 - sa) / 255) / na;
                        int b = (Img.B(Ly.P[i]) * sa + Img.B(over.P[i]) * da * (255 - sa) / 255) / na;
                        over.P[i] = Img.Rgba(r, g, b, na);
                    }
            }

            // preview base: an existing layer of the document, or plain white
            Img baseImg = new Img(W, H);
            if (!string.IsNullOrEmpty(PreviewUnder))
                baseImg = Kra.DecodeLayer(Kra.ReadEntry(zip, "unnamed/layers/" + PreviewUnder), W, H, 0, 0);
            for (int i = 0; i < W * H; i++)
                if (Img.A(baseImg.P[i]) == 0) baseImg.P[i] = unchecked((int)0xFFFFFFFF);

            Img flat = new Img(W, H);
            for (int i = 0; i < W * H; i++)
            {
                int ca = Img.A(col.P[i]);
                int c = ca == 0 ? baseImg.P[i] : col.P[i];
                if (ca > 0 && ca < 255)
                {
                    int br = Img.R(baseImg.P[i]), bg = Img.G(baseImg.P[i]), bb = Img.B(baseImg.P[i]);
                    c = Img.Rgba((Img.R(col.P[i]) * ca + br * (255 - ca)) / 255,
                                 (Img.G(col.P[i]) * ca + bg * (255 - ca)) / 255,
                                 (Img.B(col.P[i]) * ca + bb * (255 - ca)) / 255, 255);
                }
                int a = Img.A(over.P[i]);
                if (a == 0) { flat.P[i] = c; continue; }
                int r = (Img.R(over.P[i]) * a + Img.R(c) * (255 - a)) / 255;
                int g = (Img.G(over.P[i]) * a + Img.G(c) * (255 - a)) / 255;
                int b = (Img.B(over.P[i]) * a + Img.B(c) * (255 - a)) / 255;
                flat.P[i] = Img.Rgba(r, g, b, 255);
            }
            flat.Save(Path.Combine(outDir, "portada_pintada.png"));
            col.Save(Path.Combine(outDir, "flats.png"));

            // debug: painted result with region ids on top
            Img dbg = flat.Clone();
            for (int i = 1; i <= n; i++)
                if (area[i] >= 100)
                    Glyph.DrawNum(dbg, i, px[i], py[i], unchecked((int)0xFF000000), unchecked((int)0xFFFFFFFF));
            dbg.Save(Path.Combine(outDir, "debug_ids.png"));

            // ---- write .kra ----
            if (!string.IsNullOrEmpty(outKra)) WriteKra(zip, outKra, col, NoInk ? null : inkImg, flat);

            // report unassigned / magenta
            int bad = 0;
            for (int i = 1; i <= n; i++) if (rm[i] == null || !mats.ContainsKey(rm[i])) bad++;
            log.AppendLine("regions=" + n + " sin material=" + bad);
            return log.ToString();
        }

        /// distance (px) travelled from (x,y) along (ux,uy) while staying in region l, capped at max
        static double March(int[] lab, int l, int x, int y, double ux, double uy, double max)
        {
            for (double k = 1; k <= max; k += 1.0)
            {
                int nx = (int)(x + ux * k + 0.5), ny = (int)(y + uy * k + 0.5);
                if (nx < 0 || ny < 0 || nx >= W || ny >= H) return k;
                if (lab[ny * W + nx] != l) return k;
            }
            return max + 1;
        }

        /// BFS-fill colour from painted pixels into the line pixels
        static void SpreadUnderLines(Img col, int[] lab, int w, int h, int steps)
        {
            bool[] done = new bool[w * h];
            var cur = new List<int>();
            // every region pixel is a wall (the bleed must stay inside the line strokes),
            // but only the painted ones seed it - so deliberately transparent areas stay clear
            for (int i = 0; i < w * h; i++) if (lab[i] != 0) done[i] = true;
            for (int i = 0; i < w * h; i++) if (lab[i] != 0 && ((col.P[i] >> 24) & 255) != 0) cur.Add(i);
            for (int s = 0; s < steps; s++)
            {
                var next = new List<int>();
                foreach (int p in cur)
                {
                    int x = p % w, y = p / w, c = col.P[p];
                    if (x > 0) { int t = p - 1; if (!done[t]) { done[t] = true; col.P[t] = c; next.Add(t); } }
                    if (x < w - 1) { int t = p + 1; if (!done[t]) { done[t] = true; col.P[t] = c; next.Add(t); } }
                    if (y > 0) { int t = p - w; if (!done[t]) { done[t] = true; col.P[t] = c; next.Add(t); } }
                    if (y < h - 1) { int t = p + w; if (!done[t]) { done[t] = true; col.P[t] = c; next.Add(t); } }
                }
                cur = next;
            }
        }

        // ---------- kra writing ----------
        static void WriteKra(string srcZip, string dstPath, Img color, Img inkLayer, Img flatPreview)
        {
            byte[] colBlob = Kra.EncodeLayer(color);
            byte[] inkBlob = inkLayer == null ? null : Kra.EncodeLayer(inkLayer);
            byte[] icc = Kra.ReadEntry(srcZip, "unnamed/layers/layer2.icc");
            byte[] zero4 = new byte[4];

            string doc = Encoding.UTF8.GetString(Kra.ReadEntry(srcZip, "maindoc.xml"));
            string colLayer = "   <layer opacity=\"255\" onionskin=\"0\" name=\"" + ColorLayerName + "\" channelflags=\"\" visible=\"1\" x=\"0\" intimeline=\"0\" channellockflags=\"\" locked=\"0\" filename=\"" + LayerFile + "\" y=\"0\" uuid=\"{b1c0de00-0000-4000-8000-0000000000" + LayerFile.Substring(LayerFile.Length - 2).PadLeft(2, '0') + "}\" colorspacename=\"RGBA\" nodetype=\"paintlayer\" compositeop=\"normal\" colorlabel=\"0\" collapsed=\"0\"/>\n";
            string inkLayerXml = "   <layer opacity=\"255\" onionskin=\"0\" name=\"Tinta\" channelflags=\"\" visible=\"1\" x=\"0\" intimeline=\"0\" channellockflags=\"\" locked=\"0\" filename=\"layer7\" y=\"0\" uuid=\"{b1c0de00-0000-4000-8000-000000000007}\" colorspacename=\"RGBA\" nodetype=\"paintlayer\" compositeop=\"normal\" colorlabel=\"0\" collapsed=\"0\"/>\n";
            // In a .kra the FIRST <layer> of the list is the TOP one. INSERTBEFORE puts the new
            // layer directly above the named one; with no target it goes to the bottom.
            int at;
            if (!string.IsNullOrEmpty(InsertBefore))
            {
                int p = doc.IndexOf("filename=\"" + InsertBefore + "\"");
                if (p < 0) throw new Exception("no encuentro la capa " + InsertBefore);
                at = doc.LastIndexOf('\n', p) + 1;
            }
            else
            {
                int end0 = doc.IndexOf("</layers>");
                at = doc.LastIndexOf('\n', end0) + 1;
            }
            doc = doc.Substring(0, at) + colLayer + doc.Substring(at);
            if (inkBlob != null)
            {
                int end = doc.IndexOf("</layers>");
                int ls = doc.LastIndexOf('\n', end) + 1;   // back up to the start of that line
                doc = doc.Substring(0, ls) + inkLayerXml + doc.Substring(ls);
            }

            var extra = new Dictionary<string, byte[]>();
            extra["maindoc.xml"] = Encoding.UTF8.GetBytes(doc);
            extra["unnamed/layers/" + LayerFile] = colBlob;
            extra["unnamed/layers/" + LayerFile + ".defaultpixel"] = zero4;
            extra["unnamed/layers/" + LayerFile + ".icc"] = icc;
            if (inkBlob != null)
            {
                extra["unnamed/layers/layer7"] = inkBlob;
                extra["unnamed/layers/layer7.defaultpixel"] = zero4;
                extra["unnamed/layers/layer7.icc"] = icc;
            }

            using (var ms = new MemoryStream())
            {
                flatPreview.Save(Path.Combine(Path.GetTempPath(), "_kra_merged.png"));
                extra["mergedimage.png"] = File.ReadAllBytes(Path.Combine(Path.GetTempPath(), "_kra_merged.png"));
            }

            if (File.Exists(dstPath)) File.Delete(dstPath);
            var order = new List<string>();
            var src = new Dictionary<string, byte[]>();
            foreach (string e in Kra.ListEntries(srcZip)) { order.Add(e); src[e] = Kra.ReadEntry(srcZip, e); }
            foreach (var kv in extra) if (!order.Contains(kv.Key)) order.Add(kv.Key);

            using (var fs = new FileStream(dstPath, FileMode.Create))
            using (var z = new System.IO.Compression.ZipArchive(fs, System.IO.Compression.ZipArchiveMode.Create))
            {
                // mimetype first, stored
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
