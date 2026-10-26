using System; using System.Collections.Generic; using System.Drawing; using System.Drawing.Imaging; using System.IO; using System.Text;
// Segunda parte de CiudadV2: murete de jardin (16 uniones), muro de contencion, escaleras, azoteas y objetos.
public static partial class CiudadV2 {
  // orden de las 16 uniones (arriba, abajo, izquierda, derecha), el mismo de plano_mapa.cs
  public static readonly string[] UNIONES = { "0011", "0001", "0010", "1100", "0100", "1000", "0101", "0110", "1001", "1010", "0111", "1011", "1101", "1110", "1111", "0000" };

  // ---------------------------------------------------------------- murete de jardin (1 fila de alto)
  // Se dibuja en planta (la huella del murete, 12 px de grueso) en un lienzo de 3x3 casillas con los brazos seguidos
  // hasta las vecinas, se levanta 10 px (albardilla arriba, cara de piedra delante) y se recorta la casilla del centro.
  static Bitmap Murete(){
    var b = Lienzo(8, 2); const int H = 10;
    var tapa = Q(0xECE4CC); var tapaS = Q(0xD0C4A8); var cara = Q(0xC8B090); var caraS = Q(0xA8906C); var junta = Q(0x8C7458);
    for (int i = 0; i < 16; i++) {
      string u = UNIONES[i]; bool N = u[0] == '1', S = u[1] == '1', O = u[2] == '1', E = u[3] == '1';
      Func<int, int, bool> F = (x, y) => {
        bool enX = x >= 42 && x <= 53, enY = y >= 48 && y <= 59;
        if (enX && enY) return true;
        if (N && enX && y < 48) return true; if (S && enX && y > 59) return true;
        if (O && enY && x < 42) return true; if (E && enY && x > 53) return true; return false; };
      var muro = new bool[96, 96]; var esTapa = new bool[96, 96];
      for (int y = 0; y < 96; y++) for (int x = 0; x < 96; x++) {
        if (y + H < 96 + H && F(x, y + H)) { muro[x, y] = true; esTapa[x, y] = true; continue; }
        for (int k = 0; k < H; k++) if (F(x, y + k)) { muro[x, y] = true; break; } }
      int ox = (i % 8) * 32, oy = (i / 8) * 32;
      for (int y = 32; y < 64; y++) for (int x = 32; x < 64; x++) {
        int px = ox + x - 32, py = oy + y - 32;
        if (!muro[x, y]) { if (muro[x - 2 < 0 ? 0 : x - 2, y - 2 < 0 ? 0 : y - 2] && !muro[x, y]) Px(b, px, py, SOMBRA); continue; }
        Color c;
        if (esTapa[x, y]) { c = tapa; if (!esTapa[x, Math.Min(95, y + 1)]) c = tapaS; }
        else { c = cara; int fy = 0; while (y - fy - 1 >= 0 && muro[x, y - fy - 1] && !esTapa[x, y - fy - 1]) fy++;
          if (fy == 0) c = caraS; else if ((fy == 5) || ((x + (fy > 5 ? 6 : 0)) % 12 == 0)) c = junta; }
        Px(b, px, py, c);
      }
    }
    Contorno(b); return b;
  }

