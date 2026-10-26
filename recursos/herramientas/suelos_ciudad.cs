using System; using System.Drawing; using System.Drawing.Imaging;
// Los suelos de la ciudad del gimnasio, pixel a pixel, con la paleta nocturna de la maqueta:
//   [SuelosCiudad]::Hacer(salida)  una hoja de 256 de ancho (8 casillas) con, por filas de casillas:
//     0: calzada de adoquin (4 variantes que casan entre si) + baldosa de la plaza (2) + baldosa de acera (2)
//     1-3: la acera con bordillo sobre la calzada, en 3x3 (esquinas, bordes y centro) + 4 esquinas interiores (1-2, cols 3-4)
//     4-6: la plaza con su borde de piedra sobre la calzada, en 3x3
//   Luz de arriba a la izquierda; cada material con claro, medio, sombra y junta.
public static class SuelosCiudad {
  static Color C(int r, int g, int b){ return Color.FromArgb(255, r, g, b); }
  // adoquin
  static readonly Color AJ = C(13, 12, 36), AS = C(21, 20, 54), AM = C(28, 27, 66), AC = C(38, 37, 82);
  // acera (baldosa)
  static readonly Color BJ = C(30, 29, 66), BS = C(44, 42, 88), BM = C(53, 51, 101), BC = C(66, 64, 118);
  // bordillo
  static readonly Color KO = C(15, 14, 38), KS = C(58, 56, 108), KM = C(78, 76, 134), KC = C(102, 100, 160);
  // plaza
  static readonly Color PJ = C(36, 34, 74), PS = C(45, 43, 90), PM = C(49, 47, 96), PC = C(60, 58, 112);

  static void Adoquin(Bitmap b, int ox, int oy, int semilla){
    var azar = new Random(semilla);
    for (int y = 0; y < 32; y++) for (int x = 0; x < 32; x++) b.SetPixel(ox + x, oy + y, AJ);
    // hileras de 8 px de alto; piedras de 10-12 px de ancho, desplazadas en cada hilera (y que casen al repetir)
    for (int f = 0; f < 4; f++) {
      int des = (f % 2 == 0) ? 0 : 5; int x = -des;
      while (x < 32) {
        int w = 10 + azar.Next(3); if (x + w > 32 && x < 32 && 32 - x < 6) w = 32 - x;   // que la ultima cierre en 32
        for (int yy = 1; yy < 7; yy++) for (int xx = 1; xx < w - 1; xx++) {
          int px = ((x + xx) % 32 + 32) % 32, py = f * 8 + yy;
          bool esquina = (yy == 1 || yy == 6) && (xx == 1 || xx == w - 2);
          if (esquina) continue;
          Color c = AM;
          if (yy == 1 || xx == 1) c = AC; else if (yy == 6 || xx == w - 2) c = AS;
          b.SetPixel(ox + px, oy + py, c);
        }
        x += w;
      }
    }
  }

  static void Baldosa(Bitmap b, int ox, int oy, Color j, Color s, Color m, Color c, int lado, int semilla){
    var azar = new Random(semilla);
    for (int y = 0; y < 32; y++) for (int x = 0; x < 32; x++) {
      int lx = x % lado, ly = y % lado; Color k = m;
      if (lx == lado - 1 || ly == lado - 1) k = j; else if (lx == 0 || ly == 0) k = c; else if (lx == lado - 2 || ly == lado - 2) k = s;
      b.SetPixel(ox + x, oy + y, k);
    }
    // alguna mota de desgaste
    for (int i = 0; i < 4; i++) { int x = 2 + azar.Next(28), y = 2 + azar.Next(28); var k = b.GetPixel(ox + x, oy + y); if (k.ToArgb() == m.ToArgb()) b.SetPixel(ox + x, oy + y, s); }
  }

