using System; using System.Collections.Generic; using System.Drawing; using System.Drawing.Imaging;
// Una pieza de Firefly (sobre verde liso) a pieza de tileset en pixel art, a la medida exacta en px del juego:
//   [PiezaTileset]::Hacer(entrada, salida, x, y, w, h, corte, ancho, alto, colores, ajustarAbajo)
//   - (x, y, w, h): el recorte de la imagen de entrada con la pieza (en px de la entrada)
//   - corte: la inclinacion a deshacer (dy por cada px de x; 0 si viene recta)
//   - ancho x alto: el tamano final en px (casillas de 32); la pieza se encaja dentro sin deformar, centrada
//     a lo ancho y apoyada abajo si ajustarAbajo (los edificios y las farolas pisan el suelo)
//   - el fondo: el verde unido al borde (con su antialias); la mascara se hace a la resolucion de entrada y se
//     reduce por media, asi el contorno sale limpio y sin verde
//   - colores: k-medias sobre lo que queda (pixel art de pocos colores); 0 = sin reducir colores
//   [PiezaTileset]::Noche(entrada, salida, oscuro, azul)  una pieza de dia (de otros tilesets) en colores de noche
//   [PiezaTileset]::Espejo(entrada, salida)               la misma, girada de izquierda a derecha
public static class PiezaTileset {
  static int[] Leer(Bitmap b){ var r = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    var p = new int[b.Width * b.Height]; System.Runtime.InteropServices.Marshal.Copy(r.Scan0, p, 0, p.Length); b.UnlockBits(r); return p; }
  static Bitmap Escribir(int[] p, int w, int h){ var b = new Bitmap(w, h, PixelFormat.Format32bppArgb);
    var r = b.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
    System.Runtime.InteropServices.Marshal.Copy(p, 0, r.Scan0, p.Length); b.UnlockBits(r); return b; }
  static int D(int a, int b){ int r = ((a >> 16) & 255) - ((b >> 16) & 255), g = ((a >> 8) & 255) - ((b >> 8) & 255), bb = (a & 255) - (b & 255); return r * r + g * g + bb * bb; }

  public static string Hacer(string ent, string sal, int x0, int y0, int w0, int h0, double corte, int ancho, int alto, int colores, bool abajo){
    var src = new Bitmap(ent); var sp = Leer(src); int SW = src.Width, SH = src.Height;
    // el verde de fondo: el color que mas se repite en el borde de la imagen (la media se ensuciaba con lo que toca el borde)
    var cuenta = new Dictionary<int, int>();
    for (int x = 0; x < SW; x += 2) foreach (int y in new[] { 1, SH - 2 }) { int c = sp[y * SW + x] & 0xF0F0F0; cuenta[c] = cuenta.ContainsKey(c) ? cuenta[c] + 1 : 1; }
    int verde = 0, mx = 0; foreach (var kv in cuenta) if (kv.Value > mx) { mx = kv.Value; verde = kv.Key | 0x080808; }
    // la pieza enderezada y recortada
    var p = new int[w0 * h0];
    for (int y = 0; y < h0; y++) for (int x = 0; x < w0; x++) {
      int sx = x0 + x, sy = (int)Math.Round(y0 + y + corte * (x0 + x - x0));
      p[y * w0 + x] = (sx < 0 || sy < 0 || sx >= SW || sy >= SH) ? verde : sp[sy * SW + sx] & 0xFFFFFF; }
    // fondo: verde parecido unido al borde del recorte, y luego 1 px mas (el antialias)
    var fondo = new bool[w0 * h0]; var q = new Queue<int>();
    Func<int, bool> esVerde = i => { int c = p[i]; int r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255; return D(c, verde) < 30 * 30 || (g > r + 25 && g > b + 15 && g > 90); };   // cerca del verde (no mas: los cremas claros quedan a ~50)
    for (int x = 0; x < w0; x++) foreach (int i in new[] { x, (h0 - 1) * w0 + x }) if (esVerde(i) && !fondo[i]) { fondo[i] = true; q.Enqueue(i); }
    for (int y = 0; y < h0; y++) foreach (int i in new[] { y * w0, y * w0 + w0 - 1 }) if (esVerde(i) && !fondo[i]) { fondo[i] = true; q.Enqueue(i); }
    while (q.Count > 0) { int i = q.Dequeue(), x = i % w0;
      foreach (int j in new[] { i - 1, i + 1, i - w0, i + w0 }) { if (j < 0 || j >= w0 * h0) continue; if ((j == i - 1 && x == 0) || (j == i + 1 && x == w0 - 1)) continue;
        if (!fondo[j] && esVerde(j)) { fondo[j] = true; q.Enqueue(j); } } }
    for (int i = 0; i < w0 * h0; i++) if (!fondo[i] && esVerde(i)) fondo[i] = true;   // huecos encerrados de verde
    // encaje: escala para que quepa en ancho x alto
    double k = Math.Min(ancho / (double)w0, alto / (double)h0);
    int dw = Math.Max(1, (int)Math.Round(w0 * k)), dh = Math.Max(1, (int)Math.Round(h0 * k));
    int ox = (ancho - dw) / 2, oy = abajo ? alto - dh : (alto - dh) / 2;
    var o = new int[ancho * alto];
    for (int y = 0; y < dh; y++) for (int x = 0; x < dw; x++) {
      // media de area de la celda (solo lo que no es fondo) y cobertura
      double ax0 = x / k, ax1 = (x + 1) / k, ay0 = y / k, ay1 = (y + 1) / k;
      long sr = 0, sg = 0, sb = 0; int cn = 0, tot = 0;
      for (int yy = (int)ay0; yy < Math.Min(h0, (int)Math.Ceiling(ay1)); yy++) for (int xx = (int)ax0; xx < Math.Min(w0, (int)Math.Ceiling(ax1)); xx++) {
        tot++; int i = yy * w0 + xx; if (fondo[i]) continue; int c = p[i]; sr += (c >> 16) & 255; sg += (c >> 8) & 255; sb += c & 255; cn++; }
      if (tot == 0 || cn * 2 < tot) continue;
      o[(oy + y) * ancho + ox + x] = unchecked((int)0xFF000000) | (int)(sr / cn) << 16 | (int)(sg / cn) << 8 | (int)(sb / cn);
    }
    if (colores > 0) Cuantizar(o, colores);
    Escribir(o, ancho, alto).Save(sal, ImageFormat.Png);
    return "pieza " + ancho + "x" + alto + " (dibujo " + dw + "x" + dh + ")";
  }

