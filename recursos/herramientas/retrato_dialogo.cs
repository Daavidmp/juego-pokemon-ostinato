using System; using System.Drawing; using System.Drawing.Imaging; using System.Drawing.Drawing2D; using System.Drawing.Text;
// Retratos de dialogo (de la cabeza a la cadera, 615 de alto) a partir de capas exportadas del .kra,
// y placas de nombre con la misma letra y color que DlgNomSecuaz.
public static class Retrato {
  public static Rectangle Logo = Rectangle.Empty; public static string Hecho = "";
  public static void PonLogo(int x, int y, int w, int h){ Logo = new Rectangle(x, y, w, h); }
  public static string Hacer(string abajo, string arriba, int x, int y, int w, int h, bool espejo, string sal, int alto){
    var a = new Bitmap(abajo); var b = new Bitmap(arriba);
    var lienzo = new Bitmap(a.Width, a.Height, PixelFormat.Format32bppPArgb);
    using (var g = Graphics.FromImage(lienzo)){ g.DrawImage(a, 0, 0, a.Width, a.Height); g.DrawImage(b, 0, 0, b.Width, b.Height); }
    int nw = (int)Math.Round(w * (double)alto / h);
    var o = new Bitmap(nw, alto, PixelFormat.Format32bppPArgb);
    using (var g = Graphics.FromImage(o)){
      g.InterpolationMode = InterpolationMode.HighQualityBicubic; g.PixelOffsetMode = PixelOffsetMode.HighQuality; g.CompositingQuality = CompositingQuality.HighQuality;
      var ia = new ImageAttributes(); ia.SetWrapMode(WrapMode.TileFlipXY);
      var dst = espejo ? new Point[]{ new Point(nw, 0), new Point(0, 0), new Point(nw, alto) } : new Point[]{ new Point(0, 0), new Point(nw, 0), new Point(0, alto) };
      g.DrawImage(lienzo, dst, new Rectangle(x, y, w, h), GraphicsUnit.Pixel, ia);
      // al voltear, las letras de la ropa salen al reves: se vuelven a pegar sin voltear
      if (espejo && Logo != Rectangle.Empty){
        var L = Logo; double k = (double)alto / h;
        // solo lo claro (las letras) dentro de la ventana: su caja con margen
        int x0=L.Right, y0=L.Bottom, x1=L.X, y1=L.Y;
        for (int yy=L.Y; yy<L.Bottom; yy++) for (int xx=L.X; xx<L.Right; xx++){ var c=lienzo.GetPixel(xx,yy); if (c.A>200 && c.R+c.G+c.B>330){ if(xx<x0)x0=xx; if(xx>x1)x1=xx; if(yy<y0)y0=yy; if(yy>y1)y1=yy; } }
        var R = new Rectangle(x0-6, y0-6, x1-x0+13, y1-y0+13);
        float dx = (float)(nw - (R.Right - x) * k), dy = (float)((R.Y - y) * k);
        // el hueco: color de la sudadera alrededor (para tapar las letras volteadas)
        g.DrawImage(lienzo, new RectangleF(dx, dy, (float)(R.Width*k), (float)(R.Height*k)), R, GraphicsUnit.Pixel);
        Hecho = "logo " + R;
      }
    }
    var fin = new Bitmap(o); fin.Save(sal, ImageFormat.Png);
    return sal + " " + nw + "x" + alto;
  }

  // caja de tinta y color medio de la placa de muestra
  static Rectangle Tinta(Bitmap m, out Color col){
    int x0=m.Width,y0=m.Height,x1=0,y1=0; long r=0,g=0,bb=0,n=0;
    for (int y=0;y<m.Height;y++) for (int x=0;x<m.Width;x++){ var c=m.GetPixel(x,y); if (c.A>200){ if(x<x0)x0=x; if(x>x1)x1=x; if(y<y0)y0=y; if(y>y1)y1=y; r+=c.R; g+=c.G; bb+=c.B; n++; } }
    col = Color.FromArgb((int)(r/n),(int)(g/n),(int)(bb/n)); return new Rectangle(x0,y0,x1-x0+1,y1-y0+1);
  }
  public static string Placa(string muestra, string texto, string sal){
    var m = new Bitmap(muestra); Color col; var t = Tinta(m, out col);
    // tamano de letra con la misma altura de mayuscula
    float tam = 10; Rectangle caja = Rectangle.Empty; Bitmap mejor = null;
    for (float s = 14; s < 60; s += 0.5f){
      var bm = Pintar(texto, s, col, m.Height, t.Y); var c = Caja(bm);
      if (c.Height >= t.Height){ mejor = bm; caja = c; tam = s; break; }
    }
    // recortar al ancho de la tinta con el mismo margen que la muestra
    int mi = t.X, md = m.Width - (t.X + t.Width);
    var o = new Bitmap(caja.Width + mi + md, m.Height, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(o)) g.DrawImage(mejor, new Rectangle(mi, 0, caja.Width, m.Height), new Rectangle(caja.X, 0, caja.Width, m.Height), GraphicsUnit.Pixel);
    o.Save(sal, ImageFormat.Png);
    return sal + " letra " + tam + " -> " + o.Width + "x" + o.Height + " color " + col;
  }
  static Bitmap Pintar(string texto, float tam, Color col, int alto, int arriba){
    var bm = new Bitmap(800, alto, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(bm)){
      g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
      var f = new Font("Cambria", tam, FontStyle.Bold, GraphicsUnit.Pixel);
      // primero se mide donde cae la tinta para dejar la parte de arriba a la misma altura
      g.DrawString(texto, f, new SolidBrush(col), 10, 0, StringFormat.GenericTypographic);
      var c = Caja(bm); g.Clear(Color.Transparent);
      g.DrawString(texto, f, new SolidBrush(col), 10, arriba - c.Y, StringFormat.GenericTypographic);
    }
    return bm;
  }
  static Rectangle Caja(Bitmap m){
    int x0=m.Width,y0=m.Height,x1=-1,y1=-1;
    for (int y=0;y<m.Height;y++) for (int x=0;x<m.Width;x++) if (m.GetPixel(x,y).A>200){ if(x<x0)x0=x; if(x>x1)x1=x; if(y<y0)y0=y; if(y>y1)y1=y; }
    return x1<0 ? Rectangle.Empty : new Rectangle(x0,y0,x1-x0+1,y1-y0+1);
  }
}
