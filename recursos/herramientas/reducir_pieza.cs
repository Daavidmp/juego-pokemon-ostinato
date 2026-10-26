using System; using System.Collections.Generic; using System.Drawing; using System.Drawing.Imaging; using System.Drawing.Drawing2D;
// Pieza de Firefly a pixel art por media de area (para las que vienen muy detalladas y pierden detalle con pixel_real):
//   [Reducir]::Hacer(entrada, salida, ancho, alto, colores)   ancho y alto ya en px del juego (casillas de 32)
public static class Reducir {
  static int D(int a, int b){ int r=((a>>16)&255)-((b>>16)&255), g=((a>>8)&255)-((b>>8)&255), bb=(a&255)-(b&255); return r*r+g*g+bb*bb; }
  // reduce a w x h con media de area y deja 'n' colores (k-medias); el verde del fondo, transparente
  public static string Hacer(string ent, string sal, int w, int h, int n){
    var src = new Bitmap(ent); var o = new Bitmap(w, h, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(o)) { g.InterpolationMode = InterpolationMode.HighQualityBilinear; g.PixelOffsetMode = PixelOffsetMode.HighQuality; g.DrawImage(src, 0, 0, w, h); }
    var p = new int[w*h]; for (int y=0;y<h;y++) for (int x=0;x<w;x++) p[y*w+x]=o.GetPixel(x,y).ToArgb() & 0xFFFFFF;
    var pal = new List<int>(); var rnd = new Random(3);
    for (int i=0;i<n;i++) pal.Add(p[rnd.Next(p.Length)]);
    var asig = new int[p.Length];
    for (int it=0; it<12; it++) {
      var sr=new long[n]; var sg=new long[n]; var sb=new long[n]; var sn=new int[n];
      for (int i=0;i<p.Length;i++){ int b=0,bd=int.MaxValue; for(int j=0;j<n;j++){int d=D(p[i],pal[j]); if(d<bd){bd=d;b=j;}} asig[i]=b; sr[b]+=(p[i]>>16)&255; sg[b]+=(p[i]>>8)&255; sb[b]+=p[i]&255; sn[b]++; }
      for (int j=0;j<n;j++) if (sn[j]>0) pal[j]=(int)(sr[j]/sn[j])<<16|(int)(sg[j]/sn[j])<<8|(int)(sb[j]/sn[j]); else pal[j]=p[rnd.Next(p.Length)];
    }
    var r = new Bitmap(w, h, PixelFormat.Format32bppArgb);
    for (int y=0;y<h;y++) for (int x=0;x<w;x++){ int c=pal[asig[y*w+x]]; int R=(c>>16)&255,G=(c>>8)&255,B=c&255; if (G>R+30 && G>B+20) continue; r.SetPixel(x,y,Color.FromArgb(255,R,G,B)); }
    r.Save(sal, ImageFormat.Png); return "ok " + w + "x" + h;
  }
}
