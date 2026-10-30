// Lanzador de Citra 1920 para Pokelocke (se compila como azahar.exe, junto a citra-qt.exe):
//   csc /target:winexe /out:azahar.exe lanzador.cs
// - Pokelocke abre "azahar.exe -f <rom>", pero este Citra toma "-f" por la ROM: aqui se quita.
// - El juego se pinta en la ventana aparte de Citra (singleWindowMode=false) y esa ventana se pone sin bordes
//   ocupando la pantalla, POR DEBAJO del layout de Pokelocke. La pantalla completa de Citra no vale: se pone
//   encima de todo y tapa el layout.
// - Alt+Q cambia entre eso y una ventana normal (y esconde el layout mientras esta en ventana). No se pulsa
//   ninguna tecla: se cambia el estilo de la ventana, asi no le llega nada a otra ventana por error.
// - El lanzador vive lo mismo que Citra, para que Pokelocke sepa cuando se cierra el juego.
using System; using System.Collections.Generic; using System.Diagnostics; using System.IO; using System.Linq;
using System.Runtime.InteropServices; using System.Text; using System.Text.RegularExpressions; using System.Threading;

[assembly: System.Reflection.AssemblyTitle("Lanzador de Citra para Pokelocke")]
[assembly: System.Reflection.AssemblyDescription("Abre Citra con el juego colocado bajo el layout de Pokelocke")]
[assembly: System.Reflection.AssemblyCompany("David Martínez Palacios")]
[assembly: System.Reflection.AssemblyProduct("Pokelocke")]
[assembly: System.Reflection.AssemblyCopyright("© 2026 David Martínez Palacios")]
[assembly: System.Reflection.AssemblyVersion("1.0.0.0")]
[assembly: System.Reflection.AssemblyFileVersion("1.0.0.0")]

