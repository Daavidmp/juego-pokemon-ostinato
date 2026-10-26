using System; using System.Collections.Generic; using System.Drawing; using System.Drawing.Imaging; using System.IO; using System.Text;
// Quinta parte de CiudadV2: la vuelta v4 (sin nada de Carmin). Suelos de Firefly montados con transiciones.cs,
// decoracion de Firefly (Descargas\taller_deco) y solo las piezas de codigo que no salen de Anil.
//   [CiudadV2]::V4 = $true; [CiudadV2]::DECO = "...\taller_deco"; [CiudadV2]::SUELOS = "...\suelo_tiles.png"
public static partial class CiudadV2 {
  public static bool V4 = false;
  public static string DECO = null, SUELOS = null;

  static Pz RealDe(string carpetaBase, string nombre, string carpeta, int k){ var t = TALLER; TALLER = carpetaBase; var p = Real(nombre, carpeta, k); TALLER = t; return p; }

  // escalera de piedra (2 filas) con zancas a los lados, sobre el muro de contencion
  static Bitmap EscaleraPiedra(int ancho, Bitmap muro){
    var b = Lienzo(ancho, 2); int W = ancho * 32;
    for (int fy = 0; fy < 2; fy++) for (int x = 0; x < ancho; x++) Pegar(b, Trozo(muro, fy, 1 + x % 2, 1, 1), x * 32, fy * 32);
    var huella = Q(0xF0E0C0); var huellaS = Q(0xD8C498); var tabica = Q(0xB89868); var linea = Q(0x6C4C30); var zanca = Q(0xE8D0A0); var zancaS = Q(0xC0A070);
    for (int y = 0; y < 64; y++) for (int x = 7; x < W - 7; x++) { int ly = (y + 2) % 8; Color c = ly < 3 ? huella : (ly < 4 ? huellaS : tabica); if (ly == 7) c = linea; Px(b, x, y, c); }
    for (int y = 0; y < 64; y++) { for (int x = 0; x < 7; x++) Px(b, x, y, x == 0 || x == 6 ? linea : (x < 3 ? zanca : zancaS)); for (int x = W - 7; x < W; x++) Px(b, x, y, x == W - 1 || x == W - 7 ? linea : (x > W - 4 ? zancaS : zanca)); }
    foreach (int px in new[] { 0, W - 7 }) { Rect(b, px, 0, 7, 5, Q(0xF8ECD0)); Rect(b, px, 5, 7, 1, linea); }
    return b;
  }
  // valla de obra (2x1): dos pies y dos tablas a franjas rojas y blancas
  static Bitmap VallaObra(){
    var b = Lienzo(2, 1); var rojo = Q(0xD03030); var blanco = Q(0xF0F0F0); var gris = Q(0x787880);
    foreach (int px in new[] { 4, 56 }) { Rect(b, px, 6, 4, 22, gris); Rect(b, px - 3, 26, 10, 3, Q(0x585C68)); }
    foreach (int py in new[] { 7, 17 }) for (int y = py; y < py + 7; y++) for (int x = 2; x < 62; x++) Px(b, x, y, ((x + y) / 6) % 2 == 0 ? rojo : blanco);
    Contorno(b); for (int y = 29; y < 32; y++) for (int x = 2; x < 64; x++) Px(b, x, y, SOMBRA);
    return b;
  }
  // alfombra roja 1x3 sin fondo (va en la capa 1 encima de la baldosa)
  static Bitmap AlfombraSola(){
    var b = Lienzo(1, 3); var R = Q(0xC02830); var Rs = Q(0x901828); var O = Q(0xE8B848);
    for (int y = 3; y < 96; y++) for (int x = 4; x < 28; x++) { Color c = R; if (x == 4 || x == 27) c = Rs; else if (x == 6 || x == 25) c = O; Px(b, x, y, c); }
    for (int x = 5; x < 27; x += 2) Px(b, x, 2, O); for (int x = 4; x < 28; x++) Px(b, x, 95, Rs);
    return b;
  }
  // paso de cebra sin fondo: fila de arriba y de abajo
  static Bitmap CebraSola(){
    var b = Lienzo(2, 1); var r = new Random(70);
    for (int k = 0; k < 2; k++) { int ya = k == 0 ? 5 : 0, yb = k == 0 ? 32 : 27;
      for (int y = ya; y < yb; y++) for (int x = 6; x < 26; x++) { Color c = Q(0xF0F0F0); if (x == 25 || (k == 1 && y == yb - 1)) c = Q(0xC8C8C8); if (r.Next(100) < 5) c = Q(0xD8D8D8); Px(b, k * 32 + x, y, c); } }
    return b;
  }

  static void PiezasV4(){
    Nueva("suelos_v4", Cargar(SUELOS), "suelo", false);
    var muroC = MuroContencion(); Nueva("muro_c", muroC, "bloque", true);
    Nueva("escalera5", EscaleraPiedra(5, muroC), "escalera", true);
    Nueva("escalera3", EscaleraPiedra(3, muroC), "escalera", true);
    Nueva("azotea_a", Azotea(0), "bloque", true);
    Nueva("azotea_b", Azotea(1), "bloque", true);
    Nueva("azotea_c", Azotea(2), "bloque", true);
    Nueva("det_azotea", DetallesAzotea(), "bloque", true);
    Nueva("guirnalda", Guirnalda(), "alto:1", true);
    Nueva("cordon", Cordon(), "bloque", true);
    Nueva("marquesina", Marquesina(), "bloque", true);
    Nueva("alfombra", AlfombraSola(), "suelo", true);
    Nueva("cebra", CebraSola(), "suelo", true);
    Nueva("vallas", VallaObra(), "bloque", true);
    foreach (var d in new[] { "fuente_modernista", "farola_fernandina", "banco_forja", "palmera", "bolardo", "papelera", "buzon_correos", "fuente_beber",
                               "macetero_flores", "jardinera_buganvilla", "arbusto_recortado", "mesa_terraza", "quiosco_prensa", "guirnalda_banderines",
                               "matojos", "hojas_sueltas", "puesto_flores" })
      RealDe(DECO, d, d, 1);
    // v6: borde de arboleda, tapias y fachadas traseras, y el semaforo
    foreach (var d in new[] { "pino_pinonero", "platano_sombra", "cipres", "seto_alto", "fachada_trasera", "tapia_enredadera", "semaforo" }) {
      if (!Directory.Exists(Path.Combine(DECO, d))) continue;
      var p = RealDe(DECO, d, d, 1);
      if (d == "pino_pinonero" || d == "platano_sombra" || d == "cipres") {
        // la misma pieza para el perimetro: toda ella corta el paso (la copa tambien), como en Bambalina
        var q = new Pz { Nombre = d + "_b", Img = p.Img, Regla = "taller", W = p.W, H = p.H, Paso = new int[p.W, p.H], Prio = new int[p.W, p.H] };
        for (int y = 0; y < p.H; y++) for (int x = 0; x < p.W; x++) { q.Paso[x, y] = 15; q.Prio[x, y] = 0; }   // tambien las casillas vacias: sin huecos entre tronco y borde
        LISTA.Add(q);
      }
    }
  }
}
