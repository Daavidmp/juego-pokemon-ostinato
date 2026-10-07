using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Text;

namespace KraLib
{
    // ---- LZF (KoLZF variant used by Krita) ----
    public static class Lzf
    {
        public static int Decompress(byte[] inp, int inOff, int inLen, byte[] outp, int outLen)
        {
            int ip = inOff, ipEnd = inOff + inLen, op = 0;
            while (ip < ipEnd)
            {
                int ctrl = inp[ip++];
                if (ctrl < 32)
                {
                    int len = ctrl + 1;
                    if (op + len > outLen) throw new Exception("lzf overflow");
                    Buffer.BlockCopy(inp, ip, outp, op, len);
                    ip += len; op += len;
                }
                else
                {
                    int len = ctrl >> 5;
                    int refp = op - ((ctrl & 0x1f) << 8) - 1;
                    if (len == 7) len += inp[ip++];
                    refp -= inp[ip++];
                    if (refp < 0) throw new Exception("lzf bad ref");
                    if (op + len + 2 > outLen) throw new Exception("lzf overflow2");
                    outp[op++] = outp[refp++];
                    outp[op++] = outp[refp++];
                    for (int i = 0; i < len; i++) outp[op++] = outp[refp++];
                }
            }
            return op;
        }

        /// liblzf-compatible compressor (the format Krita itself writes).
        /// Returns the number of bytes written to outp, or 0 if it did not fit.
        public static int Compress(byte[] inp, int inLen, byte[] outp, int outLen)
        {
            const int HLOG = 16;
            const int HSIZE = 1 << HLOG;
            const int MAX_LIT = 1 << 5;
            const int MAX_OFF = 1 << 13;
            const int MAX_REF = (1 << 8) + (1 << 3);

            if (inLen == 0 || outLen == 0) return 0;
            int[] htab = new int[HSIZE];   // stores position+1; 0 means empty
            int ip = 0, op = 0, lit = 0;
            int inEnd = inLen;

            uint hval = (uint)((inp[0] << 8) | inp[1]);
            op++;                            // reserve the literal-run length byte

            while (ip < inEnd - 2)
            {
                hval = (hval << 8) | inp[ip + 2];
                int idx = (int)(((hval >> (3 * 8 - HLOG)) - hval * 5) & (HSIZE - 1));
                int refp = htab[idx] - 1;
                htab[idx] = ip + 1;
                int off = ip - refp - 1;

                if (refp >= 0 && refp < ip && off < MAX_OFF
                    && inp[refp] == inp[ip] && inp[refp + 1] == inp[ip + 1] && inp[refp + 2] == inp[ip + 2])
                {
                    int len = 2;
                    int maxlen = inEnd - ip - len;
                    if (maxlen > MAX_REF) maxlen = MAX_REF;

                    if (op + 3 + 1 >= outLen)
                        if (op - (lit != 0 ? 1 : 0) + 3 + 1 >= outLen) return 0;

                    outp[op - lit - 1] = (byte)(lit - 1);   // close the literal run
                    if (lit == 0) op--;

                    do { len++; } while (len < maxlen && inp[refp + len] == inp[ip + len]);
                    len -= 2;
                    ip++;

                    if (len < 7)
                        outp[op++] = (byte)((off >> 8) + (len << 5));
                    else
                    { outp[op++] = (byte)((off >> 8) + (7 << 5)); outp[op++] = (byte)(len - 7); }
                    outp[op++] = (byte)off;

                    lit = 0; op++;                          // start a new literal run
                    ip += len + 1;
                    if (ip >= inEnd - 2) break;

                    ip--;
                    hval = (uint)((inp[ip] << 8) | inp[ip + 1]);
                    hval = (hval << 8) | inp[ip + 2];
                    htab[(int)(((hval >> (3 * 8 - HLOG)) - hval * 5) & (HSIZE - 1))] = ip + 1;
                    ip++;
                }
                else
                {
                    if (op >= outLen) return 0;
                    lit++; outp[op++] = inp[ip++];
                    if (lit == MAX_LIT)
                    { outp[op - lit - 1] = (byte)(lit - 1); lit = 0; op++; }
                }
            }

            if (op + 3 > outLen) return 0;

            while (ip < inEnd)
            {
                lit++; outp[op++] = inp[ip++];
                if (lit == MAX_LIT)
                { outp[op - lit - 1] = (byte)(lit - 1); lit = 0; op++; }
            }

            outp[op - lit - 1] = (byte)(lit - 1);
            if (lit == 0) op--;
            return op;
        }
    }

    // A full-canvas RGBA image, stored as int[] 0xAARRGGBB
    public class Img
    {
        public int W, H;
        public int[] P;
        public Img(int w, int h) { W = w; H = h; P = new int[w * h]; }
        public int this[int x, int y]
        {
            get { return P[y * W + x]; }
            set { P[y * W + x] = value; }
        }
        public bool In(int x, int y) { return x >= 0 && y >= 0 && x < W && y < H; }

