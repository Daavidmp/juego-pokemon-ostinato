using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

// Portada de Pokemon Ostinato, segunda version.
// Parte del aplanado limpio del .kra (2484x1200) y hace un acabado SUAVE: nada de
// enfoque ni contraste local, que eran los que dejaban halos y ruido en la anterior.
public static class Portada3
{
    static float[] Cargar(Bitmap b, out int w, out int h)
    {
        w = b.Width; h = b.Height;
        var d = b.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        var raw = new byte[w * h * 4];
        Marshal.Copy(d.Scan0, raw, 0, raw.Length);
        b.UnlockBits(d);
        var f = new float[w * h * 3];
        for (int i = 0; i < w * h; i++)
        {
            f[i * 3] = raw[i * 4 + 2] / 255f; f[i * 3 + 1] = raw[i * 4 + 1] / 255f; f[i * 3 + 2] = raw[i * 4] / 255f;
        }
        return f;
    }

    static Bitmap Guardar(float[] f, int w, int h)
    {
        var raw = new byte[w * h * 4];
        for (int i = 0; i < w * h; i++)
        {
            raw[i * 4 + 2] = B(f[i * 3]); raw[i * 4 + 1] = B(f[i * 3 + 1]); raw[i * 4] = B(f[i * 3 + 2]); raw[i * 4 + 3] = 255;
        }
        var b = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        var d = b.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        Marshal.Copy(raw, 0, d.Scan0, raw.Length);
        b.UnlockBits(d);
        return b;
    }

    static byte B(float v) { v = v < 0 ? 0 : (v > 1 ? 1 : v); return (byte)(v * 255f + 0.5f); }

    // Desenfoque de caja separable, tres pasadas (casi gaussiano), sobre un canal.
    static float[] Blur(float[] src, int w, int h, int r)
    {
        var a = (float[])src.Clone(); var t = new float[w * h];
        for (int pass = 0; pass < 3; pass++)
        {
            for (int y = 0; y < h; y++)
            {
                float s = 0; int n = 0;
                for (int x = -r; x <= r; x++) if (x >= 0 && x < w) { s += a[y * w + x]; n++; }
                for (int x = 0; x < w; x++)
                {
                    t[y * w + x] = s / n;
                    int xo = x - r, xi = x + r + 1;
                    if (xo >= 0) { s -= a[y * w + xo]; n--; }
                    if (xi < w) { s += a[y * w + xi]; n++; }
                }
            }
            for (int x = 0; x < w; x++)
            {
                float s = 0; int n = 0;
                for (int y = -r; y <= r; y++) if (y >= 0 && y < h) { s += t[y * w + x]; n++; }
                for (int y = 0; y < h; y++)
                {
                    a[y * w + x] = s / n;
                    int yo = y - r, yi = y + r + 1;
                    if (yo >= 0) { s -= t[yo * w + x]; n--; }
                    if (yi < h) { s += t[yi * w + x]; n++; }
                }
            }
        }
        return a;
    }

    static float Smooth(float e0, float e1, float x) { float t = (x - e0) / (e1 - e0); t = t < 0 ? 0 : (t > 1 ? 1 : t); return t * t * (3 - 2 * t); }

    public static string Hacer(string entrada, string salida, int btnX0, int btnY0, int btnX1, int btnY1)
    {
        int w, h;
        float[] f;
        using (var src = new Bitmap(entrada)) f = Cargar(src, out w, out h);

        // 1. El boton de "pulsa para continuar" va aparte en el juego (latiendo): se borra
        //    rellenando cada fila con el degradado entre sus dos lados. El fondo ahi es liso.
        for (int y = btnY0; btnX1 > btnX0 && y <= btnY1; y++)
            for (int c = 0; c < 3; c++)
            {
                float l = 0, r = 0;
                for (int k = 1; k <= 4; k++) { l += f[(y * w + btnX0 - k) * 3 + c]; r += f[(y * w + btnX1 + k) * 3 + c]; }
                l /= 4; r /= 4;
                for (int x = btnX0; x <= btnX1; x++)
                {
                    float t = (x - btnX0) / (float)(btnX1 - btnX0);
                    f[(y * w + x) * 3 + c] = l + (r - l) * t;
                }
            }

        // 2. Mascara de lo que NO es el fondo azul del escenario (letras, cinta, cartel,
        //    logo, hilos, telon). Sirve para la sombra proyectada sobre el fondo.
        var fig = new float[w * h];
        for (int i = 0; i < w * h; i++)
        {
            float R = f[i * 3], G = f[i * 3 + 1], Bl = f[i * 3 + 2];
            // el fondo es azul o gris lavanda donde le da el foco; todo lo que tira a
            // calido (madera, papel, telon, hilos, amarillo del logo) es figura
            bool fondo = Bl >= R - 0.01f && (R + G + Bl) < 2.2f;
            fig[i] = fondo ? 0 : 1;
        }
        var fondoM = Blur(Array.ConvertAll(fig, v => 1 - v), w, h, 1);

        // 3. Sombra proyectada: la figura desplazada abajo a la derecha, con una sombra de
        //    contacto corta y otra larga y blanda. Solo se aplica sobre el fondo.
        int dx = (int)(w * 0.008), dy = (int)(h * 0.018);
        var mov = new float[w * h];
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                int sx = x - dx, sy = y - dy;
                mov[y * w + x] = (sx >= 0 && sy >= 0) ? fig[sy * w + sx] : 0;
            }
        float esc = w / 2484f;               // radios pensados para el lienzo de 2484
        var corta = Blur(mov, w, h, Math.Max(2, (int)(5 * esc)));
        var larga = Blur(mov, w, h, Math.Max(6, (int)(22 * esc)));

        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                int i = y * w + x;
                float nx = x / (float)w, ny = y / (float)h;
                float R = f[i * 3], G = f[i * 3 + 1], Bl = f[i * 3 + 2];

