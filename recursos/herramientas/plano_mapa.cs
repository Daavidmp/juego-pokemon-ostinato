using System; using System.Collections.Generic; using System.Drawing; using System.Drawing.Imaging; using System.IO; using System.Text;
// Monta un mapa a partir de un plano en texto y del tileset hecho con montar_tileset.cs:
//   [PlanoMapa]::Hacer(plano, manifiesto, props, tileset_png, salida_capas, salida_png)
// Plano (una orden por linea, coordenadas en casillas; # comenta):
//   mapa ANCHO ALTO
//   calzada X Y W H         adoquin (4 variantes alternadas)
//   acera X Y W H           rectangulo de acera con su bordillo (juego 3x3)
//   plaza X Y W H           rectangulo de baldosa de plaza con su borde (juego 3x3)
//   franja PIEZA X Y W      repite una pieza a lo ancho en la capa de suelo (los tejados del fondo)
//   pieza NOMBRE X Y        una pieza del manifiesto, con su esquina de abajo a la izquierda en (X, Y)
//   muro X1 Y1 X2 Y2        un tramo recto de muro; las uniones se eligen solas (16 casillas del muro)
//   entrada X Y             por donde llega Kaia (para la revision)
//   puerta NOMBRE X Y       una puerta que tiene que poder alcanzarse (para la revision)
//   (ordenes generales, con cualquier pieza del manifiesto; CAPA = 0, 1 o 2, por defecto 0)
//   relleno PIEZA X Y W H [CAPA]     repite la pieza entera como un mosaico (casa con su propio tamano)
//   variado PIEZA X Y W H [CAPA]     cada casilla, una columna de la pieza al azar (variantes de 1 casilla)
//   juego PIEZA X Y W H [ABRE] [CAPA] rectangulo con la pieza como juego de 3x3 (esquinas, bordes y centro; si es mas
//                                    grande, las filas y columnas del medio se repiten). ABRE: letras n s o e de los
//                                    lados sin borde (se usan las casillas del medio), o "-"
//   fila3 PIEZA X Y W                tramo horizontal: primera columna, las del medio alternadas y la ultima (capa 1)
//   suelo NOMBRE X Y                 como pieza, pero en la capa 0 (dibujos de suelo: medallon, alfombra)
//   tramo PIEZA X1 Y1 X2 Y2          como muro, con una pieza de 16 uniones (8x2) del manifiesto
//   rejilla PIEZA ARCHIVO            el suelo hecho con transiciones.cs: ARCHIVO es su indice ("y: i i i") en la hoja PIEZA
// Ademas se revisa solo: % que se pisa, si se llega a cada puerta y los huecos vacios grandes (_revision.png).
// Capas: 0 suelo (y las franjas); 1 las piezas; 2 lo que no cabe en la 1 o lo que tapa a Kaia (prioridad >= 1).
// Las casillas vacias de una pieza no se ponen. Salida: capas en texto ("capa y: ids...") y un PNG del mapa.
public static class PlanoMapa {
  static readonly string[] MURO = { "0011", "0001", "0010", "1100", "0100", "1000", "0101", "0110", "1001", "1010", "0111", "1011", "1101", "1110", "1111", "0000" };
  public static string Hacer(string plano, string manifiesto, string props, string tilesetPng, string salCapas, string salPng){
    var man = new Dictionary<string, int[]>();
    foreach (var l in File.ReadAllLines(manifiesto)) { var v = l.Trim().Split(' '); if (v.Length < 5) continue; man[v[0]] = new[] { int.Parse(v[1]), int.Parse(v[2]), int.Parse(v[3]), int.Parse(v[4]) }; }
    var prio = new Dictionary<int, int>(); var paso = new Dictionary<int, int>();
    foreach (var l in File.ReadAllLines(props)) { var v = l.Trim().Split(' '); if (v.Length < 4) continue; int idp = 384 + int.Parse(v[0]) * 8 + int.Parse(v[1]); prio[idp] = int.Parse(v[3]); paso[idp] = int.Parse(v[2]); }
    var entradas = new List<int[]>(); var puertas = new List<KeyValuePair<string, int[]>>();
    int W = 0, H = 0; int[,,] m = null; var muro = new HashSet<long>();
    int f0 = man.ContainsKey("suelos") ? man["suelos"][0] : 0; var tramos = new Dictionary<string, HashSet<long>>();
    Func<int, int, int> T = (fila, col) => 384 + (f0 + fila) * 8 + col;
    var errores = new StringBuilder();
    foreach (var l0 in File.ReadAllLines(plano)) {
      var l = l0.Split('#')[0].Trim(); if (l.Length == 0) continue;
      var v = l.Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
      Func<int, int> N = k => int.Parse(v[k]);
      switch (v[0]) {
        case "mapa": W = N(1); H = N(2); m = new int[W, H, 3]; break;
        case "calzada": for (int y = N(2); y < N(2) + N(4); y++) for (int x = N(1); x < N(1) + N(3); x++) if (x >= 0 && y >= 0 && x < W && y < H) m[x, y, 0] = T(0, ((x * 7 + y * 3) % 4 + 4) % 4); break;
        case "acera": case "plaza": {
          int fila = v[0] == "acera" ? 1 : 4;
          for (int y = N(2); y < N(2) + N(4); y++) for (int x = N(1); x < N(1) + N(3); x++) {
            if (x < 0 || y < 0 || x >= W || y >= H) continue;
            int cx = x == N(1) ? 0 : (x == N(1) + N(3) - 1 ? 2 : 1), cy = y == N(2) ? 0 : (y == N(2) + N(4) - 1 ? 2 : 1);
            m[x, y, 0] = T(fila + cy, cx);
          } break; }
        case "franja": {
          if (!man.ContainsKey(v[1])) { errores.Append("falta " + v[1] + "; "); break; }
          var p = man[v[1]];
          for (int x = 0; x < N(4); x++) for (int y = 0; y < p[3]; y++) { int xx = N(2) + x, yy = N(3) + y; if (xx >= W || yy >= H) continue; m[xx, yy, 0] = 384 + (p[0] + y) * 8 + p[1] + (x % p[2]); }
          break; }
        case "pieza": {
          if (!man.ContainsKey(v[1])) { errores.Append("falta " + v[1] + "; "); break; }
          var p = man[v[1]]; int x0 = N(2), y0 = N(3) - p[3] + 1;
          for (int y = 0; y < p[3]; y++) for (int x = 0; x < p[2]; x++) {
            int xx = x0 + x, yy = y0 + y; if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue;
            int id = 384 + (p[0] + y) * 8 + p[1] + x; int pr = prio.ContainsKey(id) ? prio[id] : 0;
            if (pr == 5) continue;                            // casilla vacia de la pieza
            int capa = (pr >= 1 || m[xx, yy, 1] != 0) ? 2 : 1;
            if (capa == 2 && m[xx, yy, 2] != 0 && m[xx, yy, 1] == 0) capa = 1;
            m[xx, yy, capa] = id;
          } break; }
        case "relleno": case "variado": case "juego": {
          if (!man.ContainsKey(v[1])) { errores.Append("falta " + v[1] + "; "); break; }
          var p = man[v[1]]; int X = N(2), Y = N(3), Wr = N(4), Hr = N(5); string abre = "-"; int capa = 0;
          for (int k = 6; k < v.Length; k++) { int cc; if (int.TryParse(v[k], out cc)) capa = cc; else abre = v[k]; }
          for (int y = Y; y < Y + Hr; y++) for (int x = X; x < X + Wr; x++) {
            if (x < 0 || y < 0 || x >= W || y >= H) continue; int fy, fx;
            if (v[0] == "relleno") { fx = (x - X) % p[2]; fy = (y - Y) % p[3]; }
            else if (v[0] == "variado") { fx = (int)((uint)(x * 73856093 ^ y * 19349663) % (uint)p[2]); fy = (y - Y) % p[3]; }
            else {
              Func<int, int, int, bool, bool, int> pos = (i, n, tam, abreIni, abreFin) => {
                if (i == 0 && !abreIni) return 0; if (i == n - 1 && !abreFin) return tam - 1;
                return tam <= 2 ? 0 : 1 + ((i - 1) % (tam - 2) + (tam - 2)) % (tam - 2); };
              fx = pos(x - X, Wr, p[2], abre.Contains("o"), abre.Contains("e")); fy = pos(y - Y, Hr, p[3], abre.Contains("n"), abre.Contains("s"));
            }
            int id = 384 + (p[0] + fy) * 8 + p[1] + fx; int pr = prio.ContainsKey(id) ? prio[id] : 0;
            if (capa > 0 && pr == 5) continue; m[x, y, capa] = id;
          } break; }
        case "fila3": {
          if (!man.ContainsKey(v[1])) { errores.Append("falta " + v[1] + "; "); break; }
          var p = man[v[1]]; int X = N(2), Y = N(3), Wr = N(4);
          for (int y = 0; y < p[3]; y++) for (int x = 0; x < Wr; x++) {
            int xx = X + x, yy = Y + y; if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue;
            int fx = x == 0 ? 0 : (x == Wr - 1 ? p[2] - 1 : 1 + (x - 1) % Math.Max(1, p[2] - 2));
            int id = 384 + (p[0] + y) * 8 + p[1] + fx; if (prio.ContainsKey(id) && prio[id] == 5) continue;
            m[xx, yy, m[xx, yy, 1] == 0 ? 1 : 2] = id;
          } break; }
        case "suelo": {
          if (!man.ContainsKey(v[1])) { errores.Append("falta " + v[1] + "; "); break; }
          var p = man[v[1]]; int x0 = N(2), y0 = N(3) - p[3] + 1;
          for (int y = 0; y < p[3]; y++) for (int x = 0; x < p[2]; x++) { int xx = x0 + x, yy = y0 + y; if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue;
            int id = 384 + (p[0] + y) * 8 + p[1] + x; if (prio.ContainsKey(id) && prio[id] == 5) continue; m[xx, yy, 0] = id; }
          break; }
        case "tramo": {
          if (!tramos.ContainsKey(v[1])) tramos[v[1]] = new HashSet<long>();
          int x1 = N(2), y1 = N(3), x2 = N(4), y2 = N(5);
          for (int y = Math.Min(y1, y2); y <= Math.Max(y1, y2); y++) for (int x = Math.Min(x1, x2); x <= Math.Max(x1, x2); x++) tramos[v[1]].Add((long)x << 32 | (uint)y);
          break; }
        case "rejilla": {   // rejilla PIEZA ARCHIVO: el suelo de transiciones.cs (indice de cada casilla en la hoja PIEZA)
          if (!man.ContainsKey(v[1])) { errores.Append("falta " + v[1] + "; "); break; }
          var p = man[v[1]]; string ruta = l.Substring(l.IndexOf(v[1]) + v[1].Length).Trim();
          foreach (var fl in File.ReadAllLines(ruta)) { var partes = fl.Split(':'); if (partes.Length < 2) continue; int y = int.Parse(partes[0].Trim());
            var ids = partes[1].Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
            for (int x = 0; x < ids.Length && x < W; x++) { int i = int.Parse(ids[x]); if (y < H) m[x, y, 0] = 384 + (p[0] + i / 8) * 8 + p[1] + i % 8; } }
          break; }
        case "entrada": entradas.Add(new[] { N(1), N(2) }); break;
        case "puerta": puertas.Add(new KeyValuePair<string, int[]>(v[1], new[] { N(2), N(3) })); break;
        case "muro": {
          int x1 = N(1), y1 = N(2), x2 = N(3), y2 = N(4);
          for (int y = Math.Min(y1, y2); y <= Math.Max(y1, y2); y++) for (int x = Math.Min(x1, x2); x <= Math.Max(x1, x2); x++) muro.Add((long)x << 32 | (uint)y);
          break; }
      }
    }
    // los tramos con piezas de 16 uniones (mismo orden que MURO)
    foreach (var kv in tramos) {
      if (!man.ContainsKey(kv.Key)) { errores.Append("falta " + kv.Key + "; "); continue; } var pt = man[kv.Key]; var set = kv.Value;
      foreach (var k in set) {
        int x = (int)(k >> 32), y = (int)(k & 0xFFFFFFFF);
        Func<int, int, bool> hay = (a, b) => set.Contains((long)a << 32 | (uint)b);
        string c = (hay(x, y - 1) ? "1" : "0") + (hay(x, y + 1) ? "1" : "0") + (hay(x - 1, y) ? "1" : "0") + (hay(x + 1, y) ? "1" : "0");
        int i = Array.IndexOf(MURO, c);
        if (x >= 0 && y >= 0 && x < W && y < H) m[x, y, m[x, y, 1] == 0 ? 1 : 2] = 384 + (pt[0] + i / 8) * 8 + pt[1] + i % 8;
      }
    }
    // el muro: cada casilla con los brazos hacia sus vecinas de muro
    var pm = man.ContainsKey("muro") ? man["muro"] : null; if (pm == null) muro.Clear();
    foreach (var k in muro) {
      int x = (int)(k >> 32), y = (int)(k & 0xFFFFFFFF);
      Func<int, int, bool> hay = (a, b) => muro.Contains((long)a << 32 | (uint)b);
      string c = (hay(x, y - 1) ? "1" : "0") + (hay(x, y + 1) ? "1" : "0") + (hay(x - 1, y) ? "1" : "0") + (hay(x + 1, y) ? "1" : "0");
      int i = Array.IndexOf(MURO, c);
      if (x >= 0 && y >= 0 && x < W && y < H) m[x, y, 1] = 384 + (pm[0] + i / 8) * 8 + pm[1] + i % 8;
    }
    // salida en texto
    var sb = new StringBuilder(); sb.AppendLine("mapa " + W + " " + H);
    for (int z = 0; z < 3; z++) for (int y = 0; y < H; y++) { sb.Append("capa " + z + " " + y + ":"); for (int x = 0; x < W; x++) sb.Append(" " + m[x, y, z]); sb.AppendLine(); }
    File.WriteAllText(salCapas, sb.ToString());
    // dibujo
    var ts = new Bitmap(tilesetPng); var o = new Bitmap(W * 32, H * 32, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(o)) {
      g.Clear(Color.Black);
      for (int z = 0; z < 3; z++) for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
        int id = m[x, y, z]; if (id < 384) continue; int r = (id - 384) / 8, cc = (id - 384) % 8;
        g.DrawImage(ts, new Rectangle(x * 32, y * 32, 32, 32), new Rectangle(cc * 32, r * 32, 32, 32), GraphicsUnit.Pixel);
      }
    }
    o.Save(salPng, ImageFormat.Png);
    string rev = Revisar(m, W, H, paso, prio, entradas, puertas, o, Path.ChangeExtension(salPng, null) + "_revision.png");
    return "mapa " + W + "x" + H + (errores.Length > 0 ? " · " + errores : "") + rev;
  }

  // Revision automatica: se pisa como en Essentials (capa 2 -> 0; la primera casilla con prioridad 0 decide),
  // camino desde cada entrada a cada puerta, y los huecos grandes sin nada (lo que en Anil nunca pasa).
  // Dibuja en _revision.png lo que no se alcanza (rojo), las puertas (amarillo) y los huecos vacios (azul).
  static string Revisar(int[,,] m, int W, int H, Dictionary<int, int> paso, Dictionary<int, int> prio, List<int[]> ent, List<KeyValuePair<string, int[]>> pue, Bitmap dib, string sal){
    var pisa = new bool[W, H]; var libre = new bool[W, H]; int npisa = 0;
    for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
      bool ok = true;
      for (int z = 2; z >= 0; z--) { int id = m[x, y, z]; if (id == 0) continue; int pa = paso.ContainsKey(id) ? paso[id] : 0, pr = prio.ContainsKey(id) ? prio[id] : 0;
        if (pr == 5) continue; if ((pa & 15) == 15) { ok = false; break; } if (pr == 0) break; }
      pisa[x, y] = ok; if (ok) npisa++;
      libre[x, y] = ok && m[x, y, 1] == 0 && m[x, y, 2] == 0; }
    var sb = new StringBuilder(); sb.Append(" · se pisa el " + (npisa * 100 / (W * H)) + "% del mapa");
    var llega = new bool[W, H]; var q = new Queue<int[]>();
    foreach (var e in ent) if (e[0] >= 0 && e[1] >= 0 && e[0] < W && e[1] < H) { llega[e[0], e[1]] = true; q.Enqueue(e); }
    while (q.Count > 0) { var c = q.Dequeue();
      foreach (var d in new[] { new[] { 1, 0 }, new[] { -1, 0 }, new[] { 0, 1 }, new[] { 0, -1 } }) { int x = c[0] + d[0], y = c[1] + d[1];
        if (x < 0 || y < 0 || x >= W || y >= H || llega[x, y] || !pisa[x, y]) continue; llega[x, y] = true; q.Enqueue(new[] { x, y }); } }
    // una puerta se alcanza si Kaia llega a su casilla o a la de debajo (las puertas bloqueadas se tocan desde abajo)
    foreach (var p in pue) { int x = p.Value[0], y = p.Value[1];
      bool ok = (llega[x, y]) || (y + 1 < H && llega[x, y + 1]);
      sb.Append("\n  puerta " + p.Key + " (" + x + "," + y + "): " + (ok ? "se llega" : "NO SE LLEGA")); }
    // huecos: el cuadrado vacio mas grande en cada sitio (lado >= 6 casillas = demasiado vacio para una ciudad)
    var lado = new int[W + 1, H + 1]; var huecos = new List<int[]>();
    for (int y = H - 1; y >= 0; y--) for (int x = W - 1; x >= 0; x--) lado[x, y] = libre[x, y] ? 1 + Math.Min(lado[x + 1, y], Math.Min(lado[x, y + 1], lado[x + 1, y + 1])) : 0;
    var usado = new bool[W, H];
    for (int s = Math.Min(W, H); s >= 6; s--) for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
      if (lado[x, y] < s) continue; bool solapa = false;
      for (int yy = y; yy < y + s && !solapa; yy++) for (int xx = x; xx < x + s; xx++) if (usado[xx, yy]) { solapa = true; break; }
      if (solapa) continue; huecos.Add(new[] { x, y, s });
      for (int yy = y; yy < y + s; yy++) for (int xx = x; xx < x + s; xx++) usado[xx, yy] = true; }
    if (huecos.Count > 0) { sb.Append("\n  huecos vacios (x,y lado):"); foreach (var h in huecos.GetRange(0, Math.Min(8, huecos.Count))) sb.Append(" (" + h[0] + "," + h[1] + " " + h[2] + ")"); }
    else sb.Append("\n  sin huecos vacios grandes");
    int perdidas = 0; for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) if (pisa[x, y] && !llega[x, y] && ent.Count > 0) perdidas++;
    if (ent.Count > 0) sb.Append("\n  casillas pisables a las que no se llega: " + perdidas);
    var o = new Bitmap(dib);
    using (var g = Graphics.FromImage(o)) {
      var rojo = new SolidBrush(Color.FromArgb(110, 255, 0, 0)); var azul = new Pen(Color.FromArgb(220, 60, 160, 255), 4); var am = new Pen(Color.Yellow, 4);
      for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) if (pisa[x, y] && !llega[x, y] && ent.Count > 0) g.FillRectangle(rojo, x * 32, y * 32, 32, 32);
      foreach (var h in huecos) g.DrawRectangle(azul, h[0] * 32 + 2, h[1] * 32 + 2, h[2] * 32 - 4, h[2] * 32 - 4);
      foreach (var p in pue) g.DrawRectangle(am, p.Value[0] * 32 + 2, p.Value[1] * 32 + 2, 28, 28);
      foreach (var e in ent) g.FillEllipse(Brushes.Lime, e[0] * 32 + 8, e[1] * 32 + 8, 16, 16);
    }
    o.Save(sal, ImageFormat.Png);
    return sb.ToString();
  }
}
