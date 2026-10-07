using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;

namespace KraLib
{
    public static class Render
    {
        const int CW = 2484, CH = 1200;

        static void Over(Img dst, Img src)
        {
            for (int i = 0; i < CW * CH; i++)
            {
                int a = Img.A(src.P[i]); if (a == 0) continue;
                if (a == 255) { dst.P[i] = src.P[i]; continue; }
                int d = dst.P[i];
                dst.P[i] = Img.Rgba(
                    (Img.R(src.P[i]) * a + Img.R(d) * (255 - a)) / 255,
                    (Img.G(src.P[i]) * a + Img.G(d) * (255 - a)) / 255,
                    (Img.B(src.P[i]) * a + Img.B(d) * (255 - a)) / 255, 255);
            }
        }

        public static string Run(string kra, string pathXs, string pathYs, string outDir,
                                 int frames, int outW, int outH, int quality, bool loopNotes)
        {
            Directory.CreateDirectory(outDir);

            // --- layers, bottom to top ---
            Img fondo = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/layer11"), CW, CH, 0, 0);
            Img telon = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/layer10"), CW, CH, 0, 0);
            Img letras = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/layer9"), CW, CH, 0, 0);
            Img papel = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/layer8"), CW, CH, 0, 0);
            Img madera = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/layer7"), CW, CH, 0, 0);
            Img lin5 = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/layer5"), CW, CH, 0, 0);
            Img notesL = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/layer4"), CW, CH, 0, 0);
            Img lin3 = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/layer3"), CW, CH, 0, 0);
            Img lin2 = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/layer2"), CW, CH, 0, 0);

            // the "press to continue" button, lifted out so it can pulse on its own
            Img boton = Anim.CutOut(letras, 1785, 893, 2158, 1008);

            // the note fills baked into the colour layer have to go too, or the notes would
            // leave their own shadow behind as they move
            Img plain = Img.Load(Path.Combine(Path.GetDirectoryName(outDir), "letras_sin_notas.png"));
            for (int i = 0; i < CW * CH; i++)
                if (Img.A(notesL.P[i]) >= 45) letras.P[i] = plain.P[i];

            // --- lighting, split so the key light can breathe without the vignette moving ---
            Img glow = Luz.Build(58, 6, 0);
            Img vig = Luz.Build(0, 0, 68);

            // --- ribbon path and note sprites ---
            var xs = new List<double>(); foreach (var t in pathXs.Split(',')) xs.Add(double.Parse(t));
            var ys = new List<double>(); foreach (var t in pathYs.Split(',')) ys.Add(double.Parse(t));
            byte[] band = Cinta.MaskOf(Path.Combine(Path.GetDirectoryName(outDir), "mask_cinta.png"),
                                       Path.Combine(Path.GetDirectoryName(outDir), "notas.png"), 5);
            var path = Cinta.FromPolyline(band, xs.ToArray(), ys.ToArray(), 4, 95);
            double total = path[path.Count - 1].S;
            var notas = Anim.Extract(notesL, 25, 40);
            Anim.Place(path, notas);

            // --- static plate: everything that never changes ---
            Img plate = new Img(CW, CH);
            for (int i = 0; i < CW * CH; i++) plate.P[i] = unchecked((int)0xFF000000);
            Over(plate, fondo); Over(plate, telon); Over(plate, letras);

            int cropW = (int)Math.Round(CH * (double)outW / outH);
            int cropX = (CW - cropW) / 2;

            for (int f = 0; f < frames; f++)
            {
                double u = (double)f / frames;              // 0..1 around the loop
                Img fr = plate.Clone();

                // button: a slow breath plus a brighter beat, the usual "press me"
                double puls = 0.72 + 0.28 * Math.Sin(u * Math.PI * 2 * 2);
                Anim.OverScaled(fr, boton, 0.55 + 0.45 * puls, 1.0 + 0.020 * puls, 1970, 950);

                Over(fr, papel); Over(fr, madera);
                Over(fr, vig);
                double breathe = 0.86 + 0.14 * Math.Sin(u * Math.PI * 2) + 0.05 * Math.Sin(u * Math.PI * 2 * 3 + 1.1);
                Anim.OverScaled(fr, glow, breathe, 1, 0, 0);
                Over(fr, lin5);

                // the notes drift along the staff
                double shift = loopNotes ? u * total : 0;
                foreach (var n in notas)
                    Anim.DrawNote(fr, n, path, n.S0 + shift, band, 110, 1.0);

                Over(fr, lin3); Over(fr, lin2);

                Save(fr, cropX, cropW, outW, outH, Path.Combine(outDir, string.Format("{0:0000}.jpg", f)), quality);
            }
            return "fotogramas=" + frames + "  notas=" + notas.Count + "  longitud=" + (int)total;
        }