  // ---------------------------------------------------------------- muro de contencion (2 filas) con barandilla
  // 4 columnas: 0 machon de la izquierda, 1-2 tramo (dos variantes que casan), 3 machon de la derecha.
  static Bitmap MuroContencion(){
    var b = Lienzo(4, 2);
    var luz = Q(0xF0D8A8); var med = Q(0xD8B878); var som = Q(0xB08850); var jun = Q(0x6C4C30); var base_ = Q(0x8C6840);
    var cop = Q(0xF0E8D8); var copS = Q(0xC8BCA8); var hierro = Q(0x343848); var hierroL = Q(0x5C6478);
    for (int y = 0; y < 64; y++) for (int x = 0; x < 128; x++) {
      Color? c = null;
      if (y >= 8 && y < 12) c = cop; else if (y == 12) c = copS;
      else if (y > 12 && y < 58) {
        int fila = (y - 13) / 11, ly = (y - 13) % 11; int des = (fila % 2) * 16; int lx = ((x + des) % 32);
        c = med; if (ly == 10 || lx == 31) c = jun; else if (ly == 0 || lx == 0) c = luz; else if (ly == 9 || lx == 30) c = som;
      } else if (y >= 58) c = (y >= 62) ? jun : base_;
      // barandilla de forja: pasamanos arriba, barrotes cada 6 px
      if (y < 8) { if (y == 1 || y == 2) c = (y == 1) ? hierroL : hierro; else if (y == 6) c = hierro; else if (x % 8 < 2) c = (x % 8 == 0) ? hierroL : hierro; }
      if (c.HasValue) Px(b, x, y, c.Value);
    }
    // machones de los extremos: pilastra mas clara con remate
    foreach (int mx in new[] { 0, 96 + 20 }) for (int y = 0; y < 62; y++) for (int x = mx; x < mx + 12; x++) {
      Color c = (y < 6) ? cop : ((x == mx || x == mx + 11) ? jun : (y < 8 ? copS : (((y - 8) % 14 == 13) ? jun : luz)));
      if (y < 6 && (x == mx || x == mx + 11 || y == 0)) c = copS; Px(b, x, y, c);
    }
    for (int y = 0; y < 8; y++) { for (int x = 12; x < 20; x++) Px(b, x, y, NADA); for (int x = 108; x < 116; x++) Px(b, x, y, NADA); }
    for (int y = 0; y < 8; y++) { if (y == 1 || y == 2 || y == 6) { for (int x = 12; x < 32; x++) Px(b, x, y, hierro); for (int x = 96; x < 116; x++) Px(b, x, y, hierro); } }
    for (int y = 0; y < 8; y++) for (int x = 16; x < 32; x += 8) { Px(b, x, y, hierroL); Px(b, x + 1, y, hierro); }
    for (int y = 0; y < 8; y++) for (int x = 96; x < 116; x += 8) { Px(b, x, y, hierroL); Px(b, x + 1, y, hierro); }
    return b;
  }
  // escaleras de 5 y de 3 de ancho y 2 filas: la de Carmin (f.56 y f.58, c5-7) con su columna del medio repetida
  static Bitmap Escalera(int ancho, Bitmap muro){
    var b = Lienzo(ancho, 2);
    for (int fy = 0; fy < 2; fy++) { int fila = fy == 0 ? 56 : 58;
      for (int x = 0; x < ancho; x++) { int col = x == 0 ? 5 : (x == ancho - 1 ? 7 : 6); Pegar(b, Trozo(muro, fy, 1 + x % 2, 1, 1), x * 32, fy * 32); Pegar(b, Trozo(ANIL, fila, col, 1, 1), x * 32, fy * 32); } }
    return b;
  }

