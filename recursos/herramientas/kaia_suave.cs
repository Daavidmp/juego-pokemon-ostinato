using System; using System.Collections.Generic; using System.Drawing; using System.Drawing.Imaging; using System.Drawing.Drawing2D;
// La tira de Kaia para la megaevolucion, con el recorte limpio (sin dientes de sierra, sin restos blancos ni verdes):
//   [KaiaSuave]::Hacer(hoja, cols, filas, escala, desplaz, spec, bloque, salida)
//   - cada cuadro de la hoja de Firefly (sobre verde liso), alineado con desplaz "dx,dy;dx,dy;..." (los de
//     tira_pixel.cs), y con el colgante si spec lo pide (como en colgante_pixel.cs; "-" si ya va en la hoja,
//     colgante_firefly.cs)
//   - las lineas de dentro, mas finas
//   - la mascara a la resolucion de la hoja: fondo = el verde unido al borde o el verde puro; sin motas; y fuera
//     el borde que es mezcla con el verde (los bordes claros), pero nunca la linea oscura del contorno
//   - el fondo toma el color del borde del dibujo antes de ampliar, asi al suavizar no se cuela el verde
//   - se amplia 'escala' veces con suavizado y la mascara se vuelve a cortar: contorno curvo con 1-2 px de antialias
public static class KaiaSuave {
  static int[] Leer(Bitmap b){
    var r = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    var p = new int[b.Width * b.Height]; System.Runtime.InteropServices.Marshal.Copy(r.Scan0, p, 0, p.Length); b.UnlockBits(r); return p;
  }
  static Bitmap Escribir(int[] p, int w, int h){
    var b = new Bitmap(w, h, PixelFormat.Format32bppArgb);
    var r = b.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
    System.Runtime.InteropServices.Marshal.Copy(p, 0, r.Scan0, p.Length); b.UnlockBits(r); return b;
  }
  static bool Oscuro(int c){ return Math.Max((c >> 16) & 255, Math.Max((c >> 8) & 255, c & 255)) < 75; }

  // las lineas de dentro de 3 px o mas pierden 1 px por la derecha y por abajo (toman el color de al lado)
  static void Afinar(int[] p, bool[] fg, int w, int h){
    var q = (int[])p.Clone();
    for (int y = 2; y < h - 1; y++) for (int x = 2; x < w - 1; x++) { int i = y * w + x; if (!fg[i] || !Oscuro(p[i])) continue;
      if (fg[i + 1] && !Oscuro(p[i + 1]) && Oscuro(p[i - 1]) && Oscuro(p[i - 2])) q[i] = p[i + 1];
      else if (fg[i + w] && !Oscuro(p[i + w]) && Oscuro(p[i - w]) && Oscuro(p[i - 2 * w])) q[i] = p[i + w]; }
    Array.Copy(q, p, p.Length);
  }

  // manchas pequenas de un valor (islas de dibujo sueltas o agujeros en el dibujo) pasan al otro
  static void QuitarManchas(bool[] m, int w, int h, bool valor, int minimo){
    var visto = new bool[w * h]; var q = new Queue<int>(); var comp = new List<int>();
    for (int s = 0; s < w * h; s++) {
      if (visto[s] || m[s] != valor) continue;
      comp.Clear(); visto[s] = true; q.Enqueue(s);
      while (q.Count > 0) { int i = q.Dequeue(); comp.Add(i); int x = i % w;
        foreach (int j in new[] { i - 1, i + 1, i - w, i + w }) { if (j < 0 || j >= w * h) continue; if ((j == i - 1 && x == 0) || (j == i + 1 && x == w - 1)) continue;
          if (!visto[j] && m[j] == valor) { visto[j] = true; q.Enqueue(j); } } }
      if (comp.Count < minimo) foreach (int i in comp) m[i] = !valor;
    }
  }