        public static int Rgba(int r, int g, int b, int a)
        {
            return (a << 24) | (r << 16) | (g << 8) | b;
        }
        public static int A(int c) { return (c >> 24) & 255; }
        public static int R(int c) { return (c >> 16) & 255; }
        public static int G(int c) { return (c >> 8) & 255; }
        public static int B(int c) { return c & 255; }

        public Img Clone()
        {
            Img n = new Img(W, H);
            Buffer.BlockCopy(P, 0, n.P, 0, P.Length * 4);
            return n;
        }

        public void Save(string path)
        {
            using (var bmp = new System.Drawing.Bitmap(W, H, System.Drawing.Imaging.PixelFormat.Format32bppArgb))
            {
                var bd = bmp.LockBits(new System.Drawing.Rectangle(0, 0, W, H),
                    System.Drawing.Imaging.ImageLockMode.WriteOnly,
                    System.Drawing.Imaging.PixelFormat.Format32bppArgb);
                // .NET Format32bppArgb in memory is BGRA little-endian == int 0xAARRGGBB
                System.Runtime.InteropServices.Marshal.Copy(P, 0, bd.Scan0, P.Length);
                bmp.UnlockBits(bd);
                bmp.Save(path, System.Drawing.Imaging.ImageFormat.Png);
            }
        }

        public static Img Load(string path)
        {
            using (var src = new System.Drawing.Bitmap(path))
            {
                Img im = new Img(src.Width, src.Height);
                using (var bmp = new System.Drawing.Bitmap(src.Width, src.Height, System.Drawing.Imaging.PixelFormat.Format32bppArgb))
                {
                    using (var g = System.Drawing.Graphics.FromImage(bmp))
                    {
                        g.CompositingMode = System.Drawing.Drawing2D.CompositingMode.SourceCopy;
                        g.DrawImage(src, 0, 0, src.Width, src.Height);
                    }
                    var bd = bmp.LockBits(new System.Drawing.Rectangle(0, 0, im.W, im.H),
                        System.Drawing.Imaging.ImageLockMode.ReadOnly,
                        System.Drawing.Imaging.PixelFormat.Format32bppArgb);
                    System.Runtime.InteropServices.Marshal.Copy(bd.Scan0, im.P, 0, im.P.Length);
                    bmp.UnlockBits(bd);
                }
                return im;
            }
        }
    }

    public static class Kra
    {
        public static byte[] ReadEntry(string zipPath, string entry)
        {
            using (var z = ZipFile.OpenRead(zipPath))
            {
                foreach (var e in z.Entries)
                    if (e.FullName == entry)
                    {
                        using (var s = e.Open())
                        using (var ms = new MemoryStream())
                        { s.CopyTo(ms); return ms.ToArray(); }
                    }
            }
            throw new Exception("entry not found: " + entry);
        }

        /// Rewrites a .kra swapping one entry, copying every other byte across untouched.
        /// Keeps animated layers and their keyframes intact, which a full rebuild would lose.
        public static void ReplaceEntry(string srcZip, string dstZip, string entry, byte[] data)
        {
            var order = new List<string>();
            var src = new Dictionary<string, byte[]>();
            foreach (string e in ListEntries(srcZip)) { order.Add(e); src[e] = ReadEntry(srcZip, e); }
            if (!src.ContainsKey(entry)) throw new Exception("no existe la entrada " + entry);
            src[entry] = data;
            if (File.Exists(dstZip)) File.Delete(dstZip);
            using (var fs = new FileStream(dstZip, FileMode.Create))
            using (var z = new ZipArchive(fs, ZipArchiveMode.Create))
            {
                var me = z.CreateEntry("mimetype", CompressionLevel.NoCompression);
                using (var s = me.Open()) { var b = src["mimetype"]; s.Write(b, 0, b.Length); }
                foreach (string name in order)
                {
                    if (name == "mimetype") continue;
                    var e = z.CreateEntry(name, CompressionLevel.Optimal);
                    using (var s = e.Open()) s.Write(src[name], 0, src[name].Length);
                }
            }
        }

        public static List<string> ListEntries(string zipPath)
        {
            var r = new List<string>();
            using (var z = ZipFile.OpenRead(zipPath))
                foreach (var e in z.Entries) r.Add(e.FullName);
            return r;
        }

        static string ReadLine(byte[] d, ref int pos)
        {
            var sb = new StringBuilder();
            while (pos < d.Length && d[pos] != (byte)'\n') { sb.Append((char)d[pos]); pos++; }
            pos++; // skip \n
            return sb.ToString();
        }

