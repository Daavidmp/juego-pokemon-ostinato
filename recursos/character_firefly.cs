using System; using System.Drawing; using System.Drawing.Imaging;
// Hoja 4x4 de Firefly (1024, pixel de 8) -> character 256x256: rejilla nativa 128, sin el fondo verde, x2
public static class Hoja {
  public static string Hacer(string ent, string sal){
    var b = new Bitmap(ent); int W=b.Width, H=b.Height;
    var bd=b.LockBits(new Rectangle(0,0,W,H), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    var px=new int[W*H]; System.Runtime.InteropServices.Marshal.Copy(bd.Scan0, px, 0, W*H); b.UnlockBits(bd);
    Func<int,int,Color> C = (x,y) => Color.FromArgb(px[Math.Min(H-1,y)*W+Math.Min(W-1,x)]);
    int mejor=0; double me=1e18;
    for (int o=0;o<8;o++){ double e=0; for (int j=0;j<127;j++) for (int i=0;i<127;i++){ var a=C(o+4+i*8,o+4+j*8); var c=C(o+5+i*8,o+5+j*8); e+=Math.Abs(a.R-c.R)+Math.Abs(a.G-c.G)+Math.Abs(a.B-c.B);} if(e<me){me=e;mejor=o;} }
    var o2 = new Bitmap(256,256,PixelFormat.Format32bppArgb); int quitados=0;
    for (int j=0;j<128;j++) for (int i=0;i<128;i++){
      var c=C(mejor+4+i*8, mejor+4+j*8);
      bool verde = c.G > c.R+25 && c.G > c.B+15 && c.G > 150;
      if (verde){ quitados++; continue; }
      var k=Color.FromArgb(255,c.R,c.G,c.B);
      o2.SetPixel(i*2,j*2,k); o2.SetPixel(i*2+1,j*2,k); o2.SetPixel(i*2,j*2+1,k); o2.SetPixel(i*2+1,j*2+1,k);
    }
    o2.Save(sal, ImageFormat.Png); return "desplazamiento " + mejor + ", fondo " + quitados;
  }
}