static class Lanzador {
  [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr h, int id, uint mod, uint vk);
  [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr h, int id);
  [DllImport("user32.dll")] static extern bool PeekMessage(out MSG m, IntPtr h, uint min, uint max, uint quitar);
  [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h, int idx);
  [DllImport("user32.dll")] static extern int SetWindowLong(IntPtr h, int idx, int v);
  [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr despues, int x, int y, int w, int alto, uint f);
  [DllImport("user32.dll")] static extern int GetSystemMetrics(int i);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr p);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern int GetWindowTextLength(IntPtr h);
  [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
  delegate bool EnumProc(IntPtr h, IntPtr p);
  [StructLayout(LayoutKind.Sequential)] struct MSG { public IntPtr hwnd; public uint message; public IntPtr wParam, lParam; public uint time; public int x, y; }
  const uint MOD_ALT = 0x1, MOD_NOREPEAT = 0x4000, WM_HOTKEY = 0x312;
  const int GWL_STYLE = -16, GWL_EXSTYLE = -20, WS_EX_TOOLWINDOW = 0x80, WS_EX_NOACTIVATE = 0x08000000;
  const int WS_CAPTION = 0x00C00000, WS_THICKFRAME = 0x00040000, WS_SYSMENU = 0x00080000, WS_MINIMIZEBOX = 0x00020000, WS_MAXIMIZEBOX = 0x00010000;
  const uint SWP_FRAMECHANGED = 0x20, SWP_NOACTIVATE = 0x10, SWP_SHOWWINDOW = 0x40;
  static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);

  static List<IntPtr> Ventanas(Func<uint, bool> delProceso, Func<IntPtr, bool> filtro) {
    var l = new List<IntPtr>();
    EnumWindows((h, p) => { uint pid; GetWindowThreadProcessId(h, out pid); if (delProceso(pid) && filtro(h)) l.Add(h); return true; }, IntPtr.Zero);
    return l;
  }

  // la capa del layout: ventana de herramienta, sin foco, de un proceso Pokelocke
  static void Capa(bool ver) {
    var pids = new HashSet<uint>(Process.GetProcessesByName("Pokelocke").Select(p => (uint)p.Id));
    foreach (var h in Ventanas(pids.Contains, h => { int ex = GetWindowLong(h, GWL_EXSTYLE); return (ex & WS_EX_TOOLWINDOW) != 0 && (ex & WS_EX_NOACTIVATE) != 0 && (ver || IsWindowVisible(h)); }))
      ShowWindow(h, ver ? 8 : 0);   // SW_SHOWNA / SW_HIDE
  }

  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] struct RECT { public int l, t, r, b; }

  // la ventana donde Citra pinta el juego: con la lista de juegos abierta hay dos ventanas suyas con titulo;
  // la del juego es la pequena (Citra la abre de unos 400x480)
  static IntPtr VentanaJuego(Process citra) {
    uint id = (uint)citra.Id;
    var vs = Ventanas(p => p == id, h => IsWindowVisible(h) && GetWindowTextLength(h) > 0);
    if (vs.Count < 2) return IntPtr.Zero;
    return vs.OrderBy(h => { RECT r; GetWindowRect(h, out r); return (long)(r.r - r.l) * (r.b - r.t); }).First();
  }

  static void SinBordes(IntPtr h) {
    int st = GetWindowLong(h, GWL_STYLE) & ~(WS_CAPTION | WS_THICKFRAME | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX);
    SetWindowLong(h, GWL_STYLE, st);
    // 1 px menos de alto: si tapa la pantalla entera, la grafica la pone en pantalla completa directa y deja de
    // pintar el layout encima (aunque las capturas si lo saquen)
    SetWindowPos(h, HWND_NOTOPMOST, 0, 0, GetSystemMetrics(0), GetSystemMetrics(1) - 1, SWP_FRAMECHANGED | SWP_NOACTIVATE | SWP_SHOWWINDOW);
  }

  static void EnVentana(IntPtr h) {
    SetWindowLong(h, GWL_STYLE, GetWindowLong(h, GWL_STYLE) | WS_CAPTION | WS_THICKFRAME | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX);
    int w = GetSystemMetrics(0), alto = GetSystemMetrics(1), vw = w * 2 / 3, va = alto * 2 / 3;
    SetWindowPos(h, HWND_NOTOPMOST, (w - vw) / 2, (alto - va) / 2, vw, va, SWP_FRAMECHANGED | SWP_SHOWWINDOW);
  }

  // ajustes de este Citra que Pokelocke no conoce o pone a su manera (los de Azahar); se arreglan antes de abrirlo.
  // La primera vez el ini es el que acaba de escribir Pokelocke y no tiene [UI]: lo que falte se añade, porque si
  // no Citra usa su ventana unica y el juego no sale colocado hasta la segunda vez
  static void Ajustes(string ini) {
    if (!File.Exists(ini)) return;
    string t = File.ReadAllText(ini);
    Func<string, string, string, string> poner = (txt, grupo, kv) => {
      string k = kv.Split('=')[0];
      var linea = new Regex("(?m)^" + Regex.Escape(k) + "=[^\r\n]*");
      if (linea.IsMatch(txt)) {
        txt = Regex.Replace(txt, "(?m)^" + Regex.Escape(k) + @"\\default=\w+", k + "\\default=false");
        return linea.Replace(txt, kv);
      }
      string nuevo = k + "\\default=false\r\n" + kv + "\r\n";
      var cabecera = new Regex("(?m)^\\[" + Regex.Escape(grupo) + "\\][^\r\n]*\r?\n");
      var m = cabecera.Match(txt);
      if (m.Success) return txt.Insert(m.Index + m.Length, nuevo);
      return txt.TrimEnd() + "\r\n\r\n[" + grupo + "]\r\n" + nuevo;
    };
    t = poner(t, "Layout", "layout_option=0");    // el 6 de Azahar no existe aqui y no pinta nada
    t = poner(t, "UI", "singleWindowMode=false"); // el juego en su propia ventana, sin menus
    t = poner(t, "UI", "fullscreen=false");
    // los huecos del layout: Pokelocke los escribe como Azahar (x, y, ancho, alto) y este Citra los lee como
    // bordes (izquierda, arriba, derecha, abajo) y solo si custom_layout esta activado
    Func<string, int?> leer = k => { var m = Regex.Match(t, "(?m)^" + Regex.Escape(k) + @"=(-?\d+)"); return m.Success ? int.Parse(m.Groups[1].Value) : (int?)null; };
    foreach (var n in new[] { "top", "bottom" }) {
      int? x = leer("custom_" + n + "_x"), y = leer("custom_" + n + "_y"), w = leer("custom_" + n + "_width"), h = leer("custom_" + n + "_height");
      if (x == null || y == null || w == null || h == null) continue;
      t = poner(t, "Layout", "custom_layout=true");
      t = poner(t, "Layout", "custom_" + n + "_left=" + x);
      t = poner(t, "Layout", "custom_" + n + "_top=" + y);
      t = poner(t, "Layout", "custom_" + n + "_right=" + (x + w));
      t = poner(t, "Layout", "custom_" + n + "_bottom=" + (y + h));
    }
    File.WriteAllText(ini, t, new UTF8Encoding(false));
  }

  static int Main(string[] args) {
    SetProcessDPIAware();
    string aqui = AppDomain.CurrentDomain.BaseDirectory;
    Ajustes(Path.Combine(aqui, "user", "config", "qt-config.ini"));
    var resto = args.Where(a => a != "-f").Select(a => "\"" + a + "\"");
    var citra = Process.Start(new ProcessStartInfo(Path.Combine(aqui, "citra-qt.exe"), string.Join(" ", resto)) { UseShellExecute = false, WorkingDirectory = aqui });
    bool atajo = RegisterHotKey(IntPtr.Zero, 1, MOD_ALT | MOD_NOREPEAT, (uint)'Q');
    bool ventana = false; IntPtr juego = IntPtr.Zero;
    while (!citra.WaitForExit(100)) {
      if (juego == IntPtr.Zero) {                       // espera a que salga la ventana del juego
        juego = VentanaJuego(citra);
        if (juego != IntPtr.Zero) { Thread.Sleep(300); SinBordes(juego); }
      }
      MSG m;
      while (PeekMessage(out m, IntPtr.Zero, 0, 0, 1)) {
        if (m.message != WM_HOTKEY || juego == IntPtr.Zero) continue;
        ventana = !ventana;
        if (ventana) { Capa(false); EnVentana(juego); } else { SinBordes(juego); Capa(true); }
      }
      if (ventana) Capa(false);                         // la capa se vuelve a poner delante sola cada segundo
    }
    if (atajo) UnregisterHotKey(IntPtr.Zero, 1);
    return citra.ExitCode;
  }
}
