using System; using System.IO; using System.Diagnostics; using System.Globalization; using System.Text.RegularExpressions;
// Lo mismo que bucle.py, para el PC sin Python: busca el bucle (por espectro, ajustado a un numero
// entero de pulsos), fundido cruzado de 60 ms en el salto, -16 LUFS y OGG con LOOPSTART/LOOPLENGTH.
//   Add-Type -Path bucle.cs; [Bucle]::Hacer(ffmpeg, entrada, salida.ogg, "Titulo", prueba.mp3 o "", carpeta_temporal)
// Las rutas que se le pasan a ffmpeg no pueden llevar tildes.
public static class Bucle {
  const int SR = 44100;
  static string FF, TMP;

  static string Ejecutar(string args){
    var p = new Process(); p.StartInfo = new ProcessStartInfo(FF, args){ UseShellExecute=false, RedirectStandardError=true, RedirectStandardOutput=true, CreateNoWindow=true };
    p.Start(); string err = p.StandardError.ReadToEnd(); p.StandardOutput.ReadToEnd(); p.WaitForExit(); return err;
  }
  static float[] Leer(string f){ var b = File.ReadAllBytes(f); var r = new float[b.Length/4]; Buffer.BlockCopy(b,0,r,0,r.Length*4); return r; }
  static void Escribir(string f, float[] x){ var b = new byte[x.Length*4]; Buffer.BlockCopy(x,0,b,0,b.Length); File.WriteAllBytes(f,b); }

  static void FFT(double[] re, double[] im){
    int n=re.Length;
    for (int i=1,j=0;i<n;i++){ int bit=n>>1; for(;(j&bit)!=0;bit>>=1) j^=bit; j^=bit; if(i<j){ double t=re[i];re[i]=re[j];re[j]=t; t=im[i];im[i]=im[j];im[j]=t; } }
    for (int len=2;len<=n;len<<=1){ double ang=-2*Math.PI/len; double wr=Math.Cos(ang), wi=Math.Sin(ang);
      for (int i=0;i<n;i+=len){ double cr=1, ci=0;
        for (int k=0;k<len/2;k++){ int a=i+k, b=a+len/2; double xr=re[b]*cr-im[b]*ci, xi=re[b]*ci+im[b]*cr;
          re[b]=re[a]-xr; im[b]=im[a]-xi; re[a]+=xr; im[a]+=xi; double t=cr*wr-ci*wi; ci=cr*wi+ci*wr; cr=t; } } }
  }
  // log1p(|rfft|) de cada ventana, centrado y normalizado
  static double[][] Espectro(double[] m, int hop, int n, int lo, int hi, bool normal){
    int nf = (m.Length - n)/hop + 1; var S = new double[nf][]; var han = new double[n];
    for (int i=0;i<n;i++) han[i]=0.5-0.5*Math.Cos(2*Math.PI*i/(n-1));
    var re=new double[n]; var im=new double[n];
    for (int f=0;f<nf;f++){
      for (int i=0;i<n;i++){ re[i]=m[f*hop+i]*han[i]; im[i]=0; } FFT(re,im);
      var v=new double[hi-lo]; double s=0; for (int k=lo;k<hi;k++){ v[k-lo]=Math.Log(1+Math.Sqrt(re[k]*re[k]+im[k]*im[k])); s+=v[k-lo]; }
      if (normal){ s/=v.Length; double q=0; for(int k=0;k<v.Length;k++){ v[k]-=s; q+=v[k]*v[k]; } q=Math.Sqrt(q)+1e-9; for(int k=0;k<v.Length;k++) v[k]/=q; }
      S[f]=v;
    }
    return S;
  }
  static double Dot(double[] a, double[] b){ double s=0; for(int i=0;i<a.Length;i++) s+=a[i]*b[i]; return s; }

  static double Lufs(float[] x){
    string f = Path.Combine(TMP, "lufs.f32"); Escribir(f, x);
    string e = Ejecutar("-hide_banner -f f32le -ar 44100 -ac 2 -i \"" + f + "\" -af ebur128=framelog=quiet -f null -");
    var ms = Regex.Matches(e, @"I:\s+(-?[\d.]+) LUFS"); return double.Parse(ms[ms.Count-1].Groups[1].Value, CultureInfo.InvariantCulture);
  }

