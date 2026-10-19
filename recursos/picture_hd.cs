using System; using System.Drawing; using System.Drawing.Imaging; using System.Drawing.Drawing2D; using System.Collections.Generic;
// Picture en alta: quita el fondo blanco conectado al borde y reduce con calidad (sin paleta ni rejilla)
public static class Hd {
  public static string Hacer(string ent, string sal, int alto, int lienzoW, int lienzoH, int margen){
    var src = new Bitmap(ent); int W = src.Width, H = src.Height;
    var bd = src.LockBits(new Rectangle(0,0,W,H), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    var buf = new int[W*H]; System.Runtime.InteropServices.Marshal.Copy(bd.Scan0, buf, 0, W*H); src.UnlockBits(bd);
    Func<int,bool> esFondo = p => { var c = Color.FromArgb(buf[p]); return c.A < 128 || (c.R > 236 && c.G > 236 && c.B > 236); };
    var fondo = new bool[W*H]; var q = new Queue<int>();
    for (int x=0;x<W;x++) foreach (int y in new[]{0,H-1}) { int p=y*W+x; if (esFondo(p) && !fondo[p]) { fondo[p]=true; q.Enqueue(p);} }
    for (int y=0;y<H;y++) foreach (int x in new[]{0,W-1}) { int p=y*W+x; if (esFondo(p) && !fondo[p]) { fondo[p]=true; q.Enqueue(p);} }
    while (q.Count>0){ int p=q.Dequeue(); int x=p%W, y=p/W;
      foreach (var d in new[]{new[]{1,0},new[]{-1,0},new[]{0,1},new[]{0,-1}}){ int nx=x+d[0], ny=y+d[1];
        if (nx<0||ny<0||nx>=W||ny>=H) continue; int n=ny*W+nx; if (!fondo[n] && esFondo(n)){ fondo[n]=true; q.Enqueue(n);} } }
    // el halo claro que deja el fondo alrededor del contorno: tambien fuera
    for (int pas=0; pas<2; pas++){ var f2=(bool[])fondo.Clone();
      for (int y=1;y<H-1;y++) for (int x=1;x<W-1;x++){ int p=y*W+x; if (fondo[p]) continue; var c=Color.FromArgb(buf[p]);
        if (c.R+c.G+c.B < 600) continue; if (fondo[p-1]||fondo[p+1]||fondo[p-W]||fondo[p+W]) f2[p]=true; }
      fondo=f2; }
    int x0=W,y0=H,x1=0,y1=0;
    for (int y=0;y<H;y++) for (int x=0;x<W;x++) if(!fondo[y*W+x]){ if(x<x0)x0=x; if(x>x1)x1=x; if(y<y0)y0=y; if(y>y1)y1=y; }
    for (int p=0;p<W*H;p++) if (fondo[p]) buf[p]=0;
    var lim = new Bitmap(W, H, PixelFormat.Format32bppArgb);
    var bl = lim.LockBits(new Rectangle(0,0,W,H), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
    System.Runtime.InteropServices.Marshal.Copy(buf, 0, bl.Scan0, W*H); lim.UnlockBits(bl);
    int fw=x1-x0+1, fh=y1-y0+1; int nh=alto, nw=(int)Math.Round(fw*(double)alto/fh);
    var o = new Bitmap(lienzoW, lienzoH, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(o)){
      g.Clear(Color.Transparent); g.InterpolationMode=InterpolationMode.HighQualityBicubic; g.PixelOffsetMode=PixelOffsetMode.HighQuality;
      g.CompositingMode=CompositingMode.SourceOver; g.SmoothingMode=SmoothingMode.HighQuality;
      var ia = new ImageAttributes(); ia.SetWrapMode(WrapMode.TileFlipXY);
      g.DrawImage(lim, new Rectangle((lienzoW-nw)/2, lienzoH-margen-nh, nw, nh), x0, y0, fw, fh, GraphicsUnit.Pixel, ia);
    }
    o.Save(sal, ImageFormat.Png);
    return "figura " + fw + "x" + fh + " -> " + nw + "x" + nh + " en " + lienzoW + "x" + lienzoH;
  }
}