  // ---------------------------------------------------------------- azoteas (juego de 3x3 con pretil)
  // tipo 0 rasilla roja, 1 baldosa gris, 2 baldosa ocre. El pretil: 5 px de albardilla en los bordes y, en el de
  // abajo, su cara (6 px) que se ve desde la calle.
  static Bitmap Azotea(int tipo){
    var b = Lienzo(3, 3);
    int[][] cols = { new[] { 0x985040, 0xB86848, 0xC87850, 0xD89068 }, new[] { 0x787880, 0x9898A0, 0xA8A8A8, 0xC0C0C0 }, new[] { 0x987848, 0xB89060, 0xC8A070, 0xD8B880 } };
    var cc = cols[tipo]; var J = Q(cc[0]); var S = Q(cc[1]); var M = Q(cc[2]); var L = Q(cc[3]);
    var alb = Q(0xF0E8D8); var albS = Q(0xD0C8B8); var cara = Q(0xC8BCA8); var caraS = Q(0xA89C88); var r = new Random(5 + tipo);
    for (int y = 0; y < 96; y++) for (int x = 0; x < 96; x++) {
      Color c;
      if (tipo == 0) { int lx = x % 16, ly = y % 16; c = ((x / 16 + y / 16) % 2 == 0) ? M : S; if (lx == 15 || ly == 15) c = Q(0xE0C8A8); else if (lx == 0 || ly == 0) c = L; }
      else { int lx = x % 16, ly = y % 16; c = M; if (lx == 15 || ly == 15) c = J; else if (lx == 0 || ly == 0) c = L; else if (lx == 14 || ly == 14) c = S; }
      if (c.ToArgb() == M.ToArgb() && r.Next(100) < 3) c = S;
      // pretil
      if (y >= 85) c = (y == 85) ? albS : (y >= 94 ? caraS : cara);
      else if (y < 5 || x < 5 || x >= 91) c = (y == 4 && x >= 5 && x < 91) || x == 4 || x == 91 ? albS : alb;
      else if (y >= 80) c = (y == 80) ? albS : alb;
      Px(b, x, y, c);
    }
    // sombra del pretil sobre el terrado (arriba y a la izquierda, la luz viene de arriba a la izquierda)
    for (int x = 5; x < 91; x++) Sombrear(b, x, 5); for (int y = 5; y < 80; y++) Sombrear(b, 5, y);
    for (int x = 0; x < 96; x++) Px(b, x, 95, Q(0x6C6458));
    return b;
  }
  // aire acondicionado y claraboya de azotea (1x1 cada uno)
  static Bitmap DetallesAzotea(){
    var b = Lienzo(2, 1);
    Rect(b, 5, 8, 22, 16, Q(0xE0E0E0)); Rect(b, 5, 20, 22, 4, Q(0xB0B0B8)); for (int x = 9; x < 21; x += 2) Rect(b, x, 11, 1, 7, Q(0x80808C)); Rect(b, 22, 11, 3, 3, Q(0x606070));
    for (int y = 24; y < 28; y++) for (int x = 7; x < 29; x++) Px(b, x, y, SOMBRA);
    Rect(b, 32 + 5, 6, 22, 20, Q(0xD0D0D0)); Rect(b, 32 + 7, 8, 18, 16, Q(0x88B0E0)); Rect(b, 32 + 7, 8, 18, 3, Q(0xC0D8F0)); Rect(b, 32 + 15, 8, 2, 16, Q(0xD0D0D0));
    for (int y = 26; y < 29; y++) for (int x = 32 + 7; x < 32 + 29; x++) Px(b, x, y, SOMBRA);
    Contorno(b); return b;
  }

