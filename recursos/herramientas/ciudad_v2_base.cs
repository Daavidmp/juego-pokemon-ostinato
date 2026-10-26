using System; using System.Collections.Generic; using System.Drawing; using System.Drawing.Imaging; using System.IO; using System.Text;
// Piezas por codigo de la ciudad del primer gimnasio (boceto_v2), en la paleta de Anil y con sus sombras (negro al 30 %).
// Tres archivos con la misma clase: ciudad_v2_base.cs (paleta, ayudas y suelos), ciudad_v2_muros.cs (muros, escaleras,
// azoteas y objetos) y ciudad_v2_montar.cs (sustitutos de Firefly, tileset de trabajo, manifiesto, props y laminas).
//   Add-Type -ReferencedAssemblies System.Drawing -Path ciudad_v2_base.cs,ciudad_v2_muros.cs,ciudad_v2_montar.cs
//   [CiudadV2]::Hacer(paleta_anil.txt, tileset_anil.png, props_anil.txt, carmin.png, kaia.png, carpeta_salida)
// No toca el juego: deja en la carpeta tileset.png, manifiesto.txt, props.txt, piezas\*.png y laminas\*.png.
public static partial class CiudadV2 {
  static List<Color> PAL = new List<Color>();
  static Bitmap ANIL;                       // el Exterior1 de Anil (filas 0-729 del tileset CiudadGimnasio)
  static readonly Color SOMBRA = Color.FromArgb(76, 0, 0, 0);   // la sombra de Anil
  static readonly Color NADA = Color.FromArgb(0, 0, 0, 0);