        /// Decode a Krita paint-layer tile blob into a canvas-sized Img.
        public static Img DecodeLayer(byte[] d, int canvasW, int canvasH, int offX, int offY)
        {
            int pos = 0;
            int tw = 64, th = 64, psize = 4, count = 0;
            while (true)
            {
                int save = pos;
                string line = ReadLine(d, ref pos);
                if (line.StartsWith("VERSION")) continue;
                if (line.StartsWith("TILEWIDTH")) { tw = int.Parse(line.Split(' ')[1]); continue; }
                if (line.StartsWith("TILEHEIGHT")) { th = int.Parse(line.Split(' ')[1]); continue; }
                if (line.StartsWith("PIXELSIZE")) { psize = int.Parse(line.Split(' ')[1]); continue; }
                if (line.StartsWith("DATA")) { count = int.Parse(line.Split(' ')[1]); break; }
                pos = save; break;
            }
            Img img = new Img(canvasW, canvasH);
            int tileBytes = tw * th * psize;
            byte[] raw = new byte[tileBytes];
            for (int t = 0; t < count; t++)
            {
                string hdr = ReadLine(d, ref pos);
                var parts = hdr.Split(',');
                int tx = int.Parse(parts[0]);
                int ty = int.Parse(parts[1]);
                int sz = int.Parse(parts[3]);
                byte flag = d[pos];
                if (flag == 0)
                    Buffer.BlockCopy(d, pos + 1, raw, 0, Math.Min(sz - 1, tileBytes));
                else
                    Lzf.Decompress(d, pos + 1, sz - 1, raw, tileBytes);
                pos += sz;

                // planar BGRA
                int plane = tw * th;
                for (int yy = 0; yy < th; yy++)
                {
                    int py = ty + yy + offY;
                    if (py < 0 || py >= canvasH) continue;
                    int rowBase = yy * tw;
                    for (int xx = 0; xx < tw; xx++)
                    {
                        int px = tx + xx + offX;
                        if (px < 0 || px >= canvasW) continue;
                        int i = rowBase + xx;
                        int b = raw[i];
                        int g = raw[plane + i];
                        int r = raw[2 * plane + i];
                        int a = raw[3 * plane + i];
                        img.P[py * canvasW + px] = (a << 24) | (r << 16) | (g << 8) | b;
                    }
                }
            }
            return img;
        }

        /// Encode an Img into Krita tile-blob bytes (uncompressed tiles, flag 0).
        /// Skips fully transparent tiles.
        public static byte[] EncodeLayer(Img img)
        {
            int tw = 64, th = 64, psize = 4;
            var tiles = new List<byte[]>();
            var hdrs = new List<string>();
            var markers = new List<byte>();
            int plane = tw * th;
            int ntx = (img.W + tw - 1) / tw;
            int nty = (img.H + th - 1) / th;
            for (int ty = 0; ty < nty; ty++)
            {
                for (int tx = 0; tx < ntx; tx++)
                {
                    byte[] raw = new byte[tw * th * psize];
                    bool any = false;
                    for (int yy = 0; yy < th; yy++)
                    {
                        int py = ty * th + yy;
                        if (py >= img.H) break;
                        for (int xx = 0; xx < tw; xx++)
                        {
                            int px = tx * tw + xx;
                            if (px >= img.W) break;
                            int c = img.P[py * img.W + px];
                            int a = (c >> 24) & 255;
                            if (a == 0) continue;
                            any = true;
                            int i = yy * tw + xx;
                            raw[i] = (byte)(c & 255);
                            raw[plane + i] = (byte)((c >> 8) & 255);
                            raw[2 * plane + i] = (byte)((c >> 16) & 255);
                            raw[3 * plane + i] = (byte)a;
                        }
                    }
                    if (!any) continue;
                    // compress exactly the way Krita does: 1 marker byte + LZF payload
                    byte[] buf = new byte[raw.Length * 2 + 64];
                    int cl = Lzf.Compress(raw, raw.Length, buf, buf.Length);
                    byte[] payload;
                    byte marker;
                    if (cl > 0 && cl < raw.Length)
                    {
                        payload = new byte[cl];
                        Buffer.BlockCopy(buf, 0, payload, 0, cl);
                        marker = 1;
                        // paranoia: it must decode back to the exact tile
                        byte[] back = new byte[raw.Length];
                        if (Lzf.Decompress(payload, 0, cl, back, raw.Length) != raw.Length)
                            throw new Exception("LZF round-trip length mismatch");
                        for (int q = 0; q < raw.Length; q++)
                            if (back[q] != raw[q]) throw new Exception("LZF round-trip mismatch at " + q);
                    }
                    else { payload = raw; marker = 0; }
                    markers.Add(marker);
                    hdrs.Add(string.Format("{0},{1},LZF,{2}\n", tx * tw, ty * th, payload.Length + 1));
                    tiles.Add(payload);
                }
            }
            using (var ms = new MemoryStream())
            {
                Action<string> W = delegate(string s) { var b = Encoding.ASCII.GetBytes(s); ms.Write(b, 0, b.Length); };
                W("VERSION 2\n");
                W("TILEWIDTH 64\n");
                W("TILEHEIGHT 64\n");
                W("PIXELSIZE 4\n");
                W("DATA " + tiles.Count + "\n");
                for (int i = 0; i < tiles.Count; i++)
                {
                    W(hdrs[i]);
                    ms.WriteByte(markers[i]);
                    ms.Write(tiles[i], 0, tiles[i].Length);
                }
                return ms.ToArray();
            }
        }
    }
}