        /// Still cover for the title screen, fitted by WIDTH so nothing of the canvas is cut:
        /// the drawing keeps its 2484x1200 proportions and the leftover top and bottom are
        /// filled with the dark of the theatre.
        public static string Still2(string kra, string outDir, int outW, int outH, string colorLayer)
        {
            string[] order = { "layer13", "layer10", colorLayer, "layer8", "layer7", null, "layer5", "layer4", "layer3", "layer2" };
            int bx0 = 1785, by0 = 893, bx1 = 2158, by1 = 1008;

            Img fr = new Img(CW, CH);
            for (int i = 0; i < CW * CH; i++) fr.P[i] = unchecked((int)0xFF000000);
            Img boton = null;
            foreach (string ln in order)
            {
                if (ln == null)
                {
                    Over(fr, Luz.Build(0, 0, 68));
                    Over(fr, Luz.Build(58, 6, 0));
                    continue;
                }
                Img L = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/" + ln), CW, CH, 0, 0);
                if (ln == colorLayer) boton = Anim.CutOut(L, bx0, by0, bx1, by1);
                Over(fr, L);
            }

            double k = (double)outW / CW;
            int ch2 = (int)Math.Round(CH * k);
            int yOff = (outH - ch2) / 2;

            using (var big = new Bitmap(CW, CH, PixelFormat.Format32bppArgb))
            {
                var bd = big.LockBits(new Rectangle(0, 0, CW, CH), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                System.Runtime.InteropServices.Marshal.Copy(fr.P, 0, bd.Scan0, fr.P.Length);
                big.UnlockBits(bd);
                using (var small = new Bitmap(outW, outH, PixelFormat.Format24bppRgb))
                using (var g = Graphics.FromImage(small))
                {
                    g.Clear(Color.FromArgb(7, 10, 18));
                    g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                    g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
                    g.DrawImage(big, new Rectangle(0, yOff, outW, ch2), new Rectangle(0, 0, CW, CH), GraphicsUnit.Pixel);
                    var enc = GetJpeg();
                    var ps = new EncoderParameters(1);
                    ps.Param[0] = new EncoderParameter(Encoder.Quality, 92L);
                    small.Save(Path.Combine(outDir, "OstinatoPortada.jpg"), enc, ps);
                }
            }

            int sw = (int)Math.Round((bx1 - bx0 + 1) * k), sh = (int)Math.Round((by1 - by0 + 1) * k);
            using (var big = new Bitmap(CW, CH, PixelFormat.Format32bppArgb))
            {
                var bd = big.LockBits(new Rectangle(0, 0, CW, CH), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                System.Runtime.InteropServices.Marshal.Copy(boton.P, 0, bd.Scan0, boton.P.Length);
                big.UnlockBits(bd);
                using (var small = new Bitmap(sw, sh, PixelFormat.Format32bppArgb))
                using (var g = Graphics.FromImage(small))
                {
                    g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                    g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
                    g.DrawImage(big, new Rectangle(0, 0, sw, sh), new Rectangle(bx0, by0, bx1 - bx0 + 1, by1 - by0 + 1), GraphicsUnit.Pixel);
                    small.Save(Path.Combine(outDir, "OstinatoPulsa.png"), ImageFormat.Png);
                }
            }
            return string.Format("portada {0}x{1} (dibujo {0}x{2} en y={3}); boton {4}x{5} en ({6},{7}); escala={8:0.00000}",
                outW, outH, ch2, yOff, sw, sh, (int)Math.Round(bx0 * k), yOff + (int)Math.Round(by0 * k), k);
        }

        /// One still cover (no note motion, no button) plus the button on its own, both already
        /// scaled and positioned for the game screen.
        public static string Still(string kra, string outDir, int outW, int outH)
        {
            Img fondo = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/layer11"), CW, CH, 0, 0);
            Img telon = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/layer10"), CW, CH, 0, 0);
            Img letras = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/layer9"), CW, CH, 0, 0);
            Img papel = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/layer8"), CW, CH, 0, 0);
            Img madera = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/layer7"), CW, CH, 0, 0);
            Img lin5 = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/layer5"), CW, CH, 0, 0);
            Img notesL = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/layer4"), CW, CH, 0, 0);
            Img lin3 = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/layer3"), CW, CH, 0, 0);
            Img lin2 = Kra.DecodeLayer(Kra.ReadEntry(kra, "unnamed/layers/layer2"), CW, CH, 0, 0);

            int bx0 = 1785, by0 = 893, bx1 = 2158, by1 = 1008;
            Img boton = Anim.CutOut(letras, bx0, by0, bx1, by1);

            Img fr = new Img(CW, CH);
            for (int i = 0; i < CW * CH; i++) fr.P[i] = unchecked((int)0xFF000000);
            Over(fr, fondo); Over(fr, telon); Over(fr, letras);
            Over(fr, papel); Over(fr, madera);
            Over(fr, Luz.Build(0, 0, 68));
            Over(fr, Luz.Build(58, 6, 0));
            Over(fr, lin5); Over(fr, notesL); Over(fr, lin3); Over(fr, lin2);

            int cropW = (int)Math.Round(CH * (double)outW / outH);
            int cropX = (CW - cropW) / 2;
            double k = (double)outW / cropW;
            Save(fr, cropX, cropW, outW, outH, Path.Combine(outDir, "OstinatoPortada.jpg"), 92);

            // the button, cropped tight and scaled the same way as the cover
            int sw = (int)Math.Round((bx1 - bx0 + 1) * k), sh = (int)Math.Round((by1 - by0 + 1) * k);
            using (var big = new Bitmap(CW, CH, PixelFormat.Format32bppArgb))
            {
                var bd = big.LockBits(new Rectangle(0, 0, CW, CH), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                System.Runtime.InteropServices.Marshal.Copy(boton.P, 0, bd.Scan0, boton.P.Length);
                big.UnlockBits(bd);
                using (var small = new Bitmap(sw, sh, PixelFormat.Format32bppArgb))
                using (var g = Graphics.FromImage(small))
                {
                    g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                    g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
                    g.DrawImage(big, new Rectangle(0, 0, sw, sh), new Rectangle(bx0, by0, bx1 - bx0 + 1, by1 - by0 + 1), GraphicsUnit.Pixel);
                    small.Save(Path.Combine(outDir, "OstinatoPulsa.png"), ImageFormat.Png);
                }
            }
            int px = (int)Math.Round((bx0 - cropX) * k), py = (int)Math.Round(by0 * k);
            return string.Format("portada {0}x{1}; boton {2}x{3} en ({4},{5})", outW, outH, sw, sh, px, py);
        }

        static void Save(Img src, int cropX, int cropW, int outW, int outH, string path, int quality)
        {
            using (var big = new Bitmap(CW, CH, PixelFormat.Format32bppArgb))
            {
                var bd = big.LockBits(new Rectangle(0, 0, CW, CH), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                System.Runtime.InteropServices.Marshal.Copy(src.P, 0, bd.Scan0, src.P.Length);
                big.UnlockBits(bd);
                using (var small = new Bitmap(outW, outH, PixelFormat.Format24bppRgb))
                using (var g = Graphics.FromImage(small))
                {
                    g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                    g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
                    g.DrawImage(big, new Rectangle(0, 0, outW, outH), new Rectangle(cropX, 0, cropW, CH), GraphicsUnit.Pixel);
                    var enc = GetJpeg();
                    var ps = new EncoderParameters(1);
                    ps.Param[0] = new EncoderParameter(Encoder.Quality, (long)quality);
                    small.Save(path, enc, ps);
                }
            }
        }

        static ImageCodecInfo GetJpeg()
        {
            foreach (var c in ImageCodecInfo.GetImageEncoders()) if (c.MimeType == "image/jpeg") return c;
            return null;
        }
    }
}
