using System; using System.Collections.Generic; using System.Drawing; using System.Drawing.Imaging; using System.IO; using System.Text;
// Tercera parte de CiudadV2: sustitutos grises de las piezas de Firefly (tamano exacto de su ficha), el tileset de
// trabajo (Exterior1 de Anil + todo lo nuevo detras), manifiesto, props y laminas de control al lado de Carmin.
public static partial class CiudadV2 {
  class Pz { public string Nombre, Regla; public Bitmap Img; public int W, H, Fila, Col; public int[,] Paso, Prio; public bool Lamina; }
  static List<Pz> LISTA = new List<Pz>();
  static Pz Nueva(string nombre, Bitmap img, string regla, bool lamina){
    var p = new Pz { Nombre = nombre, Img = img, Regla = regla, W = img.Width / 32, H = img.Height / 32, Lamina = lamina };
    p.Paso = new int[p.W, p.H]; p.Prio = new int[p.W, p.H];
    for (int y = 0; y < p.H; y++) for (int x = 0; x < p.W; x++) {
      if (Vacia(img, x, y)) { p.Paso[x, y] = 0; p.Prio[x, y] = 5; continue; }
      int pa = 0, pr = 0;
      if (regla == "bloque") pa = 15;
      else if (regla.StartsWith("alto:")) { int n = int.Parse(regla.Substring(5)); if (y >= p.H - n) pa = 15; else pr = 1; }
      else if (regla == "escalera") pa = (x == 0 || x == p.W - 1) ? 15 : 0;
      p.Paso[x, y] = pa; p.Prio[x, y] = pr;
    }
    LISTA.Add(p); return p;
  }
  static bool Vacia(Bitmap b, int cx, int cy){ for (int y = 0; y < 32; y++) for (int x = 0; x < 32; x++) if (b.GetPixel(cx * 32 + x, cy * 32 + y).A > 20) return false; return true; }

  // ---------------------------------------------------------------- sustitutos de las piezas de Firefly
  // edificio: tejado gris claro arriba, fachada gris medio en las 'fachada' filas de abajo, ventanas y puerta marcadas,
  // y la fila de sombra de Anil debajo. objeto: un bloque gris. pasa_detras: filas de arriba que se pisan y tapan.
  static Pz Sustituto(string nombre, int w, int h, int fachada, int puerta, string ventanas, int pasaDetras, bool sombra, bool objeto){
    int hs = h + (sombra ? 1 : 0); var b = Lienzo(w, hs);
    var tej = Q(0xB8B8C0); var fac = Q(0x9494A0); var ven = Q(0x5C6478); var pue = Q(0x3C4050); var lin = Q(0x4C4C58); var canto = Q(0xD0D0D8);
    for (int y = 0; y < h * 32; y++) for (int x = 0; x < w * 32; x++) {
      bool enFachada = objeto || y >= (h - fachada) * 32; Color c = enFachada ? fac : tej;
      if (!objeto && !enFachada && y >= (h - fachada) * 32 - 6) c = canto;          // canto del tejado / pretil
      if (x == 0 || y == 0 || x == w * 32 - 1 || y == h * 32 - 1 || (!objeto && y == (h - fachada) * 32)) c = lin;
      Px(b, x, y, c);
    }
    if (!string.IsNullOrEmpty(ventanas)) foreach (var v in ventanas.Split(' ')) { if (v.Length == 0) continue; var cf = v.Split(','); int vc = int.Parse(cf[0]), vf = int.Parse(cf[1]);
      int y0 = (h - 1 - vf) * 32; Rect(b, vc * 32 + 7, y0 + 6, 18, 18, ven); Rect(b, vc * 32 + 7, y0 + 6, 18, 3, Q(0x8890A8)); }
    if (puerta >= 0) { int y0 = (h - 1) * 32; Rect(b, puerta * 32 + 5, y0 - 13, 22, 45, pue); Rect(b, puerta * 32 + 5, y0 - 13, 22, 3, lin); }
    if (sombra) for (int y = h * 32; y < h * 32 + 14; y++) for (int x = 2; x < w * 32; x++) Px(b, x, y, SOMBRA);
    using (var g = Graphics.FromImage(b)) { var f = new Font("Arial", w >= 4 ? 8 : 6, FontStyle.Bold); var s = g.MeasureString(nombre, f);
      float ty = objeto ? 4 : Math.Max(2, ((h - fachada) * 32 - s.Height) / 2); g.DrawString(nombre, f, Brushes.White, Math.Max(1, (w * 32 - s.Width) / 2), ty); }
    var p = Nueva(nombre, b, "bloque", false);
    for (int y = 0; y < hs; y++) for (int x = 0; x < w; x++) {
      if (y >= h) { p.Paso[x, y] = 0; p.Prio[x, y] = 0; continue; }                    // la sombra se pisa
      p.Paso[x, y] = 15; p.Prio[x, y] = 0;
      if (y < pasaDetras) { p.Paso[x, y] = 0; p.Prio[x, y] = 1; }
      if (puerta == x && y == h - 1) { p.Paso[x, y] = 0; p.Prio[x, y] = 0; }
    }
    return p;
  }
  // la boca de metro: escalera de 3 en las columnas 2-4 que se pisa entera; la marquesina (filas 0-1) tapa a Kaia
  static Pz Metro(){
    var p = Sustituto("boca_metro", 7, 8, 8, -1, "", 0, false, true); var b = p.Img;
    for (int y = 0; y < 256; y++) for (int x = 64; x < 160; x++) Px(b, x, y, ((y / 8) % 2 == 0) ? Q(0xC8C8D0) : Q(0xA8A8B0));
    for (int y = 0; y < 64; y++) for (int x = 32; x < 192; x++) { var c = b.GetPixel(x, y); Px(b, x, y, Q(Color.FromArgb(255, c.R * 80 / 100, c.G * 80 / 100, c.B * 90 / 100))); }
    for (int y = 0; y < 8; y++) for (int x = 2; x <= 4; x++) { p.Paso[x, y] = 0; p.Prio[x, y] = y < 2 ? 1 : 0; }
    return p;
  }

