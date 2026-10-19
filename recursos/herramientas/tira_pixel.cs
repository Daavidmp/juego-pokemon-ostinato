using System; using System.Collections.Generic; using System.Drawing; using System.Drawing.Imaging;
// Una hoja de Firefly en "pixel art" (cuadricula de cuadros sobre fondo liso) -> una tira de pixel art de verdad:
//   [TiraPixel]::Hacer(hoja, cols, filas, paso, colores, salida, muestra, zoom)
//   - cada cuadro se reduce a su rejilla (un pixel cada 'paso' px: el color que mas se repite en el centro del bloque)
//   - el fondo (el color de los bordes del cuadro) queda transparente
//   - todos los cuadros comparten una paleta de 'colores' colores (asi no parpadean al animar)
//   - se alinean por la cabeza (arriba del todo y su centro), como el primero
//   salida: tira horizontal a tamano real; muestra: la tira ampliada x zoom sobre gris
public static class TiraPixel {
  static int Dist(int a, int b){
    int dr = ((a >> 16) & 255) - ((b >> 16) & 255), dg = ((a >> 8) & 255) - ((b >> 8) & 255), db = (a & 255) - (b & 255);
    return dr * dr + dg * dg + db * db;
  }

  public static string Hacer(string hoja, int cols, int filas, double paso, int colores, string salida, string muestra, int zoom){
    var src = new Bitmap(hoja); int SW = src.Width, SH = src.Height;
    var px = new int[SW * SH];
    var lk = src.LockBits(new Rectangle(0, 0, SW, SH), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    System.Runtime.InteropServices.Marshal.Copy(lk.Scan0, px, 0, px.Length); src.UnlockBits(lk);
    double cw = SW / (double)cols, ch = SH / (double)filas;
    int nw = (int)Math.Floor(cw / paso), nh = (int)Math.Floor(ch / paso);
    int n = cols * filas;
    var cuadros = new List<int[]>();
    // fondo: el color mas comun en el borde de toda la hoja
    var cuenta = new Dictionary<int, int>();
    for (int x = 0; x < SW; x += 3) foreach (int y in new[] { 2, SH - 3 }) { int c = px[y * SW + x] & 0xF8F8F8; cuenta[c] = cuenta.ContainsKey(c) ? cuenta[c] + 1 : 1; }
    int fondo = 0, mx = 0; foreach (var kv in cuenta) if (kv.Value > mx) { mx = kv.Value; fondo = kv.Key; }
    for (int f = 0; f < n; f++) {
      int c0 = (int)Math.Round((f % cols) * cw), r0 = (int)Math.Round((f / cols) * ch);
      var o = new int[nw * nh];
      for (int y = 0; y < nh; y++) for (int x = 0; x < nw; x++) {
        var votos = new Dictionary<int, int>(); int mejor = 0, mv = 0;
        double bx = c0 + x * paso, by = r0 + y * paso;
        for (double sy = by + paso * 0.25; sy < by + paso * 0.8; sy += 1) for (double sx = bx + paso * 0.25; sx < bx + paso * 0.8; sx += 1) {
          int ix = (int)sx, iy = (int)sy; if (ix >= SW || iy >= SH) continue;
          int c = px[iy * SW + ix] & 0xF0F0F0; int v = votos.ContainsKey(c) ? votos[c] + 1 : 1; votos[c] = v;
          if (v > mv) { mv = v; mejor = c; }
        }
        // el color exacto: la media de los pixeles del centro que caen en ese grupo
        long R = 0, G = 0, B = 0; int k = 0;
        for (double sy = by + paso * 0.25; sy < by + paso * 0.8; sy += 1) for (double sx = bx + paso * 0.25; sx < bx + paso * 0.8; sx += 1) {
          int ix = (int)sx, iy = (int)sy; if (ix >= SW || iy >= SH) continue;
          int c = px[iy * SW + ix]; if ((c & 0xF0F0F0) != mejor) continue; R += (c >> 16) & 255; G += (c >> 8) & 255; B += c & 255; k++;
        }
        int col = k > 0 ? (int)(R / k) << 16 | (int)(G / k) << 8 | (int)(B / k) : mejor;
        o[y * nw + x] = Dist(col, fondo) < 45 * 45 ? 0 : (col | unchecked((int)0xFF000000));
      }
      cuadros.Add(o);
    }
    // paleta comun (k-medias sencillo)
    var todos = new List<int>(); foreach (var o in cuadros) foreach (int c in o) if (c != 0) todos.Add(c & 0xFFFFFF);
    var frec = new Dictionary<int, int>(); foreach (int c in todos) { int q = c & 0xE0E0E0; frec[q] = frec.ContainsKey(q) ? frec[q] + 1 : 1; }
    var ini = new List<KeyValuePair<int, int>>(frec); ini.Sort((a, b) => b.Value.CompareTo(a.Value));
    var pal = new List<int>();
    foreach (var kv in ini) { bool lejos = true; foreach (int p in pal) if (Dist(p, kv.Key) < 30 * 30) { lejos = false; break; } if (lejos) pal.Add(kv.Key | 0x101010); if (pal.Count >= colores) break; }
    for (int it = 0; it < 8; it++) {
      var sr = new long[pal.Count]; var sg = new long[pal.Count]; var sb = new long[pal.Count]; var sn = new int[pal.Count];
      foreach (int c in todos) { int b = 0, bd = int.MaxValue; for (int i = 0; i < pal.Count; i++) { int d = Dist(c, pal[i]); if (d < bd) { bd = d; b = i; } }
        sr[b] += (c >> 16) & 255; sg[b] += (c >> 8) & 255; sb[b] += c & 255; sn[b]++; }
      for (int i = 0; i < pal.Count; i++) if (sn[i] > 0) pal[i] = (int)(sr[i] / sn[i]) << 16 | (int)(sg[i] / sn[i]) << 8 | (int)(sb[i] / sn[i]);
    }
    foreach (var o in cuadros) for (int i = 0; i < o.Length; i++) {
      if (o[i] == 0) continue; int c = o[i] & 0xFFFFFF; int b = 0, bd = int.MaxValue;
      for (int j = 0; j < pal.Count; j++) { int d = Dist(c, pal[j]); if (d < bd) { bd = d; b = j; } }
      o[i] = pal[b] | unchecked((int)0xFF000000);
    }
    // pixeles sueltos fuera
    foreach (var o in cuadros) { var c2 = (int[])o.Clone();
      for (int y = 0; y < nh; y++) for (int x = 0; x < nw; x++) { if (c2[y * nw + x] == 0) continue; int v = 0;
        for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) { int xx = x + dx, yy = y + dy; if ((dx != 0 || dy != 0) && xx >= 0 && yy >= 0 && xx < nw && yy < nh && c2[yy * nw + xx] != 0) v++; }
        if (v <= 1) o[y * nw + x] = 0; } }
    // alinear por la cabeza: primera fila con dibujo y el centro de las 12 filas de arriba
    var ax = new int[n]; var ay = new int[n];
    for (int f = 0; f < n; f++) { var o = cuadros[f]; int top = -1;
      for (int y = 0; y < nh && top < 0; y++) for (int x = 0; x < nw; x++) if (o[y * nw + x] != 0) { top = y; break; }
      long sx = 0; int k = 0; for (int y = top; y < Math.Min(nh, top + nh / 9); y++) for (int x = 0; x < nw; x++) if (o[y * nw + x] != 0) { sx += x; k++; }
      ay[f] = top; ax[f] = k > 0 ? (int)(sx / k) : nw / 2; }
    // y se afina comparando la cabeza del primero (sin el puño ni los brazos) con cada cuadro
    int st = Math.Max(1, nw / 127);   // a mucha resolucion, se compara uno de cada st
    for (int f = 1; f < n; f++) { int mejor = int.MaxValue, bx = 0, by = 0;
      for (int dy = -nh / 18; dy <= nh / 18; dy++) for (int dx = -nw / 8; dx <= nw / 8; dx++) { int mal = 0;
        for (int y = ay[0] + nh / 18; y < Math.Min(nh, ay[0] + nh * 43 / 100); y += st) for (int x = Math.Max(0, ax[0] - nw / 4); x < Math.Min(nw, ax[0] + nw / 4); x += st) {
          int a = cuadros[0][y * nw + x]; int sx = x - (ax[0] - ax[f]) - dx, sy = y - (ay[0] - ay[f]) - dy;
          int b = (sx < 0 || sy < 0 || sx >= nw || sy >= nh) ? 0 : cuadros[f][sy * nw + sx];
          if ((a == 0) != (b == 0) || (a != 0 && Dist(a, b) > 40 * 40)) mal++; }
        if (mal < mejor) { mejor = mal; bx = dx; by = dy; } }
      ax[f] -= bx; ay[f] -= by; }
    var tira = new Bitmap(nw * n, nh, PixelFormat.Format32bppArgb);
    string info = "";
    for (int f = 0; f < n; f++) { int dx = ax[0] - ax[f], dy = ay[0] - ay[f]; info += "(" + dx + "," + dy + ")";
      for (int y = 0; y < nh; y++) for (int x = 0; x < nw; x++) { int sx = x - dx, sy = y - dy;
        if (sx < 0 || sy < 0 || sx >= nw || sy >= nh) continue; int c = cuadros[f][sy * nw + sx]; if (c != 0) tira.SetPixel(f * nw + x, y, Color.FromArgb(c)); } }
    tira.Save(salida, ImageFormat.Png);
    var m = new Bitmap(tira.Width * zoom, tira.Height * zoom);
    using (var g = Graphics.FromImage(m)) { g.Clear(Color.FromArgb(70, 70, 80)); g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor; g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.Half; g.DrawImage(tira, 0, 0, m.Width, m.Height); }
    m.Save(muestra, ImageFormat.Png);
    return "cuadro " + nw + "x" + nh + ", " + pal.Count + " colores, desplazados " + info;
  }
}