  static void CargarPaleta(string f){
    PAL.Clear();
    foreach (var l in File.ReadAllLines(f)) { var s = l.Trim(); if (s.Length < 6) continue;
      PAL.Add(Color.FromArgb(255, Convert.ToInt32(s.Substring(0, 2), 16), Convert.ToInt32(s.Substring(2, 2), 16), Convert.ToInt32(s.Substring(4, 2), 16))); }
  }
  // el color de la paleta de Anil mas cercano (distancia con peso de luminancia)
  static Color Q(int rgb){ return Q(Color.FromArgb(255, (rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255)); }
  static Color Q(Color c){
    if (c.A < 128) return NADA; Color best = c; double bd = 1e18;
    foreach (var p in PAL) { double dr = c.R - p.R, dg = c.G - p.G, db = c.B - p.B; double d = 3 * dr * dr + 4 * dg * dg + 2 * db * db; if (d < bd) { bd = d; best = p; } }
    return best;
  }
  static Bitmap Lienzo(int wc, int hc){ var b = new Bitmap(wc * 32, hc * 32, PixelFormat.Format32bppArgb); using (var g = Graphics.FromImage(b)) g.Clear(NADA); return b; }
  static void Px(Bitmap b, int x, int y, Color c){ if (x >= 0 && y >= 0 && x < b.Width && y < b.Height) b.SetPixel(x, y, c); }
  static void Rect(Bitmap b, int x, int y, int w, int h, Color c){ for (int j = y; j < y + h; j++) for (int i = x; i < x + w; i++) Px(b, i, j, c); }
  // sombra encima de lo que ya hay (mezcla), o sola si la casilla esta vacia
  static void Sombrear(Bitmap b, int x, int y){
    if (x < 0 || y < 0 || x >= b.Width || y >= b.Height) return; var c = b.GetPixel(x, y);
    if (c.A == 0) b.SetPixel(x, y, SOMBRA);
    else if (c.A == 255) b.SetPixel(x, y, Q(Color.FromArgb(255, c.R * 70 / 100, c.G * 70 / 100, c.B * 72 / 100)));
  }
  static Bitmap Trozo(Bitmap src, int fila, int col, int wc, int hc){
    var b = Lienzo(wc, hc); using (var g = Graphics.FromImage(b)) g.DrawImage(src, new Rectangle(0, 0, wc * 32, hc * 32), new Rectangle(col * 32, fila * 32, wc * 32, hc * 32), GraphicsUnit.Pixel); return b;
  }
  static void Pegar(Bitmap dst, Bitmap src, int x, int y){ using (var g = Graphics.FromImage(dst)) g.DrawImage(src, new Rectangle(x, y, src.Width, src.Height), new Rectangle(0, 0, src.Width, src.Height), GraphicsUnit.Pixel); }
  // contorno de Anil: el borde de lo dibujado, con el color de dentro oscurecido (nunca negro puro)
  static void Contorno(Bitmap b){
    var o = (Bitmap)b.Clone();
    for (int y = 0; y < b.Height; y++) for (int x = 0; x < b.Width; x++) {
      var c = o.GetPixel(x, y); if (c.A < 255) continue;
      bool borde = false;
      foreach (var d in new[] { new[] { 1, 0 }, new[] { -1, 0 }, new[] { 0, 1 }, new[] { 0, -1 } }) { int xx = x + d[0], yy = y + d[1];
        if (xx < 0 || yy < 0 || xx >= b.Width || yy >= b.Height || o.GetPixel(xx, yy).A < 255) { borde = true; break; } }
      if (borde) b.SetPixel(x, y, Q(Color.FromArgb(255, c.R * 45 / 100, c.G * 45 / 100, c.B * 50 / 100)));
    }
  }
  // HSL para pasar piezas de Anil de un color a otro
  static void AHsl(Color c, out double h, out double s, out double l){
    double r = c.R / 255.0, g = c.G / 255.0, bb = c.B / 255.0; double mx = Math.Max(r, Math.Max(g, bb)), mn = Math.Min(r, Math.Min(g, bb));
    l = (mx + mn) / 2; if (mx == mn) { h = 0; s = 0; return; } double d = mx - mn; s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
    if (mx == r) h = (g - bb) / d + (g < bb ? 6 : 0); else if (mx == g) h = (bb - r) / d + 2; else h = (r - g) / d + 4; h *= 60;
  }
  static Color DeHsl(double h, double s, double l){
    Func<double, double, double, double> f = (p, q, t) => { if (t < 0) t += 1; if (t > 1) t -= 1; if (t < 1.0 / 6) return p + (q - p) * 6 * t; if (t < 0.5) return q; if (t < 2.0 / 3) return p + (q - p) * (2.0 / 3 - t) * 6; return p; };
    double r, g, b; if (s == 0) r = g = b = l; else { double q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q; double hh = h / 360; r = f(p, q, hh + 1.0 / 3); g = f(p, q, hh); b = f(p, q, hh - 1.0 / 3); }
    return Color.FromArgb(255, (int)Math.Round(r * 255), (int)Math.Round(g * 255), (int)Math.Round(b * 255));
  }
  // cambia de tono los pixeles cuyo tono esta entre h0 y h1 (y con saturacion), al tono nuevo
  static void Tono(Bitmap b, double h0, double h1, double hNuevo, double satX, double lumX, double satMin){ Tono(b, h0, h1, hNuevo, satX, lumX, satMin, 1.0); }
  static void Tono(Bitmap b, double h0, double h1, double hNuevo, double satX, double lumX, double satMin, double lumMax){
    for (int y = 0; y < b.Height; y++) for (int x = 0; x < b.Width; x++) {
      var c = b.GetPixel(x, y); if (c.A == 0) continue; double h, s, l; AHsl(c, out h, out s, out l);
      if (s < satMin || h < h0 || h > h1 || l > lumMax) continue;
      var n = DeHsl(hNuevo, Math.Min(1, s * satX), Math.Min(0.95, l * lumX)); n = Q(n); b.SetPixel(x, y, Color.FromArgb(c.A, n.R, n.G, n.B));
    }
  }

  // ---------------------------------------------------------------- suelos
  // acera de losa gris (cuadros de 16 px): 3 variantes que casan entre si
  static readonly int[] LOSA = { 0x7C7A84, 0xA4A2A8, 0xC4C2C0, 0xE0DED8 };   // junta, sombra, medio, luz
  static void Losa(Bitmap b, int ox, int oy, int sem, int[] col, int lado){
    var r = new Random(sem); var J = Q(col[0]); var S = Q(col[1]); var M = Q(col[2]); var L = Q(col[3]);
    for (int y = 0; y < 32; y++) for (int x = 0; x < 32; x++) {
      int lx = x % lado, ly = y % lado; Color k = M;
      if (lx == lado - 1 || ly == lado - 1) k = J; else if (lx == 0 || ly == 0) k = L; else if (lx == lado - 2 || ly == lado - 2) k = S;
      Px(b, ox + x, oy + y, k);
    }
    var M2 = Q(Color.FromArgb(255, M.R * 94 / 100, M.G * 94 / 100, M.B * 95 / 100));
    for (int y = 0; y < 32; y++) for (int x = 0; x < 32; x++) { int q = ((ox + x) / lado + (oy + y) / lado * 3 + sem) % 3; if (q == 0 && b.GetPixel(ox + x, oy + y).ToArgb() == M.ToArgb()) Px(b, ox + x, oy + y, M2); }
    for (int i = 0; i < 5; i++) { int x = 2 + r.Next(28), y = 2 + r.Next(28); if (b.GetPixel(ox + x, oy + y).ToArgb() == M.ToArgb()) Px(b, ox + x, oy + y, S); }
  }
  static Bitmap Acera(){ var b = Lienzo(3, 1); for (int i = 0; i < 3; i++) Losa(b, i * 32, 0, 11 + i, LOSA, 16); return b; }
  // acera con bordillo: abajo (la acera esta encima de la calzada) y arriba (la acera esta debajo)
  static Bitmap AceraBordillo(bool abajo){
    var b = Lienzo(2, 1);
    for (int i = 0; i < 2; i++) {
      Losa(b, i * 32, 0, 31 + i, LOSA, 16);
      Asfalto(b, i * 32, abajo ? 0 : 0, 77 + i, abajo ? 28 : 0, abajo ? 32 : 3);
      if (abajo) { Rect(b, i * 32, 22, 32, 1, Q(0x8C8C94)); Rect(b, i * 32, 23, 32, 3, Q(0xE0E0D8)); Rect(b, i * 32, 26, 32, 2, Q(0x9C9CA4)); Rect(b, i * 32, 28, 32, 1, Q(0x5C5C68)); }
      else { Rect(b, i * 32, 3, 32, 1, Q(0x5C5C68)); Rect(b, i * 32, 4, 32, 4, Q(0xE0E0D8)); Rect(b, i * 32, 8, 32, 1, Q(0x8C8C94)); }
      for (int x = 0; x < 32; x += 16) Rect(b, i * 32 + x, abajo ? 23 : 4, 1, abajo ? 5 : 4, Q(0xA8A8B0));   // juntas del bordillo
    }
    return b;
  }
  static readonly int[] ASF = { 0x5E6068, 0x6E7078, 0x82848C };
  static void Asfalto(Bitmap b, int ox, int oy, int sem, int y0, int y1){
    var r = new Random(sem); var D = Q(ASF[0]); var M = Q(ASF[1]); var L = Q(ASF[2]);
    for (int y = y0; y < y1; y++) for (int x = 0; x < 32; x++) { int n = r.Next(100); Px(b, ox + x, oy + y, n < 7 ? D : (n < 11 ? L : M)); }
  }
  // calzada (3 variantes), paso de cebra (fila de arriba y de abajo) y tapa de alcantarilla
  static Bitmap Calzada(){
    var b = Lienzo(6, 1);
    for (int i = 0; i < 3; i++) Asfalto(b, i * 32, 0, 50 + i, 0, 32);
    for (int k = 0; k < 2; k++) {   // cebra: barra blanca de 20 px; arriba empieza en y 4, abajo acaba en y 27
      int ox = (3 + k) * 32; Asfalto(b, ox, 0, 60 + k, 0, 32);
      int ya = k == 0 ? 4 : 0, yb = k == 0 ? 32 : 28; var r = new Random(70 + k);
      for (int y = ya; y < yb; y++) for (int x = 6; x < 26; x++) { Color c = Q(0xF0F0F0); if (x == 25 || (k == 1 && y == yb - 1)) c = Q(0xC8C8C8); if (r.Next(100) < 4) c = Q(0xC8C8C8); Px(b, ox + x, y, c); }
    }
    int ax = 5 * 32; Asfalto(b, ax, 0, 90, 0, 32);
    Rect(b, ax + 6, 9, 20, 14, Q(0x3C3C48)); for (int x = 8; x < 25; x += 3) Rect(b, ax + x, 11, 1, 10, Q(0x74747C)); Rect(b, ax + 6, 23, 20, 1, Q(0x9C9CA4));
    return b;
  }
  // baldosa hidraulica del eje: la de cruces de Carmin (f.401-403 c0-2) pasada de oliva a rojo, dejando el crema
  static Bitmap Eje(){ var b = Trozo(ANIL, 401, 0, 3, 3); Tono(b, 25, 70, 12, 0.9, 0.95, 0.18, 0.62); return b; }
  // medallon ceramico de 5x5 en el centro del eje
  static Bitmap Medallon(Bitmap eje){
    var b = Lienzo(5, 5); var cen = Trozo(eje, 1, 1, 1, 1);
    for (int y = 0; y < 5; y++) for (int x = 0; x < 5; x++) Pegar(b, cen, x * 32, y * 32);
    double cx = 79.5, cy = 79.5; var oscuro = Q(0x5C3424); var azul = Q(0x3060A8); var azulc = Q(0x88B0E0); var crema = Q(0xF0E4C0); var rojo = Q(0xC04830); var ocre = Q(0xE0A048); var blanco = Q(0xF8F8F0);
    for (int y = 0; y < 160; y++) for (int x = 0; x < 160; x++) {
      double dx = x - cx, dy = y - cy, r = Math.Sqrt(dx * dx + dy * dy), a = Math.Atan2(dy, dx);
      Color? c = null;
      if (r < 74 && r >= 72) c = oscuro;
      else if (r < 72 && r >= 62) { int seg = (int)Math.Floor((a + Math.PI) / (Math.PI / 12)); c = (seg % 2 == 0) ? azul : azulc; if (Math.Abs(r - 67) < 1.6 && seg % 2 == 0) c = blanco; }
      else if (r < 62 && r >= 60) c = oscuro;
      else if (r < 60) {
        // estrella de 8 puntas
        double k = Math.Cos(4 * a); double radio = 26 + 26 * Math.Pow(Math.Max(0, k), 3);
        double k2 = Math.Cos(4 * (a + Math.PI / 4)); double radio2 = 18 + 18 * Math.Pow(Math.Max(0, k2), 3);
        if (r < 9) c = azul; else if (r < 11) c = oscuro;
        else if (r < radio) c = (r > radio - 2) ? oscuro : ((dx + dy < 0) ? rojo : Q(0x983828)); else if (r < radio2) c = (r > radio2 - 2) ? oscuro : ((dx + dy < 0) ? ocre : Q(0xB87830)); else c = ((x + y) % 7 == 0 && r > 40) ? Q(0xE0D0A8) : crema;
      }
      if (c.HasValue) Px(b, x, y, c.Value);
    }
    return b;
  }
  // alfombra roja 1x3 sobre la baldosa del eje (casilla del centro), con orla dorada y fleco arriba
  static Bitmap Alfombra(Bitmap eje){
    var b = Lienzo(1, 3); var cen = Trozo(eje, 1, 1, 1, 1); for (int y = 0; y < 3; y++) Pegar(b, cen, 0, y * 32);
    var R = Q(0xC02830); var Rs = Q(0x901828); var O = Q(0xE8B848);
    for (int y = 3; y < 96; y++) for (int x = 4; x < 28; x++) { Color c = R; if (x == 4 || x == 27) c = Rs; else if (x == 6 || x == 25) c = O; else if (x == 26 || x == 5) c = R; Px(b, x, y, c); }
    for (int x = 5; x < 27; x += 2) Px(b, x, 2, O);
    for (int x = 4; x < 28; x++) Px(b, x, 95, Rs);
    return b;
  }
}