  // ---------------------------------------------------------------- piezas de Anil que se usan con nombre
  static readonly string[] ANIL_PIEZAS = {
    "farola 404 4 1 5", "palmera 439 0 2 4", "fuente 326 0 4 6", "losa_naranja 399 2 3 2", "roseton 395 3 4 4", "cesped 0 0 4 4",
    "flor_a 3 5 1 1", "flor_b 3 6 1 1", "flor_c 4 5 1 1", "arbusto 0 4 1 2", "mesa 312 4 2 2", "taburete 313 3 1 1", "sombrilla 402 6 2 2",
    "banco_i 24 6 1 2", "banco_d 24 7 1 2", "papelera 22 7 1 1", "pizarra 24 4 1 2", "tablon 20 6 2 2", "puesto_azul 646 0 3 4",
    "puesto_rosa 651 0 3 4", "sacos 652 5 2 2", "vallas 227 3 2 1", "tarima 533 0 3 4" };

  public static string Hacer(string paleta, string anilPng, string anilProps, string carmin, string kaia, string sal){
    CargarPaleta(paleta); LISTA.Clear();
    var todo = new Bitmap(anilPng); ANIL = todo.Clone(new Rectangle(0, 0, 256, 730 * 32), PixelFormat.Format32bppArgb); todo.Dispose();
    Directory.CreateDirectory(sal); Directory.CreateDirectory(Path.Combine(sal, "piezas")); Directory.CreateDirectory(Path.Combine(sal, "laminas"));
    // (b) con codigo (en la v4, solo lo que no sale de Anil: ciudad_v2_v4.cs)
    if (V4) PiezasV4(); else {
    var eje = Eje();
    Nueva("acera", Acera(), "suelo", true);
    Nueva("acera_bs", AceraBordillo(true), "suelo", true);
    Nueva("acera_bn", AceraBordillo(false), "suelo", true);
    Nueva("calzada", Calzada(), "suelo", true);
    Nueva("eje", eje, "suelo", true);
    Nueva("medallon", Medallon(eje), "suelo", true);
    Nueva("alfombra", Alfombra(eje), "suelo", true);
    Nueva("murete", Murete(), "bloque", true);
    var muroC = MuroContencion(); Nueva("muro_c", muroC, "bloque", true);
    Nueva("escalera5", Escalera(5, muroC), "escalera", true);
    Nueva("escalera3", Escalera(3, muroC), "escalera", true);
    Nueva("azotea_a", Azotea(0), "bloque", true);
    Nueva("azotea_b", Azotea(1), "bloque", true);
    Nueva("azotea_c", Azotea(2), "bloque", true);
    Nueva("det_azotea", DetallesAzotea(), "bloque", true);
    Nueva("guirnalda", Guirnalda(), "alto:1", true);
    Nueva("cordon", Cordon(), "bloque", true);
    Nueva("marquesina", Marquesina(), "bloque", true);
    Nueva("valenbisi", Valenbisi(), "bloque", true);
    Nueva("buzon", Buzon(), "alto:1", true);
    }
    // (c) las de Firefly: de verdad si hay TALLER (ciudad_v2_firefly.cs), si no sustitutos con el tamano de su ficha
    INFO = ""; if (TALLER != null) Reales(); else {
    Sustituto("gimnasio", 11, 10, 5, 5, "1,1 2,1 3,1 7,1 8,1 9,1 1,3 3,3 7,3 9,3", 0, true, false);
    Sustituto("centro", 7, 8, 4, 3, "1,1 5,1 1,2 5,2 3,2", 0, true, false);
    Sustituto("tienda", 7, 7, 4, 3, "1,1 5,1 1,2 5,2", 0, true, false);
    Sustituto("finca_bar", 6, 7, 6, 2, "4,0 0,2 2,2 4,2 0,4 2,4 4,4", 0, true, false);
    Sustituto("finca_kebab", 5, 7, 6, 2, "0,2 2,2 4,2 0,4 2,4 4,4", 0, true, false);
    Sustituto("finca_discos", 5, 7, 6, 2, "0,0 4,0 0,2 2,2 4,2 0,4 2,4 4,4", 0, true, false);
    Sustituto("finca_horch", 5, 7, 6, 2, "0,0 4,0 0,2 2,2 4,2 0,4 2,4 4,4", 0, true, false);
    Sustituto("finca_tatu", 5, 5, 4, 2, "0,0 4,0 0,2 2,2 4,2", 0, true, false);
    Sustituto("portal_a", 6, 7, 6, 3, "0,2 1,2 2,2 3,2 4,2 5,2 0,4 1,4 2,4 3,4 4,4 5,4", 0, true, false);
    Sustituto("portal_b", 4, 7, 6, 1, "0,2 1,2 2,2 3,2 0,4 1,4 2,4 3,4", 0, true, false);
    Sustituto("finca_lado", 2, 5, 4, -1, "0,1 1,1 0,3 1,3", 0, false, false);
    Metro();
    Sustituto("totem", 1, 3, 3, -1, "", 1, false, true);
    Sustituto("autobus", 5, 3, 3, -1, "", 0, false, true);
    Sustituto("naranjo", 1, 2, 2, -1, "", 1, false, true);
    Sustituto("contened", 7, 2, 2, -1, "", 0, false, true);
    Sustituto("deposito", 2, 2, 2, -1, "", 0, false, true);
    Sustituto("tendedero", 2, 2, 2, -1, "", 0, false, true);
    Sustituto("antena", 1, 2, 2, -1, "", 0, false, true);
    Sustituto("moto", 1, 2, 2, -1, "", 0, false, true);
    }
    // colocar: Anil en las filas 0-729 y todo lo nuevo detras, por baldas de la misma altura
    var baldas = new List<int[]>(); int f0 = 730;   // fila, alto, columnas usadas
    var trozos = new List<Pz>();
    foreach (var p in LISTA) for (int x0 = 0; x0 < p.W; x0 += 8) {
      int ww = Math.Min(8, p.W - x0);
      var t = new Pz { Nombre = p.W > 8 ? p.Nombre + "_" + (x0 / 8) : p.Nombre, Img = p.Img.Clone(new Rectangle(x0 * 32, 0, ww * 32, p.H * 32), PixelFormat.Format32bppArgb), W = ww, H = p.H, Lamina = p.Lamina && x0 == 0, Paso = new int[ww, p.H], Prio = new int[ww, p.H] };
      for (int y = 0; y < p.H; y++) for (int x = 0; x < ww; x++) { t.Paso[x, y] = p.Paso[x0 + x, y]; t.Prio[x, y] = p.Prio[x0 + x, y]; }
      bool ok = false; foreach (var bl in baldas) if (bl[1] == t.H && 8 - bl[2] >= t.W) { t.Fila = bl[0]; t.Col = bl[2]; bl[2] += t.W; ok = true; break; }
      if (!ok) { int f = f0; foreach (var bl in baldas) f = Math.Max(f, bl[0] + bl[1]); baldas.Add(new[] { f, t.H, t.W }); t.Fila = f; t.Col = 0; }
      trozos.Add(t);
      p.Img.Save(Path.Combine(sal, "piezas", p.Nombre + ".png"), ImageFormat.Png);
    }
    int filas = f0; foreach (var bl in baldas) filas = Math.Max(filas, bl[0] + bl[1]);
    var ts = new Bitmap(256, filas * 32, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(ts)) { g.Clear(NADA); g.DrawImage(ANIL, 0, 0, 256, 730 * 32); foreach (var t in trozos) g.DrawImage(t.Img, t.Col * 32, t.Fila * 32, t.W * 32, t.H * 32); }
    ts.Save(Path.Combine(sal, "tileset.png"), ImageFormat.Png);
    // manifiesto y props (las casillas de Anil sin dibujo pasan a prioridad 5, como en el resto del proyecto)
    var man = new StringBuilder(); foreach (var l in ANIL_PIEZAS) man.AppendLine(l);
    foreach (var t in trozos) man.AppendLine(t.Nombre + " " + t.Fila + " " + t.Col + " " + t.W + " " + t.H);
    File.WriteAllText(Path.Combine(sal, "manifiesto.txt"), man.ToString());
    var pr = new StringBuilder();
    foreach (var l in File.ReadAllLines(anilProps)) { var v = l.Trim().Split(' '); if (v.Length < 4) continue; int fi = int.Parse(v[0]), co = int.Parse(v[1]);
      if (fi >= 730) continue; pr.AppendLine(fi + " " + co + " " + v[2] + " " + (Vacia(ANIL, co, fi) ? "5" : v[3])); }
    foreach (var t in trozos) for (int y = 0; y < t.H; y++) for (int x = 0; x < t.W; x++) pr.AppendLine((t.Fila + y) + " " + (t.Col + x) + " " + t.Paso[x, y] + " " + t.Prio[x, y]);
    File.WriteAllText(Path.Combine(sal, "props.txt"), pr.ToString());
    // laminas de control: la pieza x2 sobre acera, con Kaia, y al lado Carmin x2 (casillas 25-33, 4-12)
    var car = new Bitmap(carmin); var ka = new Bitmap(kaia); int nl = 0;
    var acera = LISTA[0].Img;
    foreach (var p in LISTA) { if (!p.Lamina) continue; nl++;
      int pw = Math.Max(4, p.W + 2) * 32, ph = Math.Max(8, p.H + 2) * 32; var l = new Bitmap(pw * 2 + 16 + 512, Math.Max(ph * 2, 512) + 20, PixelFormat.Format32bppArgb);
      using (var g = Graphics.FromImage(l)) { g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor; g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.Half;
        g.Clear(Color.FromArgb(255, 40, 40, 48));
        var fondo = new Bitmap(pw, ph); using (var gf = Graphics.FromImage(fondo)) { for (int y = 0; y < ph; y += 32) for (int x = 0; x < pw; x += 32) gf.DrawImage(acera, new Rectangle(x, y, 32, 32), new Rectangle(0, 0, 32, 32), GraphicsUnit.Pixel);
          gf.DrawImage(p.Img, 32, 32, p.Img.Width, p.Img.Height); gf.DrawImage(ka, new Rectangle(pw - 64, ph - 64, 64, 64), new Rectangle(0, 0, 64, 64), GraphicsUnit.Pixel); }
        g.DrawImage(fondo, new Rectangle(0, 20, pw * 2, ph * 2), new Rectangle(0, 0, pw, ph), GraphicsUnit.Pixel);
        g.DrawImage(car, new Rectangle(pw * 2 + 16, 20, 512, 512), new Rectangle(25 * 32, 4 * 32, 256, 256), GraphicsUnit.Pixel);
        g.DrawString(p.Nombre + " (" + p.W + "x" + p.H + ")  |  Carmin a la misma escala", new Font("Arial", 10), Brushes.White, 2, 2); }
      l.Save(Path.Combine(sal, "laminas", "lamina_" + p.Nombre + ".png"), ImageFormat.Png); }
    return INFO + "tileset " + filas + " filas (Anil 0-729, nuevas 730-" + (filas - 1) + "), " + trozos.Count + " trozos, " + nl + " laminas";
  }
}