  public static string Hacer(string hoja, int cols, int filas, int escala, string desplaz, string spec, int bloque, string sal){
    var src = new Bitmap(hoja);
    double cw = src.Width / (double)cols, ch = src.Height / (double)filas;
    int w = (int)Math.Floor(cw), h = (int)Math.Floor(ch), n = cols * filas;
    var ds = desplaz.Split(';'); var lineas = spec.Split(new[] { '\n' }, StringSplitOptions.RemoveEmptyEntries);
    long R = 0, G = 0, B = 0; int k = 0;
    for (int x = 0; x < src.Width; x += 2) { var c = src.GetPixel(x, 1); R += c.R; G += c.G; B += c.B; k++; }
    double fr = R / (double)k, fg0 = G / (double)k, fb = B / (double)k;
    int W = w * escala, H = h * escala;
    var tira = new int[W * n * H];
    for (int f = 0; f < n; f++) {
      var d = ds[f].Split(','); int dx = int.Parse(d[0]), dy = int.Parse(d[1]);
      var cel = new Bitmap(w, h, PixelFormat.Format32bppArgb);
      using (var g = Graphics.FromImage(cel)) {
        g.Clear(Color.FromArgb(255, (int)fr, (int)fg0, (int)fb));
        g.DrawImage(src, new Rectangle(dx, dy, w, h), (int)Math.Round((f % cols) * cw), (int)Math.Round((f / cols) * ch), w, h, GraphicsUnit.Pixel);
      }
      var v = lineas[f].Trim().Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
      if (v[0] != "-") Colgante.Dibujar(cel, int.Parse(v[0]), int.Parse(v[1]), v[2] == "-" ? null : new[] { int.Parse(v[2]), int.Parse(v[3]), int.Parse(v[4]), int.Parse(v[5]) }, bloque);
      var p = Leer(cel);
      // --- mascara
      var dist = new double[w * h];
      for (int i = 0; i < w * h; i++) { int c = p[i]; double r = (c >> 16) & 255, gg = (c >> 8) & 255, b = c & 255;
        dist[i] = Math.Sqrt((r - fr) * (r - fr) + (gg - fg0) * (gg - fg0) + (b - fb) * (b - fb)); }
      var fondo = new bool[w * h]; var q = new Queue<int>();
      Action<int> sembrar = i => { if (!fondo[i]) { fondo[i] = true; q.Enqueue(i); } };
      for (int x = 0; x < w; x++) { if (dist[x] < 70) sembrar(x); if (dist[(h - 1) * w + x] < 70) sembrar((h - 1) * w + x); }
      for (int y = 0; y < h; y++) { if (dist[y * w] < 70) sembrar(y * w); if (dist[y * w + w - 1] < 70) sembrar(y * w + w - 1); }
      for (int i = 0; i < w * h; i++) if (dist[i] < 22) sembrar(i);          // los huecos encerrados de verde puro
      while (q.Count > 0) { int i = q.Dequeue(), x = i % w;
        foreach (int j in new[] { i - 1, i + 1, i - w, i + w }) { if (j < 0 || j >= w * h) continue; if ((j == i - 1 && x == 0) || (j == i + 1 && x == w - 1)) continue;
          if (!fondo[j] && dist[j] < 70) { fondo[j] = true; q.Enqueue(j); } } }
      var fg = new bool[w * h]; for (int i = 0; i < w * h; i++) fg[i] = !fondo[i];
      QuitarManchas(fg, w, h, true, 40);
      QuitarManchas(fg, w, h, false, 12);
      // el borde que es mezcla con el verde (claro o verdoso) fuera, 2 pasadas; la linea oscura del contorno se queda
      for (int pasada = 0; pasada < 2; pasada++) {
        var er = (bool[])fg.Clone();
        for (int y = 1; y < h - 1; y++) for (int x = 1; x < w - 1; x++) { int i = y * w + x; if (!fg[i] || Oscuro(p[i]) || dist[i] > 120) continue;
          if (!fg[i - 1] || !fg[i + 1] || !fg[i - w] || !fg[i + w]) er[i] = false; }
        fg = er;
      }
      Afinar(p, fg, w, h);
      // --- el color del fondo, del borde del dibujo (8 pasadas hacia fuera)
      var lleno = (bool[])fg.Clone();
      for (int pasada = 0; pasada < 8; pasada++) { var nl = (bool[])lleno.Clone(); var np = (int[])p.Clone();
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) { int i = y * w + x; if (lleno[i]) continue;
          long sr = 0, sg = 0, sb = 0; int c = 0;
          foreach (int j in new[] { i - 1, i + 1, i - w, i + w }) { if (j < 0 || j >= w * h) continue; if ((j == i - 1 && x == 0) || (j == i + 1 && x == w - 1)) continue;
            if (lleno[j]) { sr += (p[j] >> 16) & 255; sg += (p[j] >> 8) & 255; sb += p[j] & 255; c++; } }
          if (c > 0) { np[i] = unchecked((int)0xFF000000) | (int)(sr / c) << 16 | (int)(sg / c) << 8 | (int)(sb / c); nl[i] = true; } }
        lleno = nl; p = np; }
      // --- ampliado: color y mascara por separado
      var col = new Bitmap(W, H, PixelFormat.Format32bppArgb); var mas = new Bitmap(W, H, PixelFormat.Format32bppArgb);
      var mp = new int[w * h]; for (int i = 0; i < w * h; i++) mp[i] = fg[i] ? -1 : unchecked((int)0xFF000000);
      using (var ia = new ImageAttributes()) {
        ia.SetWrapMode(WrapMode.TileFlipXY);
        using (var g = Graphics.FromImage(col)) { g.InterpolationMode = InterpolationMode.HighQualityBicubic; g.PixelOffsetMode = PixelOffsetMode.HighQuality;
          g.DrawImage(Escribir(p, w, h), new Rectangle(0, 0, W, H), 0, 0, w, h, GraphicsUnit.Pixel, ia); }
        using (var g = Graphics.FromImage(mas)) { g.InterpolationMode = InterpolationMode.HighQualityBicubic; g.PixelOffsetMode = PixelOffsetMode.HighQuality;
          g.DrawImage(Escribir(mp, w, h), new Rectangle(0, 0, W, H), 0, 0, w, h, GraphicsUnit.Pixel, ia); }
      }
      var cp = Leer(col); var mm = Leer(mas);
      for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
        int i = y * W + x; double m = (mm[i] & 255) / 255.0;
        double a = Math.Min(1, Math.Max(0, (m - 0.3) / 0.4));        // se vuelve a cortar: borde curvo y fino
        if (a <= 0) continue;
        tira[y * W * n + f * W + x] = ((int)(a * 255) << 24) | (cp[i] & 0xFFFFFF);
      }
    }
    Escribir(tira, W * n, H).Save(sal, ImageFormat.Png);
    return "tira " + n + " x " + W + "x" + H;
  }
}
