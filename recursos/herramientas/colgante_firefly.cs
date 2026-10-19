using System; using System.Drawing; using System.Drawing.Imaging;
// El colgante de Kaia tal como lo dibujo Firefly (sin lineas puestas a mano):
//   [ColganteFF]::Mezclar(original, sin_colgantes, trozos, salida)
//     parte de la hoja sin colgantes y pega de la original los trozos "x y w h" (separados por ';'),
//     con 6 px de fundido en el borde (los dos son la misma imagen salvo lo retocado)
//   [ColganteFF]::Arcoiris(hoja, cajas, salida)
//     la gema azul de cada caja "x y w h" (';') pasa a piedra activadora: el tono va de rosa a amarillo, verde y
//     azul en diagonal, y se quedan las luces y sombras que dibujo Firefly. Devuelve el centro de cada gema.
public static class ColganteFF {
  public static string Mezclar(string orig, string sin, string trozos, string sal){
    var a = new Bitmap(orig); var b = new Bitmap(sin);
    var o = new Bitmap(b.Width, b.Height, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(o)) g.DrawImage(b, 0, 0, b.Width, b.Height);
    foreach (var t in trozos.Split(';')) {
      var v = t.Trim().Split(' '); int x0 = int.Parse(v[0]), y0 = int.Parse(v[1]), w = int.Parse(v[2]), h = int.Parse(v[3]);
      for (int y = y0; y < y0 + h; y++) for (int x = x0; x < x0 + w; x++) {
        double m = Math.Min(1, Math.Min(Math.Min(x - x0, x0 + w - 1 - x), Math.Min(y - y0, y0 + h - 1 - y)) / 6.0);
        var ca = a.GetPixel(x, y); var cb = o.GetPixel(x, y);
        o.SetPixel(x, y, Color.FromArgb(255, (int)(cb.R + (ca.R - cb.R) * m), (int)(cb.G + (ca.G - cb.G) * m), (int)(cb.B + (ca.B - cb.B) * m)));
      }
    }
    o.Save(sal, ImageFormat.Png);
    return "mezcla ok";
  }

  static Color Hsv(double h, double s, double v){
    h = ((h % 360) + 360) % 360; double c = v * s, x = c * (1 - Math.Abs((h / 60) % 2 - 1)), m = v - c, r = 0, g = 0, b = 0;
    if (h < 60) { r = c; g = x; } else if (h < 120) { r = x; g = c; } else if (h < 180) { g = c; b = x; }
    else if (h < 240) { g = x; b = c; } else if (h < 300) { r = x; b = c; } else { r = c; b = x; }
    return Color.FromArgb(255, (int)((r + m) * 255), (int)((g + m) * 255), (int)((b + m) * 255));
  }

  public static string Arcoiris(string hoja, string cajas, string sal){
    var o = new Bitmap(hoja); string r = "";
    foreach (var t in cajas.Split(';')) {
      var v = t.Trim().Split(' '); int x0 = int.Parse(v[0]), y0 = int.Parse(v[1]), w = int.Parse(v[2]), h = int.Parse(v[3]);
      long sx = 0, sy = 0; int n = 0;
      for (int y = y0; y < y0 + h; y++) for (int x = x0; x < x0 + w; x++) {
        var c = o.GetPixel(x, y);
        bool azul = c.B > c.R + 40 && c.B > c.G + 10;
        bool brillo = c.R > 200 && c.G > 220 && c.B > 235;          // las luces blancas de la gema se quedan
        if (!azul || brillo) continue;
        sx += x; sy += y; n++;
      }
      if (n == 0) { r += "(nada) "; continue; }
      int cx = (int)(sx / n), cy = (int)(sy / n); double rad = Math.Sqrt(n / Math.PI) + 1;
      for (int y = y0; y < y0 + h; y++) for (int x = x0; x < x0 + w; x++) {
        var c = o.GetPixel(x, y);
        if (!(c.B > c.R + 40 && c.B > c.G + 10)) continue;
        double lum = (0.3 * c.R + 0.59 * c.G + 0.11 * c.B) / 255.0;
        double d = ((x - cx) + (y - cy)) / (2 * rad) + 0.5;          // 0 arriba a la izquierda, 1 abajo a la derecha
        d = Math.Min(1, Math.Max(0, d));
        o.SetPixel(x, y, Hsv(320 + d * 250, 0.72, Math.Min(1, 0.35 + lum * 1.1)));
      }
      r += cx + "," + cy + " ";
    }
    o.Save(sal, ImageFormat.Png);
    return r.Trim();
  }
}
