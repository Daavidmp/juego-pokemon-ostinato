using System; using System.Collections.Generic; using System.Drawing; using System.Drawing.Imaging; using System.Drawing.Drawing2D;
// Piezas de la megaevolucion (Plugins/Ostinato/034_MegaEvolucion.rb), en Graphics/Animations/Mega/:
//   [MegaPiezas]::Pixel(carpeta)  piezas pequenas en pixel art: destello, anillo, brillo, chispa, estrella (rayos de luz)
public static class MegaPiezas {
  // pixel art: cada pieza a su tamaño real (en el juego se amplia sin suavizar)
  public static string Pixel(string dir){
    Color B = Color.White, P = Color.FromArgb(255, 255, 150, 215), L = Color.FromArgb(255, 255, 215, 240);
    // destello de 4 puntas, 11x11
    var d = new Bitmap(11, 11, PixelFormat.Format32bppArgb);
    for (int i = 0; i < 11; i++) { int k = Math.Abs(i - 5);
      if (k <= 4) { d.SetPixel(5, i, k <= 1 ? B : (k <= 3 ? L : P)); d.SetPixel(i, 5, k <= 1 ? B : (k <= 3 ? L : P)); } }
    d.SetPixel(4, 4, L); d.SetPixel(6, 4, L); d.SetPixel(4, 6, L); d.SetPixel(6, 6, L);
    d.Save(dir + "\\destello.png", ImageFormat.Png);
    // chispa pequeña, 5x5
    var s = new Bitmap(5, 5, PixelFormat.Format32bppArgb);
    s.SetPixel(2, 0, P); s.SetPixel(2, 4, P); s.SetPixel(0, 2, P); s.SetPixel(4, 2, P);
    s.SetPixel(2, 1, L); s.SetPixel(2, 3, L); s.SetPixel(1, 2, L); s.SetPixel(3, 2, L); s.SetPixel(2, 2, B);
    s.Save(dir + "\\chispa.png", ImageFormat.Png);
    // anillo de 64: blanco con borde rosa, 4 px
    int A = 64; var an = new Bitmap(A, A, PixelFormat.Format32bppArgb); double c = (A - 1) / 2.0;
    for (int y = 0; y < A; y++) for (int x = 0; x < A; x++) {
      double r = Math.Sqrt((x - c) * (x - c) + (y - c) * (y - c));
      if (r <= c && r > c - 1.5) an.SetPixel(x, y, P); else if (r <= c - 1.5 && r > c - 3.5) an.SetPixel(x, y, B); else if (r <= c - 3.5 && r > c - 5) an.SetPixel(x, y, L);
    }
    an.Save(dir + "\\anillo.png", ImageFormat.Png);
    // brillo redondo de 48 a bandas (de blanco a rosa transparente)
    int R = 48; var br = new Bitmap(R, R, PixelFormat.Format32bppArgb); c = (R - 1) / 2.0;
    for (int y = 0; y < R; y++) for (int x = 0; x < R; x++) {
      double r = Math.Sqrt((x - c) * (x - c) + (y - c) * (y - c)) / c;
      if (r < 0.45) br.SetPixel(x, y, B); else if (r < 0.65) br.SetPixel(x, y, L);
      else if (r < 0.82) br.SetPixel(x, y, Color.FromArgb(200, P)); else if (r <= 1) br.SetPixel(x, y, Color.FromArgb(110, P));
    }
    br.Save(dir + "\\brillo.png", ImageFormat.Png);
    // estrella de 8 rayos de luz, 64x64: rayos finos que se afinan hacia fuera (para girar detras del colgante)
    int E = 64; var es = new Bitmap(E, E, PixelFormat.Format32bppArgb); c = (E - 1) / 2.0;
    for (int y = 0; y < E; y++) for (int x = 0; x < E; x++) {
      double dx = x - c, dy = y - c, r = Math.Sqrt(dx * dx + dy * dy); if (r > c || r < 3) continue;
      double a = Math.Atan2(dy, dx), paso = Math.PI / 4; double da = a - Math.Round(a / paso) * paso;   // angulo al rayo mas cercano
      bool cruz = i8(a);                                                     // los 4 en cruz, largos y anchos
      if (!cruz && r > c * 0.65) continue;
      double w = (cruz ? 3.2 : 1.8) * (1 - r / c) + 0.4;
      if (Math.Abs(r * Math.Sin(da)) > w) continue;
      es.SetPixel(x, y, r < c * 0.35 ? B : (r < c * 0.7 ? L : Color.FromArgb(200, P)));
    }
    es.Save(dir + "\\estrella.png", ImageFormat.Png);
    return "pixel ok";
  }
  // los rayos en cruz (arriba, abajo, izquierda, derecha) son los largos
  static bool i8(double a){ double k = Math.Abs(Math.Sin(a * 2)); return k < 0.5; }
}