  // ---------------------------------------------------------------- objetos de la calle
  // guirnalda de bombillas 10x3: dos postes y un cable con bombillas (las luces se encienden por codigo de noche)
  static Bitmap Guirnalda(){
    var b = Lienzo(10, 3); var palo = Q(0x5C4030); var paloL = Q(0x806048); var cable = Q(0x303038); var bomb = Q(0xF8E070); var bombS = Q(0xD8A838); var cas = Q(0x605848);
    foreach (int px in new[] { 13, 303 }) { Rect(b, px, 8, 5, 80, palo); Rect(b, px, 8, 2, 80, paloL); Rect(b, px - 2, 86, 9, 4, cas); for (int y = 90; y < 94; y++) for (int x = px - 2; x < px + 10; x++) Px(b, x, y, SOMBRA); }
    for (int x = 16; x < 305; x++) { double t = (x - 16) / 289.0; int y = (int)Math.Round(10 + 20 * 4 * t * (1 - t)); Px(b, x, y, cable);
      if ((x - 16) % 18 == 9) { Rect(b, x - 1, y + 1, 3, 2, cas); Rect(b, x - 1, y + 3, 3, 4, bomb); Px(b, x + 1, y + 6, bombS); } }
    return b;
  }
  // poste de laton con cordon de terciopelo (1x2)
  static Bitmap Cordon(){
    var b = Lienzo(1, 2); var oro = Q(0xE8B848); var oroS = Q(0xA87828); var ter = Q(0xC02830); var terS = Q(0x901828);
    foreach (int py in new[] { 6, 38 }) { Rect(b, 14, py, 4, 18, oro); Rect(b, 17, py, 1, 18, oroS); Rect(b, 12, py - 3, 8, 3, oro); Rect(b, 11, py + 18, 10, 3, oroS); for (int x = 12; x < 24; x++) Px(b, x, py + 21, SOMBRA); }
    for (int y = 9; y < 41; y++) { int x = 18 + (int)Math.Round(3 * Math.Sin((y - 9) / 32.0 * Math.PI)); Px(b, x, y, ter); Px(b, x + 1, y, terS); }
    return b;
  }
  // marquesina de la EMT 4x2: techo con la franja roja, cristal, banco y panel
  static Bitmap Marquesina(){
    var b = Lienzo(4, 2); var techo = Q(0xD8D8D8); var techoS = Q(0xA8A8B0); var rojo = Q(0xD03030); var vidrio = Q(0xB8D8E8); var vidrioL = Q(0xE0F0F8); var metal = Q(0x585C68); var banco = Q(0x8890A0);
    Rect(b, 2, 2, 124, 10, techo); Rect(b, 2, 10, 124, 3, rojo); Rect(b, 2, 13, 124, 2, techoS);
    Rect(b, 6, 15, 116, 30, vidrio); for (int i = 0; i < 6; i++) Rect(b, 16 + i * 18, 18 + i % 2, 6, 2, vidrioL);
    Rect(b, 4, 15, 3, 42, metal); Rect(b, 121, 15, 3, 42, metal); Rect(b, 63, 15, 2, 30, metal);
    Rect(b, 8, 16, 22, 34, Q(0xF0F0F0)); Rect(b, 10, 18, 18, 30, Q(0x3870C0)); Rect(b, 12, 36, 14, 8, Q(0xF8D048));   // panel de anuncio
    Rect(b, 34, 44, 84, 5, banco); Rect(b, 34, 49, 84, 2, metal); Rect(b, 38, 51, 3, 6, metal); Rect(b, 112, 51, 3, 6, metal);
    Contorno(b); for (int y = 57; y < 62; y++) for (int x = 4; x < 126; x++) Px(b, x, y, SOMBRA);
    return b;
  }
  // estacion de Valenbisi 5x2: las bicis de Anil (f.314-315 c0-3) en rojo, sobre su barra, y el totem
  static Bitmap Valenbisi(){
    var b = Lienzo(5, 2); var bicis = Trozo(ANIL, 314, 0, 4, 1); Tono(bicis, 0, 360, 2, 2.5, 1.1, 0.0, 0.55);
    Rect(b, 2, 50, 124, 4, Q(0x9898A0)); Rect(b, 2, 54, 124, 2, Q(0x686870)); for (int x = 8; x < 128; x += 30) Rect(b, x, 42, 4, 10, Q(0x585C68));
    Pegar(b, bicis, 0, 22);
    Rect(b, 136, 6, 16, 48, Q(0xE0E0E0)); Rect(b, 136, 6, 16, 10, Q(0xD03030)); Rect(b, 139, 20, 10, 12, Q(0x2C3C58)); Rect(b, 140, 21, 8, 4, Q(0x6890C8));
    Contorno(b); for (int y = 56; y < 60; y++) for (int x = 2; x < 156; x++) if (b.GetPixel(x, y).A == 0) Px(b, x, y, SOMBRA);
    return b;
  }
  // buzon de Correos: el de Anil (f.24-25 c5) en amarillo
  static Bitmap Buzon(){ var b = Trozo(ANIL, 24, 5, 1, 2); Tono(b, 0, 25, 48, 1.0, 1.25, 0.3); Tono(b, 340, 360, 48, 1.0, 1.25, 0.3); return b; }
}
