using System;
using System.Text;

namespace KraLib
{
    public static class Flags
    {
        /// Count the per-tile compression marker bytes Krita itself wrote.
        public static string Scan(string kra, string[] layers)
        {
            var sb = new StringBuilder();
            foreach (string ln in layers)
            {
                byte[] d = Kra.ReadEntry(kra, "unnamed/layers/" + ln);
                int pos = 0, count = 0;
                while (true)
                {
                    int st = pos;
                    var line = new StringBuilder();
                    while (pos < d.Length && d[pos] != (byte)'\n') { line.Append((char)d[pos]); pos++; }
                    pos++;
                    string s = line.ToString();
                    if (s.StartsWith("DATA")) { count = int.Parse(s.Split(' ')[1]); break; }
                    if (!s.StartsWith("VERSION") && !s.StartsWith("TILE") && !s.StartsWith("PIXELSIZE")) { pos = st; break; }
                }
                int raw = 0, comp = 0, other = 0;
                for (int t = 0; t < count; t++)
                {
                    var line = new StringBuilder();
                    while (pos < d.Length && d[pos] != (byte)'\n') { line.Append((char)d[pos]); pos++; }
                    pos++;
                    var parts = line.ToString().Split(',');
                    int sz = int.Parse(parts[3]);
                    byte flag = d[pos];
                    if (flag == 0) raw++; else if (flag == 1) comp++; else other++;
                    pos += sz;
                }
                sb.AppendLine(string.Format("{0}: tiles={1} marcador0(crudo)={2} marcador1(LZF)={3} otros={4}",
                    ln, count, raw, comp, other));
            }
            return sb.ToString();
        }
    }
}
