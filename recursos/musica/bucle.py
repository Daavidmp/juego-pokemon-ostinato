# Prepara una cancion para el juego: busca el bucle (por espectro, ajustado a un numero entero de pulsos),
# fundido cruzado de 60 ms en el salto, ganancia fija a -16 LUFS y OGG con LOOPSTART/LOOPLENGTH.
#   python3 bucle.py entrada.mp3 "Audio/BGM/Nombre.ogg" "Titulo" [prueba.mp3]
import sys, subprocess, re
import numpy as np, imageio_ffmpeg
FF = imageio_ffmpeg.get_ffmpeg_exe(); SR = 44100
ent, sal, titulo = sys.argv[1:4]; prueba = sys.argv[4] if len(sys.argv) > 4 else None
raw = subprocess.run([FF, "-hide_banner", "-loglevel", "error", "-i", ent, "-map", "0:a", "-ac", "2", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True, check=True).stdout
a = np.frombuffer(raw, np.float32).reshape(-1, 2).astype(np.float64); m = a.mean(axis=1); dur = len(m) / SR
def espectro(hop, n, lo, hi):
    fr = np.lib.stride_tricks.sliding_window_view(m, n)[::hop] * np.hanning(n)
    S = np.log1p(np.abs(np.fft.rfft(fr, axis=1))[:, lo:hi]); S -= S.mean(axis=1, keepdims=True)
    return S / (np.linalg.norm(S, axis=1, keepdims=True) + 1e-9)
# pulso
HOP = 256
fr = np.lib.stride_tricks.sliding_window_view(m, 1024)[::HOP]
e = np.log1p(np.abs(np.fft.rfft(fr * np.hanning(1024), axis=1))).sum(axis=1)
on = np.maximum(np.diff(e), 0); on -= on.mean()
ac = np.correlate(on, on, "full")[len(on) - 1:]; lags = np.arange(len(ac)) * HOP / SR
r = (lags > 0.3) & (lags < 1.0); pulso = lags[r][np.argmax(ac[r])]
# bucle grueso: 4 s antes del fin parecidos a 4 s antes del inicio
S1 = espectro(1024, 4096, 4, 600); fps = SR / 1024; L = int(4 * fps)
mejor = (-1, 0, 0)
for e_ in range(int((dur - 25) * fps), int((dur - 1.5) * fps)):
    for s_ in range(int(4 * fps), int(min(45, dur * 0.45) * fps)):
        if e_ - s_ < max(40, dur * 0.4) * fps: continue
        v = (S1[e_ - L:e_] * S1[s_ - L:s_]).sum(axis=1).mean()
        if v > mejor[0]: mejor = (v, s_, e_)
_, s_, e_ = mejor; E = int(e_ / fps * SR)
# largo = numero entero de pulsos, y afinado fino del inicio
nb = round((E - s_ / fps * SR) / SR / pulso); base = E - int(round(nb * pulso * SR))
S2 = espectro(256, 2048, 2, 400); f2 = SR / 256
ref = S2[int((E - 3 * SR) / 256):int(E / 256)]
def sim(s):
    i = int((s - 3 * SR) / 256); return float((ref * S2[i:i + len(ref)]).sum(axis=1).mean())
v, S = max((sim(s), s) for s in range(base - 900, base + 901, 16))
# fundido cruzado y ganancia
n = int(0.06 * SR); w = np.linspace(0, 1, n)[:, None]
out = a[:E].copy(); out[E - n:E] = a[E - n:E] * (1 - w) + a[S - n:S] * w
def lufs(x):
    r = subprocess.run([FF, "-hide_banner", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-", "-af", "ebur128=framelog=quiet", "-f", "null", "-"],
                       input=x.astype(np.float32).tobytes(), capture_output=True).stderr.decode()
    return float(re.findall(r"I:\s+(-?[\d.]+) LUFS", r)[-1])
out *= 10 ** ((-16 - lufs(out)) / 20); out = np.clip(out, -1, 1)
subprocess.run([FF, "-hide_banner", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-", "-c:a", "libvorbis", "-q:a", "6",
                "-metadata", "LOOPSTART=%d" % S, "-metadata", "LOOPLENGTH=%d" % (E - S), "-metadata", "TITLE=" + titulo, sal],
               input=out.astype(np.float32).tobytes(), check=True)
if prueba:
    p = np.concatenate([out[E - 5 * SR:E], out[S:S + 5 * SR]])
    subprocess.run([FF, "-hide_banner", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-", "-c:a", "libmp3lame", "-q:a", "2", prueba],
                   input=p.astype(np.float32).tobytes(), check=True)
print("duracion original %.1f s | %.1f bpm | bucle %.2f s -> %.2f s (%d pulsos, %.2f s) | parecido %.3f | final a %.1f LUFS"
      % (dur, 60 / pulso, S / SR, E / SR, nb, (E - S) / SR, v, lufs(out)))
