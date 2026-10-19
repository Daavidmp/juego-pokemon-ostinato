using System; using System.Drawing; using System.Drawing.Imaging; using System.Drawing.Drawing2D;
// Piezas de luz de Firefly (dibujadas sobre negro) a PNG con transparencia: el negro se vuelve
// transparente y la luz conserva su color (alfa = el canal mas fuerte). Asi se pueden pintar
// sumando luz o normal. Usado para la megaevolucion (034_MegaEvolucion.rb).
//   [Luz]::Pieza(entrada, salida, lado_maximo)        recorta a lo que brilla y reduce
//   [Luz]::Cinta(entrada, salida, alto, ancho_final)   ademas endereza la cinta (su linea blanca)
public static class Luz {
  internal static int[] Leer(Bitmap b){ var d=b.LockBits(new Rectangle(0,0,b.Width,b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    var p=new int[b.Width*b.Height]; System.Runtime.InteropServices.Marshal.Copy(d.Scan0,p,0,p.Length); b.UnlockBits(d); return p; }
  internal static Bitmap Escribir(int[] p, int w, int h){ var b=new Bitmap(w,h,PixelFormat.Format32bppArgb); var d=b.LockBits(new Rectangle(0,0,w,h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
    System.Runtime.InteropServices.Marshal.Copy(p,0,d.Scan0,p.Length); b.UnlockBits(d); return b; }

  // negro -> transparente
  internal static Bitmap Alfa(Bitmap src){
    var p=Leer(src);
    for (int i=0;i<p.Length;i++){ int r=(p[i]>>16)&255, g=(p[i]>>8)&255, b=p[i]&255; int m=Math.Max(r,Math.Max(g,b));
      int a = m<=6 ? 0 : Math.Min(255, (int)((m-6)*255.0/249));
      if (a==0){ p[i]=0; continue; }
      int rr=Math.Min(255,r*255/m), gg=Math.Min(255,g*255/m), bb=Math.Min(255,b*255/m);
      p[i]=(a<<24)|(rr<<16)|(gg<<8)|bb; }
    return Escribir(p, src.Width, src.Height);
  }
  internal static Rectangle Caja(Bitmap b, int umbral){
    var p=Leer(b); int x0=b.Width,y0=b.Height,x1=-1,y1=-1;
    for (int y=0;y<b.Height;y++) for (int x=0;x<b.Width;x++){ int c=p[y*b.Width+x]; int m=Math.Max((c>>16)&255,Math.Max((c>>8)&255,c&255)); if (m>umbral){ if(x<x0)x0=x; if(x>x1)x1=x; if(y<y0)y0=y; if(y>y1)y1=y; } }
    return new Rectangle(x0,y0,x1-x0+1,y1-y0+1);
  }
  internal static Bitmap Reducir(Bitmap src, Rectangle r, int w, int h){
    var o=new Bitmap(w,h,PixelFormat.Format32bppArgb);
    using (var g=Graphics.FromImage(o)){ g.Clear(Color.Black); g.InterpolationMode=InterpolationMode.HighQualityBicubic; g.PixelOffsetMode=PixelOffsetMode.HighQuality;
      var ia=new ImageAttributes(); ia.SetWrapMode(WrapMode.TileFlipXY); g.DrawImage(src,new Rectangle(0,0,w,h),r.X,r.Y,r.Width,r.Height,GraphicsUnit.Pixel,ia); }
    return o;
  }

  public static string Pieza(string ent, string sal, int lado){
    var src=new Bitmap(ent); var r=Caja(src, 14); r.Inflate(8,8); r.Intersect(new Rectangle(0,0,src.Width,src.Height));
    double k=Math.Min(1.0, (double)lado/Math.Max(r.Width,r.Height)); int w=(int)Math.Round(r.Width*k), h=(int)Math.Round(r.Height*k);
    var o=Alfa(Reducir(src,r,w,h)); o.Save(sal, ImageFormat.Png); return sal+" "+w+"x"+h;
  }

  // la cinta de Firefly sale algo inclinada y curva: se busca su linea blanca en cada columna,
  // se ajusta una parabola y cada columna se sube o baja para dejarla recta en el centro
  public static string Cinta(string ent, string sal, int alto, int anchoFinal){
    var src=new Bitmap(ent); int W=src.Width, H=src.Height; var p=Leer(src);
    var cx=new double[W]; var cy=new double[W]; int n=0;
    for (int x=0;x<W;x+=4){ int best=-1, by=0;
      for (int y=0;y<H;y++){ int c=p[y*W+x]; int s=((c>>16)&255)+((c>>8)&255)+(c&255); int mn=Math.Min((c>>16)&255,Math.Min((c>>8)&255,c&255)); int v = mn>200 ? s : 0; if (v>best){best=v;by=y;} }
      if (best>600){ cx[n]=x; cy[n]=by; n++; } }
    // minimos cuadrados: y = a + b x + c x^2
    double s0=0,s1=0,s2=0,s3=0,s4=0,t0=0,t1=0,t2=0;
    for (int i=0;i<n;i++){ double x=cx[i]/W, y=cy[i]; s0++; s1+=x; s2+=x*x; s3+=x*x*x; s4+=x*x*x*x; t0+=y; t1+=x*y; t2+=x*x*y; }
    double[,] M={{s0,s1,s2,t0},{s1,s2,s3,t1},{s2,s3,s4,t2}};
    for (int c=0;c<3;c++){ for (int r=c+1;r<3;r++){ double f=M[r,c]/M[c,c]; for (int k=c;k<4;k++) M[r,k]-=f*M[c,k]; } }
    double C=M[2,3]/M[2,2], B=(M[1,3]-M[1,2]*C)/M[1,1], A=(M[0,3]-M[0,1]*B-M[0,2]*C)/M[0,0];
    var o=new int[W*alto];
    for (int x=0;x<W;x++){ double u=(double)x/W; double yc=A+B*u+C*u*u;
      for (int j=0;j<alto;j++){ double y=yc - alto/2.0 + j; int y0=(int)Math.Floor(y); double f=y-y0;
        if (y0<0||y0+1>=H){ o[j*W+x]=unchecked((int)0xFF000000); continue; }
        int a=p[y0*W+x], b=p[(y0+1)*W+x]; int R=(int)(((a>>16)&255)*(1-f)+((b>>16)&255)*f), G=(int)(((a>>8)&255)*(1-f)+((b>>8)&255)*f), Bl=(int)((a&255)*(1-f)+(b&255)*f);
        o[j*W+x]=unchecked((int)0xFF000000)|(R<<16)|(G<<8)|Bl; } }
    var recta=Escribir(o,W,alto);
    int h2=(int)Math.Round(alto*(double)anchoFinal/W);
    var fin=Alfa(Reducir(recta,new Rectangle(0,0,W,alto),anchoFinal,h2)); fin.Save(sal, ImageFormat.Png);
    return string.Format("{0} {1}x{2} (linea: {3} puntos, y = {4:F1} {5:+0.0;-0.0} u {6:+0.0;-0.0} u2)", sal, anchoFinal, h2, n, A, B, C);
  }

  // la bola a punto de estallar: la bola nueva y, encima, solo los rayos blancos de otra pieza
  // (los pixeles casi blancos; lo de color se queda fuera). Se suma la luz sobre negro y luego, alfa.
  public static string Rayos(string bola, string rayos, string sal, int lado, double tamBola){
    var b=new Bitmap(bola); var r=new Bitmap(rayos);
    var rb=Caja(b,14); var rr=Caja(r,14);
    var lienzo=new Bitmap(lado,lado,PixelFormat.Format32bppArgb);
    using (var g=Graphics.FromImage(lienzo)){ g.Clear(Color.Black); g.InterpolationMode=InterpolationMode.HighQualityBicubic; g.PixelOffsetMode=PixelOffsetMode.HighQuality;
      int d=(int)(lado*tamBola); g.DrawImage(b,new Rectangle((lado-d)/2,(lado-d)/2,d,d),rb,GraphicsUnit.Pixel); }
    var lr=Reducir(r,rr,lado,lado); var p=Leer(lienzo); var q=Leer(lr);
    for (int i=0;i<p.Length;i++){ int c=q[i]; int R=(c>>16)&255,G=(c>>8)&255,B=c&255; int mn=Math.Min(R,Math.Min(G,B)), mx=Math.Max(R,Math.Max(G,B));
      if (mx-mn>40 || mn<150) continue;  // con color u oscuro: es el huevo, fuera
      int a=p[i]; int r2=Math.Min(255,((a>>16)&255)+R), g2=Math.Min(255,((a>>8)&255)+G), b2=Math.Min(255,(a&255)+B);
      p[i]=unchecked((int)0xFF000000)|(r2<<16)|(g2<<8)|b2; }
    var fin=Alfa(Escribir(p,lado,lado)); fin.Save(sal, ImageFormat.Png); return sal+" "+lado+"x"+lado;
  }
}
