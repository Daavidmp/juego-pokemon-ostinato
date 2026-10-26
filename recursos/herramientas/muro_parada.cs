using System; using System.Drawing; using System.Drawing.Imaging;
// Piezas dibujadas pixel a pixel para la ciudad del gimnasio (paleta de las fincas: piedra azulada de noche):
//   [MuroParada]::Muro(salida)    el muro bajo de piedra en todas las direcciones: 16 casillas (8x2), una por
//                                 cada combinacion de brazos (arriba, abajo, izquierda, derecha). Casilla = 1 + a*1
//                                 + b*2 + i*4 + d*8 - 1 ... se ordenan como MURO_ORDEN (ver abajo).
//   [MuroParada]::Parada(salida)  la parada de autobus (marquesina de la EMT), 3x3 casillas
public static class MuroParada {
  static Color C(int r, int g, int b){ return Color.FromArgb(255, r, g, b); }
  static Color CA(int a, int r, int g, int b){ return Color.FromArgb(a, r, g, b); }
  static readonly Color O = C(14, 14, 34), TC = C(104, 112, 160), TM = C(82, 90, 134), TS = C(64, 70, 112),
                        FC = C(66, 72, 114), FM = C(52, 58, 96), FS = C(40, 44, 78), JU = C(28, 30, 58);
  // orden de las 16 casillas: arriba, abajo, izquierda, derecha (1 = hay muro hacia ese lado)
  public static readonly string[] MURO_ORDEN = {
    "0011", "0001", "0010", "1100", "0100", "1000", "0101", "0110",
    "1001", "1010", "0111", "1011", "1101", "1110", "1111", "0000" };

  // un trozo de cara (la piedra de delante) entre x0 y x1, de y0 a y1, con hiladas
  static void Cara(Bitmap b, int ox, int oy, int x0, int x1, int y0, int y1){
    for (int y = y0; y < y1; y++) for (int x = x0; x < x1; x++) {
      int fila = (y - y0) / 6, des = (fila % 2) * 5;
      bool junta = (y - y0) % 6 == 5 || ((x + des) % 10 == 0);
      Color k = junta ? JU : FM;
      if (!junta && (y - y0) % 6 == 0) k = FC; else if (!junta && (x + des) % 10 == 9) k = FS;
      if (y == y1 - 1) k = O;
      b.SetPixel(ox + x, oy + y, k);
    }
  }
  static void Tapa(Bitmap b, int ox, int oy, int x0, int x1, int y0, int y1){
    for (int y = y0; y < y1; y++) for (int x = x0; x < x1; x++) {
      Color k = TM; if (y == y0 || x == x0) k = TC; else if (y == y1 - 1 || x == x1 - 1) k = TS;
      b.SetPixel(ox + x, oy + y, k);
    }
  }
  static void Casilla(Bitmap b, int ox, int oy, string m){
    bool a = m[0] == '1', ab = m[1] == '1', i = m[2] == '1', d = m[3] == '1';
    // el muro: 12 px de grueso visto desde arriba (la tapa) y 14 px de cara por delante
    int cx0 = 10, cx1 = 22, cy0 = 4, cy1 = 14;
    int tx0 = i ? 0 : cx0, tx1 = d ? 32 : cx1;        // tramo horizontal
    int ty0 = a ? 0 : cy0, ty1 = ab ? 32 : cy1;      // tramo vertical
    // contorno de fuera (1 px) alrededor de lo que hay
    // cara de delante: debajo de la tapa horizontal, salvo donde baja el tramo vertical
    if (i || d || !ab) {
      Cara(b, ox, oy, tx0, tx1, cy1, Math.Min(32, cy1 + 14));
      if (ab) for (int y = cy1; y < Math.Min(32, cy1 + 14); y++) for (int x = cx0; x < cx1; x++) b.SetPixel(ox + x, oy + y, Color.Transparent);
    }
    // costado del tramo vertical (a la derecha, en sombra) donde baja
    if (ab || a) for (int y = ty0; y < ty1; y++) { b.SetPixel(ox + cx1, oy + y, FS); b.SetPixel(ox + cx1 + 1, oy + y, O); b.SetPixel(ox + cx0 - 1, oy + y, O); }
    if (i || d) for (int x = tx0; x < tx1; x++) b.SetPixel(ox + x, oy + cy0 - 1, O);
    Tapa(b, ox, oy, tx0, tx1, cy0, cy1);
    Tapa(b, ox, oy, cx0, cx1, ty0, ty1);
    // la cara del extremo de abajo del tramo vertical
    if (ab == false && (a)) Cara(b, ox, oy, cx0, cx1, cy1, cy1 + 14);
  }

