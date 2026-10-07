using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Text;

namespace KraLib
{
    public class ScriptEntry
    {
        public int Index;
        public long Id;
        public string Name;
        public byte[] CodeZ;     // the zlib blob exactly as stored
        public byte[] Raw;       // the whole element, byte for byte
        public bool Dirty;
        public string Code;      // inflated, only filled on demand
    }

    /// Reader/writer for RPG Maker XP's Scripts.rxdata: Ruby Marshal 4.8 holding an array of
    /// [id, name, zlib(code)]. Everything untouched is written back from its original bytes.
    public static class Rx
    {
        // ---------- Marshal integers ----------
        public static long ReadLong(byte[] b, ref int p)
        {
            sbyte c = (sbyte)b[p++];
            if (c == 0) return 0;
            if (c > 4) return c - 5;
            if (c < -4) return c + 5;
            if (c > 0)
            {
                long x = 0;
                for (int i = 0; i < c; i++) x |= (long)b[p++] << (8 * i);
                return x;
            }
            else
            {
                long x = -1;
                int n = -c;
                for (int i = 0; i < n; i++)
                {
                    x &= ~((long)0xFF << (8 * i));
                    x |= (long)b[p++] << (8 * i);
                }
                return x;
            }
        }

        public static void WriteLong(List<byte> o, long v)
        {
            if (v == 0) { o.Add(0); return; }
            if (v > 0 && v < 123) { o.Add((byte)(v + 5)); return; }
            if (v < 0 && v > -124) { o.Add((byte)(sbyte)(v - 5)); return; }
            var tmp = new List<byte>();
            long x = v;
            for (int i = 0; i < 4; i++)
            {
                tmp.Add((byte)(x & 0xFF));
                x >>= 8;
                if (v > 0 && x == 0) break;
                if (v < 0 && x == -1) break;
            }
            o.Add((byte)(v > 0 ? tmp.Count : -tmp.Count));
            o.AddRange(tmp);
        }

        // ---------- Marshal strings ----------
        /// Reads a string object. Handles the plain '"' form and the 'I"' form that carries
        /// encoding instance variables, which has to be stepped over pair by pair.
        static byte[] ReadString(byte[] b, ref int p)
        {
            byte t = b[p++];
            bool ivar = false;
            if (t == (byte)'I') { ivar = true; t = b[p++]; }
            if (t != (byte)'"') throw new Exception("no es una cadena en " + (p - 1) + " (0x" + t.ToString("X2") + ")");
            int len = (int)ReadLong(b, ref p);
            byte[] s = new byte[len];
            Buffer.BlockCopy(b, p, s, 0, len);
            p += len;
            if (ivar)
            {
                long n = ReadLong(b, ref p);
                for (long i = 0; i < n; i++) { SkipObject(b, ref p); SkipObject(b, ref p); }
            }
            return s;
        }

        static void SkipObject(byte[] b, ref int p)
        {
            byte t = b[p++];
            switch ((char)t)
            {
                case 'T': case 'F': case '0': return;
                case 'i': ReadLong(b, ref p); return;
                case ':': { int n = (int)ReadLong(b, ref p); p += n; return; }
                case ';': ReadLong(b, ref p); return;
                case '@': ReadLong(b, ref p); return;
                case '"': { int n = (int)ReadLong(b, ref p); p += n; return; }
                case 'I': SkipObject(b, ref p);
                    { long n = ReadLong(b, ref p); for (long i = 0; i < n; i++) { SkipObject(b, ref p); SkipObject(b, ref p); } }
                    return;
                case '[': { long n = ReadLong(b, ref p); for (long i = 0; i < n; i++) SkipObject(b, ref p); return; }
                default: throw new Exception("tipo Marshal inesperado '" + (char)t + "' en " + (p - 1));
            }
        }

        // ---------- zlib ----------
        public static byte[] Inflate(byte[] z)
        {
            using (var ms = new MemoryStream(z, 2, z.Length - 6))   // skip 2-byte header, 4-byte adler
            using (var ds = new DeflateStream(ms, CompressionMode.Decompress))
            using (var o = new MemoryStream())
            { ds.CopyTo(o); return o.ToArray(); }
        }