  public static string Hacer(string ff, string ent, string sal, string titulo, string prueba, string tmp){
    FF=ff; TMP=tmp; string raw = Path.Combine(tmp, "entrada.f32");
    Ejecutar("-hide_banner -loglevel error -y -i \"" + ent + "\" -map 0:a -ac 2 -ar 44100 -f f32le \"" + raw + "\"");
    var a = Leer(raw); int N = a.Length/2; var m = new double[N]; for (int i=0;i<N;i++) m[i]=(a[2*i]+a[2*i+1])*0.5; double dur=(double)N/SR;
    // pulso: autocorrelacion de la subida de energia
    int HOP=256; var E1 = Espectro(m, HOP, 1024, 0, 513, false); var en=new double[E1.Length]; for(int f=0;f<E1.Length;f++){ double s=0; foreach(var v in E1[f]) s+=v; en[f]=s; }
    var on=new double[en.Length-1]; double mo=0; for(int i=0;i<on.Length;i++){ on[i]=Math.Max(en[i+1]-en[i],0); mo+=on[i]; } mo/=on.Length; for(int i=0;i<on.Length;i++) on[i]-=mo;
    double pulso=0.5, bac=-1e18; for (int lag=1; lag*HOP/(double)SR<1.0; lag++){ double l=lag*HOP/(double)SR; if (l<=0.3) continue; double s=0; for(int i=0;i+lag<on.Length;i++) s+=on[i]*on[i+lag]; if(s>bac){bac=s;pulso=l;} }
    // bucle grueso: 4 s antes del fin parecidos a 4 s antes del inicio
    var S1 = Espectro(m, 1024, 4096, 4, 600, true); double fps=SR/1024.0; int L=(int)(4*fps);
    int e0=(int)((dur-25)*fps), e1=(int)((dur-1.5)*fps), s0=(int)(4*fps), s1=(int)(Math.Min(45, dur*0.45)*fps);
    int ea=e0-L, sa=s0-L; var G = new double[e1-ea, s1-sa];
    for (int e=ea;e<e1;e++) for (int s=sa;s<s1;s++) G[e-ea,s-sa]=Dot(S1[e],S1[s]);
    double mv=-1; int ms_=0, me_=0;
    for (int e=e0;e<e1;e++) for (int s=s0;s<s1;s++){
      if (e-s < Math.Max(40, dur*0.4)*fps) continue;
      double v=0; for (int k=1;k<=L;k++) v+=G[e-k-ea, s-k-sa]; v/=L;
      if (v>mv){ mv=v; ms_=s; me_=e; } }
    int Efin=(int)(me_/fps*SR);
    int nb=(int)Math.Round((Efin - ms_/fps*SR)/SR/pulso); int base_=Efin-(int)Math.Round(nb*pulso*SR);
    // afinado fino del inicio
    var S2 = Espectro(m, 256, 2048, 2, 400, true);
    int r0=(Efin-3*SR)/256, r1=Efin/256, len=r1-r0;
    double bv=-1e18; int S=base_;
    for (int s=base_-900; s<=base_+900; s+=16){ int i=(s-3*SR)/256; double v=0; for(int k=0;k<len;k++) v+=Dot(S2[r0+k],S2[i+k]); v/=len; if(v>bv){bv=v;S=s;} }
    // fundido cruzado y ganancia
    int n=(int)(0.06*SR); var o=new float[Efin*2]; Array.Copy(a,o,Efin*2);
    for (int i=0;i<n;i++){ double w=(double)i/(n-1); for(int c=0;c<2;c++){ int p=(Efin-n+i)*2+c, q=(S-n+i)*2+c; o[p]=(float)(a[p]*(1-w)+a[q]*w); } }
    double g=Math.Pow(10,(-16-Lufs(o))/20); for(int i=0;i<o.Length;i++) o[i]=(float)Math.Max(-1,Math.Min(1,o[i]*g));
    string fo=Path.Combine(tmp,"salida.f32"); Escribir(fo,o);
    Ejecutar("-hide_banner -loglevel error -y -f f32le -ar 44100 -ac 2 -i \"" + fo + "\" -c:a vorbis -strict -2 -ac 2 -q:a 6 -metadata LOOPSTART=" + S + " -metadata LOOPLENGTH=" + (Efin-S) + " -metadata \"TITLE=" + titulo + "\" \"" + sal + "\"");
    if (prueba != ""){ var pr=new float[10*SR*2]; Array.Copy(o,(Efin-5*SR)*2,pr,0,5*SR*2); Array.Copy(o,S*2,pr,5*SR*2,5*SR*2); string fp=Path.Combine(tmp,"prueba.f32"); Escribir(fp,pr);
      Ejecutar("-hide_banner -loglevel error -y -f f32le -ar 44100 -ac 2 -i \"" + fp + "\" -c:a libmp3lame -q:a 2 \"" + prueba + "\""); }
    return string.Format(CultureInfo.InvariantCulture, "duracion original {0:F1} s | {1:F1} bpm | bucle {2:F2} s -> {3:F2} s ({4} pulsos, {5:F2} s) | parecido {6:F3} | final a {7:F1} LUFS",
      dur, 60/pulso, (double)S/SR, (double)Efin/SR, nb, (double)(Efin-S)/SR, bv, Lufs(o));
  }
}
