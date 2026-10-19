using System; using System.Drawing; using System.Drawing.Imaging;
// El colgante con la piedra activadora en la tira de Kaia (la de tira_pixel.cs), pixel a pixel:
//   [Colgante]::Poner(tira, cuadro_ancho, spec, salida, muestra, zoom)
//   spec: un cuadro por linea "px py  ax ay  bx by"  (centro de la piedra; los dos puntos de donde sale el
//         cordon: el cuello o el puño; "-" si no hay cordon). Tambien quita los restos verdes del fondo.
public static class Colgante {
  static readonly string[] PIEDRA = {
    "..ooooo..",
    ".osssssO.",
    "osPPWBBso",
    "osPWBBGso",
    "osWBBGGso",
    "osBBGGYso",
    "osBGGYYso",
    ".osssssO.",
    "..ooooo.." };
  static Color De(char c){
    switch (c) {
      case 'o': return Color.FromArgb(255, 38, 28, 48);
      case 'O': return Color.FromArgb(255, 38, 28, 48);
      case 's': return Color.FromArgb(255, 205, 210, 222);
      case 'P': return Color.FromArgb(255, 238, 110, 200);
      case 'W': return Color.FromArgb(255, 255, 255, 255);
      case 'B': return Color.FromArgb(255, 90, 170, 245);
      case 'G': return Color.FromArgb(255, 50, 185, 120);    // verde azulado: el verde claro se confunde con el fondo de Firefly
      case 'Y': return Color.FromArgb(255, 240, 225, 90);
    }
    return Color.Transparent;
  }
  static void Linea(Bitmap b, int x0, int y0, int x1, int y1, Color c, int g){
    int dx = Math.Abs(x1 - x0), sx = x0 < x1 ? 1 : -1, dy = -Math.Abs(y1 - y0), sy = y0 < y1 ? 1 : -1, e = dx + dy;
    while (true) { for (int yy = y0; yy < y0 + g; yy++) for (int xx = x0; xx < x0 + g; xx++) if (xx >= 0 && yy >= 0 && xx < b.Width && yy < b.Height) b.SetPixel(xx, yy, c);
      if (x0 == x1 && y0 == y1) break; int e2 = 2 * e; if (e2 >= dy) { e += dy; x0 += sx; } if (e2 <= dx) { e += dx; y0 += sy; } }
  }
  // el colgante en un cuadro: piedra centrada en (px, py) y, si hay, la cadena desde (c0,c1) y (c2,c3)
  public static void Dibujar(Bitmap b, int px, int py, int[] cad, int bloque){
    int L = PIEDRA.Length, R = L / 2;
    var cordon = Color.FromArgb(255, 196, 200, 215);   // cadena plateada (se ve sobre el chaleco)
    if (cad != null) {
      Linea(b, cad[0], cad[1], px, py - R * bloque, cordon, Math.Max(1, bloque - 1));
      Linea(b, cad[2], cad[3], px, py - R * bloque, cordon, Math.Max(1, bloque - 1));
    }
    for (int y = 0; y < L; y++) for (int x = 0; x < L; x++) { char ch = PIEDRA[y][x]; if (ch == '.') continue;
      for (int yy = 0; yy < bloque; yy++) for (int xx = 0; xx < bloque; xx++) b.SetPixel(px + (x - R) * bloque + xx, py + (y - R) * bloque + yy, De(ch)); }
  }
  public static string Poner(string ent, int cw, string spec, string sal, string muestra, int zoom){ return Poner(ent, cw, spec, sal, muestra, zoom, 1); }
  // bloque: tamaño de cada pixel de la piedra y grosor de la cadena (para tiras a la resolucion de Firefly, ~4)
  public static string Poner(string ent, int cw, string spec, string sal, string muestra, int zoom, int bloque){
    var t = new Bitmap(ent); var b = new Bitmap(t.Width, t.Height, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(b)) g.DrawImage(t, 0, 0, t.Width, t.Height);
    // restos verdes del fondo fuera: solo en el borde (pegados a lo transparente), 3 pasadas;
    // dentro hay grises verdosos que son del dibujo
    for (int pasada = 0; pasada < 3; pasada++) {
      var quitar = new System.Collections.Generic.List<Point>();
      for (int y = 0; y < b.Height; y++) for (int x = 0; x < b.Width; x++) {
        var c = b.GetPixel(x, y); if (c.A == 0 || !(c.G > c.R + 12 && c.G > c.B + 6)) continue;
        bool borde = false;
        for (int dy = -1; dy <= 1 && !borde; dy++) for (int dx = -1; dx <= 1; dx++) { int xx = x + dx, yy = y + dy;
          if (xx < 0 || yy < 0 || xx >= b.Width || yy >= b.Height || b.GetPixel(xx, yy).A == 0) { borde = true; break; } }
        if (borde) quitar.Add(new Point(x, y));
      }
      foreach (var p in quitar) b.SetPixel(p.X, p.Y, Color.Transparent);
    }
    var cordon = Color.FromArgb(255, 196, 200, 215);   // cadena plateada (se ve sobre el chaleco)
    int L = PIEDRA.Length, R = L / 2;
    string[] lineas = spec.Split(new[] { '\n' }, StringSplitOptions.RemoveEmptyEntries);
    for (int f = 0; f < lineas.Length; f++) {
      var v = lineas[f].Trim().Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
      int ox = f * cw, px = int.Parse(v[0]) + ox, py = int.Parse(v[1]);
      if (v.Length >= 6 && v[2] != "-") {
        Linea(b, int.Parse(v[2]) + ox, int.Parse(v[3]), px, py - R * bloque, cordon, Math.Max(1, bloque - 1));
        Linea(b, int.Parse(v[4]) + ox, int.Parse(v[5]), px, py - R * bloque, cordon, Math.Max(1, bloque - 1));
      }
      for (int y = 0; y < L; y++) for (int x = 0; x < L; x++) { char ch = PIEDRA[y][x]; if (ch == '.') continue; for (int yy = 0; yy < bloque; yy++) for (int xx = 0; xx < bloque; xx++) b.SetPixel(px + (x - R) * bloque + xx, py + (y - R) * bloque + yy, De(ch)); }
    }
    b.Save(sal, ImageFormat.Png);
    var m = new Bitmap(b.Width * zoom, b.Height * zoom);
    using (var g = Graphics.FromImage(m)) { g.Clear(Color.FromArgb(70, 70, 80)); g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor; g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.Half; g.DrawImage(b, 0, 0, m.Width, m.Height); }
    m.Save(muestra, ImageFormat.Png);
    return "colgante en " + lineas.Length + " cuadros";
  }
}