        public static byte[] Deflate(byte[] raw)
        {
            byte[] body;
            using (var o = new MemoryStream())
            {
                using (var ds = new DeflateStream(o, CompressionMode.Compress, true))
                    ds.Write(raw, 0, raw.Length);
                body = o.ToArray();
            }
            var outp = new List<byte>();
            outp.Add(0x78); outp.Add(0x9C);
            outp.AddRange(body);
            uint a = 1, s2 = 0;
            foreach (byte c in raw) { a = (a + c) % 65521; s2 = (s2 + a) % 65521; }
            uint adler = (s2 << 16) | a;
            outp.Add((byte)(adler >> 24)); outp.Add((byte)(adler >> 16));
            outp.Add((byte)(adler >> 8)); outp.Add((byte)adler);
            return outp.ToArray();
        }

        // ---------- file ----------
        public static List<ScriptEntry> Read(string path)
        {
            byte[] b = File.ReadAllBytes(path);
            int p = 0;
            if (b[p++] != 4 || b[p++] != 8) throw new Exception("no es Marshal 4.8");
            if (b[p++] != (byte)'[') throw new Exception("se esperaba un array");
            long count = ReadLong(b, ref p);
            var list = new List<ScriptEntry>();
            for (int i = 0; i < count; i++)
            {
                int start = p;
                if (b[p++] != (byte)'[') throw new Exception("elemento " + i + " no es array");
                long n = ReadLong(b, ref p);
                if (n != 3) throw new Exception("elemento " + i + " tiene " + n + " campos");
                if (b[p++] != (byte)'i') throw new Exception("id no es entero en " + i);
                long id = ReadLong(b, ref p);
                byte[] name = ReadString(b, ref p);
                byte[] code = ReadString(b, ref p);
                var e = new ScriptEntry { Index = i, Id = id, Name = Encoding.UTF8.GetString(name), CodeZ = code };
                e.Raw = new byte[p - start];
                Buffer.BlockCopy(b, start, e.Raw, 0, p - start);
                list.Add(e);
            }
            if (p != b.Length) throw new Exception("sobran " + (b.Length - p) + " bytes");
            return list;
        }

        public static void Write(string path, List<ScriptEntry> list)
        {
            var o = new List<byte>();
            o.Add(4); o.Add(8); o.Add((byte)'[');
            WriteLong(o, list.Count);
            foreach (var e in list)
            {
                if (!e.Dirty) { o.AddRange(e.Raw); continue; }
                o.Add((byte)'['); WriteLong(o, 3);
                o.Add((byte)'i'); WriteLong(o, e.Id);
                byte[] nm = Encoding.UTF8.GetBytes(e.Name);
                o.Add((byte)'"'); WriteLong(o, nm.Length); o.AddRange(nm);
                byte[] cz = Deflate(Encoding.UTF8.GetBytes(e.Code));
                o.Add((byte)'"'); WriteLong(o, cz.Length); o.AddRange(cz);
            }
            File.WriteAllBytes(path, o.ToArray());
        }

        public static string GetCode(ScriptEntry e)
        {
            if (e.Code == null) e.Code = Encoding.UTF8.GetString(Inflate(e.CodeZ));
            return e.Code;
        }

        public static string Verify(string path)
        {
            byte[] orig = File.ReadAllBytes(path);
            var list = Read(path);
            string tmp = path + ".roundtrip";
            Write(tmp, list);
            byte[] back = File.ReadAllBytes(tmp);
            File.Delete(tmp);
            if (orig.Length != back.Length) return "DISTINTO: " + orig.Length + " vs " + back.Length;
            for (int i = 0; i < orig.Length; i++) if (orig[i] != back[i]) return "DISTINTO en el byte " + i;
            return "ida y vuelta IDENTICA (" + list.Count + " scripts, " + orig.Length + " bytes)";
        }
    }
}
