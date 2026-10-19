using System; using System.Drawing; using System.Drawing.Imaging; using System.Drawing.Drawing2D; using System.Drawing.Text;
// Las piezas de un rival nuevo para "X TE DESAFIA" (Plugins/Ostinato/015_DesafioLira.rb, Graphics/Titles/Desafio/):
//   [DesafioPiezas]::Personaje(dibujo, salida, alto)  lo dibujado (sin el margen transparente) a 'alto' px de alto
//   [DesafioPiezas]::Halo(personaje, salida)          su silueta morada difuminada, 40 px mas por cada lado
//                                                     (como lira_halo / secuaz_*_halo)
//   [DesafioPiezas]::Letrero(linea1, linea2, salida)  el letrero, como texto_LIRA: cursiva gruesa blanca rosada,
//                                                     contorno negro y sombra granate; cada linea se encoge
//                                                     si no cabe en el bollo
//   [DesafioPiezas]::Bollo(ent, salida, ancho)  la mancha del letrero (Firefly sobre blanco): fuera el blanco y los
//                                               grises claros unidos a el (la sombra de debajo), recortada y a 'ancho'
//   [DesafioPiezas]::Fondo(ent, salida)         el fondo de los huecos a 1920x1080 (llena sin deformar)
//   [DesafioPiezas]::Tenir(ent, salida, r,g,b)  una pieza de luz (el foco) de otro color
//   [DesafioPiezas]::Pegatina(ent, salida, grosor, r,g,b)  borde de pegatina alrededor (que se despegue del negro)
//   [DesafioPiezas]::Tono(ent, salida, grados, sat, luz)  la misma pieza en otro tono (la mancha de Lira, dorada)
//   [DesafioPiezas]::Polaroid(foto, fondo, salida, fx, fy)  una foto de pose (sobre verde) en polaroid, con su pared detras
public static class DesafioPiezas {
  public static string Bollo(string ent, string sal, int ancho){
    var b = new Bitmap(ent); int W = b.Width, H = b.Height;
    var px = new Color[W * H]; for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) px[y * W + x] = b.GetPixel(x, y);
    // fondo: claro y sin color (blanco o la sombra gris), unido al borde
    Func<Color, bool> claro = c => Math.Min(c.R, Math.Min(c.G, c.B)) > 140 && Math.Max(c.R, Math.Max(c.G, c.B)) - Math.Min(c.R, Math.Min(c.G, c.B)) < 22;
    var fuera = new bool[W * H]; var q = new System.Collections.Generic.Queue<int>();
    for (int x = 0; x < W; x++) foreach (int i in new[] { x, (H - 1) * W + x }) if (claro(px[i]) && !fuera[i]) { fuera[i] = true; q.Enqueue(i); }
    for (int y = 0; y < H; y++) foreach (int i in new[] { y * W, y * W + W - 1 }) if (claro(px[i]) && !fuera[i]) { fuera[i] = true; q.Enqueue(i); }
    while (q.Count > 0) { int i = q.Dequeue(), x = i % W;
      foreach (int j in new[] { i - 1, i + 1, i - W, i + W }) { if (j < 0 || j >= W * H) continue; if ((j == i - 1 && x == 0) || (j == i + 1 && x == W - 1)) continue;
        if (!fuera[j] && claro(px[j])) { fuera[j] = true; q.Enqueue(j); } } }
    int x0 = W, y0 = H, x1 = -1, y1 = -1;
    var o = new Bitmap(W, H, PixelFormat.Format32bppArgb);
    for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) { int i = y * W + x; if (fuera[i]) continue;
      var c = px[i];
      // el borde que mezcla con el blanco: alfa por lo oscuro que es (el contorno es negro)
      bool borde = (x > 0 && fuera[i - 1]) || (x < W - 1 && fuera[i + 1]) || (y > 0 && fuera[i - W]) || (y < H - 1 && fuera[i + W]);
      int a = borde ? Math.Min(255, (int)((255 - Math.Min(c.R, Math.Min(c.G, c.B))) * 1.6)) : 255;
      if (a <= 8) continue;
      o.SetPixel(x, y, Color.FromArgb(a, borde ? Color.FromArgb(20, 18, 24) : c));
      if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
    // las motitas sueltas de spray se quedan; se recorta a lo que hay y se escala
    int w = x1 - x0 + 1, h = y1 - y0 + 1; int nh = (int)Math.Round(h * ancho / (double)w);
    var r = new Bitmap(ancho, nh, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(r)) { g.InterpolationMode = InterpolationMode.HighQualityBicubic; g.PixelOffsetMode = PixelOffsetMode.HighQuality;
      g.DrawImage(o, new Rectangle(0, 0, ancho, nh), x0, y0, w, h, GraphicsUnit.Pixel); }
    r.Save(sal, ImageFormat.Png);
    return "bollo " + ancho + "x" + nh;
  }

  // otro color para una pieza de luz (el foco): mismo alfa, todo del color dado
  public static string Tenir(string ent, string sal, int cr, int cg, int cb){
    var b = new Bitmap(ent); var o = new Bitmap(b.Width, b.Height, PixelFormat.Format32bppArgb);
    for (int y = 0; y < b.Height; y++) for (int x = 0; x < b.Width; x++) { var c = b.GetPixel(x, y); if (c.A > 0) o.SetPixel(x, y, Color.FromArgb(c.A, cr, cg, cb)); }
    o.Save(sal, ImageFormat.Png);
    return "tenido";
  }

  // borde de pegatina alrededor de una pieza (para que una mancha oscura se despegue del negro): 'grosor' px del
  // color dado y un filo negro fino por fuera
  public static string Pegatina(string ent, string sal, int grosor, int cr, int cg, int cb){
    var b = new Bitmap(ent); int M = grosor + 4, W = b.Width + 2 * M, H = b.Height + 2 * M;
    var a = new double[W * H];
    for (int y = 0; y < b.Height; y++) for (int x = 0; x < b.Width; x++) if (b.GetPixel(x, y).A > 100) a[(y + M) * W + x + M] = 1;
    var gordo = Engordar(a, W, H, grosor); var filo = Engordar(a, W, H, grosor + 3);
    var o = new Bitmap(W, H, PixelFormat.Format32bppArgb);
    for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) { int i = y * W + x;
      if (gordo[i] > 0) o.SetPixel(x, y, Color.FromArgb(255, cr, cg, cb)); else if (filo[i] > 0) o.SetPixel(x, y, Color.FromArgb(255, 15, 13, 18)); }
    using (var g = Graphics.FromImage(o)) g.DrawImage(b, M, M, b.Width, b.Height);
    o.Save(sal, ImageFormat.Png);
    return "pegatina " + W + "x" + H;
  }

  // otro tono para una pieza de color (la mancha de Lira en dorado): cada pixel con color pasa al tono 'h' (grados),
  // con su misma luz; el negro del contorno y los blancos de los brillos se quedan como estan
  public static string Tono(string ent, string sal, double h, double sat, double luz){
    var b = new Bitmap(ent); var o = new Bitmap(b.Width, b.Height, PixelFormat.Format32bppArgb);
    for (int y = 0; y < b.Height; y++) for (int x = 0; x < b.Width; x++) {
      var c = b.GetPixel(x, y); if (c.A == 0) continue;
      double mx = Math.Max(c.R, Math.Max(c.G, c.B)) / 255.0, mn = Math.Min(c.R, Math.Min(c.G, c.B)) / 255.0;
      double s = mx > 0 ? (mx - mn) / mx : 0;
      if (s < 0.12) { o.SetPixel(x, y, c); continue; }              // negro, gris o blanco: igual
      double v = Math.Min(1, mx * luz), ss = Math.Min(1, s * sat);
      double cc = v * ss, hx = cc * (1 - Math.Abs((h / 60) % 2 - 1)), m = v - cc, r = 0, g = 0, bb = 0;
      if (h < 60) { r = cc; g = hx; } else if (h < 120) { r = hx; g = cc; } else if (h < 180) { g = cc; bb = hx; }
      else if (h < 240) { g = hx; bb = cc; } else if (h < 300) { r = hx; bb = cc; } else { r = cc; bb = hx; }
      o.SetPixel(x, y, Color.FromArgb(c.A, (int)((r + m) * 255), (int)((g + m) * 255), (int)((bb + m) * 255)));
    }
    o.Save(sal, ImageFormat.Png);
    return "tono " + h;
  }

  // una polaroid: la foto de Firefly (sobre verde liso) recortada con borde suave, sobre un trozo del fondo del rival
  // (fx, fy: de donde sale el trozo, de 0 a 1), en su marco crema (abajo mas ancho) con un filo oscuro
  public static string Polaroid(string ent, string fondo, string sal, double fx, double fy){
    int iw = 1040, ih = 780, bo = 48, pie = 160, W = iw + 2 * bo, H = ih + bo + pie;
    var src = new Bitmap(ent); var bg = new Bitmap(fondo);
    var o = new Bitmap(W, H, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(o)) {
      g.InterpolationMode = InterpolationMode.HighQualityBicubic; g.PixelOffsetMode = PixelOffsetMode.HighQuality; g.SmoothingMode = SmoothingMode.AntiAlias;
      using (var br = new SolidBrush(Color.FromArgb(255, 30, 26, 24))) g.FillRectangle(br, 0, 0, W, H);
      using (var br = new SolidBrush(Color.FromArgb(255, 248, 243, 230))) g.FillRectangle(br, 5, 5, W - 10, H - 10);
      // el trozo de pared, oscurecido un poco para que ellos destaquen
      int cw = (int)(bg.Height * iw / (double)ih * 0.75), chh = (int)(bg.Height * 0.75);
      int cx = (int)((bg.Width - cw) * fx), cy = (int)((bg.Height - chh) * fy);
      g.DrawImage(bg, new Rectangle(bo, bo, iw, ih), cx, cy, cw, chh, GraphicsUnit.Pixel);
      using (var br = new SolidBrush(Color.FromArgb(70, 0, 0, 10))) g.FillRectangle(br, bo, bo, iw, ih);
      // ellos, sin el verde (alfa por distancia al verde del fondo; sin tinte verde en el borde)
      var p = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb);
      long R = 0, G = 0, B = 0; int n = 0;
      for (int x = 0; x < src.Width; x += 4) foreach (int y in new[] { 2, src.Height - 3 }) { var c = src.GetPixel(x, y); R += c.R; G += c.G; B += c.B; n++; }
      double fr = R / (double)n, fg = G / (double)n, fb = B / (double)n;
      for (int y = 0; y < src.Height; y++) for (int x = 0; x < src.Width; x++) {
        var c = src.GetPixel(x, y); double r = c.R, gg = c.G, b = c.B;
        double d = Math.Sqrt((r - fr) * (r - fr) + (gg - fg) * (gg - fg) + (b - fb) * (b - fb));
        double a = Math.Min(1, Math.Max(0, (d - 30) / 45.0)); if (a <= 0) continue;
        if (a < 1) { double m = 1 - a; r = (r - m * fr) / a; gg = (gg - m * fg) / a; b = (b - m * fb) / a; double t = Math.Max(r, b); if (gg > t) gg = t;
          r = Math.Min(255, Math.Max(0, r)); gg = Math.Min(255, Math.Max(0, gg)); b = Math.Min(255, Math.Max(0, b)); }
        p.SetPixel(x, y, Color.FromArgb((int)(a * 255), (int)r, (int)gg, (int)b));
      }
      g.SetClip(new Rectangle(bo, bo, iw, ih));
      double k = Math.Max(iw / (double)src.Width, ih / (double)src.Height);
      int dw = (int)(src.Width * k), dh = (int)(src.Height * k);
      g.DrawImage(p, new Rectangle(bo + (iw - dw) / 2, bo + (ih - dh) / 2, dw, dh));
      g.ResetClip();
      using (var pen = new Pen(Color.FromArgb(255, 30, 26, 24), 3)) g.DrawRectangle(pen, bo, bo, iw, ih);
    }
    o.Save(sal, ImageFormat.Png);
    return "polaroid " + W + "x" + H;
  }

  public static string Fondo(string ent, string sal){
    var src = new Bitmap(ent); int w = 1920, h = 1080; var o = new Bitmap(w, h, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(o)) { g.InterpolationMode = InterpolationMode.HighQualityBicubic; g.PixelOffsetMode = PixelOffsetMode.HighQuality;
      double k = Math.Max((double)w / src.Width, (double)h / src.Height); int sw = (int)(w / k), sh = (int)(h / k);
      g.DrawImage(src, new Rectangle(0, 0, w, h), (src.Width - sw) / 2, (src.Height - sh) / 2, sw, sh, GraphicsUnit.Pixel); }
    o.Save(sal, ImageFormat.Png);
    return "fondo " + w + "x" + h;
  }

  public static string Personaje(string ent, string sal, int alto){
    var b = new Bitmap(ent); int x0 = b.Width, y0 = b.Height, x1 = -1, y1 = -1;
    for (int y = 0; y < b.Height; y += 1) for (int x = 0; x < b.Width; x += 1)
      if (b.GetPixel(x, y).A > 20) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
    double k = alto / (double)(y1 - y0 + 1); int w = (int)Math.Round((x1 - x0 + 1) * k);
    var o = new Bitmap(w, alto, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(o)) { g.InterpolationMode = InterpolationMode.HighQualityBicubic; g.PixelOffsetMode = PixelOffsetMode.HighQuality;
      g.DrawImage(b, new Rectangle(0, 0, w, alto), x0, y0, x1 - x0 + 1, y1 - y0 + 1, GraphicsUnit.Pixel); }
    o.Save(sal, ImageFormat.Png);
    return "personaje " + w + "x" + alto;
  }

  public static string Halo(string ent, string sal){ return Halo(ent, sal, 150, 40, 230); }
  // con otro color de luz (el de Lira y los secuaces es morado: 150, 40, 230)
  public static string Halo(string ent, string sal, int cr, int cg, int cb){
    var b = new Bitmap(ent); int M = 40, W = b.Width + 2 * M, H = b.Height + 2 * M;
    // silueta engordada 10 px y difuminada (caja 3 veces: casi gaussiana) de radio 12
    var a = new double[W * H];
    for (int y = 0; y < b.Height; y++) for (int x = 0; x < b.Width; x++) if (b.GetPixel(x, y).A > 60) a[(y + M) * W + x + M] = 1;
    a = Caja(Caja(Engordar(a, W, H, 10), W, H, 6), W, H, 6); a = Caja(a, W, H, 6);
    var o = new Bitmap(W, H, PixelFormat.Format32bppArgb);
    for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) { int al = (int)Math.Round(Math.Min(1, a[y * W + x]) * 209);
      if (al > 0) o.SetPixel(x, y, Color.FromArgb(al, cr, cg, cb)); }
    o.Save(sal, ImageFormat.Png);
    return "halo " + W + "x" + H;
  }
  static double[] Engordar(double[] a, int W, int H, int r){
    var o = new double[W * H];
    for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) { if (a[y * W + x] <= 0) continue;
      for (int dy = -r; dy <= r; dy++) for (int dx = -r; dx <= r; dx++) { if (dx * dx + dy * dy > r * r) continue;
        int xx = x + dx, yy = y + dy; if (xx >= 0 && yy >= 0 && xx < W && yy < H) o[yy * W + xx] = 1; } }
    return o;
  }
  static double[] Caja(double[] a, int W, int H, int r){
    var t = new double[W * H]; var o = new double[W * H];
    for (int y = 0; y < H; y++) { double s = 0; for (int x = -r; x < W + r; x++) { if (x + r < W && x + r >= 0) s += a[y * W + x + r]; if (x - r - 1 >= 0 && x - r - 1 < W) s -= a[y * W + x - r - 1]; if (x >= 0 && x < W) t[y * W + x] = s / (2 * r + 1); } }
    for (int x = 0; x < W; x++) { double s = 0; for (int y = -r; y < H + r; y++) { if (y + r < H && y + r >= 0) s += t[(y + r) * W + x]; if (y - r - 1 >= 0 && y - r - 1 < H) s -= t[(y - r - 1) * W + x]; if (y >= 0 && y < H) o[y * W + x] = s / (2 * r + 1); } }
    return o;
  }

  public static string Letrero(string l1, string l2, string sal){ return Letrero(l1, l2, sal, 900); }
  // W: ancho del letrero (900 el de siempre; menos si la zona lisa del bollo es mas estrecha)
  public static string Letrero(string l1, string l2, string sal, int W){ return Letrero(l1, l2, sal, W, Color.FromArgb(200, 39, 0, 20), Color.FromArgb(255, 255, 252, 254), Color.FromArgb(255, 255, 236, 244)); }
  // sombra y relleno (arriba, abajo) de otro color
  public static string Letrero(string l1, string l2, string sal, int W, Color sombra, Color arriba, Color abajo){
    int H = (int)Math.Round(340 * W / 900.0), ancho = W - 70;
    var o = new Bitmap(W, H, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(o)) {
      g.SmoothingMode = SmoothingMode.AntiAlias; g.TextRenderingHint = TextRenderingHint.AntiAlias;
      var fam = new FontFamily("Arial Black");
      var sf = new StringFormat(StringFormat.GenericTypographic) { Alignment = StringAlignment.Center };
      // cada linea: su camino, encogido si no cabe, en cursiva (inclinada) y centrado
      Func<string, float, float, GraphicsPath> linea = (txt, tam, cy) => {
        var p = new GraphicsPath(); p.AddString(txt, fam, (int)FontStyle.Regular, tam, new PointF(0, 0), sf);
        var r = p.GetBounds(); float k = Math.Min(1f, ancho / r.Width);
        var m = new Matrix(); m.Translate(W / 2f, cy); m.Scale(k, 1f); m.Shear(-0.22f, 0); m.Translate(-(r.X + r.Width / 2), -(r.Y + r.Height / 2));
        p.Transform(m); return p; };
      float e = W / 900f;
      var p1 = linea(l1, 132 * e, 105 * e); var p2 = linea(l2, 112 * e, 245 * e);
      foreach (var p in new[] { p1, p2 }) {
        // sombra granate abajo a la derecha, contorno negro grueso y relleno blanco rosado (mas rosa abajo)
        var ps = (GraphicsPath)p.Clone(); var mt = new Matrix(); mt.Translate(7 * e, 9 * e); ps.Transform(mt);
        using (var pen = new Pen(sombra, 26 * e) { LineJoin = LineJoin.Round }) g.DrawPath(pen, ps);
        using (var br = new SolidBrush(sombra)) g.FillPath(br, ps);
        using (var pen = new Pen(Color.Black, 24 * e) { LineJoin = LineJoin.Round }) g.DrawPath(pen, p);
        var r = p.GetBounds();
        using (var br = new LinearGradientBrush(new RectangleF(r.X, r.Y - 1, r.Width, r.Height + 2), arriba, abajo, 90f)) g.FillPath(br, p);
      }
    }
    o.Save(sal, ImageFormat.Png);
    return "letrero " + W + "x" + H;
  }
}
