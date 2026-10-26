using System; using System.Collections.Generic; using System.Drawing; using System.Drawing.Imaging; using System.IO; using System.Text;
// Monta la imagen de un tileset (256 de ancho) con piezas sueltas, por baldas: cada pieza ocupa casillas enteras
// (apoyada abajo y centrada), de izquierda a derecha; si no cabe, en la primera balda con hueco y altura parecida
// (hasta 2 casillas mas alta), si no, una balda nueva. Una pieza de mas de 8 casillas se parte en trozos de 8.
//   [MontarTileset]::Hacer(lista, salida)
// lista, una pieza por linea:  archivo.png  regla  [espejo]
//   regla: suelo (se pisa) | bloque / edificio (no se pisa) | alto:N (las N filas de abajo no se pisan; las de encima
//          se pisan y tapan a Kaia, prioridad 1)
//   Las casillas vacias de una pieza: se pisan y prioridad 5 (no deciden el paso).
// Deja salida.png, salida.txt (nombre fila col ancho alto, en casillas) y salida_props.txt (fila col paso prioridad).
public static class MontarTileset {
  class Pieza { public string Nombre, Regla; public Bitmap Img; public int W, H, Fila, Col; }
  public static string Hacer(string lista, string salida){
    var piezas = new List<Pieza>();
    foreach (var l0 in File.ReadAllLines(lista)) {
      var l = l0.Trim(); if (l.Length == 0 || l.StartsWith("#")) continue;
      var p = l.Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
      var b = new Bitmap(p[0]); bool esp = p.Length > 2 && p[2] == "espejo"; if (esp) b.RotateFlip(RotateFlipType.RotateNoneFlipX);
      int w = (b.Width + 31) / 32, h = (b.Height + 31) / 32;
      var c = new Bitmap(w * 32, h * 32, PixelFormat.Format32bppArgb);
      using (var g = Graphics.FromImage(c)) g.DrawImage(b, (w * 32 - b.Width) / 2, h * 32 - b.Height, b.Width, b.Height);
      string nombre = Path.GetFileNameWithoutExtension(p[0]) + (esp ? "_espejo" : "");
      for (int x0 = 0; x0 < w; x0 += 8) {
        int ww = Math.Min(8, w - x0);
        piezas.Add(new Pieza { Nombre = w > 8 ? nombre + "_" + (x0 / 8) : nombre, Regla = p[1], Img = c.Clone(new Rectangle(x0 * 32, 0, ww * 32, h * 32), c.PixelFormat), W = ww, H = h });
      }
    }
    var baldas = new List<int[]>();   // fila, alto, libre
    foreach (var q in piezas) {
      bool ok = false;
      foreach (var bl in baldas) if (bl[2] >= q.W && bl[1] >= q.H && (bl[1] - q.H <= 2 || q.W <= 2)) { q.Fila = bl[0] + bl[1] - q.H; q.Col = 8 - bl[2]; bl[2] -= q.W; ok = true; break; }
      if (!ok) { int f = 0; foreach (var bl in baldas) f = Math.Max(f, bl[0] + bl[1]); baldas.Add(new[] { f, q.H, 8 - q.W }); q.Fila = f; q.Col = 0; }
    }
    int filas = 0; foreach (var bl in baldas) filas = Math.Max(filas, bl[0] + bl[1]);
    var o = new Bitmap(256, filas * 32, PixelFormat.Format32bppArgb);
    var man = new StringBuilder(); var props = new StringBuilder();
    using (var g = Graphics.FromImage(o)) foreach (var q in piezas) {
      g.DrawImage(q.Img, q.Col * 32, q.Fila * 32, q.Img.Width, q.Img.Height);
      man.AppendLine(q.Nombre + " " + q.Fila + " " + q.Col + " " + q.W + " " + q.H);
      for (int y = 0; y < q.H; y++) for (int x = 0; x < q.W; x++) {
        bool vacia = true;
        for (int yy = 0; yy < 32 && vacia; yy += 2) for (int xx = 0; xx < 32; xx += 2) if (q.Img.GetPixel(x * 32 + xx, y * 32 + yy).A > 40) { vacia = false; break; }
        int paso = 0, prio = 0;
        if (vacia) prio = 5;
        else if (q.Regla == "bloque" || q.Regla == "edificio") paso = 15;
        else if (q.Regla.StartsWith("alto:")) { int n = int.Parse(q.Regla.Substring(5)); if (y >= q.H - n) paso = 15; else prio = 1; }
        props.AppendLine((q.Fila + y) + " " + (q.Col + x) + " " + paso + " " + prio);
      }
    }
    o.Save(salida, ImageFormat.Png);
    var bas = Path.Combine(Path.GetDirectoryName(salida), Path.GetFileNameWithoutExtension(salida));
    File.WriteAllText(bas + ".txt", man.ToString()); File.WriteAllText(bas + "_props.txt", props.ToString());
    return "tileset " + filas + " filas, " + piezas.Count + " piezas";
  }
}