  // un juego de 3x3 de un material encima de la calzada: borde de bordillo de 'g' px por fuera donde toca la calzada
  static void Juego3(Bitmap b, int ox, int oy, bool plaza){
    for (int fy = 0; fy < 3; fy++) for (int fx = 0; fx < 3; fx++) {
      int x0 = ox + fx * 32, y0 = oy + fy * 32;
      Adoquin(b, x0, y0, 7 + fx + fy * 3);
      for (int y = 0; y < 32; y++) for (int x = 0; x < 32; x++) {
        // distancia al borde del bloque 3x3 (en px), por cada lado que da a la calzada
        int gx = fx * 32 + x, gy = fy * 32 + y;
        int dl = gx, dr = 95 - gx, dt = gy, db = 95 - gy;
        int d = Math.Min(Math.Min(dl, dr), Math.Min(dt, db));
        // esquinas redondeadas (radio 6)
        int cx = Math.Max(0, Math.Max(6 - dl, 6 - dr)), cy = Math.Max(0, Math.Max(6 - dt, 6 - db));
        if (cx > 0 && cy > 0 && cx * cx + cy * cy > 36) continue;
        Color k;
        if (d < 1) k = KO;                              // contorno
        else if (d < 5) {                               // bordillo de 4 px: claro arriba-izquierda, sombra abajo-derecha
          bool luz = (dt == d || dl == d); k = (d == 1) ? (luz ? KC : KS) : (luz ? KM : KS);
          if (db == d || dr == d) k = (d == 1) ? KO : KS;
        } else {
          var baldosa = plaza ? new[] { PJ, PS, PM, PC } : new[] { BJ, BS, BM, BC }; int lado = plaza ? 32 : 16;
          int lx = gx % lado, ly = gy % lado;   // alineada con la baldosa suelta (casan)
          k = baldosa[2];
          if (lx == lado - 1 || ly == lado - 1) k = baldosa[0]; else if (lx == 0 || ly == 0) k = baldosa[3]; else if (lx == lado - 2 || ly == lado - 2) k = baldosa[1];
          if (d == 5 && (dt == 5 || dl == 5)) k = baldosa[1];   // sombra del bordillo sobre la acera
        }
        b.SetPixel(x0 + x, y0 + y, k);
      }
    }
  }

  // esquinas interiores: la acera llena con un mordisco de calzada en una esquina (para doblar calles)
  static void Interior(Bitmap b, int ox, int oy, int cual){
    Baldosa(b, ox, oy, BJ, BS, BM, BC, 16, 20 + cual);
    for (int y = 0; y < 32; y++) for (int x = 0; x < 32; x++) {
      int lx = (cual % 2 == 0) ? x : 31 - x, ly = (cual < 2) ? y : 31 - y;   // 0 arriba-izq, 1 arriba-der, 2 abajo-izq, 3 abajo-der
      double r = Math.Sqrt(lx * lx + ly * ly);
      if (r < 9) { var tmp = new Bitmap(32, 32); Adoquin(tmp, 0, 0, 3); b.SetPixel(ox + x, oy + y, tmp.GetPixel(x, y)); }
      else if (r < 10) b.SetPixel(ox + x, oy + y, KO);
      else if (r < 13) b.SetPixel(ox + x, oy + y, (r < 11.5) ? KC : KM);
    }
  }

  public static string Hacer(string sal){
    var b = new Bitmap(256, 7 * 32, PixelFormat.Format32bppArgb);
    for (int i = 0; i < 4; i++) Adoquin(b, i * 32, 0, 100 + i);
    Baldosa(b, 128, 0, PJ, PS, PM, PC, 32, 1); Baldosa(b, 160, 0, PJ, PS, PM, PC, 32, 2);
    Baldosa(b, 192, 0, BJ, BS, BM, BC, 16, 3); Baldosa(b, 224, 0, BJ, BS, BM, BC, 16, 4);
    Juego3(b, 0, 32, false);
    for (int i = 0; i < 4; i++) Interior(b, 96 + (i % 2) * 32, 32 + (i / 2) * 32, i);
    Juego3(b, 0, 128, true);
    b.Save(sal, ImageFormat.Png);
    return "suelos 256x224";
  }
}
