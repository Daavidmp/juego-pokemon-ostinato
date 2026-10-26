using System; using System.Collections.Generic; using System.Drawing; using System.Drawing.Imaging; using System.IO; using System.Text;
// Cuarta parte de CiudadV2: las piezas de verdad de Firefly (convertidas por el taller) en lugar de los sustitutos.
//   [CiudadV2]::TALLER = "C:\Users\ASUS\Downloads\taller"   antes de [CiudadV2]::Hacer(...)
// Las fincas del borde de arriba no van sueltas: se juntan al pixel en dos tiras (izquierda y derecha del gimnasio)
// para que las fachadas se toquen aunque cada una mida lo que haya salido (sin columnas vacias entre ellas), y luego
// se cortan en casillas. La puerta de cada finca cae en la casilla donde esta su centro.
public static partial class CiudadV2 {
  public static string TALLER = null;
  public static string INFO = "";

  static Bitmap Cargar(string f){ using (var t = new Bitmap(f)) return t.Clone(new Rectangle(0, 0, t.Width, t.Height), PixelFormat.Format32bppArgb); }
  static int[,][] LeerProps(string f, int w, int h){
    var r = new int[w, h][]; for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) r[x, y] = new[] { 0, 5 };
    foreach (var l in File.ReadAllLines(f)) { var v = l.Trim().Split(' '); if (v.Length < 4) continue; int fi = int.Parse(v[0]), co = int.Parse(v[1]); if (co < w && fi < h) r[co, fi] = new[] { int.Parse(v[2]), int.Parse(v[3]) }; }
    return r;
  }
  static Pz Real(string nombre, string carpeta, int k){
    var img = Cargar(Path.Combine(TALLER, carpeta, "pieza_" + k + ".png")); int w = img.Width / 32, h = img.Height / 32;
    var pr = LeerProps(Path.Combine(TALLER, carpeta, "props_" + k + ".txt"), w, h);
    var p = new Pz { Nombre = nombre, Img = img, Regla = "taller", W = w, H = h, Paso = new int[w, h], Prio = new int[w, h], Lamina = false };
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) { p.Paso[x, y] = pr[x, y][0]; p.Prio[x, y] = pr[x, y][1]; }
    LISTA.Add(p); return p;
  }

  // ---------------------------------------------------------------- tiras de fincas al pixel
  class Finca { public Bitmap Img; public int MinX, MaxX, PuertaX; public int X; }
  static Finca Leer(string carpeta, int k, bool espejo, double tono, double sat){
    var img = Cargar(Path.Combine(TALLER, carpeta, "pieza_" + k + ".png")); int w = img.Width / 32, h = img.Height / 32;
    var pr = LeerProps(Path.Combine(TALLER, carpeta, "props_" + k + ".txt"), w, h);
    int puertaCol = -1; for (int x = 0; x < w; x++) if (pr[x, h - 2][0] == 0 && pr[x, h - 2][1] == 0) puertaCol = x;
    if (tono >= 0) Tono(img, 20, 75, tono, sat, 1.0, 0.15, 0.93);          // otra finca: el revoque de otro color
    if (espejo) { img.RotateFlip(RotateFlipType.RotateNoneFlipX); if (puertaCol >= 0) puertaCol = w - 1 - puertaCol; }
    var f = new Finca { Img = img, MinX = 9999, MaxX = -1, PuertaX = puertaCol >= 0 ? puertaCol * 32 + 16 : -1 };
    for (int y = 0; y < img.Height - 32; y++) for (int x = 0; x < img.Width; x++) if (img.GetPixel(x, y).A > 200) { f.MinX = Math.Min(f.MinX, x); f.MaxX = Math.Max(f.MaxX, x); }
    return f;
  }
  // coloca las fincas seguidas desde x0 (px) hasta x1: lo que sobre o falte se reparte entre las juntas
  static void Repartir(List<Finca> fs, int x0, int x1){
    int suma = 0; foreach (var f in fs) suma += f.MaxX - f.MinX + 1; int holgura = (x1 - x0) - suma, juntas = Math.Max(1, fs.Count - 1);
    int x = x0;
    for (int i = 0; i < fs.Count; i++) { fs[i].X = x - fs[i].MinX; x += fs[i].MaxX - fs[i].MinX + 1;
      if (i < fs.Count - 1) x += holgura / juntas + (i < Math.Abs(holgura) % juntas ? Math.Sign(holgura) : 0); }
  }
  static Pz Tira(string nombre, int anchoCas, int altoCas, List<Finca> fs){
    var b = Lienzo(anchoCas, altoCas); var cubre = new bool[anchoCas * 32];
    foreach (var f in fs) { Pegar(b, f.Img, f.X, 0); for (int x = f.MinX; x <= f.MaxX; x++) { int xx = f.X + x; if (xx >= 0 && xx < cubre.Length) cubre[xx] = true; } }
    // juntas que hayan quedado abiertas (1-3 px): una medianera oscura
    var med = Q(0x3C3440);
    for (int x = 1; x < anchoCas * 32 - 1; x++) { if (cubre[x]) continue; bool izq = false, der = false;
      for (int k = 1; k <= 4; k++) { if (x - k >= 0 && cubre[x - k]) izq = true; if (x + k < cubre.Length && cubre[x + k]) der = true; }
      if (!izq || !der) continue;
      for (int y = 0; y < (altoCas - 1) * 32; y++) { bool hay = (b.GetPixel(Math.Max(0, x - 1), y).A > 200) || (b.GetPixel(Math.Min(b.Width - 1, x + 1), y).A > 200); if (hay) Px(b, x, y, med); } }
    var p = new Pz { Nombre = nombre, Img = b, Regla = "tira", W = anchoCas, H = altoCas, Paso = new int[anchoCas, altoCas], Prio = new int[anchoCas, altoCas], Lamina = false };
    for (int cy = 0; cy < altoCas; cy++) for (int cx = 0; cx < anchoCas; cx++) {
      int op = 0, alg = 0; for (int y = 0; y < 32; y++) for (int x = 0; x < 32; x++) { int a = b.GetPixel(cx * 32 + x, cy * 32 + y).A; if (a > 200) op++; if (a > 0) alg++; }
      if (cy == altoCas - 1) { p.Paso[cx, cy] = 0; p.Prio[cx, cy] = alg > 0 ? 0 : 5; continue; }
      if (op == 0) { p.Paso[cx, cy] = 0; p.Prio[cx, cy] = 5; } else { p.Paso[cx, cy] = 15; p.Prio[cx, cy] = 0; } }
    var sb = new StringBuilder(nombre + ":");
    foreach (var f in fs) if (f.PuertaX >= 0) { int cx = (f.X + f.PuertaX) / 32; if (cx >= 0 && cx < anchoCas) { p.Paso[cx, altoCas - 2] = 0; p.Prio[cx, altoCas - 2] = 0; sb.Append(" puerta en la casilla " + cx + ";"); } }
    INFO += sb.ToString() + "\n";
    LISTA.Add(p); return p;
  }

  static void Reales(){
    Real("gimnasio", "gimnasio_discoteca", 1);
    Real("centro", "centro_pokemon_modernista", 1);
    Real("tienda", "tienda_mercado", 1);
    Real("finca_tatu", "finca_tatuajes", 2);
    var metro = Real("boca_metro", "boca_metro", 1);                 // escalera de 3 que se pisa; la marquesina tapa a Kaia
    for (int y = 0; y < 8; y++) for (int x = 2; x <= 4; x++) { metro.Paso[x, y] = 0; metro.Prio[x, y] = y < 2 ? 1 : 0; }
    for (int y = 0; y < 8; y++) foreach (int x in new[] { 0, 1, 5, 6 }) { metro.Paso[x, y] = 15; metro.Prio[x, y] = 0; }   // los lados de la boca no se pisan
    Real("totem", "totem_metro", 1);
    Real("autobus", "autobus_emt", 1);
    Real("naranjo", "naranjo_alcorque", 2);
    Real("contened", "contenedores", 2);
    Real("deposito", "deposito_agua", 1);
    Real("tendedero", "tendedero_ropa", 1);
    Real("antena", "antena_chimenea", 2);
    Real("moto", "moto_scooter", 2);
    // borde de arriba, izquierda del gimnasio (casillas 0-16): portal_b (en rosa), bar, portal_a, kebab
    var izq = new List<Finca> { Leer("finca_portal_b", 1, false, 12, 0.8), Leer("finca_bar", 1, false, -1, 1), Leer("finca_portal_a", 1, false, -1, 1), Leer("finca_kebab", 1, false, -1, 1) };
    Repartir(izq, 0, 17 * 32); Tira("fila_izq", 17, 8, izq);
    // derecha del gimnasio (casillas 28-43): discos, portal_b, [callejon 35-36], horchateria, portal_b en espejo y azul
    // v6: la finca verde menta (taller_decoinca_portal_c) en lugar de una de las tres portal_b
    string pc = DECO != null ? Path.Combine(DECO, "finca_portal_c") : null;
    var d1 = new List<Finca> { Leer("finca_discos", 1, false, -1, 1), (pc != null && Directory.Exists(pc)) ? Leer(pc, 1, false, -1, 1) : Leer("finca_portal_b", 1, false, -1, 1) };
    Repartir(d1, 0, 7 * 32); Tira("fila_der_a", 7, 8, d1);
    var d2 = new List<Finca> { Leer("finca_horchateria", 1, false, -1, 1), Leer("finca_portal_b", 1, true, 205, 0.5) };
    Repartir(d2, 0, 7 * 32); Tira("fila_der_b", 7, 8, d2);
    // finca cortada por el borde izquierdo, de cara a la calle de la EMT: las 2 columnas de la derecha de portal_a
    var pa = Leer("finca_portal_a", 1, false, 40, 0.7); var lado = Lienzo(2, 5); int cx0 = (pa.MaxX + 1) - 64;
    int[] filas = { 0, 3, 4, 5, 6 };
    for (int i = 0; i < 5; i++) using (var g = Graphics.FromImage(lado)) g.DrawImage(pa.Img, new Rectangle(0, i * 32, 64, 32), new Rectangle(cx0, filas[i] * 32, 64, 32), GraphicsUnit.Pixel);
    var pl = new Pz { Nombre = "finca_lado", Img = lado, Regla = "bloque", W = 2, H = 5, Paso = new int[2, 5], Prio = new int[2, 5] };
    for (int y = 0; y < 5; y++) for (int x = 0; x < 2; x++) { pl.Paso[x, y] = 15; pl.Prio[x, y] = 0; }
    LISTA.Add(pl);
  }
}
