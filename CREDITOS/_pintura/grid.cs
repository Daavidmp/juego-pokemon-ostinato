using System;
using System.Collections.Generic;

namespace KraLib
{
    public static class Glyph
    {
        // 4x6 digit font, rows top->bottom, bit 3 = leftmost
        static readonly byte[][] D = new byte[][] {
            new byte[]{0x6,0x9,0x9,0x9,0x9,0x6}, // 0
            new byte[]{0x2,0x6,0x2,0x2,0x2,0x7}, // 1
            new byte[]{0x6,0x9,0x1,0x2,0x4,0xF}, // 2
            new byte[]{0xE,0x1,0x6,0x1,0x1,0xE}, // 3
            new byte[]{0x2,0x6,0xA,0xF,0x2,0x2}, // 4
            new byte[]{0xF,0x8,0xE,0x1,0x9,0x6}, // 5
            new byte[]{0x6,0x8,0xE,0x9,0x9,0x6}, // 6
            new byte[]{0xF,0x1,0x2,0x2,0x4,0x4}, // 7
            new byte[]{0x6,0x9,0x6,0x9,0x9,0x6}, // 8
            new byte[]{0x6,0x9,0x9,0x7,0x1,0x6}, // 9
        };

        public static void DrawNum(Img im, int num, int cx, int cy, int col, int halo)
        {
            string s = num.ToString();
            int w = s.Length * 5 - 1;
            int x0 = cx - w / 2, y0 = cy - 3;
            // halo
            if (halo != 0)
                for (int dy = -1; dy <= 1; dy++)
                    for (int dx = -1; dx <= 1; dx++)
                        Blit(im, s, x0 + dx, y0 + dy, halo);
            Blit(im, s, x0, y0, col);
        }

        static void Blit(Img im, string s, int x0, int y0, int col)
        {
            for (int k = 0; k < s.Length; k++)
            {
                byte[] g = D[s[k] - '0'];
                for (int r = 0; r < 6; r++)
                    for (int c = 0; c < 4; c++)
                        if ((g[r] & (8 >> c)) != 0)
                        {
                            int x = x0 + k * 5 + c, y = y0 + r;
                            if (im.In(x, y)) im[x, y] = col;
                        }
            }
        }
    }

    public static class GridTool
    {
        /// lineart over white with a coordinate grid every `step` px
        public static void DrawGrid(byte[] ink, int W, int H, int step, string path)
        {
            Img im = new Img(W, H);
            for (int i = 0; i < W * H; i++)
            {
                int v = 255 - ink[i];
                im.P[i] = unchecked((int)0xFF000000) | (v << 16) | (v << 8) | v;
            }
            int grey = unchecked((int)0xFFC8C8DC);
            int strong = unchecked((int)0xFF3060D0);
            for (int x = 0; x < W; x += step)
            {
                int c = (x % (step * 2) == 0) ? strong : grey;
                for (int y = 0; y < H; y++) im[x, y] = c;
            }
            for (int y = 0; y < H; y += step)
            {
                int c = (y % (step * 2) == 0) ? strong : grey;
                for (int x = 0; x < W; x++) im[x, y] = c;
            }
            int red = unchecked((int)0xFFD00000);
            for (int x = 0; x < W; x += step * 2)
                for (int y = 0; y < H; y += step * 2)
                {
                    Glyph.DrawNum(im, x, x + 14, y + 8, red, unchecked((int)0xFFFFFFFF));
                    Glyph.DrawNum(im, y, x + 14, y + 20, unchecked((int)0xFF008000), unchecked((int)0xFFFFFFFF));
                }
            im.Save(path);
        }
    }
}