  static void Cuantizar(int[] o, int n){
    var px = new List<int>(); foreach (int c in o) if (((c >> 24) & 255) > 0) px.Add(c & 0xFFFFFF);
    if (px.Count == 0) return;
    // semillas repartidas por luminosidad
    px.Sort((a, b) => (((a >> 16) & 255) + ((a >> 8) & 255) + (a & 255)).CompareTo(((b >> 16) & 255) + ((b >> 8) & 255) + (b & 255)));
    var pal = new int[n]; for (int j = 0; j < n; j++) pal[j] = px[(int)((j + 0.5) * px.Count / n)];
    for (int it = 0; it < 10; it++) {
      var sr = new long[n]; var sg = new long[n]; var sb = new long[n]; var sn = new int[n];
      foreach (int c in px) { int b = 0, bd = int.MaxValue; for (int j = 0; j < n; j++) { int d = D(c, pal[j]); if (d < bd) { bd = d; b = j; } } sr[b] += (c >> 16) & 255; sg[b] += (c >> 8) & 255; sb[b] += c & 255; sn[b]++; }
      for (int j = 0; j < n; j++) if (sn[j] > 0) pal[j] = (int)(sr[j] / sn[j]) << 16 | (int)(sg[j] / sn[j]) << 8 | (int)(sb[j] / sn[j]);
    }
    for (int i = 0; i < o.Length; i++) { if (((o[i] >> 24) & 255) == 0) continue; int c = o[i] & 0xFFFFFF, b = 0, bd = int.MaxValue;
      for (int j = 0; j < n; j++) { int d = D(c, pal[j]); if (d < bd) { bd = d; b = j; } } o[i] = unchecked((int)0xFF000000) | pal[b]; }
  }

  public static string Noche(string ent, string sal, double oscuro, int azul){
    var b = new Bitmap(ent); var p = Leer(b);
    for (int i = 0; i < p.Length; i++) { int a = (p[i] >> 24) & 255; if (a == 0) continue;
      int r = (p[i] >> 16) & 255, g = (p[i] >> 8) & 255, bb = p[i] & 255;
      r = (int)(r * oscuro); g = (int)(g * oscuro); bb = Math.Min(255, (int)(bb * oscuro) + azul);
      p[i] = a << 24 | r << 16 | g << 8 | bb; }
    Escribir(p, b.Width, b.Height).Save(sal, ImageFormat.Png); return "noche";
  }

  // como Noche, pero las luces calidas (ventanas encendidas, bombillas) se quedan como estan
  public static string NocheLuces(string ent, string sal, double oscuro, int azul){
    var b = new Bitmap(ent); var p = Leer(b);
    for (int i = 0; i < p.Length; i++) { int a = (p[i] >> 24) & 255; if (a == 0) continue;
      int r = (p[i] >> 16) & 255, g = (p[i] >> 8) & 255, bb = p[i] & 255;
      bool luz = r > 170 && g > 110 && bb < 150 && r > bb + 60;
      if (luz) continue;
      r = (int)(r * oscuro); g = (int)(g * oscuro); bb = Math.Min(255, (int)(bb * oscuro) + azul);
      p[i] = a << 24 | r << 16 | g << 8 | bb; }
    Escribir(p, b.Width, b.Height).Save(sal, ImageFormat.Png); return "noche con luces";
  }

  public static string Espejo(string ent, string sal){ var b = new Bitmap(ent); b.RotateFlip(RotateFlipType.RotateNoneFlipX); b.Save(sal, ImageFormat.Png); return "espejo"; }
}
