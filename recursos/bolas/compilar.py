from comun import *
import zlib, os
ruta = JUEGO + "/Data/PluginScripts.rxdata"
d = marshal.load_file(ruta)
base = JUEGO + "/Plugins/Ostinato/"
pl = [p for p in d if s(p[0]) == "Pokemon Ostinato"][0]
viejos = {s(x[0]): zlib.decompress(x[1].encode("utf-8", "surrogateescape")) for x in pl[2]}
nuevos = []
for f in sorted(os.listdir(base)):
    if not f.endswith(".rb"): continue
    code = open(base + f, "rb").read().replace(b"\r\n", b"\n")
    if viejos.get(f) != code: print("cambia:", f)
    nuevos.append([f, zlib.compress(code).decode("utf-8", "surrogateescape")])
pl[2] = nuevos
blob = marshal.dump(d); marshal.load(blob); open(ruta, "wb").write(blob)
print("ok", len(nuevos))