                // sombra (solo en el fondo)
                float sombra = (0.22f * corta[i] + 0.20f * larga[i]) * fondoM[i];
                float k = 1 - sombra;
                R *= k; G *= k; Bl *= k * 0.98f + 0.02f * 0; // la sombra, un pelin fria

                // foco calido desde arriba al centro del escenario, y viñeta fria suave
                float d = (float)Math.Sqrt((nx - 0.5f) * (nx - 0.5f) * 1.2f + (ny - 0.30f) * (ny - 0.30f) * 1.6f);
                float foco = 1 - Smooth(0.0f, 0.62f, d);
                R += foco * 0.045f; G += foco * 0.030f; Bl += foco * 0.008f;
                float vin = Smooth(0.45f, 0.95f, d);
                R *= 1 - 0.20f * vin; G *= 1 - 0.18f * vin; Bl *= 1 - 0.12f * vin;

                // un poco mas de color, sin quemar
                float lum = 0.299f * R + 0.587f * G + 0.114f * Bl;
                const float sat = 1.08f;
                R = lum + (R - lum) * sat; G = lum + (G - lum) * sat; Bl = lum + (Bl - lum) * sat;

                // curva de contraste muy suave, con las luces protegidas (el papel no se quema)
                R = Curva(R); G = Curva(G); Bl = Curva(Bl);
                f[i * 3] = R; f[i * 3 + 1] = G; f[i * 3 + 2] = Bl;
            }

        using (var res = Guardar(f, w, h)) res.Save(salida, ImageFormat.Png);
        return w + "x" + h;
    }

    static float Curva(float v)
    {
        v = v < 0 ? 0 : (v > 1 ? 1 : v);
        float s = v * v * (3 - 2 * v);        // S
        float o = v + (s - v) * 0.18f;        // solo un 18 % de S
        if (o > 0.92f) o = 0.92f + (o - 0.92f) * 0.6f;   // techo suave en las luces
        return o;
    }

    // Compone el lienzo de 1920x1080: el dibujo ajustado por ancho a 1920x928 en y=76 y,
    // en las franjas de arriba y abajo, el propio dibujo muy desenfocado y oscurecido, con
    // la costura fundida. Asi la pantalla entera tiene imagen y no bandas planas.
    public static string Componer(string entrada, string salida, int W, int H, int ih, int iy)
    {
        using (var src = new Bitmap(entrada))
        using (var img = new Bitmap(W, ih, PixelFormat.Format32bppArgb))
        {
            using (var g = Graphics.FromImage(img))
            {
                g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
                g.CompositingQuality = System.Drawing.Drawing2D.CompositingQuality.HighQuality;
                using (var ia = new ImageAttributes())
                {
                    ia.SetWrapMode(System.Drawing.Drawing2D.WrapMode.TileFlipXY);
                    g.DrawImage(src, new Rectangle(0, 0, W, ih), 0, 0, src.Width, src.Height, GraphicsUnit.Pixel, ia);
                }
            }
            int iw, ihh; var nit = Cargar(img, out iw, out ihh);

            // fondo: el dibujo estirado a pantalla completa, muy desenfocado y oscuro
            var fondo = new float[W * H * 3];
            for (int y = 0; y < H; y++)
            {
                float sy = (y + 0.5f) * ih / (float)H - 0.5f;
                int y0 = (int)Math.Max(0, Math.Min(ih - 1, Math.Floor(sy)));
                for (int x = 0; x < W; x++)
                    for (int c = 0; c < 3; c++) fondo[(y * W + x) * 3 + c] = nit[(y0 * W + x) * 3 + c];
            }
            for (int c = 0; c < 3; c++)
            {
                var ch = new float[W * H];
                for (int i = 0; i < W * H; i++) ch[i] = fondo[i * 3 + c];
                ch = Blur(ch, W, H, 28);
                for (int i = 0; i < W * H; i++) fondo[i * 3 + c] = ch[i];
            }

            var outp = new float[W * H * 3];
            const int FUNDIDO = 14;
            for (int y = 0; y < H; y++)
            {
                // cuanto se oscurece la franja: mas cuanto mas lejos del dibujo
                float dist = y < iy ? (iy - y) : (y >= iy + ih ? y - (iy + ih - 1) : 0);
                float osc = 0.42f * (1 - 0.55f * Smooth(0, iy, dist));
                int yi = y - iy;
                float a = 0;
                if (yi >= 0 && yi < ih)
                {
                    a = 1;
                    if (yi < FUNDIDO) a = Smooth(0, FUNDIDO, yi + 0.5f);
                    else if (yi >= ih - FUNDIDO) a = Smooth(0, FUNDIDO, ih - yi - 0.5f);
                }
                for (int x = 0; x < W; x++)
                    for (int c = 0; c < 3; c++)
                    {
                        float fb = fondo[(y * W + x) * 3 + c] * osc;
                        float nv = a > 0 ? nit[(yi * W + x) * 3 + c] : 0;
                        outp[(y * W + x) * 3 + c] = fb * (1 - a) + nv * a;
                    }
            }
            using (var res = Guardar(outp, W, H)) res.Save(salida, ImageFormat.Png);
        }
        return W + "x" + H;
    }
}