  public static string Muro(string sal){
    var b = new Bitmap(256, 64, PixelFormat.Format32bppArgb);
    for (int k = 0; k < 16; k++) Casilla(b, (k % 8) * 32, (k / 8) * 32, MURO_ORDEN[k]);
    b.Save(sal, ImageFormat.Png);
    return "muro 16 casillas";
  }

  public static string Parada(string sal){
    var b = new Bitmap(96, 96, PixelFormat.Format32bppArgb);
    Color rojo = C(170, 40, 46), rojoC = C(214, 70, 72), rojoS = C(110, 24, 32), metal = C(120, 128, 150), metalS = C(70, 76, 100),
          cristal = CA(110, 150, 200, 240), cristalB = CA(170, 200, 230, 255), banco = C(60, 50, 54), bancoC = C(92, 78, 80),
          panel = C(220, 236, 255), panelM = C(120, 170, 230), panelS = C(60, 90, 150);
    // tejado: losa roja vista desde arriba (filas 6-20), con su canto
    for (int y = 6; y < 22; y++) for (int x = 2; x < 94; x++) {
      Color k = rojo; if (y == 6) k = O; else if (y == 7 || x == 3) k = rojoC; else if (y >= 19) k = (y == 21) ? O : rojoS; else if (x == 92) k = rojoS;
      if (x == 2 || x == 93) k = O; b.SetPixel(x, y, k); }
    // cristal del fondo (entre los postes), con reflejos en diagonal
    for (int y = 22; y < 70; y++) for (int x = 8; x < 66; x++) { var k = ((x + y) % 23 < 2) ? cristalB : cristal; b.SetPixel(x, y, k); }
    // postes y marco
    foreach (int px in new[] { 6, 7, 66, 67, 88, 89 }) for (int y = 22; y < 90; y++) b.SetPixel(px, y, (px % 2 == 0) ? metal : metalS);
    for (int x = 6; x < 90; x++) { b.SetPixel(x, 22, metalS); b.SetPixel(x, 70, metal); }
    // panel de anuncio iluminado (a la derecha)
    for (int y = 26; y < 86; y++) for (int x = 68; x < 88; x++) {
      Color k = panelM; if (x == 68 || x == 87 || y == 26 || y == 85) k = metalS; else if (x < 72 || y < 30) k = panel; else if (y > 74) k = panelS;
      b.SetPixel(x, y, k); }
    for (int y = 34; y < 70; y += 9) for (int x = 72; x < 84; x++) b.SetPixel(x, y, panel);
    // halo del panel
    for (int y = 20; y < 92; y++) for (int x = 60; x < 96; x++) { if (b.GetPixel(x, y).A > 0) continue; double d = Math.Sqrt(Math.Pow(x - 78, 2) + Math.Pow(y - 56, 2)); if (d < 22) b.SetPixel(x, y, CA((int)(60 * (1 - d / 22)), 180, 210, 255)); }
    // banco dentro
    for (int y = 62; y < 74; y++) for (int x = 14; x < 60; x++) { Color k = (y < 65) ? bancoC : banco; if (y == 73) k = O; b.SetPixel(x, y, k); }
    foreach (int px in new[] { 18, 19, 54, 55 }) for (int y = 74; y < 86; y++) b.SetPixel(px, y, metalS);
    // sombra de contacto en el suelo
    for (int x = 4; x < 92; x++) { b.SetPixel(x, 90, CA(120, 0, 0, 20)); b.SetPixel(x, 91, CA(70, 0, 0, 20)); }
    b.Save(sal, ImageFormat.Png);
    return "parada 96x96";
  }
}
